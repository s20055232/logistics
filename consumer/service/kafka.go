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

// OnBatch is called when a batch of TrackPoints is ready
type OnBatch func([]TrackPoint)

// KafkaConsumerConfig holds configuration for the Kafka consumer
type KafkaConsumerConfig struct {
	Brokers      []string
	Topic        string
	GroupID      string
	BatchSize    int
	BatchTimeout time.Duration
}

// KafkaConsumer reads TrackPoints from Kafka and batches them
type KafkaConsumer struct {
	reader       *kafka.Reader
	onBatch      OnBatch
	batchSize    int
	batchTimeout time.Duration
	mu           sync.Mutex
	batch        []TrackPoint
	timer        *time.Timer
}

// NewKafkaConsumer creates a consumer for the given config
func NewKafkaConsumer(cfg KafkaConsumerConfig, onBatch OnBatch) *KafkaConsumer {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:        cfg.Brokers,
		Topic:          cfg.Topic,
		GroupID:        cfg.GroupID,
		MinBytes:       1,
		MaxBytes:       10e6, // 10MB
		CommitInterval: time.Second,
		StartOffset:    kafka.FirstOffset,
	})

	return &KafkaConsumer{
		reader:       reader,
		onBatch:      onBatch,
		batchSize:    cfg.BatchSize,
		batchTimeout: cfg.BatchTimeout,
		batch:        make([]TrackPoint, 0, cfg.BatchSize),
	}
}

// Run starts consuming messages until context is cancelled
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

// Close closes the Kafka reader
func (c *KafkaConsumer) Close() error {
	return c.reader.Close()
}
