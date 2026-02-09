# makefiles/timescaledb.mk - TimescaleDB Image Management

TIMESCALEDB_IMAGE := timescaledb-postgis-uuidv7
TIMESCALEDB_TAG := 17
TIMESCALEDB_REGISTRY := ghcr.io/$(shell git config user.name | tr '[:upper:]' '[:lower:]')

.PHONY: timescaledb-build timescaledb-push timescaledb-load timescaledb-clean help-timescaledb

timescaledb-build:
	docker build --platform linux/amd64 -f consumer/timescaledb/Dockerfile -t $(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG) consumer/

timescaledb-push: timescaledb-build
	docker tag $(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG) $(TIMESCALEDB_REGISTRY)/$(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG)
	docker push $(TIMESCALEDB_REGISTRY)/$(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG)

timescaledb-load: timescaledb-build
	minikube ssh "docker rmi -f $(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG) 2>/dev/null || true"
	minikube image load $(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG)

timescaledb-clean:
	docker rmi $(TIMESCALEDB_IMAGE):$(TIMESCALEDB_TAG) || true

help-timescaledb:
	@echo "TimescaleDB Image Management"
	@echo "  make timescaledb-build  - Build image"
	@echo "  make timescaledb-load   - Load to minikube"
	@echo "  make timescaledb-push   - Push to registry"
	@echo "  make timescaledb-clean  - Remove local image"
