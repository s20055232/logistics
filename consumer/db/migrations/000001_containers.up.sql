CREATE TABLE containers (
    id UUID DEFAULT uuid_generate_v7() PRIMARY KEY,
    container_id TEXT NOT NULL UNIQUE,
    owner TEXT,
    container_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS containers_container_id_idx ON containers (container_id);