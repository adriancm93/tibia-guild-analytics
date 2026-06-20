# Data Model

This document describes the current data model for Tibia Guild Analytics.

The database is organized into three logical layers:

1. **Core source tables** in the `public` schema
2. **Analytics cache tables** in the `analytics` schema
3. **Public API views** in the `public` schema

The production database runs on Supabase Postgres.

---

## Data Modeling Principles

The current model follows these principles:

- Store raw API payloads for lineage and recovery.
- Store parsed historical snapshots at the character level.
- Use metadata tables for world/guild selection and refresh queue state.
- Precompute expensive dashboard analytics into per-guild cache tables.
- Expose only curated public API views to the frontend.
- Keep raw tables and cache tables separate.

---

## Core Tables

### `public.raw_guild_snapshot`

Stores the full TibiaData guild API response for each extraction.

Purpose:

- Raw data lineage
- Debugging failed or unexpected parsing behavior
- Reprocessing support
- Audit trail of API responses over time

Typical columns:

| Column | Description |
|---|---|
| `snapshot_id` | Unique snapshot identifier |
| `guild_name` | Guild name requested |
| `source` | Source system, usually `tibiadata` |
| `extracted_at_utc` | UTC extraction timestamp |
| `raw_json` | Full JSON payload |

---

### `public.guild_member_snapshot`

Stores parsed member-level rows from each guild snapshot.

This is the main historical fact table.

Grain:

```text
One row per guild member per guild snapshot.
```

Typical columns:

| Column | Description |
|---|---|
| `snapshot_id` | Snapshot identifier |
| `extracted_at_utc` | UTC extraction timestamp |
| `guild_name` | Guild name |
| `world` | Tibia world |
| `character_name` | Character name |
| `guild_rank` | Character’s guild rank |
| `vocation` | Character’s vocation |
| `level` | Character level at snapshot time |
| `status` | Online/offline status at snapshot time |
| `joined` | Guild joined date when available |

This table enables:

- Level-change detection
- Guild join/leave detection
- Rank-change detection
- Online activity estimation
- Latest roster extraction

---

### `public.tibia_world`

Stores available world metadata.

Purpose:

- World selector support
- Metadata discovery tracking
- Future multi-world scalability

Current production scope is focused on Lobera, but the schema supports additional worlds.

---

### `public.tibia_guild`

Stores guild metadata and refresh queue state.

Purpose:

- Guild selector support
- Refresh scheduling
- Worker queue state
- Operational troubleshooting

Important fields include:

| Field | Purpose |
|---|---|
| `guild_name` | Guild name |
| `world` | Tibia world |
| `is_active` | Whether the guild is refreshable |
| `last_refresh_status` | Last refresh status |
| `last_refresh_started_at_utc` | Last refresh start timestamp |
| `last_refresh_completed_at_utc` | Last refresh completion timestamp |
| `next_refresh_after_utc` | Earliest next refresh time |
| `last_refresh_error` | Last refresh error message |

---

## Analytics Cache Tables

Analytics cache tables live in the `analytics` schema. They are the current serving layer for the dashboard.

The cache tables are maintained incrementally by scheduled Supabase Cron jobs that call:

```sql
analytics.process_incremental_online_activity(...)
analytics.process_incremental_general_analytics(...)
```

These processors read new snapshot pairs, skip pairs that have already been processed, and update only the cache rows needed for frontend API views.

---

### `analytics.snapshot_pairs_api_cache`

Stores consecutive snapshot pairs for each guild.

Grain:

```text
One row per previous/latest snapshot pair per guild.
```

Purpose:

- Foundation for historical comparisons
- Used to detect level changes, joins, leaves, and rank changes

Important columns:

| Column | Description |
|---|---|
| `guild_name` | Guild name |
| `world` | Tibia world |
| `previous_snapshot_time` | Earlier snapshot timestamp |
| `latest_snapshot_time` | Later snapshot timestamp |

---

### `analytics.character_estimated_online_minutes_cache`

Stores estimated online minutes per character.

Purpose:

- Estimate time online based on observed `online` snapshots
- Enrich level-change analytics with activity context

Logic:

```text
If a character is online at one snapshot,
estimate online time until the next snapshot,
capped to a safe interval.
```

Important columns:

