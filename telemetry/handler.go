package main

import (
	"encoding/json"
	"net/http"
)

// Handler processes incoming GPS data.
type Handler struct {
	producer *Producer
}

// NewHandler creates a handler with the given producer.
func NewHandler(p *Producer) *Handler {
	return &Handler{producer: p}
}

// ServeHTTP handles POST /track.
// Always expects an array of TrackPoints.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST only", http.StatusMethodNotAllowed)
		return
	}

	var points []TrackPoint
	if err := json.NewDecoder(r.Body).Decode(&points); err != nil {
		http.Error(w, "invalid JSON: expected array", http.StatusBadRequest)
		return
	}

	for _, tp := range points {
		if err := tp.Valid(); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := h.producer.Write(r.Context(), tp); err != nil {
			http.Error(w, "write failed", http.StatusInternalServerError)
			return
		}
	}

	w.WriteHeader(http.StatusAccepted)
}
