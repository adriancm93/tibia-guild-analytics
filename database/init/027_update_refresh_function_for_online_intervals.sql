-- 027_update_refresh_function_for_online_intervals.sql
-- Update the per-guild cache refresh function to populate
-- analytics.character_online_intervals_cache.
--
-- Online activity estimator:
-- If the character is online at the start of a snapshot interval,
-- count up to 15 minutes for that interval.
--
-- This intentionally caps long snapshot gaps so a 35-minute gap does not
-- automatically become 35 minutes of estimated activity.
--
-- Status transitions:
-- online  -> online   = count up to 15 minutes
-- online  -> offline  = count up to 15 minutes
-- offline -> online   = count 0
-- offline -> offline  = count 0
-- online  -> missing  = count up to 15 minutes
-- missing -> online   = count 0

SET statement_timeout = 0;

CREATE OR REPLACE FUNCTION public.refresh_frontend_analytics_for_guild(
    p_world text,
    p_guild_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout TO '0'
SET search_path TO 'public', 'analytics'
AS $function$
DECLARE
    refreshed_at timestamptz := now();
    online_interval_count integer;
    level_count integer;
    join_count integer;
    leave_count integer;
    rank_count integer;
    member_count integer;
BEGIN
    -- Remove only this guild/world from cache tables.
    DELETE FROM analytics.character_online_intervals_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.character_estimated_online_minutes_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.character_level_changes_with_online_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.snapshot_pairs_api_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.guild_joins_api_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.guild_leaves_api_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.rank_changes_api_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    DELETE FROM analytics.latest_guild_members_api_cache
    WHERE world = p_world
      AND guild_name = p_guild_name;

    -- Build snapshot pairs for this guild.
    INSERT INTO analytics.snapshot_pairs_api_cache (
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time
    )
    WITH ordered_snapshots AS (
        SELECT
            guild_name,
            world,
            extracted_at_utc AS latest_snapshot_time,
            LAG(extracted_at_utc) OVER (
                PARTITION BY world, guild_name
                ORDER BY extracted_at_utc
            ) AS previous_snapshot_time
        FROM (
            SELECT DISTINCT
                guild_name,
                world,
                extracted_at_utc
            FROM public.guild_member_snapshot
            WHERE world = p_world
              AND guild_name = p_guild_name
        ) snapshots
    )
    SELECT
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time
    FROM ordered_snapshots
    WHERE previous_snapshot_time IS NOT NULL;

    -- Build interval-grain online activity cache.
    INSERT INTO analytics.character_online_intervals_cache (
        guild_name,
        world,
        character_name,
        previous_snapshot_time,
        latest_snapshot_time,
        previous_status,
        latest_status,
        interval_minutes,
        estimated_online_minutes
    )
    WITH previous_rows AS (
        SELECT
            pairs.guild_name,
            pairs.world,
            pairs.previous_snapshot_time,
            pairs.latest_snapshot_time,
            previous.character_name,
            previous.status AS previous_status
        FROM analytics.snapshot_pairs_api_cache pairs
        JOIN public.guild_member_snapshot previous
            ON previous.guild_name = pairs.guild_name
           AND previous.world = pairs.world
           AND previous.extracted_at_utc = pairs.previous_snapshot_time
        WHERE pairs.world = p_world
          AND pairs.guild_name = p_guild_name
    ),
    latest_rows AS (
        SELECT
            pairs.guild_name,
            pairs.world,
            pairs.previous_snapshot_time,
            pairs.latest_snapshot_time,
            latest.character_name,
            latest.status AS latest_status
        FROM analytics.snapshot_pairs_api_cache pairs
        JOIN public.guild_member_snapshot latest
            ON latest.guild_name = pairs.guild_name
           AND latest.world = pairs.world
           AND latest.extracted_at_utc = pairs.latest_snapshot_time
        WHERE pairs.world = p_world
          AND pairs.guild_name = p_guild_name
    ),
    interval_rows AS (
        SELECT
            COALESCE(previous_rows.guild_name, latest_rows.guild_name) AS guild_name,
            COALESCE(previous_rows.world, latest_rows.world) AS world,
            COALESCE(previous_rows.character_name, latest_rows.character_name) AS character_name,
            COALESCE(previous_rows.previous_snapshot_time, latest_rows.previous_snapshot_time) AS previous_snapshot_time,
            COALESCE(previous_rows.latest_snapshot_time, latest_rows.latest_snapshot_time) AS latest_snapshot_time,
            previous_rows.previous_status,
            latest_rows.latest_status
        FROM previous_rows
        FULL OUTER JOIN latest_rows
            ON previous_rows.guild_name = latest_rows.guild_name
           AND previous_rows.world = latest_rows.world
           AND previous_rows.previous_snapshot_time = latest_rows.previous_snapshot_time
           AND previous_rows.latest_snapshot_time = latest_rows.latest_snapshot_time
           AND previous_rows.character_name = latest_rows.character_name
    ),
    calculated_intervals AS (
        SELECT
            guild_name,
            world,
            character_name,
            previous_snapshot_time,
            latest_snapshot_time,
            previous_status,
            latest_status,
            GREATEST(
                ROUND(EXTRACT(EPOCH FROM latest_snapshot_time - previous_snapshot_time) / 60.0),
                0
            )::integer AS interval_minutes
        FROM interval_rows
        WHERE character_name IS NOT NULL
          AND latest_snapshot_time > previous_snapshot_time
    )
    SELECT
        guild_name,
        world,
        character_name,
        previous_snapshot_time,
        latest_snapshot_time,
        previous_status,
        latest_status,
        interval_minutes,
        CASE
            WHEN LOWER(COALESCE(previous_status, '')) = 'online'
                THEN LEAST(interval_minutes, 15)
            ELSE 0
        END AS estimated_online_minutes
    FROM calculated_intervals
    ON CONFLICT (
        world,
        guild_name,
        character_name,
        previous_snapshot_time,
        latest_snapshot_time
    )
    DO UPDATE SET
        previous_status = EXCLUDED.previous_status,
        latest_status = EXCLUDED.latest_status,
        interval_minutes = EXCLUDED.interval_minutes,
        estimated_online_minutes = EXCLUDED.estimated_online_minutes,
        created_at_utc = now();

    GET DIAGNOSTICS online_interval_count = ROW_COUNT;

    -- Rebuild all-time character online totals from interval-grain cache.
    INSERT INTO analytics.character_estimated_online_minutes_cache (
        guild_name,
        world,
        character_name,
        estimated_online_minutes
    )
    SELECT
        guild_name,
        world,
        character_name,
        COALESCE(SUM(estimated_online_minutes), 0)::integer AS estimated_online_minutes
    FROM analytics.character_online_intervals_cache
    WHERE world = p_world
      AND guild_name = p_guild_name
    GROUP BY
        guild_name,
        world,
        character_name
    ON CONFLICT (world, guild_name, character_name)
    DO UPDATE SET
        estimated_online_minutes = EXCLUDED.estimated_online_minutes;

    -- Level changes for this guild.
    -- estimated_online_minutes is retained for backward compatibility and is
    -- sourced from the matching online interval row.
    INSERT INTO analytics.character_level_changes_with_online_cache (
        guild_name,
        world,
        character_name,
        vocation,
        guild_rank,
        previous_level,
        current_level,
        level_gain,
        previous_snapshot_time,
        latest_snapshot_time,
        estimated_online_minutes
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
        pairs.previous_snapshot_time,
        pairs.latest_snapshot_time,
        COALESCE(online_intervals.estimated_online_minutes, 0) AS estimated_online_minutes
    FROM analytics.snapshot_pairs_api_cache pairs
    JOIN public.guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    JOIN public.guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
       AND previous.character_name = latest.character_name
    LEFT JOIN analytics.character_online_intervals_cache online_intervals
        ON online_intervals.guild_name = latest.guild_name
       AND online_intervals.world = latest.world
       AND online_intervals.character_name = latest.character_name
       AND online_intervals.previous_snapshot_time = pairs.previous_snapshot_time
       AND online_intervals.latest_snapshot_time = pairs.latest_snapshot_time
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND latest.level IS DISTINCT FROM previous.level;

    GET DIAGNOSTICS level_count = ROW_COUNT;

    -- Guild joins for this guild.
    INSERT INTO analytics.guild_joins_api_cache (
        guild_name,
        world,
        character_name,
        vocation,
        level,
        guild_rank,
        status,
        joined_date,
        previous_snapshot_time,
        latest_snapshot_time
    )
    SELECT
        latest.guild_name,
        latest.world,
        latest.character_name,
        latest.vocation,
        latest.level,
        latest.guild_rank,
        latest.status,
        latest.joined AS joined_date,
        pairs.previous_snapshot_time,
        pairs.latest_snapshot_time
    FROM analytics.snapshot_pairs_api_cache pairs
    JOIN public.guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND NOT EXISTS (
        SELECT 1
        FROM public.guild_member_snapshot previous
        WHERE previous.guild_name = pairs.guild_name
          AND previous.world = pairs.world
          AND previous.extracted_at_utc = pairs.previous_snapshot_time
          AND previous.character_name = latest.character_name
    );

    GET DIAGNOSTICS join_count = ROW_COUNT;

    -- Guild leaves for this guild.
    INSERT INTO analytics.guild_leaves_api_cache (
        guild_name,
        world,
        character_name,
        vocation,
        level,
        guild_rank,
        status,
        joined_date,
        previous_snapshot_time,
        latest_snapshot_time
    )
    SELECT
        previous.guild_name,
        previous.world,
        previous.character_name,
        previous.vocation,
        previous.level,
        previous.guild_rank,
        previous.status,
        previous.joined AS joined_date,
        pairs.previous_snapshot_time,
        pairs.latest_snapshot_time
    FROM analytics.snapshot_pairs_api_cache pairs
    JOIN public.guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND NOT EXISTS (
        SELECT 1
        FROM public.guild_member_snapshot latest
        WHERE latest.guild_name = pairs.guild_name
          AND latest.world = pairs.world
          AND latest.extracted_at_utc = pairs.latest_snapshot_time
          AND latest.character_name = previous.character_name
    );

    GET DIAGNOSTICS leave_count = ROW_COUNT;

    -- Rank changes for this guild.
    INSERT INTO analytics.rank_changes_api_cache (
        guild_name,
        world,
        character_name,
        previous_guild_rank,
        current_guild_rank,
        previous_snapshot_time,
        latest_snapshot_time
    )
    SELECT
        latest.guild_name,
        latest.world,
        latest.character_name,
        previous.guild_rank AS previous_guild_rank,
        latest.guild_rank AS current_guild_rank,
        pairs.previous_snapshot_time,
        pairs.latest_snapshot_time
    FROM analytics.snapshot_pairs_api_cache pairs
    JOIN public.guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    JOIN public.guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
       AND previous.character_name = latest.character_name
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND latest.guild_rank IS DISTINCT FROM previous.guild_rank;

    GET DIAGNOSTICS rank_count = ROW_COUNT;

    -- Latest guild roster for this guild.
    INSERT INTO analytics.latest_guild_members_api_cache (
        guild_name,
        world,
        character_name,
        vocation,
        guild_rank,
        current_level,
        latest_snapshot_time,
        last_connected_at
    )
    WITH latest_snapshot AS (
        SELECT
            MAX(extracted_at_utc) AS latest_snapshot_time
        FROM public.guild_member_snapshot
        WHERE world = p_world
          AND guild_name = p_guild_name
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
        FROM public.guild_member_snapshot s
        JOIN latest_snapshot l
            ON s.extracted_at_utc = l.latest_snapshot_time
        WHERE s.world = p_world
          AND s.guild_name = p_guild_name
    ),
    online_activity AS (
        SELECT
            guild_name,
            world,
            character_name,
            MAX(previous_snapshot_time) AS last_online_at
        FROM analytics.character_online_intervals_cache
        WHERE world = p_world
          AND guild_name = p_guild_name
          AND LOWER(COALESCE(previous_status, '')) = 'online'
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
        FROM analytics.character_level_changes_with_online_cache
        WHERE world = p_world
          AND guild_name = p_guild_name
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
       AND r.character_name = level_change_activity.character_name
    ON CONFLICT (world, guild_name, character_name)
    DO UPDATE SET
        vocation = EXCLUDED.vocation,
        guild_rank = EXCLUDED.guild_rank,
        current_level = EXCLUDED.current_level,
        latest_snapshot_time = EXCLUDED.latest_snapshot_time,
        last_connected_at = EXCLUDED.last_connected_at;

    GET DIAGNOSTICS member_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'world', p_world,
        'guild_name', p_guild_name,
        'online_intervals', online_interval_count,
        'level_changes', level_count,
        'joins', join_count,
        'leaves', leave_count,
        'rank_changes', rank_count,
        'members', member_count,
        'refreshed_at_utc', refreshed_at,
        'online_minutes_scope', 'capped_previous_online_interval_15_minutes'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
