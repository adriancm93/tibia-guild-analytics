-- ============================================================
-- 005_create_snapshot_comparison_views.sql
-- Phase 4
-- Create analytics views that compare the latest guild snapshot
-- to the previous snapshot.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- View: analytics.snapshot_pairs
--
-- Purpose:
-- Ranks available guild snapshots from newest to oldest.
-- snapshot_rank = 1 is the latest snapshot.
-- snapshot_rank = 2 is the previous snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.snapshot_pairs AS
WITH snapshot_rankings AS (
    SELECT
        extracted_at_utc,
        DENSE_RANK() OVER (
            ORDER BY extracted_at_utc DESC
        ) AS snapshot_rank
    FROM (
        SELECT DISTINCT
            extracted_at_utc
        FROM stg_guild_member_snapshot
    ) snapshots
)

SELECT
    extracted_at_utc,
    snapshot_rank
FROM snapshot_rankings;


-- ------------------------------------------------------------
-- View: analytics.character_level_changes
--
-- Purpose:
-- Shows characters whose level changed between the latest
-- snapshot and the previous snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.character_level_changes AS
WITH latest AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 1
),

previous AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 2
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    latest.vocation,
    latest.guild_rank,
    previous.level AS previous_level,
    latest.level AS current_level,
    latest.level - previous.level AS level_gain,
    previous.extracted_at_utc AS previous_snapshot_time,
    latest.extracted_at_utc AS latest_snapshot_time
FROM latest
JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
WHERE latest.level <> previous.level;


-- ------------------------------------------------------------
-- View: analytics.guild_joins
--
-- Purpose:
-- Shows characters who are present in the latest snapshot
-- but were not present in the previous snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.guild_joins AS
WITH latest AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 1
),

previous AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 2
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    latest.vocation,
    latest.level,
    latest.guild_rank,
    latest.status,
    latest.joined_date,
    latest.extracted_at_utc AS latest_snapshot_time
FROM latest
LEFT JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
WHERE previous.character_name IS NULL;


-- ------------------------------------------------------------
-- View: analytics.guild_leaves
--
-- Purpose:
-- Shows characters who were present in the previous snapshot
-- but are no longer present in the latest snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.guild_leaves AS
WITH latest AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 1
),

previous AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 2
)

SELECT
    previous.guild_name,
    previous.world,
    previous.character_name,
    previous.vocation,
    previous.level,
    previous.guild_rank,
    previous.status,
    previous.joined_date,
    previous.extracted_at_utc AS previous_snapshot_time
FROM previous
LEFT JOIN latest
    ON previous.guild_name = latest.guild_name
   AND previous.world = latest.world
   AND previous.character_name = latest.character_name
WHERE latest.character_name IS NULL;


-- ------------------------------------------------------------
-- View: analytics.rank_changes
--
-- Purpose:
-- Shows characters whose guild rank changed between the latest
-- snapshot and the previous snapshot.
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW analytics.rank_changes AS
WITH latest AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 1
),

previous AS (
    SELECT
        s.*
    FROM stg_guild_member_snapshot s
    JOIN analytics.snapshot_pairs p
        ON s.extracted_at_utc = p.extracted_at_utc
    WHERE p.snapshot_rank = 2
)

SELECT
    latest.guild_name,
    latest.world,
    latest.character_name,
    previous.guild_rank AS previous_guild_rank,
    latest.guild_rank AS current_guild_rank,
    previous.extracted_at_utc AS previous_snapshot_time,
    latest.extracted_at_utc AS latest_snapshot_time
FROM latest
JOIN previous
    ON latest.guild_name = previous.guild_name
   AND latest.world = previous.world
   AND latest.character_name = previous.character_name
WHERE latest.guild_rank <> previous.guild_rank;