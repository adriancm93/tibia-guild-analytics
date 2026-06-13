-- 041_schedule_incremental_general_analytics_processor.sql
-- Purpose:
--   Schedule incremental non-online analytics processing separately from ingestion
--   and online activity processing.
--
-- Schedule:
--   Runs every 5 minutes, offset from ingestion and online processing.
--
-- Timing:
--   Ingestion:          */5
--   Online activity:    2-59/5
--   General analytics:  4-59/5

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM cron.job
        WHERE jobname = 'tga_incremental_general_analytics_every_5_minutes'
    ) THEN
        PERFORM cron.unschedule('tga_incremental_general_analytics_every_5_minutes');
    END IF;

    PERFORM cron.schedule(
        'tga_incremental_general_analytics_every_5_minutes',
        '4-59/5 * * * *',
        $cron$
        SELECT analytics.process_incremental_general_analytics(
            p_world => 'Lobera',
            p_guild_name => NULL,
            p_pair_limit => 100
        );
        $cron$
    );
END;
$$;
