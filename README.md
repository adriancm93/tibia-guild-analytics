# Tibia Guild Analytics

Tibia Guild Analytics is a production-style data engineering project that tracks Tibia guild activity over time and serves a public analytics dashboard.

The platform ingests guild roster snapshots from the TibiaData API, stores raw and parsed historical data in Supabase Postgres, computes per-guild analytics caches, exposes curated public API views through Supabase REST, and serves a static frontend through Cloudflare Pages.

Live site:

```text
https://tibiaguildanalytics.com/
```

Cloudflare Pages preview:

```text
https://tibia-guild-analytics.pages.dev/
```

---

## Project Overview

The project tracks guild-level and character-level activity for Tibia guilds.

Current functionality includes:

- Guild overview metrics
- Analysis by vocation
- Level changes and estimated time online
- Guild joins
- Guild leaves
- Rank changes
- Latest guild roster
- Character search and table sorting
- Date filters by analytics section
- World and guild selectors
- Automated ingestion through Supabase Cron and Supabase Edge Functions
- Per-guild analytics cache refresh for fast dashboard queries

The current production scope is focused on the Lobera world, with all Lobera guilds available through the website selector.

---

## Current Production Architecture

The current production architecture is serverless and low-cost.

```text
TibiaData API
        ↓
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres raw snapshot tables
        ↓
Per-guild analytics cache tables
        ↓
Public Supabase REST API views
        ↓
Cloudflare Pages static frontend
```

### Production Components

| Layer | Technology |
|---|---|
| Source API | TibiaData API |
| Scheduler | Supabase Cron |
| Ingestion worker | Supabase Edge Function |
| Database | Supabase Postgres |
| Raw storage | `public.raw_guild_snapshot` |
| Parsed history | `public.guild_member_snapshot` |
| Metadata / queue | `public.tibia_world`, `public.tibia_guild` |
| Analytics serving layer | `analytics.*_cache` tables |
| API layer | Public Supabase REST views |
| Frontend | Static HTML, CSS, JavaScript |
| Hosting | Cloudflare Pages |
| DNS / custom domain | Cloudflare |

The production website does not require an always-running backend server. The frontend reads from curated Supabase REST API views.

---

## Data Flow

### 1. Scheduled refresh

Supabase Cron triggers the `refresh-guilds` Edge Function on a recurring cadence.

### 2. Guild queue claim

The Edge Function claims due guilds from `public.tibia_guild` using queue-control RPC functions.

### 3. API extraction

For each claimed guild, the Edge Function calls the TibiaData API and retrieves the latest guild roster.

### 4. Raw snapshot storage

The full API payload is stored in:

```text
public.raw_guild_snapshot
```

### 5. Parsed member snapshot storage

Each guild member is parsed into one row per character per snapshot and stored in:

```text
public.guild_member_snapshot
```

### 6. Per-guild analytics cache refresh

After a guild is successfully ingested, the Edge Function calls:

```text
public.refresh_frontend_analytics_for_guild(world, guild_name)
```

That function rebuilds only that guild’s frontend analytics cache rows.

### 7. Public API views

The frontend reads from public views in the `public` schema. These views sit on top of precomputed cache tables and are optimized for dashboard queries.

---

## Current Database Model

### Core source tables

| Object | Purpose |
|---|---|
| `public.raw_guild_snapshot` | Stores raw TibiaData guild API responses |
| `public.guild_member_snapshot` | Stores parsed member rows per snapshot |
| `public.tibia_world` | Stores world metadata |
| `public.tibia_guild` | Stores guild metadata, refresh status, and queue timestamps |

### Analytics cache tables

| Object | Purpose |
|---|---|
| `analytics.snapshot_pairs_api_cache` | Consecutive snapshot pairs per guild |
| `analytics.character_estimated_online_minutes_cache` | Estimated online minutes per character |
| `analytics.character_level_changes_with_online_cache` | Level changes enriched with time-online metrics |
| `analytics.guild_joins_api_cache` | Guild join events |
| `analytics.guild_leaves_api_cache` | Guild leave events |
| `analytics.rank_changes_api_cache` | Rank change events |
| `analytics.latest_guild_members_api_cache` | Latest roster with last-connected estimate |

### Public API views used by the frontend

| View | Purpose |
|---|---|
| `public.api_worlds` | World selector |
| `public.api_guilds` | Guild selector |
| `public.api_snapshot_date_bounds_by_guild` | Date filter bounds |
| `public.api_guild_overview_by_snapshot` | Guild overview metrics by snapshot |
| `public.api_historical_character_level_changes` | Level changes and time online |
| `public.api_historical_guild_joins` | Guild joins |
| `public.api_historical_guild_leaves` | Guild leaves |
| `public.api_historical_rank_changes` | Rank changes |
| `public.api_latest_guild_members` | Latest guild roster |

### RPC functions used by the Edge Function

| Function | Purpose |
|---|---|
| `public.claim_due_guild_refresh_batch` | Claims due guilds for refresh |
| `public.mark_guild_refresh_success` | Marks a guild refresh as successful |
| `public.mark_guild_refresh_failure` | Marks a guild refresh as failed |
| `public.release_stale_running_guild_refreshes` | Releases stale running guild claims |
| `public.apply_snapshot_retention` | Deletes snapshots outside the retention window |
| `public.refresh_frontend_analytics_for_guild` | Rebuilds frontend cache rows for one guild |

---

## Dashboard Features

The dashboard is organized into tabs below the guild overview section.

