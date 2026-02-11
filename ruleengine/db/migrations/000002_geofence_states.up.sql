CREATE TABLE IF NOT EXISTS geofence_states (
    container_id TEXT NOT NULL,
    geofence_id UUID NOT NULL REFERENCES geofences(id) ON DELETE CASCADE,
    inside BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (container_id, geofence_id)
);

CREATE INDEX IF NOT EXISTS geofence_states_geofence_id_idx ON geofence_states (geofence_id);
