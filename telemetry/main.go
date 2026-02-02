package main

import (
	"context"
	"log"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

func main() {
	// write log to stdout/stderr and Kubernetes or Docker will capture it
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)
	brokers := strings.Split(getenv("KAFKA_BROKERS", "kafka.app.svc.cluster.local:9092"), ",")
	topic := getenv("KAFKA_TOPIC", "container.telemetry")
	addr := getenv("LISTEN_ADDR", ":8080")

	producer := NewKafkaProducer(brokers, topic)
	defer producer.Close()

	handler := NewHandler(producer)

	mux := http.NewServeMux()
	mux.Handle("/api/track", handler)
	srv := &http.Server{
		Addr:         addr,
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	done := make(chan struct{})
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		srv.Shutdown(ctx)
		close(done)
	}()

	slog.Info("telemetry service listening", "addr", addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatal(err)
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