### Guild Overview

Displays current summary metrics for the selected world and guild:

- Latest refresh age
- Member count
- Maximum level
- Minimum level
- Average level

### Analysis by Vocation

Shows a vocation distribution chart and roster table for the selected guild.

Features:

- Level range filter
- Base vocation normalization
- Multi-select vocation filter
- Sortable character table

Promoted and non-promoted vocations are grouped into base vocations:

| Source vocations | Base vocation |
|---|---|
| Monk variants | Monk |
| Knight / Elite Knight | Knight |
| Paladin / Royal Paladin | Paladin |
| Druid / Elder Druid | Druid |
| Sorcerer / Master Sorcerer | Sorcerer |

### Level Changes and Time Online

Shows character level changes within a selected date range.

Includes:

- Character
- Vocation
- Guild rank
- Previous level
- Current level
- Level gain
- Estimated time online

### Guild Joins / Leaves

Shows detected guild join and leave events based on consecutive roster snapshots.

### Rank Changes

Shows detected rank changes and the date the change was observed.

### Guild Members

Shows the latest roster for the selected guild.

Includes:

- Character
- Vocation
- Guild rank
- Current level
- Last connected estimate

---

## Repository Structure

```text
tibia-guild-analytics/
├── .github/
│   └── workflows/
├── archive/
│   ├── legacy_backend/
│   └── legacy_orchestration/
├── data/
├── database/
│   ├── archive/
│   ├── cleanup/
│   ├── init/
│   └── validation/
├── docs/
├── frontend/
├── ingestion/
│   └── src/
├── supabase/
│   └── functions/
│       └── refresh-guilds/
├── docker-compose.yml
└── README.md
```

### Main folders

| Folder | Purpose |
|---|---|
| `.github/workflows` | Manual fallback workflows |
| `archive` | Legacy application components preserved for reference |
| `data` | Local/generated raw data area |
| `database/init` | Current database build scripts |
| `database/archive` | Historical SQL scripts from earlier project phases |
| `database/cleanup` | One-time database cleanup scripts |
| `database/validation` | Validation SQL queries |
| `docs` | Architecture notes and learning documentation |
| `frontend` | Current production static dashboard |
| `ingestion` | Local/manual Python utilities for extraction and metadata discovery |
| `supabase/functions` | Production Supabase Edge Functions |

---

## Local Frontend Development

The frontend is a static HTML/CSS/JavaScript application.

From the project root:

```bash
cd frontend
python3 -m http.server 3000
```

Open:

```text
http://127.0.0.1:3000
```

The frontend uses `frontend/config.js` for Supabase configuration.

Do not commit real secrets. The browser should only use the Supabase anon/public key, never the Supabase secret key.

---

## Supabase Environment

For local administrative SQL work, create a local `.env.supabase` file.

Example:

```bash
POSTGRES_HOST=<supabase-db-host>
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=<supabase-db-user>
POSTGRES_PASSWORD=<supabase-db-password>
```

Load it in a terminal:

```bash
set -a
source .env.supabase
set +a
```

Do not commit `.env`, `.env.supabase`, or any secret-bearing file.

---

## Supabase Edge Function

The production ingestion worker is:

```text
supabase/functions/refresh-guilds/index.ts
```

It is responsible for:

1. Authenticating scheduled requests with `x-cron-secret`.
2. Claiming due guilds.
3. Fetching guild data from TibiaData.
4. Inserting raw and parsed snapshots.
5. Refreshing per-guild frontend analytics cache tables.
6. Updating refresh status.
7. Applying retention.

Deploy:

```bash
supabase functions deploy refresh-guilds --no-verify-jwt
```

Manual test:

```bash
curl -i \
  -X POST "https://<project-ref>.supabase.co/functions/v1/refresh-guilds" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <secret>" \
  -d '{"world":"Lobera","batch_size":5}'
```

---

## Database Initialization

Current active SQL scripts live in:

```text
database/init/
```

These scripts represent the current schema and serving architecture.

Legacy SQL scripts are kept in:

```text
database/archive/
```

One-time cleanup scripts are kept in:

```text
database/cleanup/
```

Validation scripts are kept in:

```text
database/validation/
```

---

## Local Docker

The repository includes a Docker Compose file for local Postgres development.

```bash
docker compose up -d
```

Production does not depend on the local Docker stack. Production uses Supabase Postgres.

---

## Manual / Legacy Components

The `archive/` folder contains earlier architecture components that are no longer part of production.

Examples:

- `archive/legacy_backend`: earlier FastAPI backend
- `archive/legacy_orchestration`: earlier local pipeline runner

These are preserved for learning context but are not used by the current production deployment.

---

## Portfolio Highlights

This project demonstrates:

- External API ingestion
- Raw and parsed data storage design
- Snapshot-based historical tracking
- Queue-based refresh orchestration
- Supabase Edge Function ingestion
- Supabase Cron scheduling
- PostgreSQL relational modeling
- Incremental per-guild analytics cache refresh
- Public API view design
- Static frontend deployment
- Cloudflare Pages hosting
- Secret management
- Retention policy design
- Performance optimization through precomputed cache tables

---

## Future Improvements

Potential next enhancements:

- Add more worlds beyond Lobera
- Add trend charts for member count and average level
- Add historical vocation distribution over time
- Add cache freshness monitoring
- Add automated database validation in CI
- Add screenshots and architecture diagrams
- Add error alerting for failed guild refreshes
- Add incremental cache refresh metrics
