.PHONY: minikube-up minikube-down redeploy-logistics help
.DEFAULT_GOAL := help
include makefiles/tls.mk
include makefiles/timescaledb.mk
include makefiles/telemetry.mk
include makefiles/frontend.mk
include makefiles/kafka.mk
include makefiles/ruleengine.mk
help:
	@echo "可用的命令模組:"
	@echo ""
	@echo "TLS 證書管理:"
	@echo "  make help-tls           - 查看 TLS 相關命令"
	@echo ""
	@echo "Frontend:"
	@echo "  make help-frontend      - Frontend commands"
	@echo ""
	@echo "Kafka:"
	@echo "  make help-kafka         - Kafka commands"
	@echo ""
	@echo "TimescaleDB:"
	@echo "  make help-timescaledb   - TimescaleDB image commands"
	@echo ""
	@echo "Telemetry:"
	@echo "  make help-telemetry     - Telemetry service build and test commands"
	@echo ""
	@echo "Rule Engine:"
	@echo "  make help-ruleengine    - Rule engine service commands"
	@echo ""
	@echo "其他模組:"
	@echo "  make help-docker        - Docker 相關命令"
	@echo "  make help-k8s           - Kubernetes 相關命令"
	@echo ""
	@echo "快速開始:"
	@echo "  make init-ca            - 初始化 CA"
	@echo "  make deploy-tls         - 生成證書並部署"

minikube-up:
	minikube start --cpus=4 --memory=8192 --driver=docker
	kubectl create namespace app
	kubectl apply -f infra/kafka.yaml
	kubectl wait --for=condition=Ready pod -l app=kafka -n app --timeout=120s
	kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n app
	helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.5.7 -n app
	kubectl apply -k infra/gateway/ -n app
	kubectl apply -f http-routing.yaml -n app
	sudo minikube tunnel


minikube-down:
	kubectl delete namespace app
	helm uninstall eg -n app
	kubectl delete gateway eg -n app
	minikube delete

redeploy-logistics:
	@echo "=== 删除现有部署 ==="
	-kubectl delete -f telemetry/deployment.yaml -n app
	@echo "=== 删除 minikube 中的旧镜像 ==="
	-minikube image rm telemetry:latest
	@echo "=== 构建镜像 ==="
	docker build -f telemetry/Dockerfile -t telemetry:latest .
	@echo "=== 加载镜像到 minikube ==="
	minikube image load telemetry:latest
	@echo "=== 重新部署服务 ==="
	kubectl apply -f telemetry/deployment.yaml -n app
	kubectl wait --for=condition=Available deployment/logistics-deployment -n app --timeout=60s
	@echo "=== 部署完成 ==="

redeploy-consumer:
	@echo "=== 删除现有部署 ==="
	-kubectl delete -f consumer/deployment.yaml -n app
	@echo "=== 删除 minikube 中的旧镜像 ==="
	-minikube image rm consumer:latest
	@echo "=== 构建镜像 ==="
	docker build -f consumer/Dockerfile -t consumer:latest ./consumer
	@echo "=== 加载镜像到 minikube ==="
	minikube image load consumer:latest
	@echo "=== 重新部署服务 ==="
	kubectl apply -f consumer/deployment.yaml -n app
	kubectl wait --for=condition=Available deployment/consumer-deployment -n app --timeout=60s
	@echo "=== 部署完成 ==="

redeploy-ruleengine:
	@echo "=== Delete existing deployment ==="
	-kubectl delete -f ruleengine/deployment.yaml -n app
	@echo "=== Remove old image from minikube ==="
	-minikube image rm ruleengine:latest
	@echo "=== Build image ==="
	docker build -f ruleengine/Dockerfile -t ruleengine:latest ./ruleengine
	@echo "=== Load image to minikube ==="
	minikube image load ruleengine:latest
	@echo "=== Deploy service ==="
	kubectl apply -f ruleengine/deployment.yaml -n app
	kubectl wait --for=condition=Available deployment/ruleengine-deployment -n app --timeout=60s
	@echo "=== Deploy complete ==="

# gen-tls:
# 	openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt
# 	openssl req -out www.example.com.csr -newkey rsa:2048 -nodes -keyout www.example.com.key -subj "/CN=www.example.com/O=example organization"
# 	openssl x509 -req -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 -in www.example.com.csr -out www.example.com.crt
# 	kubectl create secret tls cert -n app --key=certs/intermidiate-ca/www.example.com.key --cert=certs/intermidiate-ca/www.example.com.crt

# add-dns:
#   sudo echo "YOUR_GATEWAY_IP logistics.example.com" >> /etc/hosts

# jwt:
#   https://github.com/codecentric/helm-charts/tree/master/charts/keycloakx
#   helm repo add bitnami https://charts.bitnami.com/bitnami -n app
#   helm repo add codecentric https://codecentric.github.io/helm-charts -n app
#   helm install keycloak codecentric/keycloakx -n app
#   kubectl port-forward service/keycloak-keycloakx-http -n app 8080:80
#   helm uninstall keycloakx -n app



