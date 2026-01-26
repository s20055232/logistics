# RouteMaster NL - Logistics Platform

A cloud-native, event-driven logistics platform for tracking shipping containers.

## Architecture

```
                        ┌─────────────────────────────────────────────────────┐
                        │                 Kubernetes Cluster                  │
                        │                                                     │
 GPS/IoT ──HTTP POST──▶ │  ┌─────────────┐      ┌─────────────────────────┐   │
                        │  │  Telemetry  │      │         Kafka           │   │
                        │  │   Service   │─────▶│  container.telemetry    │   │
                        │  └─────────────┘      └───────────┬─────────────┘   │
                        │                                   │                 │
                        │                    ┌──────────────┴──────────────┐  │
                        │                    ▼                             ▼  │
                        │          ┌─────────────────┐          ┌──────────┐  │
                        │          │  Alert Service  │          │ Routing  │  │
                        │          │   (Consumer)    │          │ Service  │  │
                        │          └────────┬────────┘          └──────────┘  │
                        │                   │                                 │
                        └───────────────────┼─────────────────────────────────┘
                                            ▼
                                   Webhook / Email
```

## Project Structure

```
logistics/
├── docker-compose.yaml  # Local development (Kafka)
├── telemetry/           # Telemetry service (Kafka producer, GPS ingestion)
├── alert/               # Notification service (Kafka consumer, sends alerts)
├── routing/             # Route optimization engine (parallel computing)
└── k8s/                 # Kubernetes manifests
    ├── gateway-api-demo.yaml   # Gateway, HTTPRoutes, KongPlugins
    ├── kafka.yaml              # Kafka for K8s (KRaft mode)
    ├── rate-limit-plugin.yaml  # Global rate limiting (KongClusterPlugin)
    ├── redis.yaml              # Redis for rate limit counters
    ├── test-service.yaml       # Telemetry service deployment
    └── values.yaml             # Kong Helm values
```

## Telemetry Service

GPS data ingestion service that receives container location data and writes to Kafka.

### API

```
POST /track
Content-Type: application/json

[
  {
    "container_id": "MSCU1234567",
    "lat": 51.9225,
    "lon": 4.47917,
    "timestamp": "2024-01-15T10:30:00Z",
    "speed": 45.5
  }
]
```

**Response**: `202 Accepted`

### Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `KAFKA_BROKERS` | `localhost:9092` | Kafka cluster addresses (comma-separated) |
| `KAFKA_TOPIC` | `container.telemetry` | Target topic |
| `LISTEN_ADDR` | `:8080` | HTTP listen address |

### Running

```bash
# 1. Start Kafka (local development)
docker-compose up -d

# 2. Run telemetry service
cd telemetry
KAFKA_BROKERS=localhost:9092 go run .

# Bazel (local binary - native platform)
bazel run //telemetry:telemetry

# Build container image (cross-compiled for linux/amd64)
bazel build //telemetry:image

# Load into Docker and run
bazel run //telemetry:image_load
docker run -p 8080:8080 -e KAFKA_BROKERS=host.docker.internal:9092 telemetry:latest

# Apple Silicon: use platform emulation
docker run --platform linux/amd64 -p 8080:8080 -e KAFKA_BROKERS=host.docker.internal:9092 telemetry:latest

# Deploy to Kubernetes
bazel run //telemetry:image_load
minikube image load telemetry:latest
kubectl apply -f k8s/test-service.yaml
```

**Build Targets:**

| Target                              | Platform      | Use Case            |
|-------------------------------------|---------------|---------------------|
| `//telemetry:telemetry`             | Native (host) | Local development   |
| `//telemetry:telemetry_linux_amd64` | linux/amd64   | Container binary    |
| `//telemetry:image`                 | linux/amd64   | OCI image           |
| `//telemetry:image_load`            | linux/amd64   | Load image to Docker|
| `//telemetry:push`                  | linux/amd64   | Push to registry    |

### Data Format

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `container_id` | string | Yes | Non-empty |
| `lat` | float64 | Yes | -90 to 90 |
| `lon` | float64 | Yes | -180 to 180 |
| `timestamp` | RFC3339 | Yes | Non-zero |
| `speed` | float64 | No | >= 0 |

## Build System

This project uses **Bazel** with **bzlmod** for dependency management.

### Why Bazel?

| Feature                     | Benefit                                          |
|-----------------------------|--------------------------------------------------|
| **Hermetic builds**         | Same input = same output, regardless of machine  |
| **Caching**                 | Only rebuild what changed (local + remote cache) |
| **Cross-compilation**       | Build linux/amd64 binaries on macOS/arm64        |
| **Dependency graph**        | Bazel understands the full dependency tree       |
| **Reproducible containers** | OCI images without Dockerfile                    |

