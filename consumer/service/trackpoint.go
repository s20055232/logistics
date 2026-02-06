package service

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	consumer "github.com/lai/logistics/consumer/db"
)

// TrackPoint matches the Kafka message format from telemetry service
type TrackPoint struct {
	ContainerID string    `json:"container_id"`
	Lat         float64   `json:"lat"`
	Lon         float64   `json:"lon"`
	Timestamp   time.Time `json:"timestamp"`
	Speed       float64   `json:"speed"`
}

// BulkInsert converts TrackPoints to sqlc params and inserts via CopyFrom
func BulkInsert(ctx context.Context, q *consumer.Queries, points []TrackPoint) error {
	dbPoints := make([]consumer.TrackPoint, len(points))
	for i, p := range points {
		dbPoints[i] = consumer.TrackPoint{
			Time:        pgtype.Timestamptz{Time: p.Timestamp, Valid: true},
			ContainerID: p.ContainerID,
			Lat:         p.Lat,
			Lon:         p.Lon,
			Speed:       pgtype.Float8{Float64: p.Speed, Valid: true},
		}
	}
	return q.BulkInsertTrackPoints(ctx, dbPoints)
}
