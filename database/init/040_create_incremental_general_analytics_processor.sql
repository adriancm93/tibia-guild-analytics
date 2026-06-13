-- 040_create_incremental_general_analytics_processor.sql
-- Purpose:
--   Incrementally process non-online analytics caches:
--     - snapshot pairs
--     - level changes
--     - joins
--     - leaves
--     - rank changes
--     - latest guild members
--
-- Important:
--   Online activity is handled separately by 038/039.

CREATE TABLE IF NOT EXISTS analytics.general_analytics_processed_snapshot_pairs (
    guild_name text NOT NULL,
    world text NOT NULL,
    previous_snapshot_time timestamptz NOT NULL,
    latest_snapshot_time timestamptz NOT NULL,
    processed_at_utc timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (
        world,
        guild_name,
        previous_snapshot_time,
        latest_snapshot_time
    )
);

-- Seed from existing snapshot-pair cache so we only process new missing pairs.
INSERT INTO analytics.general_analytics_processed_snapshot_pairs (
    guild_name,
    world,
    previous_snapshot_time,
    latest_snapshot_time
)
SELECT DISTINCT
    guild_name,
    world,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.snapshot_pairs_api_cache
ON CONFLICT (
    world,
    guild_name,
    previous_snapshot_time,
    latest_snapshot_time
)
DO NOTHING;

