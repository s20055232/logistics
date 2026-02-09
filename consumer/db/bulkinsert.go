package db

import (
	"context"

	"github.com/jackc/pgx/v5"
)

// sqlc can't handle PostGIS `GEOGRAPHY` type well, so we need to manual COPY for maximum performance
func (q *Queries) BulkInsertTrackPoints(ctx context.Context, points []TrackPoint) error {
	_, err := q.db.CopyFrom(
		ctx,
		pgx.Identifier{"track_points"},
		[]string{"time", "container_id", "lat", "lon", "speed"},
		pgx.CopyFromSlice(len(points), func(i int) ([]any, error) {
			p := points[i]
			return []any{p.Time, p.ContainerID, p.Lat, p.Lon, p.Speed}, nil
		}),
	)
	return err
}
