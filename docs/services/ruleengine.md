# Rule Engine Service

Geofencing rule engine for the RouteMaster NL logistics platform. Consumes GPS track points from Kafka, evaluates them against PostGIS geofences, and publishes enter/exit events.

## Architecture

```text
Kafka (container.telemetry) → Rule Engine → Kafka (geofence.events)
                                   ↓
                          PostGIS (geofences, geofence_states)
```

## Data Format

### Input: TrackPoint

Consumes JSON from the `container.telemetry` Kafka topic:

```json
{
  "container_id": "C001",
  "lat": 22.62,
  "lon": 120.30,
  "timestamp": "2026-01-23T10:00:00Z",
  "speed": 5.2
}
```

| Field          | Type    | Description                              |
| -------------- | ------- | ---------------------------------------- |
| `container_id` | string  | Shipping container identifier (required) |
| `lat`          | float64 | Latitude, -90 to 90 (required)           |
| `lon`          | float64 | Longitude, -180 to 180 (required)        |
| `timestamp`    | RFC3339 | GPS measurement time (required)          |
| `speed`        | float64 | Speed in m/s (optional, default 0)       |

### Output: GeofenceEvent

Produces JSON to the `geofence.events` Kafka topic:

```json
{
  "container_id": "MSCU1234567",
  "geofence_id": "550e8400-e29b-41d4-a716-446655440000",
  "geofence_name": "Kaohsiung Port",
  "owner_id": "dev-owner",
  "event_type": "enter",
  "lat": 22.6163,
  "lon": 120.3009,
  "timestamp": "2026-01-23T10:00:00Z"
}
```

| Field           | Type    | Description                       |
| --------------- | ------- | --------------------------------- |
| `container_id`  | string  | Shipping container identifier     |
| `geofence_id`   | UUID    | Geofence that was triggered       |
| `geofence_name` | string  | Human-readable geofence name      |
| `owner_id`      | string  | Geofence owner (recipient lookup) |
| `event_type`    | string  | `enter` or `exit`                 |
| `lat`           | float64 | Latitude at time of event         |
| `lon`           | float64 | Longitude at time of event        |
| `timestamp`     | RFC3339 | Time the event occurred           |

## Configuration

Environment variables:

| Variable        | Default                | Description                 |
| --------------- | ---------------------- | --------------------------- |
| `DATABASE_URL`  | (see deployment.yaml)  | PostGIS connection URI      |
| `KAFKA_BROKERS` | `localhost:9092`       | Comma-separated broker list |
| `KAFKA_TOPIC`   | `container.telemetry`  | Input Kafka topic           |
| `KAFKA_GROUP`   | `ruleengine-service`   | Consumer group ID           |
| `NOTIFY_TOPIC`  | `geofence.events`      | Output Kafka topic          |
| `LISTEN_ADDR`   | `:8082`                | HTTP listen address         |
| `BATCH_SIZE`    | `100`                  | Track points per batch      |
| `BATCH_TIMEOUT` | `1s`                   | Max wait before flush       |

## Database Schema

Two tables in PostGIS (with `postgis` and `pg_uuidv7` extensions):

**geofences** — polygon boundaries for geofence detection

| Column       | Type                   | Description                    |
| ------------ | ---------------------- | ------------------------------ |
| `id`         | UUID (v7)              | Primary key                    |
| `name`       | text                   | Human-readable name            |
| `owner_id`   | text                   | Geofence owner                 |
| `boundary`   | geometry(Polygon,4326) | WGS84 polygon boundary         |
| `enabled`    | boolean                | Whether geofence is active     |
| `created_at` | timestamptz            | Creation timestamp             |
| `updated_at` | timestamptz            | Last update timestamp          |

Indexes: GIST on `boundary` (enabled only), B-tree on `owner_id`.

**geofence_states** — tracks which containers are inside which geofences

| Column         | Type        | Description                          |
| -------------- | ----------- | ------------------------------------ |
| `container_id` | text        | Shipping container ID (PK)           |
| `geofence_id`  | UUID        | Foreign key to geofences (PK)        |
| `inside`       | boolean     | Currently inside this geofence       |
| `updated_at`   | timestamptz | Last state change                    |

Primary key: (`container_id`, `geofence_id`). Events only fire on state transitions, preventing duplicate alerts.

## Build & Run

```bash
# Build
make ruleengine-build

# Generate sqlc code (after schema changes)
make ruleengine-sqlc

# Run locally
DATABASE_URL=postgres://app:password@localhost:5432/app \
KAFKA_BROKERS=localhost:9092 \
  go run ./ruleengine/cmd/...
```

## Deploy to K8s

### 1. Deploy the PostGIS database

```bash
kubectl apply -f ruleengine/postgis/deployment.yaml -n app
kubectl wait --for=condition=Ready cluster/ruleengine-db -n app --timeout=120s
```

### 2. Run migrations

```bash
make ruleengine-migrate-configmap
export VERSION=$(git rev-parse --short HEAD)
kubectl apply -f ruleengine/migrate-jobs/ -n app
envsubst < ruleengine/migrate-jobs/migrate-job.yaml | kubectl apply -n app -f -
```

### 3. Seed test geofences

```bash
# Port-forward to the database
kubectl port-forward svc/ruleengine-db-rw 5432:5432 -n app &

# Run seed data (Kaohsiung Port, Taoyuan Distribution Center, Port of Rotterdam)
psql $DATABASE_URL -f ruleengine/seed.sql
```

### 4. Deploy the service

```bash
make redeploy-ruleengine
```

## Performance

- **Batch processing**: 100 track points per batch, 1s max latency
- **GIST index**: Sub-millisecond spatial containment checks via partial index on enabled geofences
- **Partition key**: `container_id` ensures ordering per container on both input and output topics
- **Idempotent events**: State-based detection only fires on enter/exit transitions, not on every GPS ping
