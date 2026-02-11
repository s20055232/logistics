package service

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/lai/logistics/notification/db"
	"github.com/nikoksr/notify"
	"github.com/nikoksr/notify/service/mail"
)

type Notifier struct {
	queries      *db.Queries
	smtpHost     string
	smtpPort     int
	smtpUser     string
	smtpPassword string
}

func NewNotifier(queries *db.Queries, smtpHost string, smtpPort int, smtpUser, smtpPassword string) *Notifier {
	return &Notifier{
		queries:      queries,
		smtpHost:     smtpHost,
		smtpPort:     smtpPort,
		smtpUser:     smtpUser,
		smtpPassword: smtpPassword,
	}
}

func (n *Notifier) HandleBatch(ctx context.Context, events []GeofenceEvent) {
	for _, evt := range events {
		if err := n.handleEvent(ctx, evt); err != nil {
			slog.Error("handle event failed",
				"container_id", evt.ContainerID,
				"geofence", evt.GeofenceName,
				"error", err,
			)
		}
	}
}

func (n *Notifier) handleEvent(ctx context.Context, evt GeofenceEvent) error {
	recipients, err := n.queries.GetRecipientsByOwner(ctx, evt.OwnerID)
	if err != nil {
		return fmt.Errorf("get recipients: %w", err)
	}
	if len(recipients) == 0 {
		slog.Debug("no recipients for owner", "owner_id", evt.OwnerID)
		return nil
	}

	subject := fmt.Sprintf("[Logistics] Container %s %sed geofence %s",
		evt.ContainerID, evt.EventType, evt.GeofenceName)

	body := fmt.Sprintf(
		"Container: %s\nEvent: %s\nGeofence: %s\nLocation: %.6f, %.6f\nTime: %s",
		evt.ContainerID,
		evt.EventType,
		evt.GeofenceName,
		evt.Lat, evt.Lon,
		evt.Timestamp.Format("2006-01-02 15:04:05 UTC"),
	)

	emails := make([]string, len(recipients))
	for i, r := range recipients {
		emails[i] = r.Email
	}

	// Fresh mail service per event — nikoksr/notify accumulates receivers across
	// AddReceivers calls, so reusing would cause duplicate sends.
	mailSvc := mail.New(n.smtpUser, fmt.Sprintf("%s:%d", n.smtpHost, n.smtpPort))
	mailSvc.AuthenticateSMTP("", n.smtpUser, n.smtpPassword, n.smtpHost)
	mailSvc.AddReceivers(emails...)

	notifier := notify.New()
	notifier.UseServices(mailSvc)

	if err := notifier.Send(ctx, subject, body); err != nil {
		slog.Error("send email failed", "error", err, "recipients", emails)
		return fmt.Errorf("send email: %w", err)
	}

	for _, r := range recipients {
		if err := n.queries.RecordEmail(ctx, db.RecordEmailParams{
			ContainerID:    evt.ContainerID,
			GeofenceName:   evt.GeofenceName,
			EventType:      evt.EventType,
			RecipientEmail: r.Email,
			Subject:        subject,
		}); err != nil {
			slog.Error("record email failed", "recipient", r.Email, "error", err)
		}
	}

	slog.Info("notification sent",
		"container_id", evt.ContainerID,
		"event_type", evt.EventType,
		"geofence", evt.GeofenceName,
		"recipients", len(recipients),
	)

	return nil
}
