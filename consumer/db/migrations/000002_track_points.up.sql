CREATE TABLE IF NOT EXISTS track_points (
    time TIMESTAMPTZ NOT NULL,
    container_id TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION,
    CONSTRAINT valid_speed CHECK (
        speed IS NULL
        OR speed >= 0
    )
);
-- Idempotent hypertable creation
SELECT create_hypertable(
        'track_points',
        'time',
        chunk_time_interval => INTERVAL '7 days',
        if_not_exists => TRUE
    );
CREATE INDEX IF NOT EXISTS track_points_container_time_idx ON track_points (container_id, time DESC);