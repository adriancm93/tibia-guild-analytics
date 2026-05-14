-- Phase 3B
-- Create staging views for cleaned guild snapshot data.

CREATE OR REPLACE VIEW stg_guild_member_snapshot AS
SELECT
    guild_name,
    world,
    character_name,
    guild_rank,
    vocation,
    level::integer AS level,
    status,
    joined::date AS joined_date,
    extracted_at_utc
FROM guild_member_snapshot
WHERE character_name IS NOT NULL;