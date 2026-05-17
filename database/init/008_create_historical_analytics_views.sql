-- ============================================================
-- 008_create_historical_analytics_views.sql
-- Historical analytics views for date-range frontend filtering
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- View: analytics.historical_snapshot_pairs
--
-- Purpose:
-- Creates one comparison pair for every snapshot and its
-- immediately previous snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_snapshot_pairs AS
WITH ordered_snapshots AS (
    SELECT
        extracted_at_utc AS latest_snapshot_time,
        LAG(extracted_at_utc) OVER (
            ORDER BY extracted_at_utc
        ) AS previous_snapshot_time
    FROM (
        SELECT DISTINCT
            extracted_at_utc
        FROM stg_guild_member_snapshot
    ) snapshots
)

SELECT
    previous_snapshot_time,
    latest_snapshot_time
FROM ordered_snapshots
WHERE previous_snapshot_time IS NOT NULL;


-- ------------------------------------------------------------
-- View: analytics.historical_character_level_changes
--
-- Purpose:
-- Shows all level changes across all consecutive snapshot pairs.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_character_level_changes AS
WITH latest AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.previous_snapshot_time
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
--
-- Purpose:
-- Shows all characters who joined between consecutive snapshots.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_guild_joins AS
WITH latest AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.previous_snapshot_time
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
--
-- Purpose:
-- Shows all characters who left between consecutive snapshots.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_guild_leaves AS
WITH latest AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.previous_snapshot_time
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
--
-- Purpose:
-- Shows all rank changes between consecutive snapshots.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.historical_rank_changes AS
WITH latest AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.latest_snapshot_time
),

previous AS (
    SELECT
        p.previous_snapshot_time,
        p.latest_snapshot_time,
        s.*
    FROM analytics.historical_snapshot_pairs p
    JOIN stg_guild_member_snapshot s
        ON s.extracted_at_utc = p.previous_snapshot_time
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
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.api_historical_character_level_changes AS
SELECT
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