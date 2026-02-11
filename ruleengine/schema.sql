-- Geofencing Rule Engine Schema
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;

-- Geofence definitions (Supabase: schema-primary-keys — UUIDv7, time-ordered, no fragmentation)
CREATE TABLE geofences (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    name TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    -- PostGIS polygon boundary (SRID 4326 = WGS84, standard GPS)
    boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Supabase: query-partial-indexes — only index enabled geofences
CREATE INDEX geofences_boundary_idx ON geofences USING GIST (boundary) WHERE enabled = TRUE;
CREATE INDEX geofences_owner_idx ON geofences (owner_id);

-- Last-known state per (container, geofence) pair
-- Prevents alert fatigue: only fires on state CHANGE (FR2)
CREATE TABLE geofence_states (
    container_id TEXT NOT NULL,
    geofence_id UUID NOT NULL REFERENCES geofences(id) ON DELETE CASCADE,
    inside BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (container_id, geofence_id)
);

-- Supabase: schema-foreign-key-indexes — PK is (container_id, geofence_id),
-- CASCADE delete needs lookup by geofence_id alone
CREATE INDEX geofence_states_geofence_id_idx ON geofence_states (geofence_id);
