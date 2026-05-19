# Data Model

This document describes the database model for the Tibia Guild Analytics project.

The project stores historical guild snapshots in PostgreSQL/Supabase and builds analytics views on top of those snapshots.

---

## Data Modeling Approach

The project follows a layered structure:

```text
Raw snapshot table
        ↓
Parsed member snapshot table
        ↓
Staging views
        ↓
Analytics views
        ↓
Public API views
        ↓
Frontend dashboard
```

Each scheduled ingestion run creates a new guild snapshot. The project preserves those snapshots so guild changes can be analyzed over time.

---

## Core Tables

## `raw_guild_snapshot`

Stores one raw guild snapshot per extraction run.

This table is the persistent raw data layer.

### Purpose

```text
Preserve the original extracted guild payload
Track when each extraction occurred
Provide a raw source for downstream parsing and validation
```

### Grain

```text
One row per guild snapshot extraction
```

### Important Fields

| Field | Purpose |
|---|---|
| `snapshot_id` | Unique identifier for the snapshot |
| `guild_name` | Guild name extracted from TibiaData |
| `world` | Tibia world/server |
| `extracted_at_utc` | Timestamp when the snapshot was extracted |
| raw payload column | Stores the original extracted guild data |

---

## `guild_member_snapshot`

Stores parsed member-level records from each guild snapshot.

This is the main historical fact table used for analytics.

### Purpose

```text
Track each guild member's state at each snapshot
Enable level change detection
Enable guild join/leave detection
Enable rank change detection
```

### Grain

```text
One row per character per snapshot
```

For example, if a guild has 100 members and the pipeline runs 10 times, this table should contain approximately:

```text
100 members × 10 snapshots = 1,000 rows
```

### Important Fields

| Field | Purpose |
|---|---|
| `snapshot_id` | Links back to `raw_guild_snapshot` |
| `extracted_at_utc` | Snapshot timestamp |
| `guild_name` | Guild name |
| `world` | Tibia world/server |
| `character_name` | Character name |
| `guild_rank` | Guild rank at the time of the snapshot |
| `vocation` | Character vocation |
| `level` | Character level at the time of the snapshot |
| `status` | Online/offline status from the source |
| `joined` | Guild joined date when available |
| `created_at` | Database insert timestamp |

### Uniqueness

The table is designed to prevent duplicate member rows for the same snapshot.

Logical unique key:

```text
guild_name
world
character_name
extracted_at_utc
```

---

## Staging Views

Staging views standardize fields from the base tables before analytics logic is applied.

Main staging view:

```text
stg_guild_member_snapshot
```

### Purpose

```text
Provide a cleaner interface over guild_member_snapshot
Standardize field names
Prepare data for analytics views
```

### Notes

The base table uses:

```text
joined
```

The staging layer may expose it as:

```text
joined_date
```

This keeps downstream analytics views more readable.

---

## Analytics Views

Analytics views contain business logic for comparing snapshots.

There are two categories of analytics views:

```text
Latest-vs-previous analytics
Historical date-range analytics
```

---

## Latest-vs-Previous Analytics

These views compare only the latest snapshot to the immediately previous snapshot.

Examples:

```text
analytics.snapshot_pairs
analytics.character_level_changes
analytics.guild_joins
analytics.guild_leaves
analytics.rank_changes
```

### Use Case

These views are useful for answering:

```text
What changed since the most recent refresh?
```

### Current Role

These views are still useful for quick validation and local analysis, but the production frontend now primarily uses the historical analytics views.

---

## Historical Analytics

Historical analytics views compare every snapshot to the snapshot immediately before it.

This allows the frontend to support date-range filtering.

Examples:

```text
analytics.historical_snapshot_pairs
analytics.historical_character_level_changes
analytics.historical_guild_joins
analytics.historical_guild_leaves
analytics.historical_rank_changes
```

### `analytics.historical_snapshot_pairs`

Creates consecutive snapshot pairs.

Example:

```text
previous_snapshot_time        latest_snapshot_time
2026-05-16 18:00:00           2026-05-16 18:15:00
2026-05-16 18:15:00           2026-05-16 18:30:00
2026-05-16 18:30:00           2026-05-16 18:45:00
```

This view is the foundation for historical comparisons.

---

