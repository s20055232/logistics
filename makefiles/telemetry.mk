# Telemetry Service Build and Test
.PHONY: telemetry-build telemetry-test telemetry-test-race telemetry-test-integration
.PHONY: telemetry-test-load telemetry-test-load-headless help-telemetry

# Load test configuration
LOCUST_USERS ?= 50
LOCUST_SPAWN_RATE ?= 10
LOCUST_RUN_TIME ?= 60s
GATEWAY_URL ?= https://localhost:8080

help-telemetry:
	@echo "Telemetry Service"
	@echo ""
	@echo "Build:"
	@echo "  make telemetry-build              - Build the service"
	@echo ""
	@echo "Testing:"
	@echo "  make telemetry-test               - Run all unit tests"
	@echo "  make telemetry-test-race          - Run tests with race detector"
	@echo "  make telemetry-test-integration   - Run integration tests (requires env vars)"
	@echo "  make telemetry-test-load          - Run Locust with web UI (http://localhost:8089)"
	@echo "  make telemetry-test-load-headless - Run Locust headless for CI"
	@echo ""
	@echo "Load test environment variables:"
	@echo "  KEYCLOAK_USERNAME       - Test user (required)"
	@echo "  KEYCLOAK_PASSWORD       - Test password (required)"
	@echo "  KEYCLOAK_URL            - Keycloak URL (default: https://localhost:8443)"
	@echo "  GATEWAY_URL             - Gateway URL (default: https://localhost:8080)"

telemetry-build:
	cd telemetry && go build -o telemetry ./cmd/...

telemetry-test:
	cd telemetry && go test -v ./...

telemetry-test-race:
	cd telemetry && go test -v -race ./...

telemetry-test-integration:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	cd telemetry && go test -v -tags=integration ./...

telemetry-test-load:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	cd telemetry/loadtest && uv run locust --host=$(GATEWAY_URL)

telemetry-test-load-headless:
ifndef KEYCLOAK_USERNAME
	$(error KEYCLOAK_USERNAME required)
endif
ifndef KEYCLOAK_PASSWORD
	$(error KEYCLOAK_PASSWORD required)
endif
	cd telemetry/loadtest && uv run locust \
		--host=$(GATEWAY_URL) \
		--headless \
		--users $(LOCUST_USERS) \
		--spawn-rate $(LOCUST_SPAWN_RATE) \
		--run-time $(LOCUST_RUN_TIME)
