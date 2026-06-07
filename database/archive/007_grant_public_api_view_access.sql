-- ============================================================
-- 007_grant_public_api_view_access.sql
-- Grants read-only Supabase REST access to public API views
-- ============================================================

GRANT USAGE ON SCHEMA public TO anon;

GRANT SELECT ON public.api_snapshot_pairs TO anon;
GRANT SELECT ON public.api_character_level_changes TO anon;
GRANT SELECT ON public.api_guild_joins TO anon;
GRANT SELECT ON public.api_guild_leaves TO anon;
GRANT SELECT ON public.api_rank_changes TO anon;
GRANT SELECT ON public.api_summary TO anon;