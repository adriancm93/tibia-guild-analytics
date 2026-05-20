-- ============================================================
-- 014_update_historical_views_for_multi_guild.sql
-- Multi-guild-safe historical analytics views
-- ============================================================

-- ------------------------------------------------------------
-- Drop existing views first because the new versions add
-- guild_name and world columns to the front of the view outputs.
-- PostgreSQL cannot change view column order/name with
-- CREATE OR REPLACE VIEW alone.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.api_historical_character_level_changes;
DROP VIEW IF EXISTS public.api_historical_guild_joins;
DROP VIEW IF EXISTS public.api_historical_guild_leaves;
DROP VIEW IF EXISTS public.api_historical_rank_changes;

DROP VIEW IF EXISTS analytics.historical_character_level_changes;
DROP VIEW IF EXISTS analytics.historical_guild_joins;
DROP VIEW IF EXISTS analytics.historical_guild_leaves;
DROP VIEW IF EXISTS analytics.historical_rank_changes;
DROP VIEW IF EXISTS analytics.historical_snapshot_pairs;

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- View: analytics.historical_snapshot_pairs
--
-- Purpose:
-- Creates consecutive snapshot pairs per world + guild.
-- This prevents snapshots from different guilds/worlds being compared.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_snapshot_pairs AS
WITH ordered_snapshots AS (
    SELECT
        guild_name,
        world,
        extracted_at_utc AS latest_snapshot_time,
        LAG(extracted_at_utc) OVER (
            PARTITION BY world, guild_name
            ORDER BY extracted_at_utc
        ) AS previous_snapshot_time
    FROM (
        SELECT DISTINCT
            guild_name,
            world,
            extracted_at_utc
        FROM stg_guild_member_snapshot
    ) snapshots
)

SELECT
    guild_name,
    world,
    previous_snapshot_time,
    latest_snapshot_time
FROM ordered_snapshots
WHERE previous_snapshot_time IS NOT NULL;


-- ------------------------------------------------------------
-- View: analytics.historical_character_level_changes
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_character_level_changes AS
WITH latest AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.vocation,
        s.guild_rank,
        s.level
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.vocation,
        s.guild_rank,
        s.level
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.previous_snapshot_time
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    latest.vocation,
    latest.guild_rank,
    previous.level AS previous_level,
    latest.level AS current_level,
    latest.level - previous.level AS level_gain,
    latest.previous_snapshot_time,
    latest.latest_snapshot_time
FROM latest
JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
   AND latest.previous_snapshot_time = previous.previous_snapshot_time
   AND latest.latest_snapshot_time = previous.latest_snapshot_time
WHERE latest.level <> previous.level;


-- ------------------------------------------------------------
-- View: analytics.historical_guild_joins
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_guild_joins AS
WITH latest AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.vocation,
        s.level,
        s.guild_rank,
        s.status,
        s.joined_date
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.previous_snapshot_time
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    latest.vocation,
    latest.level,
    latest.guild_rank,
    latest.status,
    latest.joined_date,
    latest.previous_snapshot_time,
    latest.latest_snapshot_time
FROM latest
LEFT JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
   AND latest.previous_snapshot_time = previous.previous_snapshot_time
   AND latest.latest_snapshot_time = previous.latest_snapshot_time
WHERE previous.character_name IS NULL;


-- ------------------------------------------------------------
-- View: analytics.historical_guild_leaves
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_guild_leaves AS
WITH latest AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.vocation,
        s.level,
        s.guild_rank,
        s.status,
        s.joined_date
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.previous_snapshot_time
)

SELECT
    previous.guild_name,
    previous.world,
    previous.character_name,
    previous.vocation,
    previous.level,
    previous.guild_rank,
    previous.status,
    previous.joined_date,
    previous.previous_snapshot_time,
    previous.latest_snapshot_time
FROM previous
LEFT JOIN latest
    ON previous.guild_name = latest.guild_name
   AND previous.world = latest.world
   AND previous.character_name = latest.character_name
   AND previous.previous_snapshot_time = latest.previous_snapshot_time
   AND previous.latest_snapshot_time = latest.latest_snapshot_time
WHERE latest.character_name IS NULL;


-- ------------------------------------------------------------
-- View: analytics.historical_rank_changes
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_rank_changes AS
WITH latest AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.guild_rank
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.guild_name,
        p.world,
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.character_name,
        s.guild_rank
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.guild_name = p.guild_name
       AND s.world = p.world
       AND s.extracted_at_utc = p.previous_snapshot_time
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    previous.guild_rank AS previous_guild_rank,
    latest.guild_rank AS current_guild_rank,
    latest.previous_snapshot_time,
    latest.latest_snapshot_time
FROM latest
JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
   AND latest.previous_snapshot_time = previous.previous_snapshot_time
   AND latest.latest_snapshot_time = previous.latest_snapshot_time
WHERE latest.guild_rank <> previous.guild_rank;


-- ------------------------------------------------------------
-- Public API-facing wrapper views
--
-- Important:
-- These now include guild_name and world so the frontend can filter.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.api_historical_character_level_changes AS
SELECT
    guild_name,
    world,
    character_name,
    vocation,
    guild_rank,
    previous_level,
    current_level,
    level_gain,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.historical_character_level_changes;


CREATE OR REPLACE VIEW public.api_historical_guild_joins AS
SELECT
    guild_name,
    world,
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.historical_guild_joins;


CREATE OR REPLACE VIEW public.api_historical_guild_leaves AS
SELECT
    guild_name,
    world,
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.historical_guild_leaves;


CREATE OR REPLACE VIEW public.api_historical_rank_changes AS
SELECT
    guild_name,
    world,
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.historical_rank_changes;


GRANT SELECT ON public.api_historical_character_level_changes TO anon;
GRANT SELECT ON public.api_historical_guild_joins TO anon;
GRANT SELECT ON public.api_historical_guild_leaves TO anon;
GRANT SELECT ON public.api_historical_rank_changes TO anon;