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
| `speed`        | float64 | Speed in m/s, >= 0 (required)            |

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
bazel build //:telemetry

# Run
KAFKA_BROKERS=localhost:9092 bazel run //:telemetry

# Test endpoint
curl -X POST http://localhost:8080/track \
  -H "Content-Type: application/json" \
  -d '[{"container_id":"C001","lat":25.033,"lon":121.565,"timestamp":"2026-01-23T10:00:00Z","speed":5.2}]'
```

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
