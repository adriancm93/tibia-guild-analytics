-- ============================================================
-- 023_drop_legacy_database_objects.sql
-- Drop legacy database objects no longer used by the current website
-- ============================================================

SET statement_timeout = '0';

-- ------------------------------------------------------------
-- Drop legacy public API / analytics views
-- These are no longer called by frontend/app.js.
-- ------------------------------------------------------------

-- Drop dependent views first.
DROP VIEW IF EXISTS public.analytics_guild_summary_by_vocation;
DROP VIEW IF EXISTS public.analytics_level_distribution;
DROP VIEW IF EXISTS public.analytics_top_characters;

-- Drop base legacy analytics view last.
DROP VIEW IF EXISTS public.analytics_current_guild_roster;

DROP VIEW IF EXISTS public.api_character_level_changes;
DROP VIEW IF EXISTS public.api_guild_joins;
DROP VIEW IF EXISTS public.api_guild_leaves;
DROP VIEW IF EXISTS public.api_rank_changes;
DROP VIEW IF EXISTS public.api_snapshot_pairs;
DROP VIEW IF EXISTS public.api_summary;
DROP VIEW IF EXISTS public.api_snapshot_date_bounds;

-- IMPORTANT:
-- Do not drop public.stg_guild_member_snapshot yet.
-- Current views still depend on it:
--   public.api_guild_overview_by_snapshot
--   public.api_snapshot_date_bounds_by_guild

-- ------------------------------------------------------------
-- Drop legacy materialized views
-- These were replaced by per-guild cache tables.
-- Drop dependent materialized views first.
-- ------------------------------------------------------------

DROP MATERIALIZED VIEW IF EXISTS analytics.latest_guild_members_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.character_level_changes_with_online;
DROP MATERIALIZED VIEW IF EXISTS analytics.character_estimated_online_minutes;

DROP MATERIALIZED VIEW IF EXISTS analytics.guild_joins_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.guild_leaves_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.rank_changes_api_materialized;
DROP MATERIALIZED VIEW IF EXISTS analytics.snapshot_pairs_api_materialized;

-- ------------------------------------------------------------
-- Drop legacy analytics views
-- These were dynamic comparison views replaced by cache tables.
-- Drop dependent views first, snapshot pair views last.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS analytics.character_level_changes;
DROP VIEW IF EXISTS analytics.guild_joins;
DROP VIEW IF EXISTS analytics.guild_leaves;
DROP VIEW IF EXISTS analytics.rank_changes;
DROP VIEW IF EXISTS analytics.snapshot_pairs;

DROP VIEW IF EXISTS analytics.historical_character_level_changes;
DROP VIEW IF EXISTS analytics.historical_guild_joins;
DROP VIEW IF EXISTS analytics.historical_guild_leaves;
DROP VIEW IF EXISTS analytics.historical_rank_changes;
DROP VIEW IF EXISTS analytics.historical_snapshot_pairs;

-- ------------------------------------------------------------
-- Drop legacy global refresh function
-- Replaced by public.refresh_frontend_analytics_for_guild(text, text).
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS public.refresh_character_estimated_online_minutes();

RESET statement_timeout;

NOTIFY pgrst, 'reload schema';