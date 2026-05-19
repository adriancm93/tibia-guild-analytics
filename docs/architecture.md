# Architecture

This document describes the current production architecture for the Tibia Guild Analytics project.

## Overview

Tibia Guild Analytics is an end-to-end data engineering project that collects Tibia guild data, stores historical snapshots, models analytics in PostgreSQL, and serves a public dashboard through a static frontend website.

The current production architecture is designed to be low-cost and portfolio-friendly.

```text
GitHub Actions
        ↓
Python ingestion pipeline
        ↓
Supabase Postgres
        ↓
Supabase REST API
        ↓
Cloudflare Pages frontend
```

## Production Architecture

```text
GitHub Repository
        |
        | scheduled workflow
        v
GitHub Actions
        |
        | runs Python extraction/loading
        v
Python Ingestion Pipeline
        |
        | inserts raw and parsed snapshots
        v
Supabase Postgres
        |
        | exposes curated public views
        v
Supabase REST API
        |
        | browser requests
        v
Cloudflare Pages Frontend
```

## Main Components

| Component | Technology | Purpose |
|---|---|---|
| Data source | TibiaData API | Provides guild and character data |
| Ingestion | Python | Extracts guild data and loads snapshots |
| Database | Supabase Postgres | Stores raw and parsed historical data |
| Transformations | SQL views | Creates staging, analytics, and API-facing views |
| Scheduler | GitHub Actions | Runs ingestion automatically every 15 minutes |
| API layer | Supabase REST API | Exposes selected public views to the frontend |
| Frontend | HTML, CSS, JavaScript | Displays guild analytics dashboard |
| Hosting | Cloudflare Pages | Hosts the public static website |
| Domain | Cloudflare Registrar/DNS | Manages the custom project domain |

## Data Flow

### 1. Scheduled Ingestion

GitHub Actions runs the ingestion workflow on a schedule.

Workflow file:

```text
.github/workflows/scheduled_ingestion.yml
```

Current cadence:

```text
Every 15 minutes
```

The workflow:

1. Checks out the repository.
2. Sets up Python.
3. Installs lightweight ingestion dependencies.
4. Runs the extraction script.
5. Loads the latest snapshot into Supabase Postgres.

### 2. Data Extraction

The Python ingestion layer extracts guild data from TibiaData.

Main ingestion files:

```text
ingestion/src/main.py
ingestion/src/extract_guild.py
ingestion/src/extract_characters.py
ingestion/src/tibiadata_client.py
ingestion/src/load_postgres.py
```

The extraction process writes raw data locally during execution, then the loader persists the data to Supabase Postgres.

### 3. Database Storage

Supabase Postgres stores two main persistence layers:

```text
raw_guild_snapshot
guild_member_snapshot
```

`raw_guild_snapshot` stores one row per extraction run.

`guild_member_snapshot` stores one row per guild member per extraction run.

This structure allows the project to track historical changes over time.

### 4. SQL Modeling

The database contains SQL views for:

```text
staging
analytics
public API access
```

The staging views standardize and clean fields.

The analytics views compare snapshots and calculate guild activity.

The public API views expose curated read-only results for the frontend through Supabase REST.

### 5. Public API Access

The production frontend does not use a custom backend server.

Instead, it reads from Supabase REST API endpoints that are backed by public API views.

Example API-facing views:

```text
public.api_guild_overview_by_snapshot
public.api_historical_character_level_changes
public.api_historical_guild_joins
public.api_historical_guild_leaves
public.api_historical_rank_changes
public.api_snapshot_date_bounds
```

Only curated read-only views are exposed to the frontend.

The raw tables are not intended for direct public frontend access.

### 6. Frontend Hosting

The frontend is a static website built with:

```text
HTML
CSS
JavaScript
```

Frontend files:

```text
frontend/index.html
frontend/styles.css
frontend/app.js
frontend/config.js
```

Cloudflare Pages deploys the frontend from the `frontend/` folder and automatically redeploys after pushes to the main branch.

## Production URLs

Primary Cloudflare Pages URL:

```text
https://tibia-guild-analytics.pages.dev/
```

Custom domain:

```text
https://tibiaguildanalytics.com/
```

## Why This Architecture

The project originally explored a more traditional backend API architecture with FastAPI. That backend still exists in the repository for local development and architecture exploration.

However, the production version uses Supabase REST API directly because it reduces cost and complexity.

This avoids the need for:

```text
Always-running backend server
Managed application hosting
Dedicated API infrastructure
```

The resulting production system is:

```text
Low cost
Simple to operate
Easy to deploy
Appropriate for a portfolio project
```

## Local Development Architecture

For local development, the project can also run with Docker Compose.

```text
Docker Compose
        ↓
Local Postgres
FastAPI backend
Static frontend
```

Local URLs:

```text
Frontend: http://localhost:3000
Backend:  http://localhost:8000/docs
Postgres: localhost:5432
```

The local FastAPI backend is optional and is not required for the production deployment.

## Environment Strategy

Local development uses `.env`.

Supabase testing can use `.env.supabase`.

Production secrets are stored in GitHub repository secrets.

Important production secrets include:

```text
SUPABASE_DB_HOST
SUPABASE_DB_PORT
SUPABASE_DB_NAME
SUPABASE_DB_USER
SUPABASE_DB_PASSWORD
TIBIA_GUILD_NAME
TIBIA_WORLD
```

Environment files containing real credentials are not committed to GitHub.

## Cost Profile

The current production architecture is designed to keep operating costs near zero.

| Component | Cost expectation |
|---|---|
| Cloudflare Pages | Free tier |
| GitHub Actions scheduled ingestion | Free tier for this usage level |
| Supabase Postgres | Free tier initially |
| Supabase REST API | Included with Supabase |
| Custom domain | Annual domain registration cost |

The main recurring paid cost is the optional custom domain.

## Future Architecture Improvements

Potential future improvements include:

```text
Support multiple guilds and worlds
Add a guild/world selector to the frontend
Add richer historical trend charts
Add automated validation checks to GitHub Actions
Add alerting for failed ingestion runs
Add monitoring for stale snapshots
Move production secrets to a dedicated secrets manager if needed
Reintroduce a backend API if business logic becomes more complex
```