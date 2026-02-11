package service

import "time"

// GeofenceEvent matches the JSON format from the ruleengine's geofence.events topic.
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
