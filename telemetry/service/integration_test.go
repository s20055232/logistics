//go:build integration

package service

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"
)

// Required environment variables for integration tests:
//
//	KEYCLOAK_URL      - Keycloak server URL (e.g., https://auth.example.com)
//	KEYCLOAK_REALM    - Keycloak realm name
//	KEYCLOAK_CLIENT   - Client ID for authentication
//	KEYCLOAK_USERNAME - Test user username
//	KEYCLOAK_PASSWORD - Test user password
//	GATEWAY_URL       - API gateway URL (e.g., https://logistics.example.com)
//
// Run with: go test -v -tags=integration ./service/...

func getEnvOrSkip(t *testing.T, key string) string {
	t.Helper()
	val := os.Getenv(key)
	if val == "" {
		t.Skipf("skipping: %s not set", key)
	}
	return val
}

type keycloakConfig struct {
	url      string
	realm    string
	clientID string
	username string
	password string
}

func loadKeycloakConfig(t *testing.T) keycloakConfig {
	t.Helper()
	return keycloakConfig{
		url:      getEnvOrSkip(t, "KEYCLOAK_URL"),
		realm:    getEnvOrSkip(t, "KEYCLOAK_REALM"),
		clientID: getEnvOrSkip(t, "KEYCLOAK_CLIENT"),
		username: getEnvOrSkip(t, "KEYCLOAK_USERNAME"),
		password: getEnvOrSkip(t, "KEYCLOAK_PASSWORD"),
	}
}

func getToken(t *testing.T, cfg keycloakConfig) string {
	t.Helper()

	tokenURL := fmt.Sprintf("%s/auth/realms/%s/protocol/openid-connect/token",
		cfg.url, cfg.realm)

	data := url.Values{}
	data.Set("grant_type", "password")
	data.Set("client_id", cfg.clientID)
	data.Set("username", cfg.username)
	data.Set("password", cfg.password)

	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // for dev/test only
		},
	}

	resp, err := client.Post(tokenURL, "application/x-www-form-urlencoded", strings.NewReader(data.Encode()))
	if err != nil {
		t.Fatalf("failed to get token: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("token request failed: status=%d body=%s", resp.StatusCode, body)
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		t.Fatalf("failed to decode token response: %v", err)
	}

	if tokenResp.AccessToken == "" {
		t.Fatal("received empty access token")
	}

	return tokenResp.AccessToken
}

func callAPI(t *testing.T, gatewayURL, token string, payload []TrackPoint) *http.Response {
	t.Helper()

	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("failed to marshal payload: %v", err)
	}

	req, err := http.NewRequest(http.MethodPost, gatewayURL+"/api/track", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // for dev/test only
		},
	}

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("API request failed: %v", err)
	}

	return resp
}

func TestIntegration_ValidRequest(t *testing.T) {
	cfg := loadKeycloakConfig(t)
	gatewayURL := getEnvOrSkip(t, "GATEWAY_URL")

	token := getToken(t, cfg)

	payload := []TrackPoint{
		{
			ContainerID: "MSKU1234567",
			Lat:         25.0330,
			Lon:         121.5654,
			Timestamp:   time.Now(),
			Speed:       45.5,
		},
	}

	resp := callAPI(t, gatewayURL, token, payload)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("got status %d, want %d; body=%s", resp.StatusCode, http.StatusAccepted, body)
	}
}

func TestIntegration_BatchRequest(t *testing.T) {
	cfg := loadKeycloakConfig(t)
	gatewayURL := getEnvOrSkip(t, "GATEWAY_URL")

	token := getToken(t, cfg)

	payload := []TrackPoint{
		{ContainerID: "MSKU1234567", Lat: 25.0330, Lon: 121.5654, Timestamp: time.Now(), Speed: 45.5},
		{ContainerID: "MSKU1234567", Lat: 25.0340, Lon: 121.5670, Timestamp: time.Now(), Speed: 48.2},
		{ContainerID: "TCLU7654321", Lat: 22.6273, Lon: 120.3014, Timestamp: time.Now(), Speed: 0.0},
	}

	resp := callAPI(t, gatewayURL, token, payload)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("got status %d, want %d; body=%s", resp.StatusCode, http.StatusAccepted, body)
	}
}

func TestIntegration_NoAuthToken(t *testing.T) {
	gatewayURL := getEnvOrSkip(t, "GATEWAY_URL")

	payload := []TrackPoint{
		{ContainerID: "MSKU1234567", Lat: 25.0330, Lon: 121.5654, Timestamp: time.Now(), Speed: 45.5},
	}

	resp := callAPI(t, gatewayURL, "", payload)
	defer resp.Body.Close()

	// Expect 401 Unauthorized without token
	if resp.StatusCode != http.StatusUnauthorized {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("got status %d, want %d; body=%s", resp.StatusCode, http.StatusUnauthorized, body)
	}
}

func TestIntegration_InvalidToken(t *testing.T) {
	gatewayURL := getEnvOrSkip(t, "GATEWAY_URL")

	payload := []TrackPoint{
		{ContainerID: "MSKU1234567", Lat: 25.0330, Lon: 121.5654, Timestamp: time.Now(), Speed: 45.5},
	}

	resp := callAPI(t, gatewayURL, "invalid.token.here", payload)
	defer resp.Body.Close()

	// Expect 401 Unauthorized with invalid token
	if resp.StatusCode != http.StatusUnauthorized {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("got status %d, want %d; body=%s", resp.StatusCode, http.StatusUnauthorized, body)
	}
}

func TestIntegration_InvalidPayload(t *testing.T) {
	cfg := loadKeycloakConfig(t)
	gatewayURL := getEnvOrSkip(t, "GATEWAY_URL")

	token := getToken(t, cfg)

	// Invalid: empty container_id
	payload := []TrackPoint{
		{ContainerID: "", Lat: 25.0330, Lon: 121.5654, Timestamp: time.Now(), Speed: 45.5},
	}

	resp := callAPI(t, gatewayURL, token, payload)
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusBadRequest {
		body, _ := io.ReadAll(resp.Body)
		t.Errorf("got status %d, want %d; body=%s", resp.StatusCode, http.StatusBadRequest, body)
	}
}
