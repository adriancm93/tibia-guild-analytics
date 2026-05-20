-- ============================================================
-- 015_update_selector_ready_api_views.sql
-- Selector-ready API views for multi-world/multi-guild frontend
-- ============================================================

-- ------------------------------------------------------------
-- Snapshot date bounds by world/guild
-- ------------------------------------------------------------

CREATE OR REPLACE VIEW public.api_snapshot_date_bounds_by_guild AS
SELECT
    guild_name,
    world,
    MIN(extracted_at_utc) AS min_snapshot_time,
    MAX(extracted_at_utc) AS max_snapshot_time
FROM stg_guild_member_snapshot
GROUP BY
    guild_name,
    world;

GRANT SELECT ON public.api_snapshot_date_bounds_by_guild TO anon;


-- ------------------------------------------------------------
-- Latest guild members by world/guild
--
-- This replaces the global-latest logic with latest snapshot
-- per world + guild.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.api_latest_guild_members;

CREATE OR REPLACE VIEW public.api_latest_guild_members AS
WITH latest_snapshot AS (
    SELECT
        guild_name,
        world,
        MAX(extracted_at_utc) AS latest_snapshot_time
    FROM stg_guild_member_snapshot
    GROUP BY
        guild_name,
        world
)

SELECT
    s.guild_name,
    s.world,
    s.character_name,
    s.vocation,
    s.guild_rank,
    s.level AS current_level,
    s.extracted_at_utc AS latest_snapshot_time
FROM stg_guild_member_snapshot s
JOIN latest_snapshot l
    ON s.guild_name = l.guild_name
   AND s.world = l.world
   AND s.extracted_at_utc = l.latest_snapshot_time;

GRANT SELECT ON public.api_latest_guild_members TO anon;