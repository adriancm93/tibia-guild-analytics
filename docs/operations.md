# Operations Guide

This document describes how to operate, validate, and troubleshoot the Tibia Guild Analytics project.

The production system uses:

```text
GitHub Actions scheduled workflow
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

## Production Refresh Schedule

The production ingestion workflow runs from GitHub Actions.

Workflow file:

```text
.github/workflows/scheduled_ingestion.yml
```

Current schedule:

```text
Every 15 minutes
```

The workflow can also be run manually from GitHub:

```text
GitHub repository
→ Actions
→ Scheduled Supabase Ingestion
→ Run workflow
```

---

## Check GitHub Actions Status

To confirm the scheduled ingestion is running:

```text
GitHub repository
→ Actions
→ Scheduled Supabase Ingestion
```

A successful run should show green checks for:

```text
Check out repository
Set up Python
Install ingestion dependencies
Confirm environment configuration
Extract latest guild data
Load latest snapshot to Supabase Postgres
```

If the workflow fails, open the failed run and inspect the failed step logs.

---

## Required GitHub Secrets

The scheduled workflow depends on repository secrets.

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

These are configured in:

```text
GitHub repository
→ Settings
→ Secrets and variables
→ Actions
```

Do not commit real credentials to the repository.

---

## Connect to Supabase from Local Terminal

The project uses a local `.env.supabase` file for connecting to Supabase from your machine.

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

Export the variables:

```bash
set -a
source .env.supabase
set +a
```

Use the local Docker Postgres container as a `psql` client:

```bash
docker exec -it -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB"
```

Once connected, exit with:

```sql
\q
```

---

## Check Latest Snapshots

Run this query against Supabase:

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
LIMIT 20;
"
```

Expected result:

```text
One row per successful snapshot extraction.
```

---

## Check Snapshot Frequency

Use this query to inspect time gaps between snapshots:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT
    extracted_at_utc,
    extracted_at_utc
        - LAG(extracted_at_utc) OVER (ORDER BY extracted_at_utc) AS time_since_previous_snapshot
FROM raw_guild_snapshot
ORDER BY extracted_at_utc DESC;
"
```

Use this query to count snapshots by hour:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT
    date_trunc('hour', extracted_at_utc) AS snapshot_hour,
    COUNT(*) AS snapshot_count
FROM raw_guild_snapshot
GROUP BY date_trunc('hour', extracted_at_utc)
ORDER BY snapshot_hour DESC;
"
```

With a 15-minute schedule, the ideal result is up to:

```text
4 snapshots per hour
```

GitHub scheduled workflows may be delayed or skipped occasionally, so exact timing may vary.

---

## Check Core Table Counts

Run:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT 'raw_guild_snapshot' AS table_name, COUNT(*) AS row_count
FROM raw_guild_snapshot

UNION ALL

SELECT 'guild_member_snapshot' AS table_name, COUNT(*) AS row_count
FROM guild_member_snapshot

UNION ALL

SELECT 'stg_guild_member_snapshot' AS table_name, COUNT(*) AS row_count
FROM stg_guild_member_snapshot;
"
```

Expected pattern:

```text
raw_guild_snapshot        = number of data pulls
guild_member_snapshot     = number of snapshots × members per snapshot
stg_guild_member_snapshot = same row count as guild_member_snapshot
```

---

## Check Historical Analytics Counts

Run:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "
SELECT
    'historical_level_changes' AS view_name,
    COUNT(*) AS row_count
FROM public.api_historical_character_level_changes

UNION ALL

SELECT
    'historical_guild_joins',
    COUNT(*)
FROM public.api_historical_guild_joins

UNION ALL

SELECT
    'historical_guild_leaves',
    COUNT(*)
FROM public.api_historical_guild_leaves

UNION ALL

SELECT
    'historical_rank_changes',
    COUNT(*)
FROM public.api_historical_rank_changes;
"
```

---

## Check Snapshot Date Bounds

The frontend date filters depend on this API view:

```text
public.api_snapshot_date_bounds
```

Validate it with:

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

Expected result:

```text
min_snapshot_time = earliest available snapshot
max_snapshot_time = latest available snapshot
```

