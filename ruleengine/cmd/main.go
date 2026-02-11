package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/lai/logistics/ruleengine/db"
	"github.com/lai/logistics/ruleengine/service"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	// Config from env (defaults for K8s deployment)
	dbURL := getenv("DATABASE_URL", "postgres://app:password@telemetry-timescaledb-rw.app.svc.cluster.local:5432/app")
	kafkaBrokers := strings.Split(getenv("KAFKA_BROKERS", "kafka.app.svc.cluster.local:9092"), ",")
	kafkaTopic := getenv("KAFKA_TOPIC", "container.telemetry")
	kafkaGroup := getenv("KAFKA_GROUP", "ruleengine-service")
	notifyTopic := getenv("NOTIFY_TOPIC", "geofence.events")
	addr := getenv("LISTEN_ADDR", ":8082")
	batchSize := getenvInt("BATCH_SIZE", 100)
	batchTimeout := getenvDuration("BATCH_TIMEOUT", 1*time.Second)

	// Database pool
	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		slog.Error("database connection failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	queries := db.New(pool)
	producer := service.NewEventProducer(kafkaBrokers, notifyTopic)
	defer producer.Close()

	engine := service.NewRuleEngine(queries, producer)

	// Kafka consumer with batch callback
	kafkaConsumer := service.NewKafkaConsumer(
		kafkaBrokers, kafkaTopic, kafkaGroup,
		batchSize, batchTimeout,
		func(points []service.TrackPoint) {
			engine.EvaluateBatch(context.Background(), points)
			slog.Info("evaluated batch", "count", len(points))
		},
	)

	// Context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go kafkaConsumer.Run(ctx)

	// HTTP server (health only)
	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler(pool))

	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// Graceful shutdown
	done := make(chan struct{})
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		slog.Info("shutting down...")
		cancel()

		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer shutdownCancel()

		srv.Shutdown(shutdownCtx)
		kafkaConsumer.Close()
		close(done)
	}()

	slog.Info("ruleengine service listening", "addr", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		slog.Error("server error", "error", err)
		os.Exit(1)
	}

	<-done
	slog.Info("shutdown complete")
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}

func getenvDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return fallback
}

func healthHandler(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := pool.Ping(r.Context()); err != nil {
			http.Error(w, "database unhealthy", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	}
}
