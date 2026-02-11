# Consumer Service

Real-time telemetry consumer for the RouteMaster NL logistics platform. Consumes GPS track points from Kafka, stores them in TimescaleDB, and broadcasts position updates to WebSocket clients.

## Architecture

```text
Kafka (container.telemetry) → Consumer Service → TimescaleDB (track_points)
                                      ↓
                              WebSocket Hub → Connected Clients
```

## Data Format

### Input: TrackPoint

Consumes JSON from the `container.telemetry` Kafka topic:

```json
{
  "container_id": "MSCU1234567",
  "lat": 22.3193,
  "lon": 114.1694,
  "timestamp": "2026-02-11T10:30:45Z",
  "speed": 28.5
}
```

| Field          | Type    | Description                              |
| -------------- | ------- | ---------------------------------------- |
| `container_id` | string  | Shipping container identifier (required) |
| `lat`          | float64 | Latitude, -90 to 90 (required)           |
| `lon`          | float64 | Longitude, -180 to 180 (required)        |
| `timestamp`    | RFC3339 | GPS measurement time (required)          |
| `speed`        | float64 | Speed in m/s (optional, default 0)       |

### Output: WebSocket Message

Broadcasts to clients subscribed to a container:

```json
{
  "type": "position",
  "data": {
    "container_id": "MSCU1234567",
    "lat": 22.3193,
    "lon": 114.1694,
    "timestamp": "2026-02-11T10:30:45Z",
    "speed": 28.5
  }
}
```

## API Endpoints

| Method | Path                              | Description                  |
| ------ | --------------------------------- | ---------------------------- |
| GET    | `/health`                         | Database health check        |
| GET    | `/api/track/{containerId}?token=` | WebSocket upgrade (position) |

## Configuration

Environment variables:

| Variable        | Default                | Description                 |
| --------------- | ---------------------- | --------------------------- |
| `DATABASE_URL`  | (see deployment.yaml)  | TimescaleDB connection URI  |
| `KAFKA_BROKERS` | `localhost:9092`       | Comma-separated broker list |
| `KAFKA_TOPIC`   | `container.telemetry`  | Kafka topic to consume      |
| `KAFKA_GROUP`   | `consumer-service`     | Consumer group ID           |
| `LISTEN_ADDR`   | `:8081`                | HTTP listen address         |
| `BATCH_SIZE`    | `100`                  | Messages per batch          |
| `BATCH_TIMEOUT` | `1s`                   | Batch flush timeout         |

## Database Schema

TimescaleDB with `timescaledb`, `postgis`, and `pg_uuidv7` extensions.

**containers** — registered shipping containers

| Column           | Type        | Description                |
| ---------------- | ----------- | -------------------------- |
| `id`             | UUID (v7)   | Primary key                |
| `container_id`   | text        | ISO 6346 code (unique)     |
| `owner`          | text        | Shipping line or company   |
| `container_type` | text        | 20ft, 40ft, 40ft-HC, etc.  |
| `created_at`     | timestamptz | Creation timestamp         |

**track_points** — GPS data (TimescaleDB hypertable, 7-day chunks)

| Column         | Type             | Description                     |
| -------------- | ---------------- | ------------------------------- |
| `time`         | timestamptz      | GPS measurement time            |
| `container_id` | text             | Container identifier            |
| `lat`          | double precision | Latitude                        |
| `lon`          | double precision | Longitude                       |
| `speed`        | double precision | Speed in m/s (>= 0, nullable)   |

Policies:

- **Compression**: chunks older than 1 day, segmented by `container_id`
- **Retention**: auto-delete data older than 30 days

## Build & Run

```bash
# Build
docker build -f consumer/Dockerfile -t consumer:latest ./consumer

# Run locally
DATABASE_URL=postgres://app:password@localhost:5432/app \
KAFKA_BROKERS=localhost:9092 \
  go run ./consumer/cmd/...
```

## Deploy to K8s

### 1. Deploy the TimescaleDB database

```bash
kubectl apply -f consumer/timescaledb/deployment.yaml -n app
kubectl wait --for=condition=Ready cluster/telemetry-timescaledb -n app --timeout=120s
```

### 2. Run migrations

```bash
kubectl apply -f consumer/migrate-jobs/migrations-configmap.yaml -n app
export VERSION=$(git rev-parse --short HEAD)
envsubst < consumer/migrate-jobs/migrate-job.yaml | kubectl apply -n app -f -
kubectl wait --for=condition=complete job/consumer-migrate-${VERSION} -n app --timeout=120s
```

### 3. Deploy the service

```bash
make redeploy-consumer
```

## Performance

- **Batch insert**: 100 messages per batch via PostgreSQL COPY protocol
- **Batch timeout**: 1s max latency before flush
- **Compression**: 90%+ storage reduction on chunks older than 1 day
- **Hypertable chunks**: 7-day intervals for optimal query performance
- **WebSocket buffer**: 256 messages per client, non-blocking broadcast
- **Partition key**: `container_id` ensures ordering per container
