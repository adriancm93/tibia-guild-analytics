# Operations

This document contains operational procedures for monitoring and troubleshooting Tibia Guild Analytics.

The current production system uses:

```text
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres
        ↓
Per-guild analytics cache tables
        ↓
Public API views
        ↓
Cloudflare Pages frontend
```

---

## Key Operational Concepts

### Raw data freshness

Raw data freshness means new snapshots are being inserted into:

```text
public.guild_member_snapshot
```

### Cache freshness

Cache freshness means the per-guild analytics cache tables have been rebuilt after the latest raw snapshot.

The most important cache for roster freshness is:

```text
analytics.latest_guild_members_api_cache
```

### Frontend freshness

Frontend freshness means public API views reflect the current cache tables and the browser is loading the latest JavaScript/CSS.

---

## Monitor Supabase Cron

In the Supabase dashboard:

```text
Integrations → Cron
```

Confirm the scheduled job is running successfully.

The cron job duration usually reflects how long it took Postgres to send the HTTP request, not necessarily the full ingestion duration. Use Edge Function logs to inspect ingestion behavior.

---

## Monitor Edge Function Logs

In the Supabase dashboard:

```text
Edge Functions → refresh-guilds → Logs
```

Look for:

- Claimed guild count
- Success count
- Failure count
- Frontend cache refresh failures
- TibiaData API errors
- Database RPC errors

A healthy response should include:

```json
{
  "success": true,
  "frontend_refresh_failure_count": 0
}
```

---

## Manual Edge Function Trigger

Use a manual trigger to test ingestion:

```bash
curl -i \
  -X POST "https://<project-ref>.supabase.co/functions/v1/refresh-guilds" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <secret>" \
  -d '{"world":"Lobera","batch_size":5}'
```

If the response has:

```json
"claimed": 0
```

then no guilds were due for refresh.

---

## Make a Guild Due Immediately

For testing, force one guild to be due:

```sql
UPDATE public.tibia_guild
SET
    next_refresh_after_utc = now(),
    updated_at_utc = now()
WHERE world = 'Lobera'
  AND guild_name = 'Black Clover';
```

Then trigger the Edge Function with `batch_size: 1`.

---

## Check Guild Refresh Status

```sql
SELECT
    world,
    guild_name,
    last_refresh_status,
    last_refresh_started_at_utc,
    last_refresh_completed_at_utc,
    next_refresh_after_utc,
    LEFT(COALESCE(last_refresh_error, ''), 200) AS error_preview
FROM public.tibia_guild
WHERE world = 'Lobera'
ORDER BY updated_at_utc DESC
LIMIT 30;
```

Use this to identify recent failures or stuck guilds.

---

## Check for Stuck Running Guilds

```sql
SELECT
    world,
    guild_name,
    last_refresh_status,
    last_refresh_started_at_utc,
    now() - last_refresh_started_at_utc AS running_duration
FROM public.tibia_guild
WHERE last_refresh_status = 'running'
ORDER BY last_refresh_started_at_utc;
```

The Edge Function calls:

```sql
public.release_stale_running_guild_refreshes(p_stale_after)
```

to release stale running claims, but this query is useful for manual verification.

---

## Validate Raw Snapshot Freshness

```sql
SELECT
    world,
    guild_name,
    COUNT(DISTINCT extracted_at_utc) AS snapshot_count,
    COUNT(*) AS member_snapshot_rows,
    MAX(extracted_at_utc) AS latest_snapshot
FROM public.guild_member_snapshot
WHERE world = 'Lobera'
GROUP BY
    world,
    guild_name
ORDER BY latest_snapshot DESC
LIMIT 30;
```

This confirms whether raw parsed snapshots are being inserted.

---

## Validate Cache Freshness for One Guild

Compare the latest raw snapshot against the latest roster cache.

```sql
SELECT
    MAX(extracted_at_utc) AS base_latest_snapshot
FROM public.guild_member_snapshot
WHERE world = 'Lobera'
  AND guild_name = 'Black Clover';

SELECT
    MAX(latest_snapshot_time) AS cache_latest_snapshot
FROM analytics.latest_guild_members_api_cache
WHERE world = 'Lobera'
  AND guild_name = 'Black Clover';
```

The two timestamps should match after a successful ingestion and cache refresh.

---

## Compare Raw Roster vs Cached Roster

Use this when the website says a guild refreshed but the roster table looks stale.

