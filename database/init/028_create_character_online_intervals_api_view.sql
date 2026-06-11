-- 028_create_character_online_intervals_api_view.sql
-- Expose interval-grain estimated online time through a public API view.
--
-- Source:
-- analytics.character_online_intervals_cache
--
-- Grain:
-- One row per world/guild/character/snapshot interval.
--
-- Used by frontend date filters to calculate date-scoped estimated online time.

CREATE OR REPLACE VIEW public.api_character_online_intervals AS
SELECT
    guild_name,
    world,
    character_name,
    previous_snapshot_time,
    latest_snapshot_time,
    previous_status,
    latest_status,
    interval_minutes,
    estimated_online_minutes
FROM analytics.character_online_intervals_cache;

GRANT SELECT ON public.api_character_online_intervals TO anon;
GRANT SELECT ON public.api_character_online_intervals TO authenticated;

NOTIFY pgrst, 'reload schema';