| Column | Description |
|---|---|
| `guild_name` | Guild name |
| `world` | Tibia world |
| `character_name` | Character name |
| `estimated_online_minutes` | Estimated observed online minutes |

---

### `analytics.character_level_changes_with_online_cache`

Stores detected level changes enriched with estimated online minutes.

Grain:

```text
One row per character level change between two consecutive snapshots.
```

Purpose:

- Power the “Level Changes and Time Online” dashboard table

Important columns:

| Column | Description |
|---|---|
| `character_name` | Character name |
| `vocation` | Vocation at latest snapshot |
| `guild_rank` | Guild rank at latest snapshot |
| `previous_level` | Level in previous snapshot |
| `current_level` | Level in latest snapshot |
| `level_gain` | Difference between latest and previous level |
| `previous_snapshot_time` | Earlier snapshot timestamp |
| `latest_snapshot_time` | Detection timestamp |
| `estimated_online_minutes` | Estimated observed online minutes |

---

### `analytics.guild_joins_api_cache`

Stores detected guild join events.

Definition:

```text
A character exists in the latest snapshot but did not exist in the previous snapshot.
```

Purpose:

- Power the Guild Joins dashboard table

---

### `analytics.guild_leaves_api_cache`

Stores detected guild leave events.

Definition:

```text
A character existed in the previous snapshot but does not exist in the latest snapshot.
```

Purpose:

- Power the Guild Leaves dashboard table

---

### `analytics.rank_changes_api_cache`

Stores detected rank change events.

Definition:

```text
A character exists in both consecutive snapshots, but the guild rank changed.
```

The SQL logic uses null-safe comparison:

```sql
latest.guild_rank IS DISTINCT FROM previous.guild_rank
```

Purpose:

- Power the Rank Changes dashboard table

---

### `analytics.latest_guild_members_api_cache`

Stores the latest roster per guild.

Grain:

```text
One row per current guild member.
```

Purpose:

- Power the Guild Members table
- Power Analysis by Vocation
- Provide latest current level and last-connected estimate

Important columns:

| Column | Description |
|---|---|
| `character_name` | Character name |
| `vocation` | Current vocation |
| `guild_rank` | Current guild rank |
| `current_level` | Current level |
| `latest_snapshot_time` | Latest roster snapshot time |
| `last_connected_at` | Most recent observed online time or level-change timestamp |

---

## Public API Views

The frontend reads from public API views only.

### Selector and overview views

| View | Purpose |
|---|---|
| `public.api_worlds` | Lists worlds available in the selector |
| `public.api_guilds` | Lists guilds available in the selector |
| `public.api_snapshot_date_bounds_by_guild` | Provides date bounds for filters |
| `public.api_guild_overview_by_snapshot` | Provides snapshot-level guild summary metrics |

### Analytics views

| View | Source cache table |
|---|---|
| `public.api_historical_character_level_changes` | `analytics.character_level_changes_with_online_cache` |
| `public.api_historical_guild_joins` | `analytics.guild_joins_api_cache` |
| `public.api_historical_guild_leaves` | `analytics.guild_leaves_api_cache` |
| `public.api_historical_rank_changes` | `analytics.rank_changes_api_cache` |
| `public.api_latest_guild_members` | `analytics.latest_guild_members_api_cache` |

---

## Current Project-Owned Schemas

The project owns two functional schemas:

| Schema | Purpose |
|---|---|
| `public` | Raw data, metadata, functions, and public API views |
| `analytics` | Precomputed frontend analytics cache tables |

Supabase also creates system schemas such as `auth`, `storage`, `realtime`, `cron`, `net`, `vault`, and `extensions`. Those are platform-managed and should not be treated as project-owned application objects.

---

## Retention

The project uses a scheduled safe-retention function:

```sql
analytics.apply_safe_7_day_snapshot_retention()
```

Retention is handled by a separate Supabase Cron job, not by the ingestion Edge Function.

This reduces long-term storage growth by pruning old raw snapshots, normalized member snapshots, and analytics cache rows while keeping recent history available for the dashboard.

---

## Data Model Summary

The current model is:

```text
raw_guild_snapshot
        ↓
guild_member_snapshot
        ↓
per-guild cache refresh
        ↓
analytics cache tables
        ↓
public API views
        ↓
frontend
```

This design keeps ingestion, history, analytics, and serving responsibilities separated.
