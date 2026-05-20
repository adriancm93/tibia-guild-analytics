-- ============================================================
-- 013_create_world_guild_selector_api_views.sql
-- Public API views for world and guild selector dropdowns
-- ============================================================

CREATE OR REPLACE VIEW public.api_worlds AS
SELECT
    world_name,
    is_active,
    updated_at_utc
FROM tibia_world
WHERE is_active = true
ORDER BY world_name;


CREATE OR REPLACE VIEW public.api_guilds AS
SELECT
    guild_name,
    world,
    is_active,
    refresh_interval_minutes,
    last_refresh_completed_at_utc,
    last_refresh_status,
    updated_at_utc
FROM tibia_guild
WHERE is_active = true
ORDER BY world, guild_name;


GRANT SELECT ON public.api_worlds TO anon;
GRANT SELECT ON public.api_guilds TO anon;