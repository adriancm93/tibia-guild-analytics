-- 046_drop_legacy_full_refresh_functions.sql
-- Purpose:
--   Remove obsolete full-refresh database functions that were replaced by
--   incremental analytics processors and scheduled retention.
--
-- Replaced by:
--   analytics.process_incremental_online_activity(...)
--   analytics.process_incremental_general_analytics(...)
--   analytics.apply_safe_7_day_snapshot_retention()
--
-- Safe because:
--   Production ingestion no longer calls these functions.
--   Supabase Edge Function refresh-guilds is ingestion-only.
--   Analytics and retention are handled by separate Supabase Cron jobs.

DROP FUNCTION IF EXISTS public.refresh_frontend_analytics_for_guild(text, text);

DROP FUNCTION IF EXISTS public.refresh_frontend_analytics_for_guild_base_20260611(text, text);

DROP FUNCTION IF EXISTS public.apply_snapshot_retention(interval);
