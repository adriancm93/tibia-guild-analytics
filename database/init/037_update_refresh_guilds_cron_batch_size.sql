-- 037_update_refresh_guilds_cron_batch_size.sql
-- Purpose:
--   Reduce refresh-guilds cron batch size after making the Edge Function ingestion-only.
--
-- New behavior:
--   Run every 5 minutes with batch_size 5.
--   Analytics refresh is handled separately from ingestion.

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
                'batch_size', 5
            )
        ) AS request_id;
        $cron$
    );
END;
$$;
