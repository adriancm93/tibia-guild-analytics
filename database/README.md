# Database

This folder contains SQL assets for the Tibia Guild Analytics database.

The current production database runs on Supabase Postgres and is organized around:

1. Core raw and parsed snapshot tables
2. World/guild metadata and refresh queue tables
3. Incremental analytics cache tables
4. Public API views consumed by the frontend
5. RPC functions used by the Supabase Edge Function
6. Scheduled analytics and retention functions used by Supabase Cron

---

## Folder Structure

| Folder | Purpose |
|---|---|
| `init/` | Current schema build scripts |
| `archive/` | Historical SQL scripts from earlier development phases |
| `cleanup/` | One-time scripts used to remove legacy database objects |
| `validation/` | SQL queries used to validate data quality, pipeline behavior, and API readiness |

---

## Current Serving Pattern

The current serving pattern is:

```text
Supabase Cron
        ↓
Supabase Edge Function: refresh-guilds
        ↓
public.raw_guild_snapshot
public.guild_member_snapshot
        ↓
Supabase Cron incremental processors
        ↓
analytics.*_cache tables
        ↓
public.api_* views
        ↓
Supabase REST API
        ↓
Frontend
```

The Edge Function is ingestion-only. It claims due guilds, fetches TibiaData, stores raw snapshots, stores normalized member rows, and marks guild refresh status.

Analytics are processed asynchronously by scheduled Postgres functions. This keeps ingestion fast and prevents one large refresh operation from blocking the pipeline.

---

## Current Core Tables

| Table | Purpose |
|---|---|
| `public.raw_guild_snapshot` | Stores raw TibiaData guild API payloads |
| `public.guild_member_snapshot` | Stores parsed member rows per snapshot |
| `public.tibia_world` | Stores world metadata |
| `public.tibia_guild` | Stores guild metadata and refresh queue state |

---

## Current Analytics Cache Tables

| Table | Purpose |
|---|---|
| `analytics.snapshot_pairs_api_cache` | Stores consecutive snapshot pairs |
| `analytics.character_estimated_online_minutes_cache` | Stores estimated online time per character |
| `analytics.character_level_changes_with_online_cache` | Stores level changes with time-online metrics |
| `analytics.guild_joins_api_cache` | Stores guild join events |
| `analytics.guild_leaves_api_cache` | Stores guild leave events |
| `analytics.rank_changes_api_cache` | Stores rank change events |
| `analytics.latest_guild_members_api_cache` | Stores latest roster and last-connected estimates |

---

## Current Public API Views

| View | Purpose |
|---|---|
| `public.api_worlds` | World selector |
| `public.api_guilds` | Guild selector |
| `public.api_snapshot_date_bounds_by_guild` | Date filter bounds |
| `public.api_guild_overview_by_snapshot` | Guild overview metrics |
| `public.api_historical_character_level_changes` | Level changes and time online |
| `public.api_historical_guild_joins` | Guild joins |
| `public.api_historical_guild_leaves` | Guild leaves |
| `public.api_historical_rank_changes` | Rank changes |
| `public.api_latest_guild_members` | Latest guild roster |

---

## Current Production Functions

### RPC functions used by the Edge Function

| Function | Purpose |
|---|---|
| `public.claim_due_guild_refresh_batch` | Claims due guilds for refresh |
| `public.mark_guild_refresh_success` | Marks successful refreshes |
| `public.mark_guild_refresh_failure` | Marks failed refreshes |
| `public.release_stale_running_guild_refreshes` | Recovers stale running jobs |

### Functions used by Supabase Cron

| Function | Purpose |
|---|---|
| `analytics.process_incremental_online_activity` | Processes online activity from unprocessed snapshot pairs |
| `analytics.process_incremental_general_analytics` | Processes level changes, joins, leaves, rank changes, and latest roster cache |
| `analytics.apply_safe_7_day_snapshot_retention` | Applies safe 7-day retention across raw, normalized, and analytics cache tables |

---

## Design Notes

The database intentionally uses cache tables instead of global materialized views.

Earlier global materialized-view and dynamic-view approaches became too expensive as the dataset grew. The current design separates ingestion from analytics:

- Ingestion runs through the Edge Function.
- Analytics run through incremental scheduled processors.
- Each processor tracks completed snapshot pairs to avoid reprocessing.
- Public API views read from precomputed cache tables.
- Retention runs separately to control storage growth.

This design is more scalable than rebuilding all analytics during every guild refresh.
