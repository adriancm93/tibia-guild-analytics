# Deployment

This document explains the current deployment model for Tibia Guild Analytics.

The production architecture uses:

- Supabase Postgres
- Supabase Edge Functions
- Supabase Cron
- Cloudflare Pages
- Cloudflare DNS

The frontend is static. There is no production FastAPI server.

---

## Deployment Overview

```text
GitHub repository
        ↓
Cloudflare Pages deploys frontend
        ↓
Supabase hosts database and Edge Function
        ↓
Supabase Cron triggers scheduled ingestion
```

---

## Frontend Deployment

The frontend is located in:

```text
frontend/
```

It is deployed as a static site through Cloudflare Pages.

### Production hosting

Production domain:

```text
https://tibiaguildanalytics.com/
```

Cloudflare Pages preview domain:

```text
https://tibia-guild-analytics.pages.dev/
```

### Build model

The frontend does not require a build step unless Cloudflare Pages is configured otherwise.

Typical Cloudflare Pages settings:

| Setting | Value |
|---|---|
| Framework preset | None / static site |
| Build command | Empty |
| Output directory | `frontend` |

### Runtime configuration

The frontend reads Supabase configuration from:

```text
frontend/config.js
```

Only browser-safe values belong in this file:

- Supabase URL
- Supabase anon/public key
- data source mode

Never expose the Supabase secret key in frontend files.

---

## Supabase Deployment

Supabase hosts:

- Postgres database
- Edge Function
- Cron schedule
- Vault secrets
- `pg_net` / `pg_cron` extensions where applicable

---

## Edge Function Deployment

The production ingestion function is:

```text
supabase/functions/refresh-guilds/index.ts
```

Deploy with:

```bash
supabase functions deploy refresh-guilds --no-verify-jwt
```

The function uses the `x-cron-secret` header for authorization.

### Required Supabase secrets

| Secret | Purpose |
|---|---|
| `PROJECT_SUPABASE_URL` | Supabase project URL |
| `PROJECT_SUPABASE_SECRET_KEY` | Server-side Supabase key used by the Edge Function |
| `GUILD_REFRESH_SECRET` | Shared secret for authorized refresh calls |

Set secrets through the Supabase dashboard or Supabase CLI.

---

## Supabase Cron

Production scheduling is handled by Supabase Cron.

The cron job calls:

```text
https://<project-ref>.supabase.co/functions/v1/refresh-guilds
```

with a JSON body similar to:

```json
{
  "world": "Lobera",
  "batch_size": 50
}
```

The request must include:

```text
x-cron-secret: <GUILD_REFRESH_SECRET>
```

The Edge Function then determines which guilds are due based on `public.tibia_guild.next_refresh_after_utc`.

---

## Database Deployment

Current active SQL scripts are kept in:

```text
database/init/
```

These represent the active schema build path. Historical SQL scripts are stored in:

```text
database/archive/
```

One-time cleanup scripts are stored in:

```text
database/cleanup/
```

Validation SQL is stored in:

```text
database/validation/
```

### Apply SQL manually

For administrative work, load Supabase credentials locally:

```bash
set -a
source .env.supabase
set +a
```

Then run a script:

```bash
docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" tibia_guild_postgres psql \
  -v ON_ERROR_STOP=1 \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  < database/init/<script_name>.sql
```

The `ON_ERROR_STOP=1` flag is recommended so SQL migrations fail safely instead of continuing after an error.

---

## Manual Edge Function Test

Use this to manually trigger ingestion:

```bash
curl -i \
  -X POST "https://<project-ref>.supabase.co/functions/v1/refresh-guilds" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <secret>" \
  -d '{"world":"Lobera","batch_size":5}'
```

Expected high-level response:

```json
{
  "success": true,
  "frontend_refresh_failure_count": 0
}
```

If `claimed` is `0`, no guilds were due at that moment.

---

## Manual Fallback Workflow

GitHub Actions may be retained as a manual fallback, but it is not the primary production scheduler.

The primary scheduler is Supabase Cron.

If a GitHub Actions workflow exists, it should be configured as:

```yaml
on:
  workflow_dispatch:
```

and should not contain an active `schedule:` block unless intentionally re-enabled.

---

## Local Development

### Local frontend

```bash
cd frontend
python3 -m http.server 3000
```

Open:

```text
http://127.0.0.1:3000
```

### Local Postgres

The repository includes `docker-compose.yml` for local database development.

```bash
docker compose up -d
```

Production does not depend on the local Docker stack.

---

## Deployment Checklist

### Frontend

- [ ] `frontend/config.js` points to the correct Supabase project.
- [ ] Only anon/public key is used in browser code.
- [ ] Cloudflare Pages output directory points to `frontend`.
- [ ] Custom domain is active in Cloudflare.

### Supabase

- [ ] Database schema is current.
- [ ] Edge Function is deployed.
- [ ] Required secrets are configured.
- [ ] Supabase Cron job is active.
- [ ] Edge Function logs show successful runs.
- [ ] Public API views return data.

### Operations

- [ ] Refresh queue has no stuck `running` guilds.
- [ ] Cache latest snapshot matches raw latest snapshot for recently refreshed guilds.
- [ ] Frontend tabs load without Supabase REST errors.