### Tools Overview

| Tool | Purpose |
|------|---------|
| **Bazel** | Build system with caching and dependency tracking |
| **bzlmod** | Modern dependency management (replaces WORKSPACE) |
| **rules_go** | Build Go code: `go_binary`, `go_library`, `go_test` |
| **rules_oci** | Build OCI images: `oci_image`, `oci_load`, `oci_push` |
| **rules_pkg** | Package files: `pkg_tar`, `pkg_files` for layers |
| **Gazelle** | Auto-generate BUILD files from Go source |

### File Structure

```
logistics/
├── MODULE.bazel      # External dependencies (like package.json)
├── BUILD.bazel       # Root build targets
├── go.mod            # Go dependencies (read by Gazelle)
├── go.sum            # Go dependency checksums
└── telemetry/
    ├── BUILD         # Service build targets
    ├── main.go
    └── *.go
```

### Container Build Pipeline

The build pipeline converts Go source to a container image without Dockerfile:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  go_binary   │────▶│  pkg_files   │────▶│   pkg_tar    │────▶│  oci_image   │
│ (compile Go) │     │  (rename +   │     │  (create     │     │  (add layer  │
│              │     │   chmod)     │     │   tarball)   │     │   to base)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                                      │
                     ┌──────────────┐     ┌──────────────┐            │
                     │   oci_push   │◀────│  oci_load    │◀───────────┘
                     │ (to registry)│     │ (to Docker)  │
                     └──────────────┘     └──────────────┘
```

**Step-by-step:**

1. **go_binary** - Compiles Go code to a static binary (cross-compiled for linux/amd64)
2. **pkg_files** - Renames binary and sets executable permissions (mode 0755)
3. **pkg_tar** - Creates a tarball layer containing the binary
4. **oci_image** - Combines base image (distroless) + tarball layer + entrypoint
5. **oci_load** - Loads the OCI image into Docker daemon
6. **oci_push** - Pushes to container registry (ghcr.io)

### BUILD File Anatomy

```python
# telemetry/BUILD

# 1. Go library (shared code)
go_library(
    name = "telemetry_lib",
    srcs = ["main.go", "handler.go", ...],
    deps = ["@com_github_segmentio_kafka_go//:kafka-go"],
)

# 2. Native binary (for local development)
go_binary(
    name = "telemetry",
    embed = [":telemetry_lib"],
)

# 3. Cross-compiled binary (for containers)
go_binary(
    name = "telemetry_linux_amd64",
    embed = [":telemetry_lib"],
    goos = "linux",
    goarch = "amd64",
)

# 4. Prepare files with correct permissions
pkg_files(
    name = "telemetry_files",
    srcs = [":telemetry_linux_amd64"],
    attributes = pkg_attributes(mode = "0755"),
    renames = {":telemetry_linux_amd64": "telemetry"},
)

# 5. Create tarball layer
pkg_tar(
    name = "telemetry_layer",
    srcs = [":telemetry_files"],
)

# 6. Build OCI image
oci_image(
    name = "image",
    base = "@distroless_static_linux_amd64",
    entrypoint = ["/telemetry"],
    tars = [":telemetry_layer"],
)

# 7. Load to Docker
oci_load(
    name = "image_load",
    image = ":image",
    repo_tags = ["telemetry:latest"],
)
```

### Cross-Compilation

Bazel can build linux/amd64 binaries on any platform (macOS, Windows, Linux):

| Host Platform | Target Platform | Command                                           |
|---------------|-----------------|---------------------------------------------------|
| macOS arm64   | macOS arm64     | `bazel run //telemetry:telemetry`                 |
| macOS arm64   | linux/amd64     | `bazel build //telemetry:telemetry_linux_amd64`   |
| linux/amd64   | linux/amd64     | `bazel run //telemetry:telemetry`                 |

**Note:** Container images are always linux/amd64. On Apple Silicon, run with:

```bash
docker run --platform linux/amd64 telemetry:latest
```

### Dependency Management

**Adding a new Go dependency:**

```bash
# 1. Add to go.mod
go get github.com/some/package@v1.0.0

# 2. Regenerate BUILD files
bazel run @gazelle//:gazelle

# 3. If top-level dep, add to MODULE.bazel
use_repo(
    go_deps,
    "com_github_some_package",  # Add this line
)
```

**Finding the Bazel repo name:**

```bash
# The repo name follows pattern: com_github_<org>_<repo>
# github.com/segmentio/kafka-go → com_github_segmentio_kafka_go
```

