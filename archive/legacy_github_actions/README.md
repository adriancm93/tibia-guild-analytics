# Legacy GitHub Actions

This folder contains GitHub Actions workflows used during earlier development phases.

## Archived workflows

### manual_batch_ingestion.yml

This workflow ran the old Python ingestion pipeline manually against Supabase.

It is no longer part of the production runtime.

## Replaced by

Production ingestion now runs through:

- Supabase Cron
- Supabase Edge Function: `supabase/functions/refresh-guilds/index.ts`
- Database queue table: `public.tibia_guild`

This archive is retained for historical reference only.
