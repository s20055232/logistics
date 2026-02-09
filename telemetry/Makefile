.PHONY: test test-unit test-integration test-load test-load-headless build help
.DEFAULT_GOAL := help

help:
	@echo "Telemetry Service"
	@echo ""
	@echo "Build:"
	@echo "  make build              - Build the service"
	@echo ""
	@echo "Testing:"
	@echo "  make test               - Run all unit tests"
	@echo "  make test-race          - Run tests with race detector"
	@echo "  make test-integration   - Run integration tests (requires env vars)"
	@echo "  make test-load          - Run Locust with web UI (http://localhost:8089)"
	@echo "  make test-load-headless - Run Locust headless for CI"
	@echo ""
	@echo "Load test environment variables:"
	@echo "  KEYCLOAK_USERNAME       - Test user (required)"
	@echo "  KEYCLOAK_PASSWORD       - Test password (required)"
	@echo "  KEYCLOAK_URL            - Keycloak URL (default: https://localhost:8443)"
	@echo "  GATEWAY_URL             - Gateway URL (default: https://localhost:8080)"

build:
	go build -o telemetry ./cmd/...

# Unit tests
test:
	go test -v ./...

test-race:
	go test -v -race ./...

# Integration tests (requires Keycloak + Gateway)
test-integration:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	go test -v -tags=integration ./...

# Load tests with Locust
LOCUST_USERS ?= 50
LOCUST_SPAWN_RATE ?= 10
LOCUST_RUN_TIME ?= 60s
GATEWAY_URL ?= https://localhost:8080

test-load:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	cd loadtest && uv run locust --host=$(GATEWAY_URL)

test-load-headless:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	cd loadtest && uv run locust \
		--host=$(GATEWAY_URL) \
		--headless \
		--users $(LOCUST_USERS) \
		--spawn-rate $(LOCUST_SPAWN_RATE) \
		--run-time $(LOCUST_RUN_TIME)
