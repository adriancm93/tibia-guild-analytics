# Tibia Guild Analytics

A production-style data engineering project that collects Tibia guild data, stores historical snapshots in PostgreSQL, models guild activity with SQL analytics views, refreshes the data automatically, and serves a public dashboard through a static frontend website.

Live site:

```text
https://tibia-guild-analytics.pages.dev/
```

Custom domain:

```text
https://tibiaguildanalytics.com/
```

> The custom domain may take time to fully propagate after registration.

---

## Project Overview

This project tracks guild activity over time for a Tibia guild. It extracts guild member data on a recurring schedule, stores both raw and parsed historical snapshots, and exposes analytics for level progression, guild joins, guild leaves, rank changes, and guild-level summary metrics.

The project is designed to demonstrate an end-to-end data engineering workflow:

```text
Data extraction
        ↓
Raw snapshot storage
        ↓
Parsed relational tables
        ↓
SQL staging and analytics views
        ↓
Automated scheduled refresh
        ↓
Public frontend dashboard
```

---

## Current Production Architecture

The low-cost production deployment uses:

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

### Production Components

| Layer | Technology |
|---|---|
| Data source | TibiaData API |
| Ingestion | Python |
| Database | Supabase Postgres |
| Transformations | SQL views |
| Scheduled refresh | GitHub Actions |
| Frontend | HTML, CSS, JavaScript |
| Hosting | Cloudflare Pages |
| API access | Supabase REST API |

The production website does **not** require an always-running backend server. The frontend reads from curated public API views exposed through Supabase REST.

---

## Dashboard Features

The dashboard currently includes:

- Guild overview metrics
- Latest refresh timestamp
- Number of members
- Maximum member level
- Minimum member level
- Average member level
- Historical character level changes
- Guild joins
- Guild leaves
- Rank changes
- Independent date filters for each analytics section
- Sortable analytics tables

---

## Automated Refresh

The production pipeline runs through GitHub Actions on a scheduled workflow.

Current cadence:

```text
Every 15 minutes
```

The workflow:

1. Checks out the repository.
2. Sets up Python.
3. Installs ingestion dependencies.
4. Extracts the latest guild data.
5. Loads the snapshot into Supabase Postgres.

Workflow file:

```text
.github/workflows/scheduled_ingestion.yml
```

---

## Data Model

The database stores both raw snapshots and parsed member-level history.

### Core Tables

```text
raw_guild_snapshot
guild_member_snapshot
```

### Main Concepts

| Object | Purpose |
|---|---|
| `raw_guild_snapshot` | Stores one raw guild snapshot per extraction run |
| `guild_member_snapshot` | Stores one row per guild member per snapshot |
| Staging views | Standardize raw/parsed fields for downstream analytics |
| Analytics views | Compare snapshots and calculate guild activity |
| Public API views | Expose curated read-only data to the frontend |

---

## Analytics Views

The analytics layer supports both latest-snapshot comparisons and historical date-range analysis.

Examples:

```text
analytics.historical_character_level_changes
analytics.historical_guild_joins
analytics.historical_guild_leaves
analytics.historical_rank_changes
```

Public API-facing views are exposed from the `public` schema for Supabase REST access.

Examples:

```text
public.api_guild_overview_by_snapshot
public.api_historical_character_level_changes
public.api_historical_guild_joins
public.api_historical_guild_leaves
public.api_historical_rank_changes
public.api_snapshot_date_bounds
```

---

## Repository Structure

```text
tibia-guild-analytics/
├── .github/
│   └── workflows/
│       └── scheduled_ingestion.yml
├── backend/
│   └── app/
├── database/
│   ├── init/
│   └── validation/
├── docs/
├── frontend/
├── ingestion/
│   └── src/
├── orchestration/
├── docker-compose.yml
└── README.md
```

### Main Folders

| Folder | Purpose |
|---|---|
| `.github/workflows` | Scheduled production ingestion workflow |
| `database/init` | SQL schema, staging views, analytics views, and public API views |
| `database/validation` | SQL validation checks |
| `frontend` | Static production website |
| `ingestion/src` | Python extraction and loading scripts |
| `orchestration` | Local pipeline runner |
| `backend` | Optional local FastAPI API layer used during development |
| `docs` | Architecture and operational documentation |

