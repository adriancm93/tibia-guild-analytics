# Legacy Ingestion Scripts

This folder contains earlier Python ingestion scripts that are no longer part of the active ingestion workflow.

Current production ingestion runs through:

```text
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres
```

The active `ingestion/` folder is retained for:

- Manual fallback workflows
- Local testing
- Metadata discovery
- Administrative utilities

These scripts are archived for historical reference only and should not be used as the current production ingestion path.
