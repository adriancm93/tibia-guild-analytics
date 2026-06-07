# Supabase

This folder contains Supabase-specific project assets.

The current production ingestion process runs through a Supabase Edge Function triggered by Supabase Cron.

---

## Current Edge Function

```text
supabase/functions/refresh-guilds/index.ts
```

The function performs the production ingestion workflow:

1. Validates the `x-cron-secret` request header.
2. Reads the requested world and batch size.
3. Releases stale running refresh claims.
4. Claims due guilds from `public.tibia_guild`.
5. Fetches guild data from the TibiaData API.
6. Inserts raw payloads into `public.raw_guild_snapshot`.
7. Inserts parsed member rows into `public.guild_member_snapshot`.
8. Refreshes frontend analytics cache rows for each successfully ingested guild.
9. Marks refresh success or failure.
10. Applies snapshot retention.

---

## Required Secrets

The Edge Function expects the following secrets:

| Secret | Purpose |
|---|---|
| `PROJECT_SUPABASE_URL` | Supabase project URL |
| `PROJECT_SUPABASE_SECRET_KEY` | Server-side Supabase secret key |
| `GUILD_REFRESH_SECRET` | Shared secret used by Supabase Cron / manual callers |

The secret key must never be exposed to the frontend.

---

## Deploy

```bash
supabase functions deploy refresh-guilds --no-verify-jwt
```

The function is deployed with JWT verification disabled because it uses the `x-cron-secret` header as its trigger authorization mechanism.

---

## Manual Test

```bash
curl -i \
  -X POST "https://<project-ref>.supabase.co/functions/v1/refresh-guilds" \
  -H "Content-Type: application/json" \
  -H "x-cron-secret: <secret>" \
  -d '{"world":"Lobera","batch_size":5}'
```

A successful response should include:

```json
{
  "success": true,
  "frontend_refresh_failure_count": 0
}
```

---

## Scheduler

Production scheduling is handled by Supabase Cron.

Supabase Cron calls the Edge Function on a recurring schedule. The Edge Function then decides which guilds are due based on metadata stored in `public.tibia_guild`.

---

## Design Notes

Earlier versions of the project used GitHub Actions for scheduled ingestion. GitHub Actions is now treated as a manual fallback only.

The production scheduler is Supabase Cron because it provides more reliable recurring execution for this use case.
