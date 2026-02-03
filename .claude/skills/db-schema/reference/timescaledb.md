# TimescaleDB Reference

TimescaleDB extends PostgreSQL for time-series data. This project uses it for telemetry tracking.

## Hypertables

A hypertable is a virtual table that automatically partitions data by time.

### Create Hypertable

```sql
-- 1. Create regular table first
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL
);

-- 2. Convert to hypertable
SELECT create_hypertable(
    'metrics',
    'time',
    chunk_time_interval => INTERVAL '7 days'
);
```

### Chunk Interval Guidelines

| Data Volume | Recommended Interval |
|-------------|---------------------|
| < 10GB/day  | 7 days              |
| 10-100GB/day| 1 day               |
| > 100GB/day | 1-12 hours          |

## Compression

Compress old data to save storage (10-20x reduction typical).

### Enable Compression

```sql
-- Configure compression
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

-- Auto-compress chunks older than 1 day
SELECT add_compression_policy('metrics', INTERVAL '1 day');
```

### Compression Settings

- `compress_segmentby`: Column(s) you filter by most (e.g., device_id, container_id)
- `compress_orderby`: Usually `time DESC` for recent-first queries

### Disable Compression (Down Migration)

```sql
SELECT remove_compression_policy('metrics');
ALTER TABLE metrics SET (timescaledb.compress = false);
```

## Retention Policy

Automatically delete old data.

```sql
-- Delete data older than 30 days
SELECT add_retention_policy('metrics', INTERVAL '30 days');
```

### Remove Retention (Down Migration)

```sql
SELECT remove_retention_policy('metrics');
```

## Indexing

Hypertables support regular PostgreSQL indexes.

```sql
-- Composite index for common query pattern
CREATE INDEX metrics_device_time_idx ON metrics (device_id, time DESC);
```

**Best practice**: Put the `segmentby` column first, then `time DESC`.

## Complete Migration Example

**000006_sensor_metrics.up.sql**
```sql
CREATE TABLE sensor_metrics (
    time TIMESTAMPTZ NOT NULL,
    sensor_id TEXT NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    CONSTRAINT valid_temperature CHECK (temperature BETWEEN -50 AND 150),
    CONSTRAINT valid_humidity CHECK (humidity BETWEEN 0 AND 100)
);

SELECT create_hypertable(
    'sensor_metrics',
    'time',
    chunk_time_interval => INTERVAL '7 days'
);

CREATE INDEX sensor_metrics_sensor_time_idx ON sensor_metrics (sensor_id, time DESC);

ALTER TABLE sensor_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('sensor_metrics', INTERVAL '1 day');
SELECT add_retention_policy('sensor_metrics', INTERVAL '90 days');
```

**000006_sensor_metrics.down.sql**
```sql
SELECT remove_retention_policy('sensor_metrics');
SELECT remove_compression_policy('sensor_metrics');
DROP TABLE IF EXISTS sensor_metrics;
```

## Useful Queries

### Check Chunk Info

```sql
SELECT * FROM timescaledb_information.chunks
WHERE hypertable_name = 'metrics';
```

### Check Compression Status

```sql
SELECT * FROM timescaledb_information.compressed_chunk_stats
WHERE hypertable_name = 'metrics';
```

### Check Policies

```sql
SELECT * FROM timescaledb_information.jobs
WHERE hypertable_name = 'metrics';
```
