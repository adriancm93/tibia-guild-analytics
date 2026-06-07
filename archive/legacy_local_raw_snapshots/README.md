# Legacy Local Raw Snapshots

This folder contains raw TibiaData JSON snapshots generated during earlier local ingestion phases.

These files are no longer part of the current production pipeline.

Current production raw data is stored in Supabase Postgres:

```text
public.raw_guild_snapshot
public.guild_member_snapshot
```

These snapshots are archived for historical reference, debugging context, and project traceability only.

They should not be treated as the current source of truth. The production source of truth is the Supabase database populated by the Supabase Edge Function ingestion workflow.
