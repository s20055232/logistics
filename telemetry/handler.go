package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
)

func writeError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

type Producer interface {
	Write(ctx context.Context, tp TrackPoint) error
	Close() error
}

// Handler processes incoming GPS data.
type Handler struct {
	producer Producer
}

// NewHandler creates a handler with the given producer.
func NewHandler(p Producer) *Handler {
	return &Handler{producer: p}
}

// ServeHTTP handles POST /track.
// Always expects an array of TrackPoints.
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST only", http.StatusMethodNotAllowed)
		return
	}

	// Use slice instead of single TrackPoint for batch processing:
	// GPS devices buffer points locally and upload in batches (real-world behavior)
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
			slog.Error("kafka write failed",
				"error", err,
				"container_id", tp.ContainerID,
				"request_id", r.Header.Get("X-Request-ID"),
			)
			writeError(w, http.StatusServiceUnavailable, "service temporarily unavailable")
			return
		}
	}

	w.WriteHeader(http.StatusAccepted)
}
