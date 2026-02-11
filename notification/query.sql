-- name: GetRecipientsByOwner :many
SELECT email, name FROM notification_recipients
WHERE owner_id = $1 AND enabled = TRUE;

-- name: RecordEmail :exec
INSERT INTO email_history (container_id, geofence_name, event_type, recipient_email, subject)
VALUES ($1, $2, $3, $4, $5);
