-- ============================================================
-- 024_remove_staging_dependency_from_api_views.sql
-- Remove dependency on public.stg_guild_member_snapshot
-- ============================================================

SET statement_timeout = '0';

-- ------------------------------------------------------------
-- Rebuild api_guild_overview_by_snapshot without staging view
--
-- This view powers the Guild Overview cards and latest refresh display.
-- It reads directly from guild_member_snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.api_guild_overview_by_snapshot AS
SELECT
    guild_name,
    world,
    extracted_at_utc AS snapshot_time,
    COUNT(*) AS number_of_members,
    MAX(level) AS max_level,
    MIN(level) AS min_level,
    ROUND(AVG(level)::numeric, 1) AS average_level
FROM public.guild_member_snapshot
GROUP BY
    guild_name,
    world,
    extracted_at_utc;


-- ------------------------------------------------------------
-- Rebuild api_snapshot_date_bounds_by_guild without staging view
--
-- This powers the min/max date bounds for date filters.
-- It reads directly from guild_member_snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.api_snapshot_date_bounds_by_guild AS
SELECT
    guild_name,
    world,
    MIN(extracted_at_utc) AS min_snapshot_time,
    MAX(extracted_at_utc) AS max_snapshot_time
FROM public.guild_member_snapshot
GROUP BY
    guild_name,
    world;


GRANT SELECT ON public.api_guild_overview_by_snapshot TO anon;
GRANT SELECT ON public.api_snapshot_date_bounds_by_guild TO anon;


-- ------------------------------------------------------------
-- Now that current API views no longer depend on staging,
-- drop the staging view.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.stg_guild_member_snapshot;

RESET statement_timeout;

NOTIFY pgrst, 'reload schema';