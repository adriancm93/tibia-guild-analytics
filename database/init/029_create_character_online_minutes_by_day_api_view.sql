-- 029_create_character_online_minutes_by_day_api_view.sql
-- Expose date-grain estimated online minutes through a public API view.
--
-- Source:
-- analytics.character_online_intervals_cache
--
-- Grain:
-- One row per world/guild/character/activity_date.
--
-- Purpose:
-- Let the frontend fetch date-scoped online minutes without pulling every
-- raw snapshot interval row.

CREATE OR REPLACE VIEW public.api_character_online_minutes_by_day AS
SELECT
    guild_name,
    world,
    character_name,
    latest_snapshot_time::date AS activity_date,
    SUM(estimated_online_minutes)::integer AS estimated_online_minutes,
    COUNT(*)::integer AS online_interval_rows
FROM analytics.character_online_intervals_cache
GROUP BY
    guild_name,
    world,
    character_name,
    latest_snapshot_time::date;

GRANT SELECT ON public.api_character_online_minutes_by_day TO anon;
GRANT SELECT ON public.api_character_online_minutes_by_day TO authenticated;

NOTIFY pgrst, 'reload schema';