---

## Check Guild Overview Metrics

The frontend Guild Overview section uses:

```text
public.api_guild_overview_by_snapshot
```

Validate it with:

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
LIMIT 10;
"
```

---

## Export Historical Data to CSV

Create an exports folder locally:

```bash
mkdir -p exports
```

Export all parsed member snapshots:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "\COPY (
      SELECT *
      FROM guild_member_snapshot
      ORDER BY extracted_at_utc DESC
  ) TO STDOUT WITH CSV HEADER" \
  > exports/guild_member_snapshot_history.csv
```

Export raw snapshot history:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  -c "\COPY (
      SELECT *
      FROM raw_guild_snapshot
      ORDER BY extracted_at_utc DESC
  ) TO STDOUT WITH CSV HEADER" \
  > exports/raw_guild_snapshot_history.csv
```

Check the files:

```bash
ls -lh exports
head exports/guild_member_snapshot_history.csv
```

The `exports/` folder is ignored by Git and should not be committed.

---

## Apply a New SQL Script to Supabase

Use this pattern for files in `database/init/`:

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

## Run the Local Docker Stack

For local development:

```bash
docker compose up --build
```

Local URLs:

```text
Frontend: http://localhost:3000
Backend:  http://localhost:8000/docs
Postgres: localhost:5432
```

Stop the stack:

```bash
docker compose down
```

Reset the local database volume:

```bash
docker compose down -v
docker compose up --build
```

Warning: `docker compose down -v` deletes the local PostgreSQL Docker volume.

---

## Run the Local Pipeline

Activate the ingestion environment:

```bash
source ingestion/.venv/bin/activate
```

Run the local orchestration script:

```bash
python orchestration/run_pipeline.py
```

The local pipeline runs:

```text
Extract latest guild data
Load latest snapshot into local Postgres
Refresh staging and analytics views
Run validation checks
```

---

## Troubleshooting

## GitHub Actions workflow fails

Check:

```text
GitHub repository
→ Actions
→ Scheduled Supabase Ingestion
→ Failed run
```

Common causes:

```text
Missing GitHub secret
Invalid Supabase password
Supabase connection issue
Python dependency issue
TibiaData API issue
SQL/table mismatch
```

## Snapshot count is not increasing

Check:

```text
1. Did the GitHub Actions workflow run successfully?
2. Did the load step complete?
3. Are GitHub secrets correct?
4. Is Supabase reachable?
5. Are duplicate snapshot constraints preventing inserts?
```

Then run:

```sql
SELECT *
FROM raw_guild_snapshot
ORDER BY extracted_at_utc DESC
LIMIT 20;
```

## Frontend loads but data is missing

Check browser developer tools:

```text
Chrome
→ Developer Tools
→ Console
→ Network
```

Common causes:

```text
Supabase anon key issue
Missing SELECT grant on public API view
Incorrect view name in frontend/app.js
Date filter outside available snapshot range
Cloudflare Pages has not redeployed latest commit
Browser cache
```

## Supabase REST API returns 401 or 403

Confirm the relevant public API view has been granted to `anon`.

Example:

```sql
GRANT SELECT ON public.api_historical_character_level_changes TO anon;
```

Grant scripts are stored in:

```text
database/init/
```

## Local backend works but production does not

The local FastAPI backend is optional and is not used by production.

Production frontend reads from:

```text
Supabase REST API
```

not from:

```text
FastAPI
```

## `.env.supabase` fails when sourced

If a value contains spaces, quote it.

Correct:

```env
TIBIA_GUILD_NAME="Black Clover"
```

Incorrect:

```env
TIBIA_GUILD_NAME=Black Clover
```

---

## Operational Checklist

Use this checklist after major changes:

```text
1. Apply new SQL scripts to Supabase if needed.
2. Validate public API views with psql.
3. Test frontend locally.
4. Commit and push code.
5. Confirm Cloudflare Pages deployment succeeds.
6. Confirm live site reflects latest changes.
7. Manually run GitHub Actions ingestion if needed.
8. Confirm raw_guild_snapshot count increases.
9. Confirm frontend date filters and tables work.
```