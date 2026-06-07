# Architecture

This document describes the current production architecture for Tibia Guild Analytics.

Tibia Guild Analytics is a serverless-style data engineering project that ingests Tibia guild roster data, stores historical snapshots, computes per-guild analytics caches, exposes curated Supabase REST API views, and serves a static dashboard through Cloudflare Pages.

---

## High-Level Architecture

```text
TibiaData API
        ↓
Supabase Cron
        ↓
Supabase Edge Function: refresh-guilds
        ↓
Supabase Postgres
        ↓
Raw and parsed snapshot tables
        ↓
Per-guild analytics cache tables
        ↓
Public Supabase REST API views
        ↓
Cloudflare Pages static frontend
```

The production system does not require an always-running application server. The frontend is static and reads from Supabase REST API views. The ingestion workload is handled by a Supabase Edge Function triggered by Supabase Cron.

---

## Production Components

| Component | Technology | Responsibility |
|---|---|---|
| Source API | TibiaData API | Provides current guild roster payloads |
| Scheduler | Supabase Cron | Triggers recurring ingestion runs |
| Ingestion worker | Supabase Edge Function | Claims due guilds, calls TibiaData, writes snapshots, refreshes caches |
| Database | Supabase Postgres | Stores raw snapshots, parsed history, metadata, and analytics caches |
| API layer | Supabase REST over public views | Serves curated, frontend-ready datasets |
| Frontend | Static HTML/CSS/JavaScript | Renders the public dashboard |
| Hosting | Cloudflare Pages | Hosts the static website |
| DNS | Cloudflare | Routes custom domain traffic |

---

## Current Data Flow

### 1. Supabase Cron triggers ingestion

Supabase Cron calls the deployed Edge Function:

```text
/functions/v1/refresh-guilds
```

The request includes:

```json
{
  "world": "Lobera",
  "batch_size": 50
}
```

The function is protected with an `x-cron-secret` header. This avoids exposing the ingestion endpoint publicly without authorization.

---

### 2. The Edge Function claims due guilds

The function calls:

```sql
public.claim_due_guild_refresh_batch(p_world, p_batch_size)
```

This function selects guilds that are due for refresh and marks them as running. This prevents overlapping workers from refreshing the same guild at the same time.

The refresh queue is stored in:

```text
public.tibia_guild
```

Important queue/status columns include:

- `last_refresh_status`
- `last_refresh_started_at_utc`
- `last_refresh_completed_at_utc`
- `next_refresh_after_utc`
- `last_refresh_error`

---

### 3. The Edge Function fetches guild data

For each claimed guild, the Edge Function calls the TibiaData guild endpoint and receives the latest guild roster.

The full payload is stored in:

```text
public.raw_guild_snapshot
```

This preserves the raw API response for lineage, debugging, and future reprocessing.

---

### 4. Parsed member rows are inserted

The Edge Function parses member-level fields into:

```text
public.guild_member_snapshot
```

This table stores one row per character per guild snapshot.

Typical fields include:

- `snapshot_id`
- `extracted_at_utc`
- `guild_name`
- `world`
- `character_name`
- `guild_rank`
- `vocation`
- `level`
- `status`
- `joined`

This table is the historical fact table for the project.

---

### 5. Per-guild analytics cache refresh

After a guild is successfully ingested, the Edge Function calls:

```sql
public.refresh_frontend_analytics_for_guild(p_world, p_guild_name)
```

This function rebuilds analytics cache rows only for the refreshed guild.

That function populates:

- `analytics.snapshot_pairs_api_cache`
- `analytics.character_estimated_online_minutes_cache`
- `analytics.character_level_changes_with_online_cache`
- `analytics.guild_joins_api_cache`
- `analytics.guild_leaves_api_cache`
- `analytics.rank_changes_api_cache`
- `analytics.latest_guild_members_api_cache`

This is the key performance design in the current architecture.

---

## Why Per-Guild Cache Tables Are Used

Earlier versions of the project used dynamic analytics views and then global materialized views. That worked at smaller scale, but as snapshot volume increased, dashboard queries and global refreshes became too expensive.

The current design uses per-guild cache tables because the ingestion worker refreshes one batch of guilds at a time. After a guild is ingested, only that guild’s analytics need to be rebuilt.

This provides three benefits:

1. **Fast frontend reads**  
   The dashboard reads from precomputed cache tables through public API views.

2. **Smaller refresh workload**  
   Refreshing one guild is significantly cheaper than recomputing analytics for every guild.

3. **Better operational isolation**  
   A refresh problem with one guild does not require rebuilding the entire analytics layer.

---

## Public API Views

The frontend reads only from public API views:

| View | Purpose |
|---|---|
| `public.api_worlds` | World selector |
| `public.api_guilds` | Guild selector |
| `public.api_snapshot_date_bounds_by_guild` | Date filter bounds |
| `public.api_guild_overview_by_snapshot` | Guild overview metrics |
| `public.api_historical_character_level_changes` | Level changes and time online |
| `public.api_historical_guild_joins` | Guild join events |
| `public.api_historical_guild_leaves` | Guild leave events |
| `public.api_historical_rank_changes` | Rank change events |
| `public.api_latest_guild_members` | Latest roster and last-connected estimate |

The frontend does not query raw tables directly. Public API views provide a stable contract between the database and the UI.

---

## Frontend Architecture

The frontend is a static application in:

```text
frontend/
```

It uses:

- `index.html` for layout
- `styles.css` for visual styling
- `app.js` for data fetching, state management, sorting, filtering, and rendering
- `config.js` for runtime Supabase configuration

The dashboard contains:

- Guild Overview
- Analysis by Vocation
- Level Changes and Time Online
- Guild Joins / Leaves
- Rank Changes
- Guild Members

The Guild Overview remains visible at the top. Analytical sections are organized into tabs below the overview.

---

## Legacy Components

The repository keeps earlier architecture components in:

```text
archive/
```

Examples:

- `archive/legacy_backend`: earlier FastAPI backend
- `archive/legacy_orchestration`: earlier local orchestration runner

These are retained for project history and learning context but are not part of production.

---

## Current Production Pattern

The final architecture is best described as:

```text
scheduled serverless ingestion
+ Postgres historical fact storage
+ per-guild analytics cache refresh
+ public SQL API views
+ static frontend
```

This is a professional, cost-conscious pattern for a small analytics product that still demonstrates production data engineering concepts.
