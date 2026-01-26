package main

import (
	"errors"
	"time"
)

// TrackPoint is a single GPS measurement from a container.
type TrackPoint struct {
	ContainerID string    `json:"container_id"`
	Lat         float64   `json:"lat"`
	Lon         float64   `json:"lon"`
	Timestamp   time.Time `json:"timestamp"`
	Speed       float64   `json:"speed"`
}

// Valid returns an error if the TrackPoint is invalid.
func (t TrackPoint) Valid() error {
	if t.ContainerID == "" {
		return errors.New("container_id required")
	}
	if t.Lat < -90 || t.Lat > 90 {
		return errors.New("lat out of range")
	}
	if t.Lon < -180 || t.Lon > 180 {
		return errors.New("lon out of range")
	}
	if t.Timestamp.IsZero() {
		return errors.New("timestamp required")
	}
	if t.Speed < 0 {
		return errors.New("speed cannot be negative")
	}
	return nil
}
