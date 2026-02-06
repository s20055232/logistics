package service

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"
	"sync"

	"golang.org/x/net/websocket"
)

// WSMessage matches frontend/src/types/index.ts
type WSMessage struct {
	Type    string      `json:"type"` // "position", "route", "error"
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
}

// Client represents a connected WebSocket client
type Client struct {
	conn        *websocket.Conn
	containerID string
	send        chan []byte
}

// Hub manages WebSocket clients grouped by containerID
type Hub struct {
	mu      sync.RWMutex
	clients map[string]map[*Client]bool // containerID -> set of clients
}

// NewHub creates a new WebSocket hub
func NewHub() *Hub {
	return &Hub{
		clients: make(map[string]map[*Client]bool),
	}
}

// ServeWS handles WebSocket upgrade and client lifecycle
// URL: /api/track/{containerId}?token={authToken}
func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request) {
	// Extract containerId from path: /api/track/MSCU1234567
	path := strings.TrimPrefix(r.URL.Path, "/api/track/")
	containerID := strings.TrimSuffix(path, "/")
	if containerID == "" {
		http.Error(w, "container_id required", http.StatusBadRequest)
		return
	}

	// Validate token before upgrade (Gateway validates, but check exists)
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "token required", http.StatusUnauthorized)
		return
	}

	// Upgrade to WebSocket
	wsHandler := websocket.Handler(func(conn *websocket.Conn) {
		client := &Client{
			conn:        conn,
			containerID: containerID,
			send:        make(chan []byte, 256),
		}

		h.register(client)
		defer h.unregister(client)

		slog.Info("client connected",
			"container_id", containerID,
			"remote", conn.Request().RemoteAddr)

		// Write pump
		go func() {
			for msg := range client.send {
				if _, err := conn.Write(msg); err != nil {
					return
				}
			}
		}()

		// Read pump (for close detection)
		buf := make([]byte, 512)
		for {
			_, err := conn.Read(buf)
			if err != nil {
				return
			}
		}
	})

	wsHandler.ServeHTTP(w, r)
}

func (h *Hub) register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.clients[c.containerID] == nil {
		h.clients[c.containerID] = make(map[*Client]bool)
	}
	h.clients[c.containerID][c] = true
}

func (h *Hub) unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if clients, ok := h.clients[c.containerID]; ok {
		delete(clients, c)
		close(c.send)
		if len(clients) == 0 {
			delete(h.clients, c.containerID)
		}
	}
	slog.Info("client disconnected", "container_id", c.containerID)
}

// Broadcast sends a message to all clients subscribed to a containerID
func (h *Hub) Broadcast(containerID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		slog.Error("marshal failed", "error", err)
		return
	}

	h.mu.RLock()
	clients := h.clients[containerID]
	h.mu.RUnlock()

	for client := range clients {
		select {
		case client.send <- data:
		default:
			slog.Warn("client buffer full", "container_id", containerID)
		}
	}
}

// CloseAll closes all client connections
func (h *Hub) CloseAll() {
	h.mu.Lock()
	defer h.mu.Unlock()

	for _, clients := range h.clients {
		for client := range clients {
			close(client.send)
			client.conn.Close()
		}
	}
	h.clients = make(map[string]map[*Client]bool)
}