```sql
WITH latest_base_snapshot AS (
    SELECT
        MAX(extracted_at_utc) AS latest_snapshot_time
    FROM public.guild_member_snapshot
    WHERE world = 'Lobera'
      AND guild_name = 'Black Clover'
),

base_roster AS (
    SELECT
        s.character_name,
        s.level AS base_current_level,
        s.guild_rank AS base_guild_rank,
        s.extracted_at_utc AS base_latest_snapshot_time
    FROM public.guild_member_snapshot s
    JOIN latest_base_snapshot l
        ON s.extracted_at_utc = l.latest_snapshot_time
    WHERE s.world = 'Lobera'
      AND s.guild_name = 'Black Clover'
),

cache_roster AS (
    SELECT
        character_name,
        current_level AS cache_current_level,
        guild_rank AS cache_guild_rank,
        latest_snapshot_time AS cache_latest_snapshot_time
    FROM analytics.latest_guild_members_api_cache
    WHERE world = 'Lobera'
      AND guild_name = 'Black Clover'
)

SELECT
    COALESCE(b.character_name, c.character_name) AS character_name,
    b.base_current_level,
    c.cache_current_level,
    b.base_guild_rank,
    c.cache_guild_rank,
    b.base_latest_snapshot_time,
    c.cache_latest_snapshot_time
FROM base_roster b
FULL OUTER JOIN cache_roster c
    ON b.character_name = c.character_name
WHERE b.base_current_level IS DISTINCT FROM c.cache_current_level
   OR b.base_guild_rank IS DISTINCT FROM c.cache_guild_rank
   OR b.base_latest_snapshot_time IS DISTINCT FROM c.cache_latest_snapshot_time
ORDER BY character_name
LIMIT 50;
```

Expected result after a healthy refresh:

```text
0 rows
```

---

## Manually Process Analytics

If raw data exists but analytics cache tables are stale, run the incremental analytics processors manually.

For one world and all due guilds:

```sql
SELECT analytics.process_incremental_online_activity('Lobera', NULL, 100);

SELECT analytics.process_incremental_general_analytics('Lobera', NULL, 100);
```

For one specific guild:

```sql
SELECT analytics.process_incremental_online_activity('Lobera', 'Black Clover', 100);

SELECT analytics.process_incremental_general_analytics('Lobera', 'Black Clover', 100);
```

Then reload the website.

---

## Validate Website API Views

```sql
SELECT 'api_worlds' AS view_name, COUNT(*) FROM public.api_worlds
UNION ALL
SELECT 'api_guilds', COUNT(*) FROM public.api_guilds
UNION ALL
SELECT 'api_snapshot_date_bounds_by_guild', COUNT(*) FROM public.api_snapshot_date_bounds_by_guild
UNION ALL
SELECT 'api_guild_overview_by_snapshot', COUNT(*) FROM public.api_guild_overview_by_snapshot
UNION ALL
SELECT 'api_historical_character_level_changes', COUNT(*) FROM public.api_historical_character_level_changes
UNION ALL
SELECT 'api_historical_guild_joins', COUNT(*) FROM public.api_historical_guild_joins
UNION ALL
SELECT 'api_historical_guild_leaves', COUNT(*) FROM public.api_historical_guild_leaves
UNION ALL
SELECT 'api_historical_rank_changes', COUNT(*) FROM public.api_historical_rank_changes
UNION ALL
SELECT 'api_latest_guild_members', COUNT(*) FROM public.api_latest_guild_members;
```

This confirms the frontend-facing views are populated.

---

## Validate Project-Owned Database Objects

```sql
SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('public', 'analytics')
ORDER BY table_schema, table_type, table_name;
```

Current expected project-owned structure:

- 4 core public tables
- 7 analytics cache tables
- 9 public API views
- no materialized views

Check materialized views:

```sql
SELECT
    schemaname,
    matviewname
FROM pg_matviews
WHERE schemaname IN ('public', 'analytics')
ORDER BY schemaname, matviewname;
```

Expected:

```text
0 rows
```

---

## Validate Function Inventory

```sql
SELECT
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema IN ('public', 'analytics')
ORDER BY routine_schema, routine_name;
```

Expected project functions:

Public RPC functions used by the Edge Function:

- `claim_due_guild_refresh_batch`
- `mark_guild_refresh_failure`
- `mark_guild_refresh_success`
- `release_stale_running_guild_refreshes`

Analytics and retention functions used by Supabase Cron:

- `process_incremental_online_activity`
- `process_incremental_general_analytics`
- `apply_safe_7_day_snapshot_retention`

---

## Common Issues

### Website says refreshed, but tables look stale

Likely cause:

```text
Raw snapshot inserted, but incremental analytics have not processed the latest snapshot pair yet.
```

Actions:

1. Compare raw latest snapshot vs cache latest snapshot.
2. Check Supabase Cron job status for the incremental analytics jobs.
3. Manually run `analytics.process_incremental_online_activity(...)`.
4. Manually run `analytics.process_incremental_general_analytics(...)`.
5. Review Edge Function logs only if raw snapshots are missing.

---

### Edge Function claims zero guilds

Likely cause:

```text
No guilds are due based on next_refresh_after_utc.
```

Actions:

1. Check `public.tibia_guild.next_refresh_after_utc`.
2. Force a guild due for manual testing.
3. Confirm Cron is still triggering on schedule.

---

### REST API returns statement timeout

This should be rare under the current cache-table architecture.

Possible causes:

- API view was accidentally rewritten to use dynamic historical logic.
- Cache table indexes are missing.
- Supabase is under temporary load.

Actions:

1. Confirm public API views point to cache tables.
2. Validate indexes on cache tables.
3. Check Supabase logs.

---

## Operational Best Practice

When changing database objects, avoid `CASCADE` during cleanup unless dependencies have been manually reviewed.

Prefer:

```bash
psql -v ON_ERROR_STOP=1
```

This ensures SQL scripts stop at the first error and do not leave the schema partially modified.
