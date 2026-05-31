-- ============================================================
-- 022_fix_frontend_materialized_refresh_rpc.sql
-- Make frontend materialized view refresh RPC safer for Edge Function calls
-- ============================================================

CREATE OR REPLACE FUNCTION public.refresh_character_estimated_online_minutes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '0'
SET search_path = public, analytics, extensions
AS $$
DECLARE
    refreshed_at timestamptz := now();
BEGIN
    REFRESH MATERIALIZED VIEW analytics.character_estimated_online_minutes;
    REFRESH MATERIALIZED VIEW analytics.character_level_changes_with_online;
    REFRESH MATERIALIZED VIEW analytics.snapshot_pairs_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.guild_joins_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.guild_leaves_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.rank_changes_api_materialized;
    REFRESH MATERIALIZED VIEW analytics.latest_guild_members_api_materialized;

    RETURN jsonb_build_object(
        'success', true,
        'refreshed_at_utc', refreshed_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_character_estimated_online_minutes() TO service_role;

NOTIFY pgrst, 'reload schema';