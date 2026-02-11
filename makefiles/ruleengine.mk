.PHONY: ruleengine-build ruleengine-test ruleengine-sqlc ruleengine-migrate-configmap help-ruleengine

help-ruleengine:
	@echo "Rule Engine Service"
	@echo ""
	@echo "Build:"
	@echo "  make ruleengine-build              - Build the service"
	@echo "  make ruleengine-sqlc               - Generate sqlc code"
	@echo ""
	@echo "Database:"
	@echo "  make ruleengine-migrate-configmap   - Generate ConfigMap from db/migrations/"
	@echo ""
	@echo "Testing:"
	@echo "  make ruleengine-test               - Run all unit tests"

ruleengine-build:
	cd ruleengine && go build -o /tmp/ruleengine ./cmd/...

ruleengine-test:
	cd ruleengine && go test -v ./...

ruleengine-sqlc:
	cd ruleengine && sqlc generate

ruleengine-migrate-configmap:
	cd ruleengine && kubectl create configmap ruleengine-migrations --namespace=app --from-file=db/migrations/ --dry-run=client -o yaml > migrate-jobs/migrations-configmap.yaml
	@echo "Generated migrate-jobs/migrations-configmap.yaml from db/migrations/"
