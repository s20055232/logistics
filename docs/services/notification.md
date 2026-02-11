# Notification Service

Email notification service for the RouteMaster NL logistics platform. Consumes geofence events from Kafka and sends email alerts via Gmail SMTP.

## Architecture

```text
Kafka (geofence.events) → Notification Service → Gmail SMTP → Recipient inbox
                                    ↓
                          PostgreSQL (email_history)
```

## Data Format

Consumes `GeofenceEvent` JSON from the `geofence.events` Kafka topic:

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

| Variable        | Default                    | Description                 |
| --------------- | -------------------------- | --------------------------- |
| `DATABASE_URL`  | (see deployment.yaml)      | PostgreSQL connection URI   |
| `KAFKA_BROKERS` | `kafka:9092`               | Comma-separated broker list |
| `KAFKA_TOPIC`   | `geofence.events`          | Kafka topic to consume      |
| `KAFKA_GROUP`   | `notification-service`     | Consumer group ID           |
| `LISTEN_ADDR`   | `:8083`                    | HTTP listen address         |
| `BATCH_SIZE`    | `10`                       | Messages per batch          |
| `BATCH_TIMEOUT` | `5s`                       | Batch flush timeout         |
| `SMTP_HOST`     | `smtp.gmail.com`           | SMTP server host            |
| `SMTP_PORT`     | `587`                      | SMTP server port            |
| `SMTP_USER`     | (required)                 | Gmail address               |
| `SMTP_PASSWORD` | (required)                 | Gmail App Password          |

## Database Schema

Two tables in PostgreSQL (with `pg_uuidv7` extension):

**notification_recipients** — who gets emailed (seeded, no API yet)

| Column     | Type        | Description              |
| ---------- | ----------- | ------------------------ |
| `id`       | UUID (v7)   | Primary key              |
| `owner_id` | text        | Matches geofence owner   |
| `email`    | text        | Recipient email address  |
| `name`     | text        | Display name             |
| `enabled`  | boolean     | Whether to send emails   |

**email_history** — log of sent emails

| Column            | Type        | Description              |
| ----------------- | ----------- | ------------------------ |
| `id`              | UUID (v7)   | Primary key              |
| `container_id`    | text        | Container that triggered |
| `geofence_name`   | text        | Geofence name            |
| `event_type`      | text        | enter or exit            |
| `recipient_email` | text        | Who received the email   |
| `subject`         | text        | Email subject line       |
| `sent_at`         | timestamptz | When the email was sent  |

## Build & Run

```bash
# Build
make notification-build

# Generate sqlc code (after schema changes)
make notification-sqlc

# Run locally
SMTP_USER=you@gmail.com SMTP_PASSWORD=your-app-password \
DATABASE_URL=postgres://app:password@localhost:5432/app \
KAFKA_BROKERS=localhost:9092 \
  go run ./cmd
```

## Deploy to K8s

### 1. Deploy the database

```bash
kubectl apply -f notification/postgres/deployment.yaml -n app
kubectl wait --for=condition=Ready cluster/notification-db -n app --timeout=120s
```

### 2. Replace email in migration seed

Edit `notification/db/migrations/000001_init.up.sql` and replace the seed email with yours.

### 3. Run migrations

```bash
make notification-migrate-configmap
export VERSION=$(git rev-parse --short HEAD)
kubectl apply -f notification/migrate-jobs/ -n app
envsubst < notification/migrate-jobs/migrate-job.yaml | kubectl apply -n app -f -
```

### 4. Create SMTP secret

Get a [Gmail App Password](https://myaccount.google.com/apppasswords), then:

```bash
make notification-smtp-secret SMTP_USER=your@gmail.com SMTP_PASSWORD=your-app-password
```

### 5. Deploy the service

```bash
make redeploy-notification
```

## Email Format

**Subject:** `[Logistics] Container MSCU1234567 entered geofence Kaohsiung Port`

**Body:**

```text
Container: MSCU1234567
Event: enter
Geofence: Kaohsiung Port
Location: 22.616300, 120.300900
Time: 2026-01-23 10:00:00 UTC
```
