# Product Requirements Document (PRD): Cloud-Native Logistics Orchestrator

## 1. Project Overview

**Project Name**: RouteMaster NL (Event-Driven Logistics Platform)
**Objective**: Build a scalable, real-time system to track shipping containers moving from the Port of Rotterdam to various European hubs. The system will process high-frequency GPS data, optimize routes in real-time, and alert stakeholders of delays.

## 2. Target Audience

**Operations Managers**: Need a dashboard to see fleet status.
**Drivers/IoT Sensors**: Need a high-performance endpoint to send location updates.
Third-Party Logistics (3PL) Partners: Need automated notifications for cargo arrival.

## 3. Key Features

### A. Real-Time Ingestion (Kafka + Go)

- The system must handle up to 10,000 GPS "pings" per second.
- Requirement: A "Telemetry Service" (Go) that acts as a Kafka producer, sending location data to a container.telemetry topic.

### B. Parallel Route Optimization (Go + Parallel Computing)

When a delay is detected (e.g., traffic in Utrecht), the system must recalculate the Estimated Time of Arrival (ETA).
Requirement: Use Goroutines to run multiple "what-if" routing simulations in parallel to find the fastest path without blocking the main process.

### C. Automated Alerting (Microservices)

Requirement: A "Notification Service" that consumes Kafka events and sends alerts (Webhooks/Email) when a container enters a specific "Geofence" area.

## 4. Technical Architecture

To demonstrate your skills, the project will be organized as follows:

| Component | Technology | Role |
| ----------- | ------------ | ------ |
| Monorepo Structure | Go Workspaces / Bazel | Houses api-gateway, routing-engine, and notification-service. |
| Message Broker | Kafka | Decouples telemetry ingestion from processing logic. |
| Processing Engine | Go (Concurrency) | Uses workers to process batches of Kafka messages in parallel. |
| Orchestration | Kubernetes (K8S) | Manages scaling; uses Helm for deployment charts. |
| CI/CD | GitHub Actions | Automatically builds Docker images and runs go test on every PR. |

## 5. User Stories

1. As a Manager, I want to see the real-time location of all containers on a map so I can manage client expectations.
2. As a System, I want to process GPS data asynchronously so that a spike in traffic doesn't crash the API.
3. As a Developer, I want to deploy any service independently using a single CI/CD pipeline in my monorepo.

## 6. Non-Functional Requirements

- Scalability: The system must scale horizontally using K8S HPA (Horizontal Pod Autoscaler) based on CPU usage.
- Resiliency: If the Routing Service fails, Kafka must retain the data so no location updates are lost.
- Observability: Basic health checks for all microservices in K8S.

## 7. Success Metrics

- Latency: ETA recalculations should take less than 200ms using parallel Go workers.
- Throughput: System must handle 1 million events per day on a single small K8S cluster.
