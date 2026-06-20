# Portfolio Summary

## Project name

Tibia Guild Analytics

## Short description

Tibia Guild Analytics is a production-style data engineering project that tracks Tibia guild roster snapshots, detects member movement and level changes, estimates online activity, and exposes the results through a public web dashboard.

## What the project does

The system continuously ingests guild roster data from the TibiaData API, stores raw and normalized snapshots in Supabase Postgres, processes analytics incrementally, and serves the results through REST-ready database views consumed by a static frontend.

## Production architecture

```text
TibiaData API
    ↓
Supabase Edge Function
    ↓
Supabase Postgres raw + normalized tables
    ↓
Supabase Cron incremental analytics jobs
    ↓
Supabase public API views
    ↓
Static frontend
    ↓
Cloudflare Pages + custom domain
```

## Key engineering features

- Serverless ingestion using Supabase Edge Functions
- Queue-based guild refresh system using Postgres
- Incremental analytics processing with processed snapshot-pair tracking
- Raw data retention for debugging and auditability
- Normalized snapshot tables for analytics
- Public API views for frontend consumption
- Automated retention policy to control database growth
- Static frontend hosted on Cloudflare Pages
- Custom domain deployment
- Legacy code archived for project history and maintainability

## Main database objects

| Layer | Objects |
|---|---|
| Raw ingestion | `public.raw_guild_snapshot` |
| Normalized snapshots | `public.guild_member_snapshot` |
| Queue metadata | `public.tibia_guild`, `public.tibia_world` |
| Analytics processing | `analytics.process_incremental_online_activity`, `analytics.process_incremental_general_analytics` |
| Retention | `analytics.apply_safe_7_day_snapshot_retention` |
| API layer | `public.api_*` views |

## What this demonstrates

This project demonstrates practical data engineering skills across ingestion, orchestration, database modeling, incremental processing, API design, frontend integration, deployment, and production maintenance.

It also shows the evolution from a local Python ingestion prototype into a serverless production pipeline with documented architecture and archived legacy code.

## Resume bullet ideas

- Built a serverless data pipeline that ingests Tibia guild roster data from an external API into Supabase Postgres and processes analytics incrementally.
- Designed normalized snapshot tables, queue metadata, analytics cache tables, and public REST-ready views for a production web dashboard.
- Implemented scheduled ingestion and analytics processing with Supabase Cron, Edge Functions, and Postgres functions.
- Reduced database growth risk through retention policies, cache pruning, and production health checks.
- Deployed a static frontend through Cloudflare Pages with a custom domain and Supabase-backed API views.
