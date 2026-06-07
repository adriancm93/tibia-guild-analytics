# Legacy Ingestion Dockerfile

This folder contains the earlier Dockerfile used for containerized Python ingestion.

It is no longer part of the current production ingestion architecture.

Current production ingestion runs through:

```text
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres
```

The Python ingestion scripts are still retained in `ingestion/` for manual fallback workflows, local testing, metadata discovery, and administrative utilities.

This Dockerfile is archived for historical reference only and is not used by the current pipeline.
