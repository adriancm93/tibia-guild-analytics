-- ============================================================
-- 012_create_multi_guild_metadata.sql
-- Multi-world and multi-guild metadata foundation
-- ============================================================

-- ------------------------------------------------------------
-- Table: tibia_world
--
-- Purpose:
-- Stores worlds discovered from TibiaData/Tibia.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tibia_world (
    world_name text PRIMARY KEY,
    is_active boolean NOT NULL DEFAULT true,
    discovered_at_utc timestamp with time zone NOT NULL DEFAULT now(),
    updated_at_utc timestamp with time zone NOT NULL DEFAULT now()
);


-- ------------------------------------------------------------
-- Table: tibia_guild
--
-- Purpose:
-- Stores guilds discovered per world and controls refresh cadence.
--
-- This table will later act as the queue source for batch ingestion.
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tibia_guild (
    guild_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    guild_name text NOT NULL,
    world text NOT NULL REFERENCES tibia_world(world_name),
    is_active boolean NOT NULL DEFAULT true,

    -- Refresh control
    refresh_interval_minutes integer NOT NULL DEFAULT 120,
    next_refresh_after_utc timestamp with time zone,
    last_refresh_started_at_utc timestamp with time zone,
    last_refresh_completed_at_utc timestamp with time zone,
    last_refresh_status text,
    last_refresh_error text,

    -- Optional prioritization for future use
    refresh_priority integer NOT NULL DEFAULT 100,

    discovered_at_utc timestamp with time zone NOT NULL DEFAULT now(),
    updated_at_utc timestamp with time zone NOT NULL DEFAULT now(),

    CONSTRAINT uq_tibia_guild_world_name UNIQUE (world, guild_name)
);


-- ------------------------------------------------------------
-- Indexes for metadata lookup and future batch selection
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_tibia_guild_world
    ON tibia_guild (world);

CREATE INDEX IF NOT EXISTS idx_tibia_guild_active_due
    ON tibia_guild (is_active, next_refresh_after_utc, refresh_priority);

CREATE INDEX IF NOT EXISTS idx_tibia_guild_world_name
    ON tibia_guild (world, guild_name);


-- ------------------------------------------------------------
-- Indexes for existing snapshot tables
--
-- These are important once the data contains many worlds/guilds.
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_raw_guild_snapshot_world_guild_time
    ON raw_guild_snapshot (world, guild_name, extracted_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_world_guild_time
    ON guild_member_snapshot (world, guild_name, extracted_at_utc DESC);

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_world_guild_character_time
    ON guild_member_snapshot (world, guild_name, character_name, extracted_at_utc DESC);


-- ------------------------------------------------------------
-- Function: apply_snapshot_retention
--
-- Purpose:
-- Deletes raw snapshots older than the retention window.
--
-- Because guild_member_snapshot has a foreign key to raw_guild_snapshot
-- with ON DELETE CASCADE, deleting old raw snapshots also removes the
-- related parsed member snapshot rows.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.apply_snapshot_retention(
    retention_window interval DEFAULT interval '3 months'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    deleted_count integer;
BEGIN
    DELETE FROM raw_guild_snapshot
    WHERE extracted_at_utc < now() - retention_window;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RETURN deleted_count;
END;
$$;


-- ------------------------------------------------------------
-- Seed current known world/guild so the existing production flow
-- has a metadata record before full discovery exists.
-- ------------------------------------------------------------

INSERT INTO tibia_world (world_name, is_active)
VALUES ('Lobera', true)
ON CONFLICT (world_name)
DO UPDATE SET
    is_active = EXCLUDED.is_active,
    updated_at_utc = now();


INSERT INTO tibia_guild (
    guild_name,
    world,
    is_active,
    refresh_interval_minutes,
    next_refresh_after_utc,
    last_refresh_status
)
VALUES (
    'Black Clover',
    'Lobera',
    true,
    120,
    now(),
    'seeded'
)
ON CONFLICT (world, guild_name)
DO UPDATE SET
    is_active = EXCLUDED.is_active,
    refresh_interval_minutes = EXCLUDED.refresh_interval_minutes,
    updated_at_utc = now();