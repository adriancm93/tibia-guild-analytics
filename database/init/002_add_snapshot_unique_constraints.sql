-- Phase 3A
-- Prevent duplicate guild member snapshot rows when the same snapshot is loaded more than once.

ALTER TABLE guild_member_snapshot
ADD CONSTRAINT uq_guild_member_snapshot
UNIQUE (
    guild_name,
    world,
    character_name,
    extracted_at_utc
);