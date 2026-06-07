-- ============================================================
-- 019_materialize_level_changes_api_view.sql
-- Materialize level changes API view for frontend performance
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- The public API view depends on the underlying materialized source,
-- so drop it first.
DROP VIEW IF EXISTS public.api_historical_character_level_changes;

DROP MATERIALIZED VIEW IF EXISTS analytics.character_level_changes_with_online;

CREATE MATERIALIZED VIEW analytics.character_level_changes_with_online AS
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

CREATE INDEX idx_character_level_changes_with_online_filter_sort
    ON analytics.character_level_changes_with_online (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level_gain DESC,
        current_level DESC
    );

CREATE INDEX idx_character_level_changes_with_online_character
    ON analytics.character_level_changes_with_online (
        world,
        guild_name,
        character_name
    );

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
    latest_snapshot_time,
    estimated_online_minutes
FROM analytics.character_level_changes_with_online;

GRANT SELECT ON public.api_historical_character_level_changes TO anon;
GRANT SELECT ON analytics.character_level_changes_with_online TO anon;


-- Refresh both materialized views used by the frontend.
-- The Edge Function already calls this RPC, so keeping the same function
-- name avoids another Edge Function code change.
CREATE OR REPLACE FUNCTION public.refresh_character_estimated_online_minutes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW analytics.character_estimated_online_minutes;
    REFRESH MATERIALIZED VIEW analytics.character_level_changes_with_online;
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO service_role;