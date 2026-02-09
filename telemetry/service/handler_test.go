package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

// mockProducer implements Producer for testing.
type mockProducer struct {
	written []TrackPoint
	err     error
}

func (m *mockProducer) Write(ctx context.Context, tp TrackPoint) error {
	if m.err != nil {
		return m.err
	}
	m.written = append(m.written, tp)
	return nil
}

func (m *mockProducer) Close() error {
	return nil
}

func validTrackPoint() TrackPoint {
	return TrackPoint{
		ContainerID: "MSKU1234567",
		Lat:         25.0330,
		Lon:         121.5654,
		Timestamp:   time.Now(),
		Speed:       45.5,
	}
}

func TestHandler_ServeHTTP(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		body       any
		prodErr    error
		wantStatus int
	}{
		{
			name:       "valid single point",
			method:     http.MethodPost,
			body:       []TrackPoint{validTrackPoint()},
			wantStatus: http.StatusAccepted,
		},
		{
			name:   "valid batch",
			method: http.MethodPost,
			body: []TrackPoint{
				validTrackPoint(),
				{ContainerID: "TCLU7654321", Lat: 22.6273, Lon: 120.3014, Timestamp: time.Now(), Speed: 0},
				{ContainerID: "HLXU9876543", Lat: 24.1234, Lon: 120.5678, Timestamp: time.Now(), Speed: 30.5},
			},
			wantStatus: http.StatusAccepted,
		},
		{
			name:       "wrong method GET",
			method:     http.MethodGet,
			body:       nil,
			wantStatus: http.StatusMethodNotAllowed,
		},
		{
			name:       "wrong method PUT",
			method:     http.MethodPut,
			body:       []TrackPoint{validTrackPoint()},
			wantStatus: http.StatusMethodNotAllowed,
		},
		{
			name:       "invalid JSON",
			method:     http.MethodPost,
			body:       "{broken",
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "empty array",
			method:     http.MethodPost,
			body:       []TrackPoint{},
			wantStatus: http.StatusAccepted, // empty batch is valid, just does nothing
		},
		{
			name:   "empty container_id",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "", Lat: 25.0, Lon: 121.0, Timestamp: time.Now(), Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "lat too high",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: 91.0, Lon: 121.0, Timestamp: time.Now(), Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "lat too low",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: -91.0, Lon: 121.0, Timestamp: time.Now(), Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "lon too high",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: 25.0, Lon: 181.0, Timestamp: time.Now(), Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "lon too low",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: 25.0, Lon: -181.0, Timestamp: time.Now(), Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "negative speed",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: 25.0, Lon: 121.0, Timestamp: time.Now(), Speed: -1},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:   "zero timestamp",
			method: http.MethodPost,
			body: []TrackPoint{
				{ContainerID: "TEST123", Lat: 25.0, Lon: 121.0, Timestamp: time.Time{}, Speed: 10},
			},
			wantStatus: http.StatusBadRequest,
		},
		{
			name:       "producer error",
			method:     http.MethodPost,
			body:       []TrackPoint{validTrackPoint()},
			prodErr:    errors.New("kafka unavailable"),
			wantStatus: http.StatusServiceUnavailable,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mock := &mockProducer{err: tt.prodErr}
			h := NewHandler(mock)

			var body []byte
			switch v := tt.body.(type) {
			case string:
				body = []byte(v)
			case nil:
				body = nil
			default:
				var err error
				body, err = json.Marshal(v)
				if err != nil {
					t.Fatalf("failed to marshal body: %v", err)
				}
			}

			req := httptest.NewRequest(tt.method, "/track", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()

			h.ServeHTTP(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("got status %d, want %d", rec.Code, tt.wantStatus)
			}
		})
	}
}

func TestHandler_WritesAllPoints(t *testing.T) {
	mock := &mockProducer{}
	h := NewHandler(mock)

	points := []TrackPoint{
		{ContainerID: "A", Lat: 10, Lon: 20, Timestamp: time.Now(), Speed: 1},
		{ContainerID: "B", Lat: 11, Lon: 21, Timestamp: time.Now(), Speed: 2},
		{ContainerID: "C", Lat: 12, Lon: 22, Timestamp: time.Now(), Speed: 3},
	}

	body, _ := json.Marshal(points)
	req := httptest.NewRequest(http.MethodPost, "/track", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusAccepted {
		t.Fatalf("got status %d, want %d", rec.Code, http.StatusAccepted)
	}

	if len(mock.written) != 3 {
		t.Errorf("got %d written points, want 3", len(mock.written))
	}

	for i, got := range mock.written {
		if got.ContainerID != points[i].ContainerID {
			t.Errorf("point %d: got ContainerID %q, want %q", i, got.ContainerID, points[i].ContainerID)
		}
	}
}

func TestHandler_StopsOnFirstInvalid(t *testing.T) {
	mock := &mockProducer{}
	h := NewHandler(mock)

	// Second point is invalid
	points := []TrackPoint{
		{ContainerID: "VALID", Lat: 10, Lon: 20, Timestamp: time.Now(), Speed: 1},
		{ContainerID: "", Lat: 10, Lon: 20, Timestamp: time.Now(), Speed: 1}, // invalid
		{ContainerID: "ALSO_VALID", Lat: 10, Lon: 20, Timestamp: time.Now(), Speed: 1},
	}

	body, _ := json.Marshal(points)
	req := httptest.NewRequest(http.MethodPost, "/track", bytes.NewReader(body))
	rec := httptest.NewRecorder()

	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want %d", rec.Code, http.StatusBadRequest)
	}

	// Only the first point should be written before validation fails
	if len(mock.written) != 1 {
		t.Errorf("got %d written points, want 1 (should stop on first invalid)", len(mock.written))
	}
}
