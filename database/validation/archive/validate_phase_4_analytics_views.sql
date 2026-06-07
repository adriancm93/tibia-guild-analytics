-- ============================================================
-- validate_phase_4_analytics_views.sql
-- Phase 4 validation checks for analytics snapshot comparison views
-- ============================================================

-- ------------------------------------------------------------
-- 1. Confirm snapshot ranking exists
-- ------------------------------------------------------------

SELECT
    extracted_at_utc,
    snapshot_rank
FROM analytics.snapshot_pairs
ORDER BY snapshot_rank;


-- ------------------------------------------------------------
-- 2. Count records in each Phase 4 analytics view
-- ------------------------------------------------------------

SELECT
    'character_level_changes' AS view_name,
    COUNT(*) AS row_count
FROM analytics.character_level_changes

UNION ALL

SELECT
    'guild_joins' AS view_name,
    COUNT(*) AS row_count
FROM analytics.guild_joins

UNION ALL

SELECT
    'guild_leaves' AS view_name,
    COUNT(*) AS row_count
FROM analytics.guild_leaves

UNION ALL

SELECT
    'rank_changes' AS view_name,
    COUNT(*) AS row_count
FROM analytics.rank_changes;


-- ------------------------------------------------------------
-- 3. Review largest level gains
-- ------------------------------------------------------------

SELECT
    character_name,
    vocation,
    guild_rank,
    previous_level,
    current_level,
    level_gain,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.character_level_changes
ORDER BY level_gain DESC, current_level DESC
LIMIT 25;


-- ------------------------------------------------------------
-- 4. Review guild joins
-- ------------------------------------------------------------

SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    latest_snapshot_time
FROM analytics.guild_joins
ORDER BY level DESC, character_name;


-- ------------------------------------------------------------
-- 5. Review guild leaves
-- ------------------------------------------------------------

SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    previous_snapshot_time
FROM analytics.guild_leaves
ORDER BY level DESC, character_name;


-- ------------------------------------------------------------
-- 6. Review rank changes
-- ------------------------------------------------------------

SELECT
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.rank_changes
ORDER BY character_name;