# Archive

This folder contains legacy project components that are no longer part of the production architecture.

Archived components are preserved for learning history and traceability.

They should not be used as the current deployment path.

Current production architecture:

```text
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres
        ↓
Public Supabase REST API views
        ↓
Cloudflare Pages frontend
```
