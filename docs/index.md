# RouteMaster NL Documentation

A cloud-native, event-driven logistics platform for tracking shipping containers.

## Quick Links

- [Getting Started](getting-started.md) - Setup and deployment guide
- [TLS/PKI Guide](guides/tls-guide.md) - Certificate management and PKI setup
- [Telemetry Service](services/telemetry.md) - GPS data ingestion
- [Rule Engine Service](services/ruleengine.md) - Geofence evaluation, publishes events
- [Notification Service](services/notification.md) - Email alerts on geofence events

## Services

| Service | Port | Description |
|---------|------|-------------|
| Telemetry | 8080 | GPS data ingestion, writes to Kafka |
| Consumer | 8081 | Kafka consumer, writes to TimescaleDB, WebSocket |
| Rule Engine | 8082 | Geofence evaluation, publishes events |
| Notification | 8083 | Email alerts on geofence events (Gmail SMTP) |
| Frontend | 80 | React SPA with Keycloak auth |

## Architecture Overview

![system architecture](./assets/system_design.png)

## Getting Started

See the [Getting Started](getting-started.md) guide for setup instructions.
