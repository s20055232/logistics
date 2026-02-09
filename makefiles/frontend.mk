# Frontend
.PHONY: frontend-build frontend-deploy frontend-redeploy frontend-dev help-frontend

help-frontend:
	@echo "Frontend:"
	@echo "  make frontend-dev       - Start frontend dev server"
	@echo "  make frontend-build     - Build frontend Docker image"
	@echo "  make frontend-deploy    - Deploy frontend to Kubernetes"
	@echo "  make frontend-redeploy  - Redeploy frontend"

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
