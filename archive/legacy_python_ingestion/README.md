# Legacy Python Ingestion

This folder contains the original Python-based ingestion scripts used during early development.

These scripts are no longer part of the production runtime.

## Replaced by

Production ingestion now runs through:

- Supabase Edge Function: `supabase/functions/refresh-guilds/index.ts`
- Supabase Cron job: `refresh-lobera-guilds-every-5-minutes`
- Database queue table: `public.tibia_guild`
- Raw/member snapshot tables:
  - `public.raw_guild_snapshot`
  - `public.guild_member_snapshot`

## Why archived

The Python pipeline was useful for local development and early validation, but production now uses a serverless architecture with Supabase-managed scheduling and database processing.

This folder is retained for historical reference only.
