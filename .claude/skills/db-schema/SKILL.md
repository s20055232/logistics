---
name: db-schema
description: Design PostgreSQL schemas and generate migration files following golang-migrate conventions. Use when creating new tables, modifying schemas, adding indexes, or setting up TimescaleDB hypertables.
---

# Database Schema

## Purpose

Design PostgreSQL schemas and generate paired up/down migration files following golang-migrate conventions and TimescaleDB best practices used in this project.

**Critical**: All migrations must be idempotent (safe to run multiple times).

## Process

1. **Understand the requirement**
   - What data needs to be stored?
   - What are the relationships?
   - What queries will run against this data?

2. **Find the next migration number**
   - Check `consumer/db/migrations/` for existing migrations
   - Use sequential 6-digit format: `000001`, `000002`, etc.

3. **Design the schema**
   - Follow PostgreSQL best practices
   - Use appropriate data types
   - Add constraints and indexes

4. **Generate both migration files**
   - `{version}_{name}.up.sql` - Creates/modifies schema
   - `{version}_{name}.down.sql` - Reverts changes completely

5. **Update sqlc if needed**
   - Add queries to `consumer/db/query.sql`
   - Update `consumer/db/schema.sql` if maintaining full schema
   - Run `sqlc generate` to regenerate Go code

## Migration File Format

See [reference/MIGRATIONS.md](reference/MIGRATIONS.md) for full golang-migrate documentation.

**This project uses sequential numbering:**

```
000001_extensions.up.sql
000001_extensions.down.sql
000002_containers.up.sql
000002_containers.down.sql
```

## Example Migration

**000005_orders.up.sql**
```sql
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
    container_id TEXT NOT NULL REFERENCES containers(id),
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_status CHECK (status IN ('pending', 'active', 'completed', 'cancelled'))
);

CREATE INDEX orders_container_idx ON orders (container_id);
CREATE INDEX orders_status_idx ON orders (status) WHERE status != 'completed';
```

**000005_orders.down.sql**
```sql
DROP TABLE IF EXISTS orders;
```

## TimescaleDB Patterns

For time-series data, use hypertables. See [reference/timescaledb.md](reference/timescaledb.md).

```sql
-- Create table first
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL
);

-- Convert to hypertable
SELECT create_hypertable('sensor_data', 'time', chunk_time_interval => INTERVAL '7 days');

-- Add index for common query pattern
CREATE INDEX sensor_data_device_time_idx ON sensor_data (device_id, time DESC);
```

## Best Practices

1. **Always create both up and down migrations**
   - Down migration must fully revert the up migration
   - Use `DROP TABLE IF EXISTS` for safety

2. **One logical change per migration**
   - Don't mix unrelated schema changes
   - Makes rollback predictable

3. **Use constraints**
   - `NOT NULL` where appropriate
   - `CHECK` constraints for valid values
   - Foreign keys for referential integrity

4. **Index strategically**
   - Index columns used in WHERE clauses
   - Use partial indexes when filtering common values
   - Composite indexes for multi-column queries (most selective first)

5. **Use appropriate data types**
   - `TIMESTAMPTZ` for timestamps (not `TIMESTAMP`)
   - `TEXT` over `VARCHAR` (PostgreSQL handles equally)
   - `UUID` with `uuid_generate_v7()` for time-ordered IDs

6. **PostgreSQL-specific features**
   - Use `IF EXISTS` / `IF NOT EXISTS` for idempotency
   - Leverage partial indexes
   - Use `JSONB` for semi-structured data

## Related Skills

- `/supabase-postgres-best-practices` - Query optimization and performance
