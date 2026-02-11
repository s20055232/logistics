.PHONY: notification-build notification-test notification-sqlc notification-migrate-configmap notification-smtp-secret help-notification

help-notification:
	@echo "Notification Service"
	@echo ""
	@echo "Build:"
	@echo "  make notification-build              - Build the service"
	@echo "  make notification-sqlc               - Generate sqlc code"
	@echo ""
	@echo "Database:"
	@echo "  make notification-migrate-configmap   - Generate ConfigMap from db/migrations/"
	@echo ""
	@echo "Secrets:"
	@echo "  make notification-smtp-secret         - Create SMTP secret (requires SMTP_USER and SMTP_PASSWORD)"
	@echo ""
	@echo "Testing:"
	@echo "  make notification-test               - Run all unit tests"

notification-build:
	cd notification && go build -o /tmp/notification ./cmd/...

notification-test:
	cd notification && go test -v ./...

notification-sqlc:
	cd notification && sqlc generate

notification-migrate-configmap:
	cd notification && kubectl create configmap notification-migrations --namespace=app --from-file=db/migrations/ --dry-run=client -o yaml > migrate-jobs/migrations-configmap.yaml
	@echo "Generated migrate-jobs/migrations-configmap.yaml from db/migrations/"

notification-smtp-secret:
ifndef SMTP_USER
	$(error SMTP_USER is required. Usage: make notification-smtp-secret SMTP_USER=you@gmail.com SMTP_PASSWORD=your-app-password)
endif
ifndef SMTP_PASSWORD
	$(error SMTP_PASSWORD is required. Usage: make notification-smtp-secret SMTP_USER=you@gmail.com SMTP_PASSWORD=your-app-password)
endif
	kubectl create secret generic notification-smtp --namespace=app --from-literal=user='$(SMTP_USER)' --from-literal=password='$(SMTP_PASSWORD)' --dry-run=client -o yaml | kubectl apply -f -
	@echo "SMTP secret created/updated in namespace app"
