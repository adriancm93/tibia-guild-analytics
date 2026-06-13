-- 044_update_refresh_guilds_cron_http_timeout.sql
-- Purpose:
--   Keep ingestion at batch_size 25, but allow pg_net to wait longer
--   before recording a timeout in net._http_response.
--
-- Why:
--   Real ingestion can take more than 5 seconds even when the Edge Function
--   succeeds. The default/current pg_net timeout was creating false timeout
--   rows in net._http_response.

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
            ),
            timeout_milliseconds := 120000
        ) AS request_id;
        $cron$
    );
END;
$$;
