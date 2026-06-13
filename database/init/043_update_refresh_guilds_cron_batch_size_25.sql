-- 043_update_refresh_guilds_cron_batch_size_25.sql
-- Purpose:
--   Restore ingestion cron and increase batch size from 5 to 25.
--
-- Why 25:
--   Real load testing showed batch_size 25 completed successfully in about 76 seconds.
--   Batch_size 50 completed but took about 100 seconds, so 25 is a safer production step.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM cron.job
        WHERE jobname = 'refresh-lobera-guilds-every-5-minutes'
    ) THEN
        PERFORM cron.unschedule('refresh-lobera-guilds-every-5-minutes');
    END IF;

    PERFORM cron.schedule(
        'refresh-lobera-guilds-every-5-minutes',
        '*/5 * * * *',
        $cron$
        SELECT net.http_post(
            url := (
                SELECT decrypted_secret
                FROM vault.decrypted_secrets
                WHERE name = 'project_url'
            ) || '/functions/v1/refresh-guilds',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', (
                    SELECT decrypted_secret
                    FROM vault.decrypted_secrets
                    WHERE name = 'guild_refresh_secret'
                )
            ),
            body := jsonb_build_object(
                'world', 'Lobera',
                'batch_size', 25
            )
        ) AS request_id;
        $cron$
    );
END;
$$;
