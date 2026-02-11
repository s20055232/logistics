CREATE EXTENSION IF NOT EXISTS pg_uuidv7;
CREATE TABLE IF NOT EXISTS notification_recipients (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    owner_id TEXT NOT NULL,
    email TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS notification_recipients_owner_idx ON notification_recipients (owner_id)
WHERE enabled = TRUE;
CREATE TABLE IF NOT EXISTS email_history (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    container_id TEXT NOT NULL,
    geofence_name TEXT NOT NULL,
    event_type TEXT NOT NULL,
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS email_history_container_idx ON email_history (container_id, sent_at DESC);
-- Seed notification recipients for development
-- owner_id 'dev-owner' matches ruleengine seed data
INSERT INTO notification_recipients (owner_id, email, name)
VALUES (
        'dev-owner',
        'your@gmail.com',
        'Dev Operator'
    );