-- 001_validate_current_pipeline.sql
-- Validate the current Tibia Guild Analytics production database architecture.
--
-- Current architecture:
-- raw/member snapshots
-- -> per-guild analytics cache tables
-- -> public API views
-- -> frontend

-- ============================================================
-- 1. Core table row counts
-- ============================================================

SELECT
    'public.raw_guild_snapshot' AS object_name,
    COUNT(*) AS row_count
FROM public.raw_guild_snapshot

UNION ALL

SELECT
    'public.guild_member_snapshot' AS object_name,
    COUNT(*) AS row_count
FROM public.guild_member_snapshot

UNION ALL

SELECT
    'public.tibia_world' AS object_name,
    COUNT(*) AS row_count
FROM public.tibia_world

UNION ALL

SELECT
    'public.tibia_guild' AS object_name,
    COUNT(*) AS row_count
FROM public.tibia_guild;


-- ============================================================
-- 2. Latest raw/member snapshot freshness by guild
-- ============================================================

SELECT
    world,
    guild_name,
    COUNT(DISTINCT extracted_at_utc) AS snapshot_count,
    COUNT(*) AS member_snapshot_rows,
    MAX(extracted_at_utc) AS latest_member_snapshot_time
FROM public.guild_member_snapshot
GROUP BY
    world,
    guild_name
ORDER BY
    latest_member_snapshot_time DESC,
    world,
    guild_name
LIMIT 50;


-- ============================================================
-- 3. Guild refresh queue status
-- ============================================================

SELECT
    world,
    guild_name,
    last_refresh_status,
    last_refresh_started_at_utc,
    last_refresh_completed_at_utc,
    next_refresh_after_utc,
    LEFT(COALESCE(last_refresh_error, ''), 200) AS error_preview
FROM public.tibia_guild
ORDER BY
    last_refresh_completed_at_utc DESC NULLS LAST,
    updated_at_utc DESC NULLS LAST
LIMIT 50;


-- ============================================================
-- 4. Stuck running guild refreshes
-- Expected result: 0 rows during normal operation.
-- ============================================================

SELECT
    world,
    guild_name,
    last_refresh_status,
    last_refresh_started_at_utc,
    now() - last_refresh_started_at_utc AS running_duration
FROM public.tibia_guild
WHERE last_refresh_status = 'running'
ORDER BY last_refresh_started_at_utc;


-- ============================================================
-- 5. Analytics cache table row counts
-- ============================================================

SELECT
    'analytics.snapshot_pairs_api_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.snapshot_pairs_api_cache

UNION ALL

SELECT
    'analytics.character_estimated_online_minutes_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.character_estimated_online_minutes_cache

UNION ALL

SELECT
    'analytics.character_level_changes_with_online_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.character_level_changes_with_online_cache

UNION ALL

SELECT
    'analytics.guild_joins_api_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.guild_joins_api_cache

UNION ALL

SELECT
    'analytics.guild_leaves_api_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.guild_leaves_api_cache

UNION ALL

SELECT
    'analytics.rank_changes_api_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.rank_changes_api_cache

UNION ALL

SELECT
    'analytics.latest_guild_members_api_cache' AS object_name,
    COUNT(*) AS row_count
FROM analytics.latest_guild_members_api_cache;


-- ============================================================
-- 6. Public API view row counts
-- ============================================================

SELECT
    'public.api_worlds' AS object_name,
    COUNT(*) AS row_count
FROM public.api_worlds

UNION ALL

SELECT
    'public.api_guilds' AS object_name,
    COUNT(*) AS row_count
FROM public.api_guilds

UNION ALL

SELECT
    'public.api_snapshot_date_bounds_by_guild' AS object_name,
    COUNT(*) AS row_count
FROM public.api_snapshot_date_bounds_by_guild

UNION ALL

SELECT
    'public.api_guild_overview_by_snapshot' AS object_name,
    COUNT(*) AS row_count
FROM public.api_guild_overview_by_snapshot

UNION ALL

SELECT
    'public.api_historical_character_level_changes' AS object_name,
    COUNT(*) AS row_count
FROM public.api_historical_character_level_changes

UNION ALL

SELECT
    'public.api_historical_guild_joins' AS object_name,
    COUNT(*) AS row_count
FROM public.api_historical_guild_joins

UNION ALL

SELECT
    'public.api_historical_guild_leaves' AS object_name,
    COUNT(*) AS row_count
FROM public.api_historical_guild_leaves

UNION ALL

SELECT
    'public.api_historical_rank_changes' AS object_name,
    COUNT(*) AS row_count
FROM public.api_historical_rank_changes

UNION ALL

SELECT
    'public.api_latest_guild_members' AS object_name,
    COUNT(*) AS row_count
FROM public.api_latest_guild_members;


-- ============================================================
-- 7. Latest raw snapshot vs latest frontend roster cache by guild
-- Expected: latest_member_snapshot_time and latest_cache_snapshot_time
-- should generally match for recently refreshed guilds.
-- ============================================================

WITH latest_member_snapshot AS (
    SELECT
        world,
        guild_name,
        MAX(extracted_at_utc) AS latest_member_snapshot_time
    FROM public.guild_member_snapshot
    GROUP BY
        world,
        guild_name
),

latest_cache_snapshot AS (
    SELECT
        world,
        guild_name,
        MAX(latest_snapshot_time) AS latest_cache_snapshot_time
    FROM analytics.latest_guild_members_api_cache
    GROUP BY
        world,
        guild_name
)

SELECT
    COALESCE(m.world, c.world) AS world,
    COALESCE(m.guild_name, c.guild_name) AS guild_name,
    m.latest_member_snapshot_time,
    c.latest_cache_snapshot_time,
    m.latest_member_snapshot_time IS NOT DISTINCT FROM c.latest_cache_snapshot_time AS is_cache_current
FROM latest_member_snapshot m
FULL OUTER JOIN latest_cache_snapshot c
    ON m.world = c.world
   AND m.guild_name = c.guild_name
ORDER BY
    is_cache_current ASC,
    m.latest_member_snapshot_time DESC NULLS LAST,
    c.latest_cache_snapshot_time DESC NULLS LAST
LIMIT 100;


-- ============================================================
-- 8. Project-owned public/analytics tables and views
-- ============================================================

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('public', 'analytics')
ORDER BY
    table_schema,
    table_type,
    table_name;


-- ============================================================
-- 9. Project-owned routines
-- Expected functions:
-- - apply_snapshot_retention
-- - claim_due_guild_refresh_batch
-- - mark_guild_refresh_failure
-- - mark_guild_refresh_success
-- - refresh_frontend_analytics_for_guild
-- - release_stale_running_guild_refreshes
-- ============================================================

SELECT
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema IN ('public', 'analytics')
ORDER BY
    routine_schema,
    routine_name;


-- ============================================================
-- 10. Materialized views check
-- Expected result: 0 rows.
-- The current architecture uses cache tables, not materialized views.
-- ============================================================

SELECT
    schemaname,
    matviewname
FROM pg_matviews
WHERE schemaname IN ('public', 'analytics')
ORDER BY
    schemaname,
    matviewname;


-- ============================================================
-- 11. Legacy staging view check
-- Expected result: 0 rows.
-- ============================================================

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'stg_guild_member_snapshot';


-- ============================================================
-- 12. Legacy refresh RPC check
-- Expected result: 0 rows.
-- ============================================================

SELECT
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'refresh_character_estimated_online_minutes';
