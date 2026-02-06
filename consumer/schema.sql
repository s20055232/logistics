-- Enable UUIDv7 extension (time-ordered, no index fragmentation)
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;
-- Container metadata (UUIDv7 for distributed system elasticity)
CREATE TABLE containers (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    -- ISO 6346 code like "MSCU1234567"
    container_id TEXT NOT NULL UNIQUE,
    -- Shipping line
    owner TEXT,
    -- 20ft, 40ft, 40ft-HC, reefer
    container_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Index for lookups (Supabase: query-missing-indexes)
CREATE INDEX containers_container_id_idx ON containers (container_id);
-- Enable extensions (already in deployment.yaml postInitSQL)
CREATE EXTENSION IF NOT EXISTS timescaledb;
-- Telemetry data from IoT devices on containers
CREATE TABLE track_points (
    -- Partition column (Supabase: always use timestamptz)
    time TIMESTAMPTZ NOT NULL,
    -- Segment column for compression
    container_id TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    -- km/h, nullable
    speed DOUBLE PRECISION,
    -- No separate PK - TimescaleDB uses (time, container_id) as natural key
    CONSTRAINT valid_speed CHECK (
        speed IS NULL
        OR speed >= 0
    )
);
-- Convert to hypertable (7-day chunks for 30-day retention)
SELECT create_hypertable(
        'track_points',
        'time',
        chunk_time_interval => INTERVAL '7 days'
    );
-- Composite index: container + time range queries (most common pattern)
-- Supabase: query-composite-indexes - equality column first, range column last
CREATE INDEX track_points_container_time_idx ON track_points (container_id, time DESC);
-- Spatial index for "find containers near location" queries
CREATE INDEX track_points_location_idx ON track_points USING GIST (location);
-- Enable compression with segmentby for efficient queries
ALTER TABLE track_points
SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'container_id',
        timescaledb.compress_orderby = 'time DESC'
    );
-- Auto-compress chunks older than 1 day
-- 90%+ storage reduction
SELECT add_compression_policy('track_points', INTERVAL '1 day');
-- Hourly summary per container (for dashboard)
-- While access to the data stored in a materialized view is often much faster than accessing the underlying tables directly or through a view, the data is not always current
CREATE MATERIALIZED VIEW track_points_hourly WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
    container_id,
    COUNT(*) AS point_count,
    AVG(speed) AS avg_speed,
    MAX(speed) AS max_speed,
    ST_MakeLine(
        location::geometry
        ORDER BY time
    ) AS route_line
FROM track_points
GROUP BY bucket,
    container_id WITH NO DATA;
-- Refresh policy: update every 30 minutes, keep data up to 1 hour old
SELECT add_continuous_aggregate_policy(
        'track_points_hourly',
        start_offset => INTERVAL '3 hours',
        end_offset => INTERVAL '1 hour',
        schedule_interval => INTERVAL '30 minutes'
    );
-- Auto-delete data older than 30 days
SELECT add_retention_policy('track_points', INTERVAL '30 days');