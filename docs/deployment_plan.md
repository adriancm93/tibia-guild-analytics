# Low-Cost Deployment Plan

This document describes the low-cost production deployment architecture for the Tibia Guild Analytics project.

## Project Goal

Host a public website that displays Tibia guild analytics and refreshes the underlying data once every hour.

The website should show analytics such as:

```text
Snapshot summary
Character level changes
Guild joins
Guild leaves
Rank changes
```

## Target Architecture

```text
GitHub Repository
        |
        | hosts source code
        |
        +-----------------------------+
        |                             |
        v                             v
GitHub Pages / Cloudflare Pages       GitHub Actions scheduled workflow
        |                             |
        | serves static frontend       | runs once every hour
        v                             v
HTML / CSS / JavaScript Website       Python ingestion pipeline
        |                             |
        | reads analytics data         | writes latest snapshot
        v                             v
Supabase API / PostgREST --------> Supabase Postgres
```

## Production Services

### Frontend Hosting

Recommended options:

```text
GitHub Pages
Cloudflare Pages
```

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

The frontend will be publicly hosted and will read analytics data from Supabase.

## Database

Recommended service:

```text
Supabase Postgres
```

Supabase provides a hosted PostgreSQL database that can store the same tables and views currently used locally.

Current local database:

```text
PostgreSQL
Database: tibia_analytics
```

Production database:

```text
Supabase Postgres
```

Database scripts:

```text
database/init/001_create_tables.sql
database/init/002_add_snapshot_unique_constraints.sql
database/init/003_create_staging_views.sql
database/init/004_create_analytics_views.sql
database/init/005_create_snapshot_comparison_views.sql
```

Validation scripts:

```text
database/validation/001_validate_guild_snapshot_pipeline.sql
database/validation/validate_phase_4_analytics_views.sql
```

## Backend Strategy

For the low-cost production version, the FastAPI backend will not be required initially.

Current local backend:

```text
FastAPI
```

Production approach:

```text
Frontend JavaScript reads from Supabase API
```

This removes the need for an always-running backend server and keeps hosting costs lower.

The FastAPI backend can still remain in the repository as a local API layer and as evidence of backend experience.

## Hourly Data Refresh

The project should retrieve and load new guild data once every hour.

Recommended service:

```text
GitHub Actions scheduled workflow
```

Target cadence:

```text
once every hour
```

The scheduled workflow should run the equivalent of the local pipeline:

```text
1. Extract latest Tibia guild data
2. Load latest snapshot into Supabase Postgres
3. Refresh or rely on analytics views
4. Optionally run validation checks
```

Current local orchestration script:

```text
orchestration/run_pipeline.py
```

For production, this may need a GitHub Actions-specific pipeline command that does not depend on local Docker.

## Important Production Difference

The local pipeline currently connects to local Docker Postgres:

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

The GitHub Actions production pipeline will connect to Supabase Postgres using secrets:

```env
POSTGRES_HOST=<supabase-db-host>
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=<supabase-user>
POSTGRES_PASSWORD=<supabase-password>
```

These values should be stored as GitHub repository secrets, not committed to GitHub.

## GitHub Secrets

The GitHub Actions workflow should use repository secrets such as:

```text
SUPABASE_DB_HOST
SUPABASE_DB_PORT
SUPABASE_DB_NAME
SUPABASE_DB_USER
SUPABASE_DB_PASSWORD
TIBIA_GUILD_NAME
TIBIA_WORLD
```

The real values should never be committed.

## Frontend Data Access

The frontend can read from Supabase in one of two ways.

### Option A — Use Supabase REST API

The frontend calls Supabase-generated REST endpoints for tables/views.

This is the lowest-cost and simplest production option.

### Option B — Use Supabase JavaScript Client

The frontend uses the Supabase JavaScript client library.

This is more flexible, but adds an external dependency to the frontend.

## Recommended First Version

Use:

```text
Frontend hosting: GitHub Pages or Cloudflare Pages
Database: Supabase Postgres
Hourly refresh: GitHub Actions
Frontend data access: Supabase REST API
Backend: skip production FastAPI for now
```

## Deployment Phases

### Phase 11 — Create Supabase Postgres database

Tasks:

```text
Create Supabase project
Create database password
Get database connection details
Store credentials locally in .env for testing
Do not commit credentials
```

### Phase 12 — Prepare SQL scripts for Supabase

Tasks:

```text
Review local SQL scripts for Supabase compatibility
Apply schema scripts to Supabase
Apply staging and analytics views
Run validation checks
Confirm data can be loaded
```

### Phase 13 — Configure GitHub Actions hourly ingestion

Tasks:

```text
Create GitHub Actions workflow
Store Supabase credentials as GitHub secrets
Run ingestion pipeline on schedule
Run workflow manually for testing
Confirm new snapshots appear in Supabase
```

### Phase 14 — Host frontend

Tasks:

```text
Choose GitHub Pages or Cloudflare Pages
Deploy frontend folder
Configure frontend Supabase API URL
Confirm website loads production data
```

### Phase 15 — Optional custom domain

Tasks:

```text
Choose domain
Buy domain
Point domain to frontend hosting
Configure HTTPS
Update project README with public URL
```

## Cost Target

The target cost for the first production version is:

```text
$0/month for hosting and refresh infrastructure
Optional domain: approximately $12–$20 per year
```

Potential future cost:

```text
Supabase paid tier if the project exceeds free tier limits
```

## Main Tradeoff

This low-cost architecture reduces or removes the need for:

```text
Always-running backend service
Managed cloud app server
Managed AWS RDS instance
```

The tradeoff is that the production frontend depends more directly on Supabase.

This is acceptable for the first public portfolio version because the main project value is the data engineering pipeline, database modeling, hourly refresh, and public visualization.
