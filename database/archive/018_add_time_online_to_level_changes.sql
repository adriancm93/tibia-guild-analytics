-- ============================================================
-- 018_add_time_online_to_level_changes.sql
-- Add precomputed time online estimate to level changes API view
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP VIEW IF EXISTS public.api_historical_character_level_changes;
DROP MATERIALIZED VIEW IF EXISTS analytics.character_estimated_online_minutes;

CREATE MATERIALIZED VIEW analytics.character_estimated_online_minutes AS
WITH online_intervals AS (
    SELECT
        guild_name,
        world,
        character_name,
        extracted_at_utc,
        status,
        LEAD(extracted_at_utc) OVER (
            PARTITION BY world, guild_name, character_name
            ORDER BY extracted_at_utc
        ) AS next_snapshot_time
    FROM stg_guild_member_snapshot
),

online_minutes AS (
    SELECT
        guild_name,
        world,
        character_name,
        SUM(
            EXTRACT(
                EPOCH FROM LEAST(
                    next_snapshot_time,
                    extracted_at_utc + interval '15 minutes'
                ) - extracted_at_utc
            ) / 60.0
        ) AS estimated_online_minutes
    FROM online_intervals
    WHERE LOWER(COALESCE(status, '')) = 'online'
      AND next_snapshot_time IS NOT NULL
      AND next_snapshot_time > extracted_at_utc
    GROUP BY
        guild_name,
        world,
        character_name
)

SELECT
    guild_name,
    world,
    character_name,
    COALESCE(ROUND(estimated_online_minutes), 0)::integer AS estimated_online_minutes
FROM online_minutes;

CREATE UNIQUE INDEX idx_character_estimated_online_minutes_unique
    ON analytics.character_estimated_online_minutes (world, guild_name, character_name);

CREATE INDEX idx_character_estimated_online_minutes_world_guild
    ON analytics.character_estimated_online_minutes (world, guild_name);

CREATE OR REPLACE FUNCTION public.refresh_character_estimated_online_minutes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.character_estimated_online_minutes;
END;
$$;

CREATE OR REPLACE VIEW public.api_historical_character_level_changes AS
SELECT
    level_changes.guild_name,
    level_changes.world,
    level_changes.character_name,
    level_changes.vocation,
    level_changes.guild_rank,
    level_changes.previous_level,
    level_changes.current_level,
    level_changes.level_gain,
    level_changes.previous_snapshot_time,
    level_changes.latest_snapshot_time,
    COALESCE(online_minutes.estimated_online_minutes, 0)::integer AS estimated_online_minutes
FROM analytics.historical_character_level_changes level_changes
LEFT JOIN analytics.character_estimated_online_minutes online_minutes
    ON level_changes.guild_name = online_minutes.guild_name
   AND level_changes.world = online_minutes.world
   AND level_changes.character_name = online_minutes.character_name;

GRANT SELECT ON public.api_historical_character_level_changes TO anon;
GRANT SELECT ON analytics.character_estimated_online_minutes TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO service_role;