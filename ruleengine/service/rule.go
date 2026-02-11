package service

import (
	"context"
	"errors"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/lai/logistics/ruleengine/db"
)

type RuleEngine struct {
	queries  *db.Queries
	producer *EventProducer
}

func NewRuleEngine(queries *db.Queries, producer *EventProducer) *RuleEngine {
	return &RuleEngine{queries: queries, producer: producer}
}

func (e *RuleEngine) EvaluateBatch(ctx context.Context, points []TrackPoint) {
	for _, p := range points {
		if err := e.evaluatePoint(ctx, p); err != nil {
			slog.Error("evaluate point failed",
				"container_id", p.ContainerID,
				"error", err,
			)
		}
	}
}

func (e *RuleEngine) evaluatePoint(ctx context.Context, p TrackPoint) error {
	// ST_MakePoint takes (lon, lat), not (lat, lon)
	containing, err := e.queries.FindContainingGeofences(ctx, db.FindContainingGeofencesParams{
		StMakepoint:   p.Lon,
		StMakepoint_2: p.Lat,
	})
	if err != nil {
		return err
	}

	// Set of geofence IDs the point is currently inside
	insideNow := make(map[string]db.FindContainingGeofencesRow, len(containing))
	for _, g := range containing {
		id, _ := g.ID.Value()
		insideNow[id.(string)] = g
	}

	// ENTER detection: for each containing geofence, check previous state
	for idStr, gf := range insideNow {
		state, err := e.queries.GetState(ctx, db.GetStateParams{
			ContainerID: p.ContainerID,
			GeofenceID:  gf.ID,
		})

		wasInside := err == nil && state.Inside

		if errors.Is(err, pgx.ErrNoRows) {
			err = nil
		}
		if err != nil {
			slog.Error("get state failed", "error", err)
			continue
		}

		if !wasInside {
			evt := GeofenceEvent{
				ContainerID:  p.ContainerID,
				GeofenceID:   idStr,
				GeofenceName: gf.Name,
				OwnerID:      gf.OwnerID,
				EventType:    "enter",
				Lat:          p.Lat,
				Lon:          p.Lon,
				Timestamp:    p.Timestamp,
			}
			if pubErr := e.producer.Publish(ctx, evt); pubErr != nil {
				slog.Error("publish enter event failed", "error", pubErr)
			}
			slog.Info("geofence enter",
				"container_id", p.ContainerID,
				"geofence", gf.Name,
			)
		}

		if upsertErr := e.queries.UpsertState(ctx, db.UpsertStateParams{
			ContainerID: p.ContainerID,
			GeofenceID:  gf.ID,
			Inside:      true,
		}); upsertErr != nil {
			slog.Error("upsert state failed", "error", upsertErr)
		}
	}

	// EXIT detection: find geofences where container was inside but is no longer
	insideStates, err := e.queries.GetInsideStates(ctx, p.ContainerID)
	if err != nil {
		return err
	}

	for _, s := range insideStates {
		id, _ := s.GeofenceID.Value()
		idStr := id.(string)

		if _, stillInside := insideNow[idStr]; !stillInside {
			evt := GeofenceEvent{
				ContainerID:  p.ContainerID,
				GeofenceID:   idStr,
				GeofenceName: s.Name,
				OwnerID:      s.OwnerID,
				EventType:    "exit",
				Lat:          p.Lat,
				Lon:          p.Lon,
				Timestamp:    p.Timestamp,
			}
			if pubErr := e.producer.Publish(ctx, evt); pubErr != nil {
				slog.Error("publish exit event failed", "error", pubErr)
			}
			slog.Info("geofence exit",
				"container_id", p.ContainerID,
				"geofence", s.Name,
			)

			if upsertErr := e.queries.UpsertState(ctx, db.UpsertStateParams{
				ContainerID: p.ContainerID,
				GeofenceID:  s.GeofenceID,
				Inside:      false,
			}); upsertErr != nil {
				slog.Error("upsert state failed", "error", upsertErr)
			}
		}
	}

	return nil
}