CREATE OR REPLACE FUNCTION analytics.process_incremental_general_analytics(
    p_world text DEFAULT NULL,
    p_guild_name text DEFAULT NULL,
    p_pair_limit integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout TO '0'
SET search_path TO 'public', 'analytics'
AS $$
DECLARE
    v_pair_count integer := 0;
    v_snapshot_pair_rows integer := 0;
    v_level_rows integer := 0;
    v_join_rows integer := 0;
    v_leave_rows integer := 0;
    v_rank_rows integer := 0;
    v_latest_member_rows integer := 0;
    v_processed_rows integer := 0;
BEGIN
    IF p_pair_limit IS NULL OR p_pair_limit < 1 THEN
        RAISE EXCEPTION 'p_pair_limit must be at least 1';
    END IF;

    DROP TABLE IF EXISTS due_general_snapshot_pairs;

    CREATE TEMP TABLE due_general_snapshot_pairs ON COMMIT DROP AS
    WITH snapshots AS (
        SELECT DISTINCT
            guild_name,
            world,
            extracted_at_utc
        FROM public.guild_member_snapshot
        WHERE (p_world IS NULL OR world = p_world)
          AND (p_guild_name IS NULL OR guild_name = p_guild_name)
    ),
    paired AS (
        SELECT
            guild_name,
            world,
            LAG(extracted_at_utc) OVER (
                PARTITION BY world, guild_name
                ORDER BY extracted_at_utc
            ) AS previous_snapshot_time,
            extracted_at_utc AS latest_snapshot_time
        FROM snapshots
    )
    SELECT
        paired.guild_name,
        paired.world,
        paired.previous_snapshot_time,
        paired.latest_snapshot_time
    FROM paired
    LEFT JOIN analytics.general_analytics_processed_snapshot_pairs processed
        ON processed.guild_name = paired.guild_name
       AND processed.world = paired.world
       AND processed.previous_snapshot_time = paired.previous_snapshot_time
       AND processed.latest_snapshot_time = paired.latest_snapshot_time
    WHERE paired.previous_snapshot_time IS NOT NULL
      AND paired.latest_snapshot_time > paired.previous_snapshot_time
      AND processed.guild_name IS NULL
    ORDER BY paired.latest_snapshot_time
    LIMIT p_pair_limit;

    SELECT COUNT(*)
    INTO v_pair_count
    FROM due_general_snapshot_pairs;

    IF v_pair_count = 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'processed_pairs', 0,
            'message', 'No unprocessed general analytics snapshot pairs found'
        );
    END IF;

    -- Snapshot pairs.
    INSERT INTO analytics.snapshot_pairs_api_cache (
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time
    )
    SELECT
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time
    FROM due_general_snapshot_pairs pairs
    WHERE NOT EXISTS (
        SELECT 1
        FROM analytics.snapshot_pairs_api_cache existing
        WHERE existing.guild_name = pairs.guild_name
          AND existing.world = pairs.world
          AND existing.previous_snapshot_time = pairs.previous_snapshot_time
          AND existing.latest_snapshot_time = pairs.latest_snapshot_time
    );

    GET DIAGNOSTICS v_snapshot_pair_rows = ROW_COUNT;

    -- Level changes.
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
    FROM due_general_snapshot_pairs pairs
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
    WHERE latest.level IS DISTINCT FROM previous.level
      AND NOT EXISTS (
        SELECT 1
        FROM analytics.character_level_changes_with_online_cache existing
        WHERE existing.guild_name = latest.guild_name
          AND existing.world = latest.world
          AND existing.character_name = latest.character_name
          AND existing.previous_snapshot_time = pairs.previous_snapshot_time
          AND existing.latest_snapshot_time = pairs.latest_snapshot_time
      );

    GET DIAGNOSTICS v_level_rows = ROW_COUNT;

    -- Joins.
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
    FROM due_general_snapshot_pairs pairs
    JOIN public.guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.guild_member_snapshot previous
        WHERE previous.guild_name = pairs.guild_name
          AND previous.world = pairs.world
          AND previous.extracted_at_utc = pairs.previous_snapshot_time
          AND previous.character_name = latest.character_name
    )
      AND NOT EXISTS (
        SELECT 1
        FROM analytics.guild_joins_api_cache existing
        WHERE existing.guild_name = latest.guild_name
          AND existing.world = latest.world
          AND existing.character_name = latest.character_name
          AND existing.previous_snapshot_time = pairs.previous_snapshot_time
          AND existing.latest_snapshot_time = pairs.latest_snapshot_time
      );

    GET DIAGNOSTICS v_join_rows = ROW_COUNT;

    -- Leaves.
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
    FROM due_general_snapshot_pairs pairs
    JOIN public.guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.guild_member_snapshot latest
        WHERE latest.guild_name = pairs.guild_name
          AND latest.world = pairs.world
          AND latest.extracted_at_utc = pairs.latest_snapshot_time
          AND latest.character_name = previous.character_name
    )
      AND NOT EXISTS (
        SELECT 1
        FROM analytics.guild_leaves_api_cache existing
        WHERE existing.guild_name = previous.guild_name
          AND existing.world = previous.world
          AND existing.character_name = previous.character_name
          AND existing.previous_snapshot_time = pairs.previous_snapshot_time
          AND existing.latest_snapshot_time = pairs.latest_snapshot_time
      );

    GET DIAGNOSTICS v_leave_rows = ROW_COUNT;

    -- Rank changes.
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
    FROM due_general_snapshot_pairs pairs
    JOIN public.guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    JOIN public.guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
       AND previous.character_name = latest.character_name
    WHERE latest.guild_rank IS DISTINCT FROM previous.guild_rank
      AND NOT EXISTS (
        SELECT 1
        FROM analytics.rank_changes_api_cache existing
        WHERE existing.guild_name = latest.guild_name
          AND existing.world = latest.world
          AND existing.character_name = latest.character_name
          AND existing.previous_snapshot_time = pairs.previous_snapshot_time
          AND existing.latest_snapshot_time = pairs.latest_snapshot_time
      );

    GET DIAGNOSTICS v_rank_rows = ROW_COUNT;

    -- Latest roster for guilds touched by this run.
    WITH affected_guilds AS (
        SELECT DISTINCT
            guild_name,
            world
        FROM due_general_snapshot_pairs
    ),
    latest_snapshot AS (
        SELECT
            g.guild_name,
            g.world,
            MAX(s.extracted_at_utc) AS latest_snapshot_time
        FROM affected_guilds g
        JOIN public.guild_member_snapshot s
            ON s.guild_name = g.guild_name
           AND s.world = g.world
        GROUP BY
            g.guild_name,
            g.world
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
            ON l.guild_name = s.guild_name
           AND l.world = s.world
           AND l.latest_snapshot_time = s.extracted_at_utc
    ),
    online_activity AS (
        SELECT
            intervals.guild_name,
            intervals.world,
            intervals.character_name,
            MAX(intervals.previous_snapshot_time) AS last_online_at
        FROM analytics.character_online_intervals_cache intervals
        JOIN affected_guilds g
            ON g.guild_name = intervals.guild_name
           AND g.world = intervals.world
        WHERE LOWER(COALESCE(intervals.previous_status, '')) = 'online'
        GROUP BY
            intervals.guild_name,
            intervals.world,
            intervals.character_name
    ),
    level_change_activity AS (
        SELECT
            changes.guild_name,
            changes.world,
            changes.character_name,
            MAX(changes.latest_snapshot_time) AS last_level_change_at
        FROM analytics.character_level_changes_with_online_cache changes
        JOIN affected_guilds g
            ON g.guild_name = changes.guild_name
           AND g.world = changes.world
        GROUP BY
            changes.guild_name,
            changes.world,
            changes.character_name
    )
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
    SELECT
        roster.guild_name,
        roster.world,
        roster.character_name,
        roster.vocation,
        roster.guild_rank,
        roster.current_level,
        roster.latest_snapshot_time,
        CASE
            WHEN online_activity.last_online_at IS NULL
             AND level_change_activity.last_level_change_at IS NULL
                THEN NULL
            ELSE GREATEST(
                COALESCE(online_activity.last_online_at, timestamp with time zone '-infinity'),
                COALESCE(level_change_activity.last_level_change_at, timestamp with time zone '-infinity')
            )
        END AS last_connected_at
    FROM latest_roster roster
    LEFT JOIN online_activity
        ON online_activity.guild_name = roster.guild_name
       AND online_activity.world = roster.world
       AND online_activity.character_name = roster.character_name
    LEFT JOIN level_change_activity
        ON level_change_activity.guild_name = roster.guild_name
       AND level_change_activity.world = roster.world
       AND level_change_activity.character_name = roster.character_name
    ON CONFLICT (world, guild_name, character_name)
    DO UPDATE SET
        vocation = EXCLUDED.vocation,
        guild_rank = EXCLUDED.guild_rank,
        current_level = EXCLUDED.current_level,
        latest_snapshot_time = EXCLUDED.latest_snapshot_time,
        last_connected_at = EXCLUDED.last_connected_at;

    GET DIAGNOSTICS v_latest_member_rows = ROW_COUNT;

    INSERT INTO analytics.general_analytics_processed_snapshot_pairs (
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time,
        processed_at_utc
    )
    SELECT
        guild_name,
        world,
        previous_snapshot_time,
        latest_snapshot_time,
        now()
    FROM due_general_snapshot_pairs
    ON CONFLICT (
        world,
        guild_name,
        previous_snapshot_time,
        latest_snapshot_time
    )
    DO UPDATE SET
        processed_at_utc = EXCLUDED.processed_at_utc;

    GET DIAGNOSTICS v_processed_rows = ROW_COUNT;

    ANALYZE analytics.snapshot_pairs_api_cache;
    ANALYZE analytics.character_level_changes_with_online_cache;
    ANALYZE analytics.guild_joins_api_cache;
    ANALYZE analytics.guild_leaves_api_cache;
    ANALYZE analytics.rank_changes_api_cache;
    ANALYZE analytics.latest_guild_members_api_cache;
    ANALYZE analytics.general_analytics_processed_snapshot_pairs;

    RETURN jsonb_build_object(
        'success', true,
        'processed_pairs', v_pair_count,
        'snapshot_pair_rows', v_snapshot_pair_rows,
        'level_change_rows', v_level_rows,
        'join_rows', v_join_rows,
        'leave_rows', v_leave_rows,
        'rank_change_rows', v_rank_rows,
        'latest_member_rows', v_latest_member_rows,
        'processed_pair_rows_written', v_processed_rows,
        'scope_world', p_world,
        'scope_guild_name', p_guild_name,
        'pair_limit', p_pair_limit
    );
END;
$$;
