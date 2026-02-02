.PHONY: minikube-up minikube-down redeploy-logistics help
.PHONY: frontend-build frontend-deploy frontend-redeploy frontend-dev
.PHONY: kafka-shell kafka-info kafka-topics kafka-consume kafka-describe kafka-offsets
.DEFAULT_GOAL := help
include makefiles/tls.mk
help:
	@echo "可用的命令模組:"
	@echo ""
	@echo "TLS 證書管理:"
	@echo "  make help-tls           - 查看 TLS 相關命令"
	@echo ""
	@echo "Frontend:"
	@echo "  make frontend-dev       - 啟動前端開發服務器"
	@echo "  make frontend-build     - 構建前端 Docker 鏡像"
	@echo "  make frontend-deploy    - 部署前端到 Kubernetes"
	@echo "  make frontend-redeploy  - 重新部署前端"
	@echo ""
	@echo "Kafka:"
	@echo "  make kafka-shell        - Enter Kafka container"
	@echo "  make kafka-info         - Show Kafka broker and topics"
	@echo "  make kafka-topics       - List all topics"
	@echo "  make kafka-consume TOPIC=<name>           - Consume new messages"
	@echo "  make kafka-consume TOPIC=<name> FROM=all  - Consume from beginning"
	@echo "  make kafka-describe TOPIC=<name>          - Describe topic details"
	@echo "  make kafka-offsets TOPIC=<name>           - Show topic offsets"
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
	@echo "=== Bazel 构建镜像 ==="
	bazel run //telemetry:image_load
	@echo "=== 加载镜像到 minikube ==="
	minikube image load telemetry:latest
	@echo "=== 重新部署服务 ==="
	kubectl apply -f telemetry/deployment.yaml -n app
	kubectl wait --for=condition=Available deployment/logistics-deployment -n app --timeout=60s
	@echo "=== 部署完成 ==="

# ============================================================
# Frontend
# ============================================================

frontend-dev:
	cd frontend && npm install && npm run dev

frontend-build:
	@echo "=== 構建前端 Docker 鏡像 ==="
	docker build -t frontend:latest frontend/
	@echo "=== 構建完成 ==="

frontend-deploy: frontend-build
	@echo "=== 加載鏡像到 minikube ==="
	minikube image load frontend:latest
	@echo "=== 部署前端服務 ==="
	kubectl apply -f frontend/deployment.yaml -n app
	kubectl wait --for=condition=Available deployment/frontend -n app --timeout=60s
	@echo "=== 部署完成 ==="

frontend-redeploy:
	@echo "=== 刪除現有部署 ==="
	-kubectl delete -f frontend/deployment.yaml -n app
	@echo "=== 刪除 minikube 中的舊鏡像 ==="
	-minikube image rm frontend:latest
	@echo "=== 重新構建並部署 ==="
	$(MAKE) frontend-deploy

# ============================================================
# Kafka
# ============================================================

kafka-shell:
	kubectl exec -it kafka-0 -n app -- /bin/bash

kafka-info:
	@echo "=== Kafka Broker Info ==="
	kubectl exec -n app kafka-0 -- /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
	@echo ""
	@echo "=== Kafka Topics ==="
	kubectl exec -n app kafka-0 -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

kafka-topics:
	kubectl exec -n app kafka-0 -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

kafka-consume:
ifndef TOPIC
	$(error TOPIC is required. Usage: make kafka-consume TOPIC=your-topic [FROM=all])
endif
ifeq ($(FROM),all)
	kubectl exec -it kafka-0 -n app -- /opt/kafka/bin/kafka-console-consumer.sh \
		--bootstrap-server localhost:9092 \
		--topic $(TOPIC) \
		--from-beginning
else
	kubectl exec -it kafka-0 -n app -- /opt/kafka/bin/kafka-console-consumer.sh \
		--bootstrap-server localhost:9092 \
		--topic $(TOPIC)
endif

kafka-describe:
ifndef TOPIC
	$(error TOPIC is required. Usage: make kafka-describe TOPIC=your-topic)
endif
	kubectl exec -n app kafka-0 -- /opt/kafka/bin/kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--describe \
		--topic $(TOPIC)

kafka-offsets:
ifndef TOPIC
	$(error TOPIC is required. Usage: make kafka-offsets TOPIC=your-topic)
endif
	kubectl exec -n app kafka-0 -- /opt/kafka/bin/kafka-run-class.sh kafka.tools.GetOffsetShell \
		--broker-list localhost:9092 \
		--topic $(TOPIC)

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



