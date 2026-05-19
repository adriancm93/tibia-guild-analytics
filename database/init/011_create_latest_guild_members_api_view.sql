-- ============================================================
-- 011_create_latest_guild_members_api_view.sql
-- Public API view for latest guild member roster
-- ============================================================

CREATE OR REPLACE VIEW public.api_latest_guild_members AS
WITH latest_snapshot AS (
    SELECT
        MAX(extracted_at_utc) AS latest_snapshot_time
    FROM stg_guild_member_snapshot
)

SELECT
    s.character_name,
    s.vocation,
    s.guild_rank,
    s.level AS current_level,
    s.guild_name,
    s.world,
    s.extracted_at_utc AS latest_snapshot_time
FROM stg_guild_member_snapshot s
JOIN latest_snapshot l
    ON s.extracted_at_utc = l.latest_snapshot_time;

GRANT SELECT ON public.api_latest_guild_members TO anon;