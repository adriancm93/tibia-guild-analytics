-- 035_create_snapshot_retention_function.sql
-- Purpose:
--   Create a safe database-side retention function for snapshot data.
--
-- Retention rule:
--   Keep snapshots where extracted_at_utc >= latest_snapshot_timestamp - interval '7 days'.
--
-- Safety:
--   Deletes cache/child rows before parent raw snapshot rows.

CREATE OR REPLACE FUNCTION analytics.apply_safe_7_day_snapshot_retention()
RETURNS TABLE (
    step_name text,
    deleted_rows bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cutoff timestamptz;
    v_deleted bigint;
BEGIN
    SELECT MAX(extracted_at_utc) - interval '7 days'
    INTO v_cutoff
    FROM public.raw_guild_snapshot;

    IF v_cutoff IS NULL THEN
        step_name := 'no_raw_snapshots_found';
        deleted_rows := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    DELETE FROM analytics.character_online_minutes_by_day_cache c
    WHERE c.activity_date < v_cutoff::date;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'character_online_minutes_by_day_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.character_online_intervals_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'character_online_intervals_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.character_level_changes_with_online_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'character_level_changes_with_online_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.guild_joins_api_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'guild_joins_api_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.guild_leaves_api_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'guild_leaves_api_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.rank_changes_api_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'rank_changes_api_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM analytics.snapshot_pairs_api_cache c
    WHERE c.latest_snapshot_time < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'snapshot_pairs_api_cache';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM public.guild_member_snapshot gms
    WHERE gms.extracted_at_utc < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'guild_member_snapshot';
    deleted_rows := v_deleted;
    RETURN NEXT;

    DELETE FROM public.raw_guild_snapshot rgs
    WHERE rgs.extracted_at_utc < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    step_name := 'raw_guild_snapshot';
    deleted_rows := v_deleted;
    RETURN NEXT;

    ANALYZE public.guild_member_snapshot;
    ANALYZE public.raw_guild_snapshot;
    ANALYZE analytics.character_online_intervals_cache;
    ANALYZE analytics.character_online_minutes_by_day_cache;

    step_name := 'analyze_completed';
    deleted_rows := 0;
    RETURN NEXT;
END;
$$;
