SET statement_timeout = '0';

-- ============================================================
-- 022_create_per_guild_frontend_cache_refresh.sql
-- Replace global materialized refresh with per-guild frontend cache tables
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- Frontend cache tables
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.character_estimated_online_minutes_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    estimated_online_minutes integer NOT NULL,
    PRIMARY KEY (world, guild_name, character_name)
);

CREATE TABLE IF NOT EXISTS analytics.character_level_changes_with_online_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    vocation text,
    guild_rank text,
    previous_level integer,
    current_level integer,
    level_gain integer,
    previous_snapshot_time timestamptz,
    latest_snapshot_time timestamptz,
    estimated_online_minutes integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS analytics.snapshot_pairs_api_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    previous_snapshot_time timestamptz NOT NULL,
    latest_snapshot_time timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics.guild_joins_api_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    vocation text,
    level integer,
    guild_rank text,
    status text,
    joined_date date,
    previous_snapshot_time timestamptz,
    latest_snapshot_time timestamptz
);

CREATE TABLE IF NOT EXISTS analytics.guild_leaves_api_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    vocation text,
    level integer,
    guild_rank text,
    status text,
    joined_date date,
    previous_snapshot_time timestamptz,
    latest_snapshot_time timestamptz
);

CREATE TABLE IF NOT EXISTS analytics.rank_changes_api_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    previous_guild_rank text,
    current_guild_rank text,
    previous_snapshot_time timestamptz,
    latest_snapshot_time timestamptz
);

CREATE TABLE IF NOT EXISTS analytics.latest_guild_members_api_cache (
    guild_name text NOT NULL,
    world text NOT NULL,
    character_name text NOT NULL,
    vocation text,
    guild_rank text,
    current_level integer,
    latest_snapshot_time timestamptz,
    last_connected_at timestamptz,
    PRIMARY KEY (world, guild_name, character_name)
);

-- ------------------------------------------------------------
-- Indexes matching frontend query patterns
-- ------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_level_changes_cache_filter_sort
    ON analytics.character_level_changes_with_online_cache (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level_gain DESC,
        current_level DESC
    );

CREATE INDEX IF NOT EXISTS idx_level_changes_cache_character
    ON analytics.character_level_changes_with_online_cache (
        world,
        guild_name,
        character_name
    );

CREATE INDEX IF NOT EXISTS idx_joins_cache_filter_sort
    ON analytics.guild_joins_api_cache (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level DESC,
        character_name ASC
    );

CREATE INDEX IF NOT EXISTS idx_leaves_cache_filter_sort
    ON analytics.guild_leaves_api_cache (
        world,
        guild_name,
        latest_snapshot_time DESC,
        level DESC,
        character_name ASC
    );

CREATE INDEX IF NOT EXISTS idx_rank_changes_cache_filter_sort
    ON analytics.rank_changes_api_cache (
        world,
        guild_name,
        latest_snapshot_time DESC,
        character_name ASC
    );

CREATE INDEX IF NOT EXISTS idx_latest_members_cache_filter_sort
    ON analytics.latest_guild_members_api_cache (
        world,
        guild_name,
        current_level DESC,
        character_name ASC
    );

