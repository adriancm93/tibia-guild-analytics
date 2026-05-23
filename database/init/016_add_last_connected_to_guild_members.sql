-- ============================================================
-- 016_add_last_connected_to_guild_members.sql
-- Add last connected timestamp to latest guild members API view
-- ============================================================

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
),

latest_roster AS (
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
       AND s.extracted_at_utc = l.latest_snapshot_time
),

online_activity AS (
    SELECT
        guild_name,
        world,
        character_name,
        MAX(extracted_at_utc) AS last_online_at
    FROM stg_guild_member_snapshot
    WHERE LOWER(COALESCE(status, '')) = 'online'
    GROUP BY
        guild_name,
        world,
        character_name
),

level_change_activity AS (
    SELECT
        guild_name,
        world,
        character_name,
        MAX(latest_snapshot_time) AS last_level_change_at
    FROM analytics.historical_character_level_changes
    GROUP BY
        guild_name,
        world,
        character_name
)

SELECT
    r.guild_name,
    r.world,
    r.character_name,
    r.vocation,
    r.guild_rank,
    r.current_level,
    r.latest_snapshot_time,
    CASE
        WHEN online_activity.last_online_at IS NULL
         AND level_change_activity.last_level_change_at IS NULL
            THEN NULL
        ELSE GREATEST(
            COALESCE(online_activity.last_online_at, timestamp with time zone '-infinity'),
            COALESCE(level_change_activity.last_level_change_at, timestamp with time zone '-infinity')
        )
    END AS last_connected_at
FROM latest_roster r
LEFT JOIN online_activity
    ON r.guild_name = online_activity.guild_name
   AND r.world = online_activity.world
   AND r.character_name = online_activity.character_name
LEFT JOIN level_change_activity
    ON r.guild_name = level_change_activity.guild_name
   AND r.world = level_change_activity.world
   AND r.character_name = level_change_activity.character_name;

GRANT SELECT ON public.api_latest_guild_members TO anon;