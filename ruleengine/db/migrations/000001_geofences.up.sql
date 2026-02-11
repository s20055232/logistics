CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;

CREATE TABLE IF NOT EXISTS geofences (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    name TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS geofences_boundary_idx ON geofences USING GIST (boundary) WHERE enabled = TRUE;
CREATE INDEX IF NOT EXISTS geofences_owner_idx ON geofences (owner_id);
