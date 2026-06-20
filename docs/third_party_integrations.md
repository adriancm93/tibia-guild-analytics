# Third-Party Integrations

This project uses a serverless, low-cost production architecture built around Supabase, TibiaData, Cloudflare Pages, and a static frontend.

## Integration overview

```text
TibiaData API
    ↓
Supabase Edge Function: refresh-guilds
    ↓
Supabase Postgres
    ↓
Supabase Cron incremental processors
    ↓
public.api_* REST views
    ↓
Static frontend
    ↓
Cloudflare Pages + custom domain
```

## TibiaData API

TibiaData is the external data source for Tibia guild roster information.

The production ingestion flow calls TibiaData from the Supabase Edge Function and stores each response in two forms:

- Raw API snapshot: `public.raw_guild_snapshot`
- Normalized member rows: `public.guild_member_snapshot`

The raw snapshot is kept for traceability and debugging. The normalized table powers analytics and frontend-facing API views.

## Supabase Edge Functions

The production ingestion runtime is:

```text
supabase/functions/refresh-guilds/index.ts
```

The Edge Function is intentionally ingestion-only.

It is responsible for:

- Validating the cron secret
- Claiming due guilds from `public.tibia_guild`
- Fetching guild data from TibiaData
- Inserting raw guild snapshots
- Inserting normalized guild member snapshots
- Marking each guild refresh as success or failure

It does not rebuild analytics directly. Analytics are handled asynchronously by database cron jobs.

## Supabase Postgres

Supabase Postgres is the system of record.

Core production tables:

| Object | Purpose |
|---|---|
| `public.tibia_world` | Tracks Tibia worlds available to the app |
| `public.tibia_guild` | Guild refresh queue and metadata |
| `public.raw_guild_snapshot` | Raw TibiaData API responses |
| `public.guild_member_snapshot` | Normalized guild roster snapshots |

Analytics tables live under the `analytics` schema and are populated incrementally.

## Supabase Cron

Supabase Cron coordinates production scheduling.

Current production jobs:

| Job | Purpose |
|---|---|
| `refresh-lobera-guilds-every-5-minutes` | Calls the ingestion Edge Function |
| `tga_incremental_online_activity_every_5_minutes` | Processes online activity deltas |
| `tga_incremental_general_analytics_every_5_minutes` | Processes level changes, joins, leaves, rank changes, and latest roster cache |
| `tga_safe_7_day_snapshot_retention` | Applies safe snapshot retention |

The ingestion job only loads data. The analytics jobs process new snapshot pairs independently.

## Supabase REST API

The frontend reads from public API views exposed by Supabase PostgREST.

Important views include:

| View | Purpose |
|---|---|
| `public.api_worlds` | Active worlds |
| `public.api_guilds` | Active guilds and refresh status |
| `public.api_latest_guild_members` | Latest roster per guild |
| `public.api_historical_character_level_changes` | Historical level changes |
| `public.api_historical_guild_joins` | Guild joins |
| `public.api_historical_guild_leaves` | Guild leaves |
| `public.api_historical_rank_changes` | Rank changes |
| `public.api_character_online_intervals` | Online interval estimates |
| `public.api_character_online_minutes_by_day` | Daily online time estimates |
| `public.api_snapshot_date_bounds_by_guild` | Date ranges available per guild |

## Cloudflare Pages

The frontend is hosted as a static site through Cloudflare Pages.

Cloudflare provides:

- Static frontend hosting
- Preview deployments
- Custom domain management
- DNS management

The production domain points to the Cloudflare Pages deployment.

## Frontend

The frontend is a static HTML/CSS/JavaScript app located in:

```text
frontend/
```

It calls Supabase REST endpoints directly through the configured Supabase URL and anon key.

The frontend does not run a custom backend server. Supabase Postgres views act as the API layer.
