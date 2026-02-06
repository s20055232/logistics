SELECT remove_retention_policy('track_points', if_exists => true);
SELECT remove_compression_policy('track_points', if_exists => true);
ALTER TABLE track_points
SET (timescaledb.compress = false);