## `analytics.historical_character_level_changes`

Shows character level changes across all consecutive snapshot pairs.

### Grain

```text
One row per character per snapshot-pair level change
```

A character may appear multiple times if they leveled up across multiple snapshot intervals.

The frontend can aggregate these rows by character to show total level gain over a selected date range.

### Example Use Cases

```text
Who gained the most levels in the last 7 days?
Who leveled up during the selected period?
What was a character's total level gain?
```

---

## `analytics.historical_guild_joins`

Shows characters who appear in a later snapshot but were not present in the previous snapshot.

### Grain

```text
One row per detected guild join event
```

### Example Use Cases

```text
Who joined the guild this week?
How many members joined during a selected date range?
```

---

## `analytics.historical_guild_leaves`

Shows characters who were present in a previous snapshot but are missing from the next snapshot.

### Grain

```text
One row per detected guild leave event
```

### Example Use Cases

```text
Who left the guild this week?
How many members left during a selected date range?
```

---

## `analytics.historical_rank_changes`

Shows characters whose guild rank changed between consecutive snapshots.

### Grain

```text
One row per character per detected rank change
```

### Example Use Cases

```text
Who was promoted?
Who was demoted?
Which ranks changed during a selected date range?
```

---

## Public API Views

The production frontend reads from Supabase REST API.

To avoid exposing raw tables directly, the project creates curated public API views in the `public` schema.

Examples:

```text
public.api_guild_overview_by_snapshot
public.api_historical_character_level_changes
public.api_historical_guild_joins
public.api_historical_guild_leaves
public.api_historical_rank_changes
public.api_snapshot_date_bounds
```

These views are granted read-only access for Supabase's public/anon API role.

---

## `public.api_guild_overview_by_snapshot`

Provides guild-level metrics by snapshot.

### Grain

```text
One row per guild per world per snapshot
```

### Fields

| Field | Purpose |
|---|---|
| `guild_name` | Guild name |
| `world` | Tibia world |
| `snapshot_time` | Snapshot timestamp |
| `number_of_members` | Number of members in that snapshot |
| `max_level` | Highest member level in that snapshot |
| `min_level` | Lowest member level in that snapshot |
| `average_level` | Rounded average member level in that snapshot |

### Frontend Use

The dashboard uses this view to populate the Guild Overview section.

---

## `public.api_snapshot_date_bounds`

Provides the earliest and latest available snapshot timestamps.

### Purpose

```text
Set minimum and maximum allowed dates in frontend date filters
Prevent users from selecting dates outside the available data range
```

### Fields

| Field | Purpose |
|---|---|
| `min_snapshot_time` | Earliest available snapshot |
| `max_snapshot_time` | Latest available snapshot |

---

## Data Refresh Behavior

The production ingestion workflow runs on a schedule and appends new snapshots.

Current cadence:

```text
Every 15 minutes
```

Each successful run should add:

```text
1 row to raw_guild_snapshot
N rows to guild_member_snapshot
```

where `N` is approximately the number of guild members in the extracted snapshot.

---

## Data Quality and Validation

Validation scripts are stored in:

```text
database/validation/
```

They are used to check:

```text
Raw snapshot counts
Parsed member snapshot counts
Snapshot ranking
Latest-vs-previous changes
Historical analytics outputs
```

Recommended validation checks include:

```sql
SELECT COUNT(*) FROM raw_guild_snapshot;

SELECT COUNT(*) FROM guild_member_snapshot;

SELECT *
FROM analytics.snapshot_pairs
ORDER BY snapshot_rank;

SELECT *
FROM public.api_snapshot_date_bounds;
```

---

## Current Production Data Path

```text
GitHub Actions scheduled workflow
        ↓
Python ingestion
        ↓
raw_guild_snapshot
        ↓
guild_member_snapshot
        ↓
stg_guild_member_snapshot
        ↓
analytics historical views
        ↓
public API views
        ↓
Supabase REST API
        ↓
Cloudflare Pages frontend
```

---

## Notes for Future Expansion

The current model is designed around one guild and one world, but the table structure already includes:

```text
guild_name
world
```

This makes it possible to expand the project later to support:

```text
Multiple guilds
Multiple worlds
Guild/world filters in the frontend
Cross-guild comparisons
Longer-term trend analysis
```