SET statement_timeout = '0';

-- ============================================================
-- 020_materialize_movement_api_views.sql
-- Materialize guild movement API views directly from base table
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- Base indexes for fast snapshot comparison
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_gms_world_guild_time_character
    ON guild_member_snapshot (
        world,
        guild_name,
        extracted_at_utc,
        character_name
    );

CREATE INDEX IF NOT EXISTS idx_gms_world_guild_character_time
    ON guild_member_snapshot (
        world,
        guild_name,
        character_name,
        extracted_at_utc
    );

CREATE INDEX IF NOT EXISTS idx_gms_world_guild_time
    ON guild_member_snapshot (
        world,
        guild_name,
        extracted_at_utc
    );

-- ------------------------------------------------------------
-- Drop public API views first
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.api_historical_guild_joins;
DROP VIEW IF EXISTS public.api_historical_guild_leaves;
DROP VIEW IF EXISTS public.api_historical_rank_changes;

-- ------------------------------------------------------------
-- Drop old materialized views if they exist
-- ------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS analytics.guild_joins_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.guild_leaves_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.rank_changes_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.snapshot_pairs_api_materialized;

-- ------------------------------------------------------------
-- Snapshot pairs materialized source
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW analytics.snapshot_pairs_api_materialized AS
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
        FROM guild_member_snapshot
    ) snapshots
)

SELECT
    guild_name,
    world,
    previous_snapshot_time,
    latest_snapshot_time
FROM ordered_snapshots
WHERE previous_snapshot_time IS NOT NULL;

CREATE INDEX idx_snapshot_pairs_api_filter
    ON analytics.snapshot_pairs_api_materialized (
        world,
        guild_name,
        latest_snapshot_time DESC
    );

-- ------------------------------------------------------------
-- Guild Joins materialized API source
-- Character exists in latest snapshot but not previous snapshot
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW analytics.guild_joins_api_materialized AS
SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    latest.vocation,
    latest.level,
    latest.guild_rank,
    latest.status,
    latest.joined AS joined_date,
    pairs.previous_snapshot_time,
    pairs.latest_snapshot_time
FROM analytics.snapshot_pairs_api_materialized pairs
JOIN guild_member_snapshot latest
    ON latest.guild_name = pairs.guild_name
   AND latest.world = pairs.world
   AND latest.extracted_at_utc = pairs.latest_snapshot_time
WHERE NOT EXISTS (
    SELECT 1
    FROM guild_member_snapshot previous
    WHERE previous.guild_name = pairs.guild_name
      AND previous.world = pairs.world
      AND previous.extracted_at_utc = pairs.previous_snapshot_time
      AND previous.character_name = latest.character_name
);

CREATE INDEX idx_guild_joins_api_filter_sort
    ON analytics.guild_joins_api_materialized (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level DESC,
        character_name ASC
    );

-- ------------------------------------------------------------
-- Guild Leaves materialized API source
-- Character exists in previous snapshot but not latest snapshot
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW analytics.guild_leaves_api_materialized AS
SELECT
    previous.guild_name,
    previous.world,
    previous.character_name,
    previous.vocation,
    previous.level,
    previous.guild_rank,
    previous.status,
    previous.joined AS joined_date,
    pairs.previous_snapshot_time,
    pairs.latest_snapshot_time
FROM analytics.snapshot_pairs_api_materialized pairs
JOIN guild_member_snapshot previous
    ON previous.guild_name = pairs.guild_name
   AND previous.world = pairs.world
   AND previous.extracted_at_utc = pairs.previous_snapshot_time
WHERE NOT EXISTS (
    SELECT 1
    FROM guild_member_snapshot latest
    WHERE latest.guild_name = pairs.guild_name
      AND latest.world = pairs.world
      AND latest.extracted_at_utc = pairs.latest_snapshot_time
      AND latest.character_name = previous.character_name
);

CREATE INDEX idx_guild_leaves_api_filter_sort
    ON analytics.guild_leaves_api_materialized (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level DESC,
        character_name ASC
    );

-- ------------------------------------------------------------
-- Rank Changes materialized API source
-- Same character exists in both snapshots but rank changed
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW analytics.rank_changes_api_materialized AS
SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    previous.guild_rank AS previous_guild_rank,
    latest.guild_rank AS current_guild_rank,
    pairs.previous_snapshot_time,
    pairs.latest_snapshot_time
FROM analytics.snapshot_pairs_api_materialized pairs
JOIN guild_member_snapshot latest
    ON latest.guild_name = pairs.guild_name
   AND latest.world = pairs.world
   AND latest.extracted_at_utc = pairs.latest_snapshot_time
JOIN guild_member_snapshot previous
    ON previous.guild_name = pairs.guild_name
   AND previous.world = pairs.world
   AND previous.extracted_at_utc = pairs.previous_snapshot_time
   AND previous.character_name = latest.character_name
WHERE latest.guild_rank IS DISTINCT FROM previous.guild_rank;

CREATE INDEX idx_rank_changes_api_filter_sort
    ON analytics.rank_changes_api_materialized (
        world,
        guild_name,
        latest_snapshot_time DESC,
        character_name ASC
    );

-- ------------------------------------------------------------
-- Recreate public API views
-- ------------------------------------------------------------

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
FROM analytics.guild_joins_api_materialized;

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
FROM analytics.guild_leaves_api_materialized;

CREATE OR REPLACE VIEW public.api_historical_rank_changes AS
SELECT
    guild_name,
    world,
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.rank_changes_api_materialized;

GRANT SELECT ON public.api_historical_guild_joins TO anon;
GRANT SELECT ON public.api_historical_guild_leaves TO anon;
GRANT SELECT ON public.api_historical_rank_changes TO anon;

GRANT SELECT ON analytics.snapshot_pairs_api_materialized TO anon;
GRANT SELECT ON analytics.guild_joins_api_materialized TO anon;
GRANT SELECT ON analytics.guild_leaves_api_materialized TO anon;
GRANT SELECT ON analytics.rank_changes_api_materialized TO anon;

-- ------------------------------------------------------------
-- Refresh all frontend materialized analytics
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_character_estimated_online_minutes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.character_estimated_online_minutes;
    REFRESH MATERIALIZED VIEW analytics.character_level_changes_with_online;
    REFRESH MATERIALIZED VIEW analytics.snapshot_pairs_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.guild_joins_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.guild_leaves_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.rank_changes_api_materialized;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO service_role;

RESET statement_timeout;