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

type OnBatch func([]GeofenceEvent)

type KafkaConsumer struct {
	reader       *kafka.Reader
	onBatch      OnBatch
	batchSize    int
	batchTimeout time.Duration
	mu           sync.Mutex
	batch        []GeofenceEvent
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
		batch:        make([]GeofenceEvent, 0, batchSize),
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

			var evt GeofenceEvent
			if err := json.Unmarshal(msg.Value, &evt); err != nil {
				slog.Warn("invalid message", "error", err, "offset", msg.Offset)
				c.reader.CommitMessages(ctx, msg)
				continue
			}

			c.mu.Lock()
			c.batch = append(c.batch, evt)
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
	c.batch = make([]GeofenceEvent, 0, c.batchSize)
	c.mu.Unlock()

	c.onBatch(toFlush)
}

func (c *KafkaConsumer) Close() error {
	return c.reader.Close()
}
