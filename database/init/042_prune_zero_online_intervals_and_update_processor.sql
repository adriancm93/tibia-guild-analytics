-- 042_prune_zero_online_intervals_and_update_processor.sql
-- Purpose:
--   Reduce storage and resource pressure from online interval processing.
--
-- Change:
--   Store interval rows only when previous_status = 'online'.
--   Offline rows are equivalent to 0 estimated online minutes and do not need
--   to be physically stored.

CREATE OR REPLACE FUNCTION analytics.process_incremental_online_activity(
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
    v_interval_rows integer := 0;
    v_daily_rows integer := 0;
    v_total_rows integer := 0;
    v_processed_rows integer := 0;
BEGIN
    IF p_pair_limit IS NULL OR p_pair_limit < 1 THEN
        RAISE EXCEPTION 'p_pair_limit must be at least 1';
    END IF;

    DROP TABLE IF EXISTS due_online_snapshot_pairs;

    CREATE TEMP TABLE due_online_snapshot_pairs ON COMMIT DROP AS
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
    LEFT JOIN analytics.online_activity_processed_snapshot_pairs processed
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
    FROM due_online_snapshot_pairs;

    IF v_pair_count = 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'processed_pairs', 0,
            'online_interval_rows', 0,
            'daily_online_minutes_rows', 0,
            'all_time_online_minutes_rows', 0,
            'message', 'No unprocessed snapshot pairs found'
        );
    END IF;

    INSERT INTO analytics.character_online_intervals_cache (
        guild_name,
        world,
        character_name,
        previous_snapshot_time,
        latest_snapshot_time,
        previous_status,
        latest_status,
        interval_minutes,
        estimated_online_minutes,
        created_at_utc
    )
    WITH previous_online_rows AS (
        SELECT
            pairs.guild_name,
            pairs.world,
            pairs.previous_snapshot_time,
            pairs.latest_snapshot_time,
            previous.character_name,
            previous.status AS previous_status
        FROM due_online_snapshot_pairs pairs
        JOIN public.guild_member_snapshot previous
            ON previous.guild_name = pairs.guild_name
           AND previous.world = pairs.world
           AND previous.extracted_at_utc = pairs.previous_snapshot_time
        WHERE LOWER(COALESCE(previous.status, '')) = 'online'
    ),
    latest_rows AS (
        SELECT
            pairs.guild_name,
            pairs.world,
            pairs.previous_snapshot_time,
            pairs.latest_snapshot_time,
            latest.character_name,
            latest.status AS latest_status
        FROM due_online_snapshot_pairs pairs
        JOIN public.guild_member_snapshot latest
            ON latest.guild_name = pairs.guild_name
           AND latest.world = pairs.world
           AND latest.extracted_at_utc = pairs.latest_snapshot_time
    ),
    calculated_intervals AS (
        SELECT
            previous_online_rows.guild_name,
            previous_online_rows.world,
            previous_online_rows.character_name,
            previous_online_rows.previous_snapshot_time,
            previous_online_rows.latest_snapshot_time,
            previous_online_rows.previous_status,
            latest_rows.latest_status,
            GREATEST(
                ROUND(EXTRACT(EPOCH FROM previous_online_rows.latest_snapshot_time - previous_online_rows.previous_snapshot_time) / 60.0),
                0
            )::integer AS interval_minutes
        FROM previous_online_rows
        LEFT JOIN latest_rows
            ON latest_rows.guild_name = previous_online_rows.guild_name
           AND latest_rows.world = previous_online_rows.world
           AND latest_rows.previous_snapshot_time = previous_online_rows.previous_snapshot_time
           AND latest_rows.latest_snapshot_time = previous_online_rows.latest_snapshot_time
           AND latest_rows.character_name = previous_online_rows.character_name
        WHERE previous_online_rows.latest_snapshot_time > previous_online_rows.previous_snapshot_time
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
        LEAST(interval_minutes, 15) AS estimated_online_minutes,
        now() AS created_at_utc
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

    GET DIAGNOSTICS v_interval_rows = ROW_COUNT;

    WITH affected_days AS (
        SELECT DISTINCT
            intervals.guild_name,
            intervals.world,
            intervals.character_name,
            intervals.latest_snapshot_time::date AS activity_date
        FROM analytics.character_online_intervals_cache intervals
        JOIN due_online_snapshot_pairs pairs
            ON pairs.guild_name = intervals.guild_name
           AND pairs.world = intervals.world
           AND pairs.previous_snapshot_time = intervals.previous_snapshot_time
           AND pairs.latest_snapshot_time = intervals.latest_snapshot_time
    ),
    daily_totals AS (
        SELECT
            intervals.guild_name,
            intervals.world,
            intervals.character_name,
            intervals.latest_snapshot_time::date AS activity_date,
            COALESCE(SUM(intervals.estimated_online_minutes), 0)::integer AS estimated_online_minutes,
            COUNT(*)::integer AS online_interval_rows
        FROM analytics.character_online_intervals_cache intervals
        JOIN affected_days affected
            ON affected.guild_name = intervals.guild_name
           AND affected.world = intervals.world
           AND affected.character_name = intervals.character_name
           AND affected.activity_date = intervals.latest_snapshot_time::date
        GROUP BY
            intervals.guild_name,
            intervals.world,
            intervals.character_name,
            intervals.latest_snapshot_time::date
    )
    INSERT INTO analytics.character_online_minutes_by_day_cache (
        guild_name,
        world,
        character_name,
        activity_date,
        estimated_online_minutes,
        online_interval_rows,
        refreshed_at_utc
    )
    SELECT
        guild_name,
        world,
        character_name,
        activity_date,
        estimated_online_minutes,
        online_interval_rows,
        now() AS refreshed_at_utc
    FROM daily_totals
    WHERE estimated_online_minutes > 0
    ON CONFLICT (
        world,
        guild_name,
        character_name,
        activity_date
    )
    DO UPDATE SET
        estimated_online_minutes = EXCLUDED.estimated_online_minutes,
        online_interval_rows = EXCLUDED.online_interval_rows,
        refreshed_at_utc = now();

    GET DIAGNOSTICS v_daily_rows = ROW_COUNT;

    WITH affected_characters AS (
        SELECT DISTINCT
            intervals.guild_name,
            intervals.world,
            intervals.character_name
        FROM analytics.character_online_intervals_cache intervals
        JOIN due_online_snapshot_pairs pairs
            ON pairs.guild_name = intervals.guild_name
           AND pairs.world = intervals.world
           AND pairs.previous_snapshot_time = intervals.previous_snapshot_time
           AND pairs.latest_snapshot_time = intervals.latest_snapshot_time
    ),
    all_time_totals AS (
        SELECT
            intervals.guild_name,
            intervals.world,
            intervals.character_name,
            COALESCE(SUM(intervals.estimated_online_minutes), 0)::integer AS estimated_online_minutes
        FROM analytics.character_online_intervals_cache intervals
        JOIN affected_characters affected
            ON affected.guild_name = intervals.guild_name
           AND affected.world = intervals.world
           AND affected.character_name = intervals.character_name
        GROUP BY
            intervals.guild_name,
            intervals.world,
            intervals.character_name
    )
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
        estimated_online_minutes
    FROM all_time_totals
    WHERE estimated_online_minutes > 0
    ON CONFLICT (
        world,
        guild_name,
        character_name
    )
    DO UPDATE SET
        estimated_online_minutes = EXCLUDED.estimated_online_minutes;

    GET DIAGNOSTICS v_total_rows = ROW_COUNT;

    INSERT INTO analytics.online_activity_processed_snapshot_pairs (
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
    FROM due_online_snapshot_pairs
    ON CONFLICT (
        world,
        guild_name,
        previous_snapshot_time,
        latest_snapshot_time
    )
    DO UPDATE SET
        processed_at_utc = EXCLUDED.processed_at_utc;

    GET DIAGNOSTICS v_processed_rows = ROW_COUNT;

    ANALYZE analytics.character_online_intervals_cache;
    ANALYZE analytics.character_online_minutes_by_day_cache;
    ANALYZE analytics.character_estimated_online_minutes_cache;
    ANALYZE analytics.online_activity_processed_snapshot_pairs;

    RETURN jsonb_build_object(
        'success', true,
        'processed_pairs', v_pair_count,
        'processed_pair_rows_written', v_processed_rows,
        'online_interval_rows', v_interval_rows,
        'daily_online_minutes_rows', v_daily_rows,
        'all_time_online_minutes_rows', v_total_rows,
        'scope_world', p_world,
        'scope_guild_name', p_guild_name,
        'pair_limit', p_pair_limit,
        'storage_policy', 'store_previous_online_intervals_only'
    );
END;
$$;

-- Remove historical zero-minute interval rows created before this optimization.
DELETE FROM analytics.character_online_intervals_cache
WHERE COALESCE(estimated_online_minutes, 0) = 0;

DELETE FROM analytics.character_online_minutes_by_day_cache
WHERE COALESCE(estimated_online_minutes, 0) = 0;

DELETE FROM analytics.character_estimated_online_minutes_cache
WHERE COALESCE(estimated_online_minutes, 0) = 0;

ANALYZE analytics.character_online_intervals_cache;
ANALYZE analytics.character_online_minutes_by_day_cache;
ANALYZE analytics.character_estimated_online_minutes_cache;
