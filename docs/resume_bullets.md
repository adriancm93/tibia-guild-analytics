# Resume Bullets

## Short project description

Built Tibia Guild Analytics, a production-style data engineering project that ingests MMORPG guild roster data from an external API, stores raw and normalized snapshots in Supabase Postgres, processes incremental analytics, and serves a public dashboard through Cloudflare Pages.

## Resume bullet options

- Built a serverless data pipeline that ingests Tibia guild roster data from the TibiaData API into Supabase Postgres using scheduled Edge Functions and queue-based refresh metadata.
- Designed raw, normalized, and analytics cache tables to support historical guild tracking, level-change detection, joins, leaves, rank changes, and online activity estimates.
- Implemented incremental analytics processors in Postgres to process new snapshot pairs without rebuilding all historical analytics on every refresh.
- Separated ingestion, analytics processing, retention, and frontend serving into independent production workflows using Supabase Cron, Edge Functions, Postgres functions, and public API views.
- Created REST-ready `public.api_*` views consumed by a static JavaScript frontend hosted on Cloudflare Pages with a custom domain.
- Added safe retention logic to control database growth while preserving recent guild history and frontend date-range usability.
- Refactored the project from a local Python ingestion prototype into a serverless production architecture and archived legacy workflows for maintainability.
- Documented system architecture, data model, deployment, operations, third-party integrations, and live-site verification procedures.

## LinkedIn / portfolio version

Tibia Guild Analytics is a full-stack data engineering portfolio project built around a serverless production architecture. It ingests guild roster snapshots from the TibiaData API, stores raw and normalized data in Supabase Postgres, processes incremental analytics with scheduled database functions, and exposes results through REST-ready public API views consumed by a Cloudflare-hosted static dashboard.

## Interview talking points

### Architecture

The project started as a local Python ingestion pipeline and evolved into a serverless production architecture. The current design uses Supabase Edge Functions for ingestion, Supabase Cron for scheduling, Postgres for storage and analytics processing, public API views for the serving layer, and Cloudflare Pages for hosting.

### Scalability

Early versions used dynamic views and broader refresh patterns. As the data grew, the architecture moved to incremental processors that track processed snapshot pairs and update analytics cache tables only when new data arrives.

### Reliability

The ingestion process is queue-based. Each guild has refresh metadata, status tracking, failure handling, and stale-claim recovery. A failed guild refresh does not stop the full batch.

### Cost control

The project uses a low-cost serverless stack and includes safe retention to limit storage growth in Supabase while preserving recent historical data for the frontend.

### Data modeling

The database separates raw snapshots, normalized member snapshots, metadata tables, analytics cache tables, processed-pair tracking tables, and public API views. This keeps ingestion, processing, and serving responsibilities clear.
