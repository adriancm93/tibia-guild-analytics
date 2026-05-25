-- ============================================================
-- 018_add_time_online_to_level_changes.sql
-- Add time online estimate to level changes API view
-- ============================================================

CREATE OR REPLACE VIEW public.api_historical_character_level_changes AS
WITH online_intervals AS (
    SELECT
        guild_name,
        world,
        character_name,
        extracted_at_utc,
        status,
        LEAD(extracted_at_utc) OVER (
            PARTITION BY world, guild_name, character_name
            ORDER BY extracted_at_utc
        ) AS next_snapshot_time
    FROM stg_guild_member_snapshot
),

online_minutes AS (
    SELECT
        guild_name,
        world,
        character_name,
        SUM(
            EXTRACT(
                EPOCH FROM LEAST(
                    COALESCE(next_snapshot_time, extracted_at_utc),
                    extracted_at_utc + interval '15 minutes'
                ) - extracted_at_utc
            ) / 60.0
        ) AS estimated_online_minutes
    FROM online_intervals
    WHERE LOWER(COALESCE(status, '')) = 'online'
      AND next_snapshot_time IS NOT NULL
      AND next_snapshot_time > extracted_at_utc
    GROUP BY
        guild_name,
        world,
        character_name
)

SELECT
    level_changes.guild_name,
    level_changes.world,
    level_changes.character_name,
    level_changes.vocation,
    level_changes.guild_rank,
    level_changes.previous_level,
    level_changes.current_level,
    level_changes.level_gain,
    level_changes.previous_snapshot_time,
    level_changes.latest_snapshot_time,
    COALESCE(ROUND(online_minutes.estimated_online_minutes), 0)::integer AS estimated_online_minutes
FROM analytics.historical_character_level_changes level_changes
LEFT JOIN online_minutes
    ON level_changes.guild_name = online_minutes.guild_name
   AND level_changes.world = online_minutes.world
   AND level_changes.character_name = online_minutes.character_name;

GRANT SELECT ON public.api_historical_character_level_changes TO anon;