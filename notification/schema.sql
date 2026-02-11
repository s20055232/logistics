-- Enable UUIDv7 extension (time-ordered, no index fragmentation)
CREATE EXTENSION IF NOT EXISTS pg_uuidv7;

-- Notification recipients — who gets emailed on geofence events
CREATE TABLE notification_recipients (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    owner_id TEXT NOT NULL,
    email TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX notification_recipients_owner_idx
    ON notification_recipients (owner_id) WHERE enabled = TRUE;

-- Email sending history — append-only log
CREATE TABLE email_history (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    container_id TEXT NOT NULL,
    geofence_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX email_history_container_idx
    ON email_history (container_id, sent_at DESC);
