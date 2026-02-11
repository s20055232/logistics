package service

import "time"

// TrackPoint matches the Kafka JSON format from the telemetry service.
type TrackPoint struct {
	ContainerID string    `json:"container_id"`
	Lat         float64   `json:"lat"`
	Lon         float64   `json:"lon"`
	Timestamp   time.Time `json:"timestamp"`
	Speed       float64   `json:"speed"`
}

// GeofenceEvent is published to the geofence.events Kafka topic.
type GeofenceEvent struct {
	ContainerID  string    `json:"container_id"`
	GeofenceID   string    `json:"geofence_id"`
	GeofenceName string    `json:"geofence_name"`
	OwnerID      string    `json:"owner_id"`
	EventType    string    `json:"event_type"` // "enter" or "exit"
	Lat          float64   `json:"lat"`
	Lon          float64   `json:"lon"`
	Timestamp    time.Time `json:"timestamp"`
}
