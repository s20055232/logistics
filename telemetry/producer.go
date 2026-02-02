package main

import (
	"context"
	"encoding/json"
	"time"

	"github.com/segmentio/kafka-go"
)

// Producer writes TrackPoints to Kafka in batches.
type KafkaProducer struct {
	writer *kafka.Writer
}

// NewProducer creates a producer for the given topic.
func NewKafkaProducer(brokers []string, topic string) *KafkaProducer {
	w := &kafka.Writer{
		Addr:                   kafka.TCP(brokers...),
		Topic:                  topic,
		Balancer:               &kafka.LeastBytes{},
		BatchSize:              100,
		BatchTimeout:           10 * time.Millisecond,
		Async:                  true,
		RequiredAcks:           kafka.RequireOne,
		AllowAutoTopicCreation: true,
	}
	return &KafkaProducer{writer: w}
}

// Write sends a TrackPoint to Kafka.
func (p *KafkaProducer) Write(ctx context.Context, tp TrackPoint) error {
	data, err := json.Marshal(tp)
	if err != nil {
		return err
	}
	return p.writer.WriteMessages(ctx, kafka.Message{
		Key:   []byte(tp.ContainerID),
		Value: data,
	})
}

// Close flushes pending messages and closes the connection.
func (p *KafkaProducer) Close() error {
	return p.writer.Close()
}
