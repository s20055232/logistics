1. go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# 1. Apply migrations ConfigMap
kubectl apply -n app -f consumer/k8s/migrations-configmap.yaml

# 2. Run migration job (unique name per deploy)
export VERSION=$(git rev-parse --short HEAD)
envsubst < consumer/migrate-jobs/migrate-job.yaml | kubectl apply -n app -f -

# 3. Wait for completion
kubectl wait --for=condition=complete job/consumer-migrate-${VERSION} -n app --timeout=120s

# 4. Deploy app
kubectl apply -n app -f consumer/k8s/deployment.yaml


A WebSocket hub is a server-side component that manages multiple persistent client connections for real-time, bidirectional communication, commonly used in chat apps or live dashboards. It centralizes message broadcasting, connection lifecycle (register/unregister), and state management (e.g., active users).
Key Functions of a WebSocket Hub:
- Broadcasting: Sending messages to all or specific connected clients.
- Connection Management: Handling client authentication, connections, and disconnections.
- State Maintenance: Managing active users or shared data.
- Scaling: Using backplanes like Redis to manage connections across multiple server nodes. 


# Recreate cluster to get pg_uuidv7 extension
kubectl delete cluster telemetry-timescaledb -n app
kubectl apply -f consumer/timescaledb/deployment.yaml

# Update configmap and run migration
kubectl apply -f consumer/migrate-jobs/migrations-configmap.yaml
kubectl apply -f consumer/k8s/migrate-job.yaml