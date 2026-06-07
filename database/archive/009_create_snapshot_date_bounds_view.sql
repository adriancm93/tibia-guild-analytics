-- ============================================================
-- 009_create_snapshot_date_bounds_view.sql
-- Public API view for available snapshot date range
-- ============================================================

CREATE OR REPLACE VIEW public.api_snapshot_date_bounds AS
SELECT
    MIN(extracted_at_utc) AS min_snapshot_time,
    MAX(extracted_at_utc) AS max_snapshot_time
FROM raw_guild_snapshot;

GRANT SELECT ON public.api_snapshot_date_bounds TO anon;