# Telemetry Service

GPS track point ingestion service for the RouteMaster NL logistics platform. Receives GPS data via HTTP and produces to Kafka.

## Architecture

```text
GPS Devices → HTTP POST /track → Telemetry Service → Kafka (container.telemetry)
```

## Data Format

POST JSON array to `/track`:

```json
[
  {
    "container_id": "C001",
    "lat": 25.033,
    "lon": 121.565,
    "timestamp": "2026-01-23T10:00:00Z",
    "speed": 5.2
  }
]
```

| Field          | Type    | Description                              |
| -------------- | ------- | ---------------------------------------- |
| `container_id` | string  | Shipping container identifier (required) |
| `lat`          | float64 | Latitude, -90 to 90 (required)           |
| `lon`          | float64 | Longitude, -180 to 180 (required)        |
| `timestamp`    | RFC3339 | GPS measurement time (required)          |
| `speed`        | float64 | Speed in m/s, >= 0 (optional, default 0) |

## Configuration

Environment variables:

| Variable        | Default               | Description                  |
| --------------- | --------------------- | ---------------------------- |
| `KAFKA_BROKERS` | `localhost:9092`      | Comma-separated broker list  |
| `KAFKA_TOPIC`   | `container.telemetry` | Target Kafka topic           |
| `LISTEN_ADDR`   | `:8080`               | HTTP listen address          |

## Build & Run

```bash
# Build
make build

# Run locally
KAFKA_BROKERS=localhost:9092 ./telemetry

# Test endpoint
curl -X POST http://localhost:8080/track \
  -H "Content-Type: application/json" \
  -d '[{"container_id":"C001","lat":25.033,"lon":121.565,"timestamp":"2026-01-23T10:00:00Z","speed":5.2}]'
```

## Development

```bash
# Run unit tests
make test

# Run tests with race detector
make test-race

# Run integration tests (requires Keycloak + Gateway running)
export KEYCLOAK_USERNAME=myuser
export KEYCLOAK_PASSWORD=myuser
make test-integration

# Run load tests with web UI (http://localhost:8089)
make test-load

# Run load tests headless (for CI)
make test-load-headless LOCUST_USERS=100 LOCUST_RUN_TIME=120s
```

### Load Test Configuration

| Variable            | Default                    | Description           |
| ------------------- | -------------------------- | --------------------- |
| `KEYCLOAK_URL`      | `https://localhost:8443`   | Keycloak server       |
| `GATEWAY_URL`       | `https://localhost:8080`   | API gateway           |
| `KEYCLOAK_USERNAME` | (required)                 | Test user             |
| `KEYCLOAK_PASSWORD` | (required)                 | Test password         |
| `LOCUST_USERS`      | `50`                       | Concurrent users      |
| `LOCUST_SPAWN_RATE` | `10`                       | Users spawned/second  |
| `LOCUST_RUN_TIME`   | `60s`                      | Test duration         |

## Performance

Designed for 10,000 GPS pings/second:

- **Batch size**: 100 messages per Kafka batch
- **Batch timeout**: 10ms max wait before flush
- **Async writes**: HTTP returns immediately, Kafka batches in background
- **Partition key**: `container_id` ensures ordering per container

## Response Codes

| Code | Meaning                             |
| ---- | ----------------------------------- |
| 202  | Accepted                            |
| 400  | Invalid JSON or validation failure  |
| 405  | Method not allowed (POST only)      |
| 500  | Kafka write failure                 |