### Build Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `cannot execute binary file` | Wrong platform (linux binary on macOS) | Use `bazel run //telemetry:telemetry` for local dev |
| `permission denied` | Binary not executable | Add `attributes = pkg_attributes(mode = "0755")` |
| `no such file or directory` | Binary renamed incorrectly | Check `renames` in `pkg_files` |
| `no matching manifest` | Base image doesn't support platform | Use amd64-only base or different image |
| `undefined: SomeFunc` | Missing dependency | Run `bazel run @gazelle//:gazelle` |
| `module not found` | Dep not in use_repo | Add to `use_repo()` in MODULE.bazel |

## Common Commands

```bash
# Build all targets
bazel build //...

# Run telemetry service locally
bazel run //telemetry:telemetry

# Generate/update BUILD files from Go source
bazel run @gazelle//:gazelle

# Build container image
bazel build //telemetry:image

# Load image into Docker
bazel run //telemetry:image_load

# Push image to registry
bazel run //telemetry:push

# Load image into Minikube
minikube image load telemetry:latest

# Clean build cache
bazel clean
```

## Getting Started

### Prerequisites

| Tool | Installation | Version |
|------|-------------|---------|
| Bazel | https://bazel.build/install | 7.x |
| Docker | https://docker.com | 24.x |
| Minikube | `brew install minikube` | 1.32+ |
| kubectl | `brew install kubectl` | 1.29+ |
| Helm | `brew install helm` | 3.x |

### Build and Run Locally

```bash
# Build all services
bazel build //...

# Run telemetry service (requires local Kafka)
bazel run //telemetry:telemetry
```

### Deploy to Kubernetes

