-- 045_set_lobera_guild_refresh_interval_30_minutes.sql
-- Purpose:
--   Set all active Lobera guilds to refresh every 30 minutes.
--
-- Notes:
--   Also recalculates next_refresh_after_utc so guilds that were previously
--   waiting on a 120-minute schedule become due according to the new 30-minute
--   schedule.

UPDATE public.tibia_guild
SET
    refresh_interval_minutes = 30,
    next_refresh_after_utc = CASE
        WHEN last_refresh_completed_at_utc IS NULL THEN now()
        ELSE LEAST(
            COALESCE(next_refresh_after_utc, now()),
            last_refresh_completed_at_utc + interval '30 minutes'
        )
    END,
    updated_at_utc = now()
WHERE world = 'Lobera'
  AND is_active = true;