---

## Local Development

### 1. Clone the repository

```bash
git clone https://github.com/adriancm93/tibia-guild-analytics.git
cd tibia-guild-analytics
```

### 2. Create local environment files

Create a local `.env` file from the example:

```bash
cp .env.example .env
```

Example variables:

```env
TIBIA_GUILD_NAME="Black Clover"
TIBIA_WORLD=Lobera
RAW_DATA_DIR=data/raw

POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=tibia_analytics
POSTGRES_USER=tibia_user
POSTGRES_PASSWORD=tibia_password
```

Do not commit real environment files.

---

## Run the Local Docker Stack

The repository includes a local Docker Compose stack for development.

```bash
docker compose up --build
```

Local services:

```text
Frontend: http://localhost:3000
Backend:  http://localhost:8000/docs
Postgres: localhost:5432
```

The local Docker stack is useful for development and testing. The production deployment uses Supabase and Cloudflare Pages.

---

## Run the Ingestion Pipeline Locally

Create and activate the ingestion virtual environment:

```bash
python3 -m venv ingestion/.venv
source ingestion/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r ingestion/requirements.txt
```

Run extraction:

```bash
python ingestion/src/main.py
```

Load the latest snapshot:

```bash
python ingestion/src/load_postgres.py
```

Run the local orchestration script:

```bash
python orchestration/run_pipeline.py
```

---

## Supabase Production Connection

Production data is stored in Supabase Postgres.

For local testing against Supabase, create a local file named:

```text
.env.supabase
```

Do not commit this file.

Example format:

```env
TIBIA_GUILD_NAME="Black Clover"
TIBIA_WORLD=Lobera
RAW_DATA_DIR=data/raw

POSTGRES_HOST=<supabase-host>
POSTGRES_PORT=<supabase-port>
POSTGRES_DB=postgres
POSTGRES_USER=<supabase-user>
POSTGRES_PASSWORD=<supabase-password>
```

To export these variables in the terminal:

```bash
set -a
source .env.supabase
set +a
```

---

## Deployment

### Production Deployment

| Component | Deployment |
|---|---|
| Database | Supabase Postgres |
| Scheduled refresh | GitHub Actions |
| Frontend | Cloudflare Pages |
| Custom domain | Cloudflare DNS / Registrar |

### Frontend Hosting

The frontend is deployed from:

```text
frontend/
```

Cloudflare Pages serves the static site and automatically redeploys after pushes to the main branch.

### Database Refresh

GitHub Actions runs the ingestion workflow on a schedule and loads new snapshots into Supabase.

---

## Optional Local FastAPI Backend

The repository includes a FastAPI backend used during local development and earlier architecture exploration.

The production deployment currently uses Supabase REST API directly to minimize hosting cost and avoid an always-running backend service.

Run locally:

```bash
source backend/.venv/bin/activate
uvicorn app.main:app --reload --app-dir backend
```

API docs:

```text
http://127.0.0.1:8000/docs
```

---

## Validation

Database validation scripts are stored in:

```text
database/validation/
```

Example validation checks include:

- Snapshot counts
- Parsed member counts
- Latest snapshot comparison checks
- Historical analytics checks

---

## Portfolio Highlights

This project demonstrates:

- Python data ingestion from an external API
- Raw and parsed data storage design
- PostgreSQL relational modeling
- SQL staging and analytics views
- Historical snapshot comparison logic
- Scheduled cloud-based data refresh
- Supabase-hosted production database
- Public REST API exposure through curated database views
- Static frontend deployment through Cloudflare Pages
- Environment variable and secret management
- Local Docker-based development workflow

---

## Future Improvements

Planned or potential enhancements:

- Add guild and world selector filters
- Support multiple guilds and worlds
- Add charts for level progression and member trends
- Add richer historical summary metrics
- Improve frontend UX and mobile layout
- Add automated SQL validation to GitHub Actions
- Add monitoring for failed ingestion runs
- Add project architecture diagram
- Add screenshots to documentation