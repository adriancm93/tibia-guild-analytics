-- 034_apply_safe_7_day_snapshot_retention.sql
-- Purpose:
--   Apply safe 7-day retention for Tibia Guild Analytics snapshot data.
--
-- Important:
--   This script deletes child/cache rows before parent raw snapshot rows.
--   Do not delete from raw_guild_snapshot before guild_member_snapshot.
--
-- Retention rule:
--   Keep snapshots where extracted_at_utc >= latest_snapshot_timestamp - interval '7 days'.

\echo '=== APPLY SAFE 7-DAY SNAPSHOT RETENTION ==='

WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
)
SELECT
    cutoff_timestamp,
    cutoff_timestamp::date AS cutoff_date
FROM retention_cutoff;

\echo '=== DELETE OLD ONLINE MINUTES BY DAY CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.character_online_minutes_by_day_cache c
    USING retention_cutoff r
    WHERE c.activity_date < r.cutoff_timestamp::date
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD ONLINE INTERVALS CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.character_online_intervals_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD LEVEL CHANGES CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.character_level_changes_with_online_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD GUILD JOINS CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.guild_joins_api_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD GUILD LEAVES CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.guild_leaves_api_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD RANK CHANGES CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.rank_changes_api_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD SNAPSHOT PAIRS CACHE ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM analytics.snapshot_pairs_api_cache c
    USING retention_cutoff r
    WHERE c.latest_snapshot_time < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD GUILD MEMBER SNAPSHOT CHILD ROWS FIRST ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM public.guild_member_snapshot gms
    USING retention_cutoff r
    WHERE gms.extracted_at_utc < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== DELETE OLD RAW GUILD SNAPSHOT PARENT ROWS SECOND ==='
WITH retention_cutoff AS (
    SELECT MAX(extracted_at_utc) - interval '7 days' AS cutoff_timestamp
    FROM public.raw_guild_snapshot
),
deleted AS (
    DELETE FROM public.raw_guild_snapshot rgs
    USING retention_cutoff r
    WHERE rgs.extracted_at_utc < r.cutoff_timestamp
    RETURNING 1
)
SELECT COUNT(*) AS deleted_rows
FROM deleted;

\echo '=== ANALYZE CLEANED TABLES ==='
ANALYZE public.guild_member_snapshot;
ANALYZE public.raw_guild_snapshot;
ANALYZE analytics.character_online_intervals_cache;
ANALYZE analytics.character_online_minutes_by_day_cache;

\echo '=== FINAL RETENTION CHECK ==='
SELECT
    'public.raw_guild_snapshot' AS table_name,
    MIN(extracted_at_utc) AS earliest_snapshot,
    MAX(extracted_at_utc) AS latest_snapshot,
    COUNT(*) AS row_count
FROM public.raw_guild_snapshot
UNION ALL
SELECT
    'public.guild_member_snapshot' AS table_name,
    MIN(extracted_at_utc) AS earliest_snapshot,
    MAX(extracted_at_utc) AS latest_snapshot,
    COUNT(*) AS row_count
FROM public.guild_member_snapshot;
