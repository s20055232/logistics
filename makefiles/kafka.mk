# Kafka
.PHONY: kafka-shell kafka-info kafka-topics kafka-consume kafka-describe kafka-offsets help-kafka

help-kafka:
	@echo "Kafka:"
	@echo "  make kafka-shell                            - Enter Kafka container"
	@echo "  make kafka-info                             - Show Kafka broker and topics"
	@echo "  make kafka-topics                           - List all topics"
	@echo "  make kafka-consume TOPIC=<name>             - Consume new messages"
	@echo "  make kafka-consume TOPIC=<name> FROM=all    - Consume from beginning"
	@echo "  make kafka-describe TOPIC=<name>            - Describe topic details"
	@echo "  make kafka-offsets TOPIC=<name>             - Show topic offsets"

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
