package main

import (
	"context"
	"encoding/json"
	"time"

	"github.com/segmentio/kafka-go"
)

// Producer writes TrackPoints to Kafka in batches.
type Producer struct {
	writer *kafka.Writer
}

// NewProducer creates a producer for the given topic.
func NewProducer(brokers []string, topic string) *Producer {
	w := &kafka.Writer{
		Addr:         kafka.TCP(brokers...),
		Topic:        topic,
		Balancer:     &kafka.LeastBytes{},
		BatchSize:    100,
		BatchTimeout: 10 * time.Millisecond,
		Async:        true,
		RequiredAcks: kafka.RequireOne,
	}
	return &Producer{writer: w}
}

// Write sends a TrackPoint to Kafka.
func (p *Producer) Write(ctx context.Context, tp TrackPoint) error {
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
func (p *Producer) Close() error {
	return p.writer.Close()
}
