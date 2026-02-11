-- Find all enabled geofences containing a given point
-- $1 = longitude, $2 = latitude (PostGIS ST_MakePoint takes x,y = lon,lat)
-- name: FindContainingGeofences :many
SELECT id, name, owner_id
FROM geofences
WHERE enabled = TRUE
  AND ST_Contains(boundary, ST_SetSRID(ST_MakePoint($1, $2), 4326));

-- Get current state for a (container, geofence) pair
-- name: GetState :one
SELECT inside, updated_at
FROM geofence_states
WHERE container_id = $1
  AND geofence_id = $2;

-- Supabase: data-upsert — atomic INSERT ... ON CONFLICT, no race condition
-- name: UpsertState :exec
INSERT INTO geofence_states (container_id, geofence_id, inside, updated_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (container_id, geofence_id)
DO UPDATE SET inside = $3, updated_at = NOW();

-- All geofences where a container is currently "inside" (for EXIT detection)
-- name: GetInsideStates :many
SELECT gs.geofence_id, g.name, g.owner_id
FROM geofence_states gs
JOIN geofences g ON g.id = gs.geofence_id
WHERE gs.container_id = $1
  AND gs.inside = TRUE
  AND g.enabled = TRUE;
