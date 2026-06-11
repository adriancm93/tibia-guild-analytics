-- 026_create_character_online_intervals_cache.sql
-- Add interval-grain online time cache for character activity.
--
-- Grain:
-- One row per world/guild/character/snapshot interval.
--
-- Purpose:
-- Support date-scoped estimated online time without scanning raw snapshot
-- rows from the frontend.
--
-- Estimator rule:
-- If a character is online at the start of a snapshot interval, count the
-- elapsed time between the previous snapshot and the latest snapshot.
--
-- Status transitions:
-- online  -> online   = count interval
-- online  -> offline  = count interval
-- offline -> online   = count 0
-- offline -> offline  = count 0

SET statement_timeout = 0;

CREATE TABLE IF NOT EXISTS analytics.character_online_intervals_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    previous_snapshot_time timestamptz NOT NULL,
    latest_snapshot_time timestamptz NOT NULL,
    previous_status text,
    latest_status text,
    interval_minutes integer NOT NULL DEFAULT 0,
    estimated_online_minutes integer NOT NULL DEFAULT 0,
    created_at_utc timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT character_online_intervals_cache_pkey
        PRIMARY KEY (
            world,
            guild_name,
            character_name,
            previous_snapshot_time,
            latest_snapshot_time
        ),

    CONSTRAINT character_online_intervals_positive_interval
        CHECK (latest_snapshot_time > previous_snapshot_time),

    CONSTRAINT character_online_intervals_nonnegative_minutes
        CHECK (
            interval_minutes >= 0
            AND estimated_online_minutes >= 0
        )
);

CREATE INDEX IF NOT EXISTS idx_character_online_intervals_filter_sort
    ON analytics.character_online_intervals_cache (
        world,
        guild_name,
        latest_snapshot_time DESC,
        character_name
    );

CREATE INDEX IF NOT EXISTS idx_character_online_intervals_character_time
    ON analytics.character_online_intervals_cache (
        world,
        guild_name,
        character_name,
        latest_snapshot_time DESC
    );

GRANT SELECT ON analytics.character_online_intervals_cache TO anon;
GRANT SELECT ON analytics.character_online_intervals_cache TO authenticated;

NOTIFY pgrst, 'reload schema';
