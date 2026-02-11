package service

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"sync"
	"time"

	"github.com/segmentio/kafka-go"
)

// --- Kafka Consumer (same pattern as consumer/service/kafka.go) ---

type OnBatch func([]TrackPoint)

type KafkaConsumer struct {
	reader       *kafka.Reader
	onBatch      OnBatch
	batchSize    int
	batchTimeout time.Duration
	mu           sync.Mutex
	batch        []TrackPoint
	timer        *time.Timer
}

func NewKafkaConsumer(brokers []string, topic, groupID string, batchSize int, batchTimeout time.Duration, onBatch OnBatch) *KafkaConsumer {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:        brokers,
		Topic:          topic,
		GroupID:        groupID,
		MinBytes:       1,
		MaxBytes:       10e6,
		CommitInterval: time.Second,
		StartOffset:    kafka.FirstOffset,
	})
	return &KafkaConsumer{
		reader:       reader,
		onBatch:      onBatch,
		batchSize:    batchSize,
		batchTimeout: batchTimeout,
		batch:        make([]TrackPoint, 0, batchSize),
	}
}

func (c *KafkaConsumer) Run(ctx context.Context) {
	slog.Info("starting Kafka consumer",
		"brokers", c.reader.Config().Brokers,
		"topic", c.reader.Config().Topic,
		"group_id", c.reader.Config().GroupID,
	)
	c.timer = time.NewTimer(c.batchTimeout)
	defer c.timer.Stop()

	for {
		select {
		case <-ctx.Done():
			c.flush()
			return
		case <-c.timer.C:
			c.flush()
			c.timer.Reset(c.batchTimeout)
		default:
			readCtx, cancel := context.WithTimeout(ctx, 100*time.Millisecond)
			msg, err := c.reader.FetchMessage(readCtx)
			cancel()

			if err != nil {
				if errors.Is(err, context.DeadlineExceeded) {
					continue
				}
				slog.Error("fetch message failed", "error", err)
				if ctx.Err() != nil {
					return
				}
				continue
			}

			var tp TrackPoint
			if err := json.Unmarshal(msg.Value, &tp); err != nil {
				slog.Warn("invalid message", "error", err, "offset", msg.Offset)
				c.reader.CommitMessages(ctx, msg)
				continue
			}

			c.mu.Lock()
			c.batch = append(c.batch, tp)
			shouldFlush := len(c.batch) >= c.batchSize
			c.mu.Unlock()

			if shouldFlush {
				c.flush()
				c.timer.Reset(c.batchTimeout)
			}

			c.reader.CommitMessages(ctx, msg)
		}
	}
}

func (c *KafkaConsumer) flush() {
	c.mu.Lock()
	if len(c.batch) == 0 {
		c.mu.Unlock()
		return
	}
	toFlush := c.batch
	c.batch = make([]TrackPoint, 0, c.batchSize)
	c.mu.Unlock()

	c.onBatch(toFlush)
}

func (c *KafkaConsumer) Close() error {
	return c.reader.Close()
}

// --- Kafka Producer for geofence events ---

type EventProducer struct {
	writer *kafka.Writer
}

func NewEventProducer(brokers []string, topic string) *EventProducer {
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
	return &EventProducer{writer: w}
}

func (p *EventProducer) Publish(ctx context.Context, evt GeofenceEvent) error {
	data, err := json.Marshal(evt)
	if err != nil {
		return err
	}
	return p.writer.WriteMessages(ctx, kafka.Message{
		Key:   []byte(evt.ContainerID),
		Value: data,
	})
}

func (p *EventProducer) Close() error {
	return p.writer.Close()
}
