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


minikube start --cpus=4 --memory=8192 --driver=docker
kubectl create namespace app
kubectl apply -f infra/kafka.yaml
kubectl wait --for=condition=Ready pod -l app=kafka -n app --timeout=120s
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n app

# To see what inside in helm chart
helm pull oci://docker.io/envoyproxy/gateway-helm --version v1.5.7 --untar
# Install envoyproxy
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.5.7 -n app
kubectl apply -f https://github.com/envoyproxy/gateway/releases/download/v1.5.7/quickstart.yaml -n app


# Run in a separate terminal (requires sudo to bind port 80)
sudo minikube tunnel

# Test
curl -i http://127.0.0.1


## Clean-Up
Use the steps in this section to uninstall everything from the quickstart.

Delete the GatewayClass, Gateway, HTTPRoute and Example App:

kubectl delete -f https://github.com/envoyproxy/gateway/releases/download/v1.5.7/quickstart.yaml --ignore-not-found=true
Delete the Gateway API CRDs and Envoy Gateway:

helm uninstall eg -n envoy-gateway-system


## Test
export GATEWAY_HOST=$(kubectl get gateway/eg -n app -o jsonpath='{.status.addresses[0].value}')
curl --verbose --header "Host: www.example.com" http://$GATEWAY_HOST/get