-- Idempotent compression setup
DO $$ BEGIN -- Enable compression if not already enabled
IF NOT EXISTS (
    SELECT 1
    FROM timescaledb_information.hypertables
    WHERE hypertable_name = 'track_points'
        AND compression_enabled = true
) THEN
ALTER TABLE track_points
SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'container_id',
        timescaledb.compress_orderby = 'time DESC'
    );
END IF;
-- Add policies if not exist
IF NOT EXISTS (
    SELECT 1
    FROM timescaledb_information.jobs
    WHERE hypertable_name = 'track_points'
        AND proc_name = 'policy_compression'
) THEN PERFORM add_compression_policy('track_points', INTERVAL '1 day');
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM timescaledb_information.jobs
    WHERE hypertable_name = 'track_points'
        AND proc_name = 'policy_retention'
) THEN PERFORM add_retention_policy('track_points', INTERVAL '30 days');
END IF;
END $$;