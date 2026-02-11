# Product Requirements Document (PRD): Geofencing Rule Engine

**Project Owner:** Backend Team / [Your Name]
**Status:** Draft
**Goal:** To provide real-time automated monitoring of GPS assets entering or exiting predefined geographic boundaries (Geofences) to improve logistics transparency.

---

## 1. Executive Summary

The Rule Engine is an event-driven service that consumes real-time telemetry data from Kafka. It evaluates whether a device has crossed a spatial boundary (Geofence) and triggers automated actions (alerts/notifications). This eliminates the need for manual monitoring of shipment progress.

## 2. User Stories

* **As a Logistics Manager**, I want to receive an email when a container enters the port so I can prepare for unloading.
* **As a Customer**, I want to see a "Milestone Completed" status on my dashboard when my package reaches the local distribution center.
* **As a System Administrator**, I want the system to handle thousands of coordinate updates per second without delaying the live map.

## 3. Functional Requirements

| ID | Feature | Description |
| --- | --- | --- |
| **FR1** | **Spatial Filtering** | System must check if a `(lat, lon)` point is inside a `POLYGON` using PostGIS `ST_Contains`. |
| **FR2** | **State Transition** | System must distinguish between "Stayed Inside" and "Entered." Alerts should only fire on **State Change** (Enter/Exit). |
| **FR3** | **Multi-Tenant Zones** | Users should be able to define their own custom geofences (Warehouses, Ports, Hubs). |
| **FR4** | **Async Notifications** | Detected events must be pushed to a `notifications` Kafka topic to keep the Rule Engine decoupled. |

## 4. Technical Architecture & Logic

The engine follows a **Stateless Evaluation + State Store** pattern.

### The "State Change" Logic:

To avoid "Alert Fatigue" (sending an alert every 5 seconds while a truck is parked inside a warehouse), the engine follows this logic:

1. **Current State:** Calculate if the point is currently `INSIDE` or `OUTSIDE`.
2. **Previous State:** Fetch the last known status from a fast-access cache (e.g., Redis or a dedicated PostgreSQL table).
3. **Comparison:**
* `OUTSIDE` → `INSIDE`: Trigger **"Enter"** Event.
* `INSIDE` → `OUTSIDE`: Trigger **"Exit"** Event.
* `INSIDE` → `INSIDE`: Update timestamp only (No alert).



## 5. Non-Functional Requirements

* **Latency:** Rule evaluation must complete in under **100ms** from the moment the Kafka message is read.
* **Scalability:** The service must be horizontally scalable (multiple instances consuming different Kafka partitions).
* **Availability:** Use **CNPG (CloudNativePG)** to ensure high availability for the spatial database.

## 6. Success Metrics

* **Accuracy:** 100% detection of boundary crossings (zero missed events).
* **Performance:** System handles **5k+ events/sec** with a single instance.
* **User Engagement:** Reduction in manual "Where is my shipment?" inquiries.
