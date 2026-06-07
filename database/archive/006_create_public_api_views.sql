-- ============================================================
-- 006_create_public_api_views.sql
-- Public API-facing views for Supabase REST access
-- ============================================================

CREATE OR REPLACE VIEW public.api_snapshot_pairs AS
SELECT
    extracted_at_utc,
    snapshot_rank
FROM analytics.snapshot_pairs;


CREATE OR REPLACE VIEW public.api_character_level_changes AS
SELECT
    character_name,
    vocation,
    guild_rank,
    previous_level,
    current_level,
    level_gain,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.character_level_changes;


CREATE OR REPLACE VIEW public.api_guild_joins AS
SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    latest_snapshot_time
FROM analytics.guild_joins;


CREATE OR REPLACE VIEW public.api_guild_leaves AS
SELECT
    character_name,
    vocation,
    level,
    guild_rank,
    status,
    joined_date,
    previous_snapshot_time
FROM analytics.guild_leaves;


CREATE OR REPLACE VIEW public.api_rank_changes AS
SELECT
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.rank_changes;


CREATE OR REPLACE VIEW public.api_summary AS
WITH snapshot_times AS (
    SELECT
        MAX(CASE WHEN snapshot_rank = 1 THEN extracted_at_utc END) AS latest_snapshot_time,
        MAX(CASE WHEN snapshot_rank = 2 THEN extracted_at_utc END) AS previous_snapshot_time
    FROM analytics.snapshot_pairs
),

metric_counts AS (
    SELECT
        (SELECT COUNT(*) FROM analytics.character_level_changes) AS level_changes,
        (SELECT COUNT(*) FROM analytics.guild_joins) AS guild_joins,
        (SELECT COUNT(*) FROM analytics.guild_leaves) AS guild_leaves,
        (SELECT COUNT(*) FROM analytics.rank_changes) AS rank_changes
)

SELECT
    snapshot_times.latest_snapshot_time,
    snapshot_times.previous_snapshot_time,
    metric_counts.level_changes,
    metric_counts.guild_joins,
    metric_counts.guild_leaves,
    metric_counts.rank_changes
FROM snapshot_times
CROSS JOIN metric_counts;