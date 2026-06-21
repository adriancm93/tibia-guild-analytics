# Live Site Verification Checklist

Use this checklist after production changes, database migrations, frontend updates, or deployment changes.

## Website

- [ ] Production site loads successfully.
- [ ] Custom domain resolves correctly.
- [ ] Main dashboard renders without console errors.
- [ ] World selector loads available worlds.
- [ ] Guild selector loads available guilds.
- [ ] Default world and guild load correctly.
- [ ] Date filters load valid bounds.

## Guild Overview

- [ ] Latest refresh timestamp is visible.
- [ ] Member count loads correctly.
- [ ] Maximum level, minimum level, and average level render.
- [ ] Guild summary cards are not empty.
- [ ] Selected guild and world labels are correct.

## Analytics Tabs

- [ ] Level changes tab loads results.
- [ ] Guild joins tab loads without errors.
- [ ] Guild leaves tab loads without errors.
- [ ] Rank changes tab loads without errors.
- [ ] Latest members table loads current roster.
- [ ] Online activity / time-online metrics load where available.

## Supabase API Views

- [ ] `public.api_worlds` returns rows.
- [ ] `public.api_guilds` returns rows.
- [ ] `public.api_snapshot_date_bounds_by_guild` returns rows.
- [ ] `public.api_latest_guild_members` returns rows.
- [ ] Historical analytics views return rows or valid empty results.

## Ingestion

- [ ] Supabase Cron ingestion job is active.
- [ ] Edge Function returns HTTP 200.
- [ ] Recent Edge Function responses show successful guild claims.
- [ ] `public.raw_guild_snapshot` receives new rows.
- [ ] `public.guild_member_snapshot` receives new rows.
- [ ] Failed guild refreshes, if any, are isolated to individual guilds and do not break the batch.

## Incremental Analytics

- [ ] Online activity processor cron job is active.
- [ ] General analytics processor cron job is active.
- [ ] Processed snapshot-pair tracking tables are growing.
- [ ] Analytics cache tables update after new snapshots.
- [ ] Frontend API views reflect newly processed analytics.

## Retention

- [ ] Safe retention cron job is active.
- [ ] Raw/member snapshot date range remains near the expected retention window.
- [ ] Analytics cache tables do not retain unnecessary stale rows.
- [ ] No current frontend date bounds are broken after retention.

## Final Result

- [ ] Live site is usable.
- [ ] Data is current.
- [ ] Analytics are processing.
- [ ] Documentation still matches production architecture.
