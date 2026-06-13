-- 039_schedule_incremental_online_activity_processor.sql
-- Purpose:
--   Schedule incremental online activity processing separately from ingestion.
--
-- Schedule:
--   Runs every 5 minutes, offset from ingestion by 2 minutes.
--
-- Why:
--   Ingestion should stay fast. Online activity processing is handled
--   asynchronously in small batches.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM cron.job
        WHERE jobname = 'tga_incremental_online_activity_every_5_minutes'
    ) THEN
        PERFORM cron.unschedule('tga_incremental_online_activity_every_5_minutes');
    END IF;

    PERFORM cron.schedule(
        'tga_incremental_online_activity_every_5_minutes',
        '2-59/5 * * * *',
        $cron$
        SELECT analytics.process_incremental_online_activity(
            p_world => 'Lobera',
            p_guild_name => NULL,
            p_pair_limit => 100
        );
        $cron$
    );
END;
$$;
