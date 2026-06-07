-- Validation: Guild Snapshot Pipeline
-- Purpose:
-- Run these checks after loading new guild snapshot data into PostgreSQL.
-- This validates row counts, duplicate prevention, latest snapshot health,
-- and Phase 3 analytics comparison views.

-- ============================================================
-- 1. Raw table row counts
-- ============================================================

SELECT
    'raw_guild_snapshot' AS check_name,
    COUNT(*) AS row_count
FROM raw_guild_snapshot;

SELECT
    'guild_member_snapshot' AS check_name,
    COUNT(*) AS row_count
FROM guild_member_snapshot;


-- ============================================================
-- 2. Snapshot inventory
-- Shows how many rows exist per extracted_at_utc snapshot.
-- ============================================================

SELECT
    extracted_at_utc,
    COUNT(*) AS row_count
FROM guild_member_snapshot
GROUP BY extracted_at_utc
ORDER BY extracted_at_utc DESC;


-- ============================================================
-- 3. Unique snapshot count
-- You need at least 2 snapshots for Phase 3D comparisons.
-- ============================================================

SELECT
    COUNT(DISTINCT extracted_at_utc) AS unique_snapshot_count
FROM guild_member_snapshot;


-- ============================================================
-- 4. Latest snapshot row count
-- This should roughly equal the current guild roster size.
-- ============================================================

SELECT
    extracted_at_utc AS latest_snapshot_time,
    COUNT(*) AS latest_snapshot_row_count
FROM guild_member_snapshot
WHERE extracted_at_utc = (
    SELECT MAX(extracted_at_utc)
    FROM guild_member_snapshot
)
GROUP BY extracted_at_utc;


-- ============================================================
-- 5. Duplicate check
-- Expected result: 0 rows.
-- If this returns rows, duplicate protection failed or old
-- duplicates still exist.
-- ============================================================

SELECT
    guild_name,
    world,
    character_name,
    extracted_at_utc,
    COUNT(*) AS duplicate_count
FROM guild_member_snapshot
GROUP BY
    guild_name,
    world,
    character_name,
    extracted_at_utc
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- ============================================================
-- 6. Staging view row count
-- Should usually match guild_member_snapshot unless null
-- character_name rows exist.
-- ============================================================

SELECT
    'stg_guild_member_snapshot' AS check_name,
    COUNT(*) AS row_count
FROM stg_guild_member_snapshot;


-- ============================================================
-- 7. Current roster analytics view
-- Should equal latest snapshot row count.
-- ============================================================

SELECT
    'analytics_current_guild_roster' AS check_name,
    COUNT(*) AS row_count
FROM analytics_current_guild_roster;


-- ============================================================
-- 8. Analytics summary by vocation
-- Useful for checking whether vocations are parsed cleanly.
-- ============================================================

SELECT
    vocation,
    character_count,
    avg_level,
    min_level,
    max_level
FROM analytics_guild_summary_by_vocation
ORDER BY character_count DESC;


-- ============================================================
-- 9. Level distribution check
-- Useful for dashboard/chart readiness.
-- ============================================================

SELECT
    level_band,
    character_count
FROM analytics_level_distribution
ORDER BY level_band;


-- ============================================================
-- 10. Snapshot comparison row counts
-- These counts show how many changes were detected between
-- the latest and previous snapshots.
-- ============================================================

SELECT
    'analytics_character_level_changes' AS check_name,
    COUNT(*) AS row_count
FROM analytics_character_level_changes

UNION ALL

SELECT
    'analytics_guild_joins' AS check_name,
    COUNT(*) AS row_count
FROM analytics_guild_joins

UNION ALL

SELECT
    'analytics_guild_leaves' AS check_name,
    COUNT(*) AS row_count
FROM analytics_guild_leaves

UNION ALL

SELECT
    'analytics_rank_changes' AS check_name,
    COUNT(*) AS row_count
FROM analytics_rank_changes;


-- ============================================================
-- 11. Top level gains
-- Quick sanity check for character progression.
-- ============================================================

SELECT
    character_name,
    previous_level,
    current_level,
    level_gain,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics_character_level_changes
ORDER BY level_gain DESC
LIMIT 20;


-- ============================================================
-- 12. New guild members
-- Quick sanity check for joins.
-- ============================================================

SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    joined_date,
    latest_snapshot_time
FROM analytics_guild_joins
ORDER BY level DESC
LIMIT 20;


-- ============================================================
-- 13. Members who left
-- Quick sanity check for leaves.
-- ============================================================

SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    joined_date,
    previous_snapshot_time
FROM analytics_guild_leaves
ORDER BY level DESC
LIMIT 20;


-- ============================================================
-- 14. Rank changes
-- Quick sanity check for promotions/demotions.
-- ============================================================

SELECT
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics_rank_changes
ORDER BY character_name
LIMIT 20;