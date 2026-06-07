-- ============================================================
-- 010_create_guild_overview_api_view.sql
-- Public API view for guild overview metrics by snapshot
-- ============================================================

CREATE OR REPLACE VIEW public.api_guild_overview_by_snapshot AS
SELECT
    guild_name,
    world,
    extracted_at_utc AS snapshot_time,
    COUNT(*) AS number_of_members,
    MAX(level) AS max_level,
    MIN(level) AS min_level,
    ROUND(AVG(level)::numeric, 0) AS average_level
FROM stg_guild_member_snapshot
GROUP BY
    guild_name,
    world,
    extracted_at_utc;

GRANT SELECT ON public.api_guild_overview_by_snapshot TO anon;