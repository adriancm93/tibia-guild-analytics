-- 030_create_character_online_minutes_by_day_cache.sql
-- Hotfix: replace dynamic daily online-minutes aggregation with a cache table.
--
-- Problem:
-- public.api_character_online_minutes_by_day was aggregating directly from
-- analytics.character_online_intervals_cache on every REST request.
--
-- Fix:
-- 1. Create analytics.character_online_minutes_by_day_cache.
-- 2. Point public.api_character_online_minutes_by_day to the cache table.
-- 3. Wrap public.refresh_frontend_analytics_for_guild so every guild refresh
--    rebuilds the daily online-minutes cache for that guild.

SET statement_timeout = 0;

-- ============================================================
-- 1. Daily online-minutes cache table
-- ============================================================

CREATE TABLE IF NOT EXISTS analytics.character_online_minutes_by_day_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    activity_date date NOT NULL,
    estimated_online_minutes integer NOT NULL DEFAULT 0,
    online_interval_rows integer NOT NULL DEFAULT 0,
    refreshed_at_utc timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT character_online_minutes_by_day_cache_pkey
        PRIMARY KEY (
            world,
            guild_name,
            character_name,
            activity_date
        ),

    CONSTRAINT character_online_minutes_by_day_nonnegative_values
        CHECK (
            estimated_online_minutes >= 0
            AND online_interval_rows >= 0
        )
);

CREATE INDEX IF NOT EXISTS idx_online_minutes_by_day_filter_sort
    ON analytics.character_online_minutes_by_day_cache (
        world,
        guild_name,
        activity_date DESC,
        character_name
    );

CREATE INDEX IF NOT EXISTS idx_online_minutes_by_day_character_date
    ON analytics.character_online_minutes_by_day_cache (
        world,
        guild_name,
        character_name,
        activity_date DESC
    );

GRANT SELECT ON analytics.character_online_minutes_by_day_cache TO anon;
GRANT SELECT ON analytics.character_online_minutes_by_day_cache TO authenticated;


-- ============================================================
-- 2. Rename existing refresh function once, then create wrapper
-- ============================================================

DO $$
BEGIN
    IF to_regprocedure('public.refresh_frontend_analytics_for_guild_base_20260611(text,text)') IS NULL
       AND to_regprocedure('public.refresh_frontend_analytics_for_guild(text,text)') IS NOT NULL
    THEN
        ALTER FUNCTION public.refresh_frontend_analytics_for_guild(text, text)
        RENAME TO refresh_frontend_analytics_for_guild_base_20260611;
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.refresh_frontend_analytics_for_guild(
    p_world text,
    p_guild_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout TO '0'
SET search_path TO 'public', 'analytics'
AS $function$
DECLARE
    base_result jsonb;
    daily_cache_count integer;
BEGIN
    -- Run the existing cache refresh function first.
    base_result := public.refresh_frontend_analytics_for_guild_base_20260611(
        p_world,
        p_guild_name
    );

    -- Rebuild daily online-minutes cache for only this guild/world.
    DELETE FROM analytics.character_online_minutes_by_day_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    INSERT INTO analytics.character_online_minutes_by_day_cache (
        guild_name,
        world,
        character_name,
        activity_date,
        estimated_online_minutes,
        online_interval_rows,
        refreshed_at_utc
    )
    SELECT
        guild_name,
        world,
        character_name,
        latest_snapshot_time::date AS activity_date,
        COALESCE(SUM(estimated_online_minutes), 0)::integer AS estimated_online_minutes,
        COUNT(*)::integer AS online_interval_rows,
        now() AS refreshed_at_utc
    FROM analytics.character_online_intervals_cache
    WHERE world = p_world
      AND guild_name = p_guild_name
    GROUP BY
        guild_name,
        world,
        character_name,
        latest_snapshot_time::date;

    GET DIAGNOSTICS daily_cache_count = ROW_COUNT;

    RETURN base_result || jsonb_build_object(
        'daily_online_minutes_cache_rows',
        daily_cache_count,
        'daily_online_minutes_source',
        'analytics.character_online_minutes_by_day_cache'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO authenticated;


-- ============================================================
-- 3. Repoint public API view to cache table
-- ============================================================

CREATE OR REPLACE VIEW public.api_character_online_minutes_by_day AS
SELECT
    guild_name,
    world,
    character_name,
    activity_date,
    estimated_online_minutes,
    online_interval_rows,
    refreshed_at_utc
FROM analytics.character_online_minutes_by_day_cache;

GRANT SELECT ON public.api_character_online_minutes_by_day TO anon;
GRANT SELECT ON public.api_character_online_minutes_by_day TO authenticated;


-- ============================================================
-- 4. Backfill daily cache from existing interval cache
-- ============================================================

INSERT INTO analytics.character_online_minutes_by_day_cache (
    guild_name,
    world,
    character_name,
    activity_date,
    estimated_online_minutes,
    online_interval_rows,
    refreshed_at_utc
)
SELECT
    guild_name,
    world,
    character_name,
    latest_snapshot_time::date AS activity_date,
    COALESCE(SUM(estimated_online_minutes), 0)::integer AS estimated_online_minutes,
    COUNT(*)::integer AS online_interval_rows,
    now() AS refreshed_at_utc
FROM analytics.character_online_intervals_cache
GROUP BY
    guild_name,
    world,
    character_name,
    latest_snapshot_time::date
ON CONFLICT (
    world,
    guild_name,
    character_name,
    activity_date
)
DO UPDATE SET
    estimated_online_minutes = EXCLUDED.estimated_online_minutes,
    online_interval_rows = EXCLUDED.online_interval_rows,
    refreshed_at_utc = EXCLUDED.refreshed_at_utc;


NOTIFY pgrst, 'reload schema';