-- ------------------------------------------------------------
-- Per-guild refresh function
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.refresh_frontend_analytics_for_guild(
    p_world text,
    p_guild_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET statement_timeout = '0'
SET search_path = public, analytics
AS $$
DECLARE
    refreshed_at timestamptz := now();
    level_count integer;
    join_count integer;
    leave_count integer;
    rank_count integer;
    member_count integer;
BEGIN
    -- Remove only this guild/world from cache tables.
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
            FROM guild_member_snapshot
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

    -- Estimate online minutes for this guild.
    INSERT INTO analytics.character_estimated_online_minutes_cache (
        guild_name,
        world,
        character_name,
        estimated_online_minutes
    )
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
        FROM guild_member_snapshot
        WHERE world = p_world
          AND guild_name = p_guild_name
    ),
    online_minutes AS (
        SELECT
            guild_name,
            world,
            character_name,
            SUM(
                EXTRACT(
                    EPOCH FROM LEAST(
                        next_snapshot_time,
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
        guild_name,
        world,
        character_name,
        COALESCE(ROUND(estimated_online_minutes), 0)::integer
    FROM online_minutes
    ON CONFLICT (world, guild_name, character_name)
    DO UPDATE SET
        estimated_online_minutes = EXCLUDED.estimated_online_minutes;

    -- Level changes for this guild.
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
        COALESCE(online_minutes.estimated_online_minutes, 0) AS estimated_online_minutes
    FROM analytics.snapshot_pairs_api_cache pairs
    JOIN guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    JOIN guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
       AND previous.character_name = latest.character_name
    LEFT JOIN analytics.character_estimated_online_minutes_cache online_minutes
        ON latest.guild_name = online_minutes.guild_name
       AND latest.world = online_minutes.world
       AND latest.character_name = online_minutes.character_name
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
    JOIN guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND NOT EXISTS (
        SELECT 1
        FROM guild_member_snapshot previous
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
    JOIN guild_member_snapshot previous
        ON previous.guild_name = pairs.guild_name
       AND previous.world = pairs.world
       AND previous.extracted_at_utc = pairs.previous_snapshot_time
    WHERE pairs.world = p_world
      AND pairs.guild_name = p_guild_name
      AND NOT EXISTS (
        SELECT 1
        FROM guild_member_snapshot latest
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
    JOIN guild_member_snapshot latest
        ON latest.guild_name = pairs.guild_name
       AND latest.world = pairs.world
       AND latest.extracted_at_utc = pairs.latest_snapshot_time
    JOIN guild_member_snapshot previous
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
        FROM guild_member_snapshot
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
        FROM guild_member_snapshot s
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
            MAX(extracted_at_utc) AS last_online_at
        FROM guild_member_snapshot
        WHERE world = p_world
          AND guild_name = p_guild_name
          AND LOWER(COALESCE(status, '')) = 'online'
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
        'level_changes', level_count,
        'joins', join_count,
        'leaves', leave_count,
        'rank_changes', rank_count,
        'members', member_count,
        'refreshed_at_utc', refreshed_at
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_frontend_analytics_for_guild(text, text) TO service_role;

-- ------------------------------------------------------------
-- Public API views now point to cache tables
-- ------------------------------------------------------------

DROP VIEW IF EXISTS public.api_historical_character_level_changes;
DROP VIEW IF EXISTS public.api_historical_guild_joins;
DROP VIEW IF EXISTS public.api_historical_guild_leaves;
DROP VIEW IF EXISTS public.api_historical_rank_changes;
DROP VIEW IF EXISTS public.api_latest_guild_members;

CREATE OR REPLACE VIEW public.api_historical_character_level_changes AS
SELECT
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
FROM analytics.character_level_changes_with_online_cache;

CREATE OR REPLACE VIEW public.api_historical_guild_joins AS
SELECT
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
FROM analytics.guild_joins_api_cache;

CREATE OR REPLACE VIEW public.api_historical_guild_leaves AS
SELECT
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
FROM analytics.guild_leaves_api_cache;

CREATE OR REPLACE VIEW public.api_historical_rank_changes AS
SELECT
    guild_name,
    world,
    character_name,
    previous_guild_rank,
    current_guild_rank,
    previous_snapshot_time,
    latest_snapshot_time
FROM analytics.rank_changes_api_cache;

CREATE OR REPLACE VIEW public.api_latest_guild_members AS
SELECT
    guild_name,
    world,
    character_name,
    vocation,
    guild_rank,
    current_level,
    latest_snapshot_time,
    last_connected_at
FROM analytics.latest_guild_members_api_cache;

GRANT SELECT ON public.api_historical_character_level_changes TO anon;
GRANT SELECT ON public.api_historical_guild_joins TO anon;
GRANT SELECT ON public.api_historical_guild_leaves TO anon;
GRANT SELECT ON public.api_historical_rank_changes TO anon;
GRANT SELECT ON public.api_latest_guild_members TO anon;

GRANT SELECT ON analytics.character_level_changes_with_online_cache TO anon;
GRANT SELECT ON analytics.guild_joins_api_cache TO anon;
GRANT SELECT ON analytics.guild_leaves_api_cache TO anon;
GRANT SELECT ON analytics.rank_changes_api_cache TO anon;
GRANT SELECT ON analytics.latest_guild_members_api_cache TO anon;

NOTIFY pgrst, 'reload schema';

RESET statement_timeout;