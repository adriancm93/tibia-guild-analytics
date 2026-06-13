-- 036_schedule_safe_7_day_snapshot_retention_cron.sql
-- Purpose:
--   Schedule daily safe 7-day snapshot retention using pg_cron.
--
-- Schedule:
--   Runs daily at 11:10 UTC.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM cron.job
        WHERE jobname = 'tga_safe_7_day_snapshot_retention'
    ) THEN
        PERFORM cron.unschedule('tga_safe_7_day_snapshot_retention');
    END IF;

    PERFORM cron.schedule(
        'tga_safe_7_day_snapshot_retention',
        '10 11 * * *',
        'SELECT * FROM analytics.apply_safe_7_day_snapshot_retention();'
    );
END;
$$;
