-- ============================================================
-- 017_create_generic_edge_refresh_rpc.sql
-- Generic RPC helpers for Supabase Edge Function guild refresh
-- ============================================================

-- ------------------------------------------------------------
-- Function: claim_due_guild_refresh_batch
--
-- Purpose:
-- Safely claims a batch of due guilds for a selected world.
--
-- This function supports a generic Edge Function design where
-- the same function can refresh Lobera, Antica, Astera, or any
-- other world by passing a world parameter.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.claim_due_guild_refresh_batch(
    p_world text DEFAULT 'Lobera',
    p_batch_size integer DEFAULT 25
)
RETURNS TABLE (
    guild_id uuid,
    guild_name text,
    world text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH due_guilds AS (
        SELECT
            tg.guild_id
        FROM tibia_guild tg
        WHERE tg.is_active = true
          AND tg.world = p_world
          AND (
                tg.next_refresh_after_utc IS NULL
                OR tg.next_refresh_after_utc <= now()
          )
        ORDER BY
            tg.refresh_priority ASC,
            COALESCE(tg.next_refresh_after_utc, timestamp with time zone '1970-01-01') ASC,
            tg.guild_name ASC
        LIMIT p_batch_size
        FOR UPDATE SKIP LOCKED
    )
    UPDATE tibia_guild tg
    SET
        last_refresh_started_at_utc = now(),
        last_refresh_status = 'running',
        last_refresh_error = NULL,
        updated_at_utc = now()
    FROM due_guilds
    WHERE tg.guild_id = due_guilds.guild_id
    RETURNING
        tg.guild_id,
        tg.guild_name,
        tg.world;
END;
$$;


-- ------------------------------------------------------------
-- Function: mark_guild_refresh_success
--
-- Purpose:
-- Marks one guild refresh as successful and schedules the next
-- eligible refresh time using refresh_interval_minutes.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_guild_refresh_success(
    p_guild_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE tibia_guild
    SET
        last_refresh_completed_at_utc = now(),
        last_refresh_status = 'success',
        last_refresh_error = NULL,
        next_refresh_after_utc =
            now() + make_interval(mins => refresh_interval_minutes),
        updated_at_utc = now()
    WHERE guild_id = p_guild_id;
END;
$$;


-- ------------------------------------------------------------
-- Function: mark_guild_refresh_failure
--
-- Purpose:
-- Marks one guild refresh as failed and schedules a retry.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_guild_refresh_failure(
    p_guild_id uuid,
    p_error_message text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE tibia_guild
    SET
        last_refresh_completed_at_utc = now(),
        last_refresh_status = 'failed',
        last_refresh_error = LEFT(p_error_message, 1000),
        next_refresh_after_utc = now() + interval '30 minutes',
        updated_at_utc = now()
    WHERE guild_id = p_guild_id;
END;
$$;


-- ------------------------------------------------------------
-- Function: release_stale_running_guild_refreshes
--
-- Purpose:
-- Resets guilds stuck in running status for too long.
-- This protects the queue if an Edge Function times out or fails
-- before marking a guild success/failure.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.release_stale_running_guild_refreshes(
    p_stale_after interval DEFAULT interval '15 minutes'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    released_count integer;
BEGIN
    UPDATE tibia_guild
    SET
        last_refresh_status = 'retry_ready',
        last_refresh_error = 'Released from stale running status',
        next_refresh_after_utc = now(),
        updated_at_utc = now()
    WHERE last_refresh_status = 'running'
      AND last_refresh_started_at_utc < now() - p_stale_after;

    GET DIAGNOSTICS released_count = ROW_COUNT;

    RETURN released_count;
END;
$$;