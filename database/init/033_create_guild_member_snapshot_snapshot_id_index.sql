-- 033_create_guild_member_snapshot_snapshot_id_index.sql
-- Purpose:
--   Add an index on guild_member_snapshot.snapshot_id.
--
-- Why:
--   raw_guild_snapshot is referenced by guild_member_snapshot through snapshot_id.
--   Deletes from raw_guild_snapshot trigger foreign-key/cascade checks on
--   guild_member_snapshot.snapshot_id. Without this index, retention cleanup can
--   become extremely slow or time out.

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_snapshot_id
ON public.guild_member_snapshot (snapshot_id);