See [Quick Start](#quick-start-zero-to-hero) for the complete zero-to-hero guide.

## Adding Dependencies

1. Add the dependency to your `go.mod`:

   ```bash
   go get github.com/some/package@v1.0.0
   ```

2. Run Gazelle to update BUILD files:

   ```bash
   bazel run @gazelle//:gazelle
   ```

3. If it's a new top-level dependency, add it to `use_repo()` in `MODULE.bazel`

## Local Development with Kong

Complete guide to running Kong API Gateway from scratch.

### Prerequisites

| Tool | Installation | Description |
|------|-------------|-------------|
| Docker | <https://docker.com> | Container runtime |
| Minikube | `brew install minikube` | Local K8s cluster |
| kubectl | `brew install kubectl` | K8s CLI |
| Helm | `brew install helm` | K8s package manager |

### Quick Start (Zero to Hero)

Complete setup from scratch:

```bash
# 1. Start Minikube
minikube start --cpus=4 --memory=8192 --driver=docker

# 2. Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

# 3. Install Kong Gateway
helm repo add kong https://charts.konghq.com && helm repo update
helm install kong kong/ingress -n kong --create-namespace -f k8s/values.yaml

# 4. Wait for Kong to be ready
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=app -n kong --timeout=120s

# 5. Deploy Redis (for rate limiting)
kubectl apply -f k8s/redis.yaml
kubectl wait --for=condition=Ready pod -l app=redis -n redis --timeout=60s

# 6. Deploy Kafka
kubectl apply -f k8s/kafka.yaml
kubectl wait --for=condition=Ready pod -l app=kafka -n kafka --timeout=120s

# 7. Deploy Gateway API routes and plugins
kubectl apply -f k8s/gateway-api-demo.yaml
kubectl apply -f k8s/rate-limit-plugin.yaml

# 8. Build and load telemetry service image
bazel run //telemetry:image_load
minikube image load telemetry:latest

# 9. Deploy telemetry service
kubectl apply -f k8s/test-service.yaml

# 10. Get Kong URL
export KONG_URL="http://$(minikube ip):$(kubectl get svc kong-gateway-proxy -n kong -o jsonpath='{.spec.ports[0].nodePort}')"
echo $KONG_URL

# 11. Test
curl -X POST $KONG_URL/track \
  -H "Content-Type: application/json" \
  -d '[{"container_id":"TEST123","lat":51.9,"lon":4.4,"timestamp":"2024-01-15T10:30:00Z"}]'
```

### Accessing Kong

Kong runs inside Minikube. There are two ways to access it:

**Option A: NodePort (Recommended)**

NodePort is recommended for local development because:

- No sudo required - binds to high ports (30000-32767) instead of privileged port 80
- No extra terminal - `minikube tunnel` must run in foreground
- More stable - tunnel can disconnect or require re-authentication
- Simpler - one command to get the URL, no background process needed

```bash
# Get the access URL
KONG_URL="http://$(minikube ip):$(kubectl get svc kong-gateway-proxy -n kong -o jsonpath='{.spec.ports[0].nodePort}')"
echo $KONG_URL

# Test
curl -i $KONG_URL
```

**Option B: Minikube Tunnel**

Use this if you need standard ports (80/443):

```bash
# Run in a separate terminal (requires sudo to bind port 80)
sudo minikube tunnel

# Test
curl -i http://127.0.0.1
```

### Verify Kong is Running

```bash
# Expected: 404 + "no Route matched" (normal - Kong is running but no routes configured)
curl -i $KONG_URL

# Check pod status (should show Running)
kubectl get pods -n kong

# Check Gateway resources
kubectl get gateway,httproute -n kong
```

### Test Routing

```bash
# Deploy telemetry service
kubectl apply -f k8s/test-service.yaml

# Test telemetry endpoint (POST /track)
curl -X POST $KONG_URL/track \
  -H "Content-Type: application/json" \
  -d '[{"container_id":"TEST123","lat":51.9,"lon":4.4,"timestamp":"2024-01-15T10:30:00Z"}]'

# Test rate limiting (6th request should return 429)
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} " -X POST $KONG_URL/track \
    -H "Content-Type: application/json" \
    -d '[{"container_id":"TEST","lat":0,"lon":0,"timestamp":"2024-01-01T00:00:00Z"}]'
done
echo
```

### Common Commands

```bash
# View all Kong resources
kubectl get all -n kong

# View Kong logs
kubectl logs -f deployment/kong-gateway -n kong

# Enter Kong pod for debugging
kubectl exec -it deployment/kong-gateway -n kong -- /bin/sh

# Restart Kong
kubectl rollout restart deployment/kong-gateway -n kong

# Clean up
kubectl delete namespace kong
minikube stop
```

### Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Pod status `Pending` | Insufficient resources | `minikube start --cpus=4 --memory=8192` |
| Pod status `CrashLoopBackOff` | Configuration error | `kubectl logs -n kong <pod-name>` |
| `EXTERNAL-IP` shows `<pending>` | Minikube doesn't provision LB | Use NodePort or `minikube tunnel` |
| `curl` connection refused | Port not exposed | Check `minikube ip` and NodePort |
| Routes return 404 | HTTPRoute not configured | `kubectl get httproute -n kong` |

## Gateway API

Gateway API is the next-generation Kubernetes traffic management standard, replacing traditional Ingress.

```
GatewayClass → Gateway → HTTPRoute → Service
     ↓            ↓          ↓           ↓
 Implementation  Listener   Routing     Backend
                 Entry      Rules       Service
```

### Verification

```bash
# Check status
kubectl get gatewayclass
kubectl get gateway -n kong
kubectl get httproute -n kong

# Test with port-forward
kubectl port-forward svc/kong-gateway-proxy -n kong 8080:80

# Unauthenticated route
curl -H "Host: admin.local" http://localhost:8080/status

# Authenticated route (returns 401)
curl -H "Host: admin-secure.local" http://localhost:8080/status
```

### Resource Reference

| Resource | Purpose |
|----------|---------|
| `GatewayClass` | Declares Kong as the Gateway implementation |
| `Gateway` | Defines listener ports (port 80 entry point) |
| `HTTPRoute` | Routing rules (host → service mapping) |
| `KongPlugin` | Kong extensions (auth, rate limiting, etc.) |

### Registering a Service

Create an `HTTPRoute` to route traffic to your service:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-service-route
  namespace: kong
spec:
  parentRefs:
  - name: demo-gateway
  hostnames:
  - "my-service.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-service
      port: 80
```

**Adding plugins** (auth/rate limiting):

```yaml
metadata:
  annotations:
    konghq.com/plugins: rate-limit,key-auth
```

## Rate Limiting

Global rate limiting is applied to all traffic through Kong Gateway.

### Architecture

```
Client Request → Kong Gateway → Redis (shared counter) → Backend Service
                      ↓
              Check: requests < 5/min?
                      ↓
              Yes: Allow → Backend
              No:  Block → 429 Too Many Requests
```

### Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| `minute` | 5 | Max requests per minute |
| `policy` | redis | Shared counter across all Kong pods |
| `redis_host` | redis.redis.svc.cluster.local | Redis service address |

### Deploy Rate Limiting

```bash
# 1. Deploy Redis
kubectl apply -f k8s/redis.yaml
kubectl wait --for=condition=Ready pod -l app=redis -n redis --timeout=60s

# 2. Apply global rate limit plugin
kubectl apply -f k8s/rate-limit-plugin.yaml

# 3. Verify (6th request should return 429)
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} " -X POST $KONG_URL/track \
    -H "Content-Type: application/json" \
    -d '[{"container_id":"TEST","lat":0,"lon":0,"timestamp":"2024-01-01T00:00:00Z"}]'
done
echo
```

### Customizing Limits

Edit `k8s/rate-limit-plugin.yaml`:

```yaml
config:
  minute: 60      # 60 requests per minute
  hour: 1000      # 1000 requests per hour
  policy: redis
```
