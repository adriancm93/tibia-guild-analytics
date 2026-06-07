# Database

This folder contains SQL assets for the Tibia Guild Analytics database.

The current production database runs on Supabase Postgres and is organized around:

1. Core raw and parsed snapshot tables
2. World/guild metadata and refresh queue tables
3. Per-guild analytics cache tables
4. Public API views consumed by the frontend
5. RPC functions used by the Supabase Edge Function

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
guild_member_snapshot
        ↓
refresh_frontend_analytics_for_guild(world, guild_name)
        ↓
analytics.*_cache tables
        ↓
public.api_* views
        ↓
Supabase REST API
        ↓
Frontend
```

The dashboard does not query dynamic historical comparison views. Expensive analytics are precomputed into cache tables per guild.

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

## Current RPC Functions

| Function | Purpose |
|---|---|
| `public.claim_due_guild_refresh_batch` | Claims due guilds for refresh |
| `public.mark_guild_refresh_success` | Marks successful refreshes |
| `public.mark_guild_refresh_failure` | Marks failed refreshes |
| `public.release_stale_running_guild_refreshes` | Recovers stale running jobs |
| `public.apply_snapshot_retention` | Applies the snapshot retention policy |
| `public.refresh_frontend_analytics_for_guild` | Refreshes frontend cache rows for one guild |

---

## Design Notes

The database intentionally uses cache tables instead of global materialized views.

Earlier global materialized-view and dynamic-view approaches became too expensive as the dataset grew. The current design refreshes only the guild that was ingested, which is more scalable and better aligned with the queue-based ingestion model.
