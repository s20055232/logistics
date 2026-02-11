-- Test geofences for development
-- Run after migrations: psql $DATABASE_URL -f seed.sql

-- Kaohsiung Port (Taiwan)
INSERT INTO geofences (name, owner_id, boundary) VALUES (
    'Kaohsiung Port',
    'dev-owner',
    ST_GeomFromGeoJSON('{"type":"Polygon","coordinates":[[[120.28,22.61],[120.32,22.61],[120.32,22.64],[120.28,22.64],[120.28,22.61]]]}')
);

-- Taoyuan Distribution Center (Taiwan)
INSERT INTO geofences (name, owner_id, boundary) VALUES (
    'Taoyuan Distribution Center',
    'dev-owner',
    ST_GeomFromGeoJSON('{"type":"Polygon","coordinates":[[[121.20,25.00],[121.24,25.00],[121.24,25.03],[121.20,25.03],[121.20,25.00]]]}')
);

-- Port of Rotterdam (Netherlands)
INSERT INTO geofences (name, owner_id, boundary) VALUES (
    'Port of Rotterdam',
    'dev-owner',
    ST_GeomFromGeoJSON('{"type":"Polygon","coordinates":[[[3.95,51.88],[4.10,51.88],[4.10,51.96],[3.95,51.96],[3.95,51.88]]]}')
);
