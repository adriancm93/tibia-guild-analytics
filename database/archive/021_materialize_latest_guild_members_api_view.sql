SET statement_timeout = '0';

-- ============================================================
-- 021_materialize_latest_guild_members_api_view.sql
-- Materialize latest guild members API view for frontend performance
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- Drop public API view first
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.api_latest_guild_members;

DROP MATERIALIZED VIEW IF EXISTS analytics.latest_guild_members_api_materialized;

-- ------------------------------------------------------------
-- Latest guild members materialized API source
-- ------------------------------------------------------------

CREATE MATERIALIZED VIEW analytics.latest_guild_members_api_materialized AS
WITH latest_snapshot AS (
    SELECT
        guild_name,
        world,
        MAX(extracted_at_utc) AS latest_snapshot_time
    FROM guild_member_snapshot
    GROUP BY
        guild_name,
        world
),

latest_roster AS (
    SELECT
        s.guild_name,
        s.world,
        s.character_name,
        s.vocation,
        s.guild_rank,
        s.level AS current_level,
        s.extracted_at_utc AS latest_snapshot_time
    FROM guild_member_snapshot s
    JOIN latest_snapshot l
        ON s.guild_name = l.guild_name
       AND s.world = l.world
       AND s.extracted_at_utc = l.latest_snapshot_time
),

online_activity AS (
    SELECT
        guild_name,
        world,
        character_name,
        MAX(extracted_at_utc) AS last_online_at
    FROM guild_member_snapshot
    WHERE LOWER(COALESCE(status, '')) = 'online'
    GROUP BY
        guild_name,
        world,
        character_name
),

level_change_activity AS (
    SELECT
        guild_name,
        world,
        character_name,
        MAX(latest_snapshot_time) AS last_level_change_at
    FROM analytics.character_level_changes_with_online
    GROUP BY
        guild_name,
        world,
        character_name
)

SELECT
    r.guild_name,
    r.world,
    r.character_name,
    r.vocation,
    r.guild_rank,
    r.current_level,
    r.latest_snapshot_time,
    CASE
        WHEN online_activity.last_online_at IS NULL
         AND level_change_activity.last_level_change_at IS NULL
            THEN NULL
        ELSE GREATEST(
            COALESCE(online_activity.last_online_at, timestamp with time zone '-infinity'),
            COALESCE(level_change_activity.last_level_change_at, timestamp with time zone '-infinity')
        )
    END AS last_connected_at
FROM latest_roster r
LEFT JOIN online_activity
    ON r.guild_name = online_activity.guild_name
   AND r.world = online_activity.world
   AND r.character_name = online_activity.character_name
LEFT JOIN level_change_activity
    ON r.guild_name = level_change_activity.guild_name
   AND r.world = level_change_activity.world
   AND r.character_name = level_change_activity.character_name;

CREATE INDEX idx_latest_guild_members_api_filter_sort
    ON analytics.latest_guild_members_api_materialized (
        world,
        guild_name,
        current_level DESC,
        character_name ASC
    );

CREATE INDEX idx_latest_guild_members_api_character
    ON analytics.latest_guild_members_api_materialized (
        world,
        guild_name,
        character_name
    );

CREATE OR REPLACE VIEW public.api_latest_guild_members AS
SELECT
    guild_name,
    world,
    character_name,
    vocation,
    guild_rank,
    current_level,
    latest_snapshot_time,
    last_connected_at
FROM analytics.latest_guild_members_api_materialized;

GRANT SELECT ON public.api_latest_guild_members TO anon;
GRANT SELECT ON analytics.latest_guild_members_api_materialized TO anon;

-- ------------------------------------------------------------
-- Update refresh function used by the Edge Function
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
    REFRESH MATERIALIZED VIEW analytics.latest_guild_members_api_materialized;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO service_role;

RESET statement_timeout;