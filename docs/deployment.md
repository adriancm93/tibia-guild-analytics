# Deployment Guide

This document describes how the Tibia Guild Analytics project is deployed.

The current production deployment uses a low-cost architecture:

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

---

## Production Services

| Layer | Service |
|---|---|
| Database | Supabase Postgres |
| Scheduled ingestion | GitHub Actions |
| Frontend hosting | Cloudflare Pages |
| Public API access | Supabase REST API |
| Custom domain | Cloudflare Registrar / DNS |

---

## Production URLs

Cloudflare Pages URL:

```text
https://tibia-guild-analytics.pages.dev/
```

Custom domain:

```text
https://tibiaguildanalytics.com/
```

---

## 1. Supabase Setup

Supabase is used as the production PostgreSQL database.

### Required Supabase Details

From the Supabase project dashboard, collect:

```text
Database host
Database port
Database name
Database user
Database password
Project URL
Anon / publishable API key
```

The database credentials are used by GitHub Actions to load data.

The project URL and anon key are used by the frontend to read public API views.

---

## 2. Apply Database Scripts to Supabase

Database setup scripts are stored in:

```text
database/init/
```

To apply a script to Supabase from your local machine:

```bash
set -a
source .env.supabase
set +a

docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  < database/init/YOUR_SCRIPT.sql
```

Example:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  < database/init/010_create_guild_overview_api_view.sql
```

---

## 3. GitHub Actions Scheduled Ingestion

The production ingestion job is defined in:

```text
.github/workflows/scheduled_ingestion.yml
```

The workflow runs on a schedule and can also be triggered manually.

Current cadence:

```text
Every 15 minutes
```

The workflow performs these steps:

```text
Check out repository
Set up Python
Install ingestion dependencies
Confirm environment configuration
Extract latest guild data
Load latest snapshot to Supabase Postgres
```

---

## 4. GitHub Secrets

The scheduled ingestion workflow requires GitHub repository secrets.

Configure them in:

```text
GitHub repository
→ Settings
→ Secrets and variables
→ Actions
```

Required secrets:

```text
TIBIA_GUILD_NAME
TIBIA_WORLD
SUPABASE_DB_HOST
SUPABASE_DB_PORT
SUPABASE_DB_NAME
SUPABASE_DB_USER
SUPABASE_DB_PASSWORD
```

Example values:

```text
TIBIA_GUILD_NAME = Black Clover
TIBIA_WORLD = Lobera
SUPABASE_DB_NAME = postgres
```

Do not commit real credentials to GitHub.

---

## 5. Frontend Configuration

The frontend configuration is stored in:

```text
frontend/config.js
```

The production frontend reads from Supabase REST API.

Example structure:

```javascript
window.APP_CONFIG = {
    DATA_SOURCE: "supabase",

    API_BASE_URL: "http://127.0.0.1:8000",

    SUPABASE_URL: "https://your-project.supabase.co",
    SUPABASE_ANON_KEY: "your-anon-or-publishable-key"
};
```

The `SUPABASE_ANON_KEY` is safe to use in browser code only when database access is restricted through read-only public views and appropriate grants.

Never expose the Supabase service-role key in frontend code.

---

## 6. Public API Views

The frontend does not query raw tables directly.

Instead, it reads from curated public API views such as:

```text
public.api_guild_overview_by_snapshot
public.api_historical_character_level_changes
public.api_historical_guild_joins
public.api_historical_guild_leaves
public.api_historical_rank_changes
public.api_snapshot_date_bounds
```

These views expose only the data needed by the public dashboard.

Read access is granted to the Supabase `anon` role.

Example grant:

```sql
GRANT SELECT ON public.api_historical_character_level_changes TO anon;
```

---

## 7. Cloudflare Pages Deployment

The production frontend is hosted on Cloudflare Pages.

Cloudflare Pages deploys the static frontend from:

```text
frontend/
```

Recommended Cloudflare Pages settings:

```text
Framework preset: None
Build command: leave blank
Build output directory: frontend
Production branch: main
```

Cloudflare automatically redeploys the site after pushes to the main branch.

---

## 8. Custom Domain

The project uses a custom domain:

```text
https://tibiaguildanalytics.com/
```

The domain is managed through Cloudflare.

Typical setup:

```text
Cloudflare Pages
→ Project
→ Custom domains
→ Add domain
```

Recommended domains to configure:

```text
tibiaguildanalytics.com
www.tibiaguildanalytics.com
```

Cloudflare handles HTTPS certificates for the Pages deployment.

---

## 9. Deployment Workflow

The usual deployment process is:

```text
1. Make code changes locally.
2. Test locally.
3. Commit changes.
4. Push to GitHub.
5. GitHub Actions continues scheduled ingestion.
6. Cloudflare Pages automatically redeploys the frontend.
7. Validate the live website.
```

For frontend changes, check:

```text
Cloudflare Dashboard
→ Workers & Pages
→ tibia-guild-analytics
→ Deployments
```

For ingestion changes, check:

```text
GitHub repository
→ Actions
→ Scheduled Supabase Ingestion
```

---

## 10. Manual Production Validation

After deployment, validate the production system.

### Check latest snapshots

```bash
set -a
source .env.supabase
set +a

docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT
    extracted_at_utc,
    guild_name,
    world
FROM raw_guild_snapshot
ORDER BY extracted_at_utc DESC
LIMIT 10;
"
```

### Check frontend API date bounds

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT *
FROM public.api_snapshot_date_bounds;
"
```

### Check guild overview API view

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT
    guild_name,
    world,
    snapshot_time,
    number_of_members,
    max_level,
    min_level,
    average_level
FROM public.api_guild_overview_by_snapshot
ORDER BY snapshot_time DESC
LIMIT 5;
"
```

---

## 11. Troubleshooting Deployment

## Cloudflare Pages deployed, but the live site looks old

Try:

```text
Hard refresh the browser
Open the site in incognito mode
Check the Cloudflare Pages deployment status
Confirm the latest commit was pushed to main
```

Cloudflare preview deployment URLs may update before the custom domain.

## Frontend loads, but data is missing

Check:

```text
Browser console
Browser network requests
Supabase URL in frontend/config.js
Supabase anon key in frontend/config.js
SELECT grants on public API views
Date filter values
```

## GitHub Actions ingestion fails

Check:

```text
Missing repository secrets
Wrong Supabase database password
Wrong Supabase pooler host or port
Python dependency issue
TibiaData API issue
Database schema mismatch
```

## Custom domain does not work yet

Possible causes:

```text
DNS propagation still in progress
Custom domain not attached to Cloudflare Pages
Cloudflare SSL certificate still provisioning
Browser cache
```

---

## 12. Security Notes

Do not commit:

```text
.env
.env.supabase
database passwords
Supabase service-role key
private API tokens
```

It is acceptable for the frontend to contain the Supabase anon/publishable key, as long as the database only exposes safe read-only public views to the `anon` role.

The service-role key must never be used in frontend code.