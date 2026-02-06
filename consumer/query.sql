-- Bulk insert via pgx.CopyFrom (bypass sqlc for performance)
-- name: CreateTrackPoints :copyfrom
INSERT INTO track_points (time, container_id, lat, lon, speed)
VALUES ($1, $2, $3, $4, $5);
-- Latest position per container (map markers)
-- name: GetLatestPositions :many
SELECT DISTINCT ON (container_id) container_id,
    time,
    lat,
    lon,
    speed
FROM track_points
WHERE time > NOW() - INTERVAL '1 hour'
ORDER BY container_id,
    time DESC;
-- Container route for time range (draw polyline)
-- name: GetContainerRoute :many
SELECT time,
    lat,
    lon,
    speed
FROM track_points
WHERE container_id = $1
    AND time BETWEEN $2 AND $3
ORDER BY time;