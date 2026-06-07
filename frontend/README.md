# Frontend

This folder contains the current production frontend for Tibia Guild Analytics.

The frontend is a static HTML, CSS, and JavaScript dashboard deployed through Cloudflare Pages. It reads directly from Supabase REST API views and does not require a FastAPI backend in production.

---

## Architecture

```text
Cloudflare Pages
        ↓
Static HTML/CSS/JavaScript
        ↓
Supabase REST API
        ↓
Public API views
        ↓
Per-guild analytics cache tables
```

The frontend is intentionally lightweight. Data transformation, historical comparison logic, and performance optimization happen in PostgreSQL through per-guild cache tables and curated public API views.

---

## Main Files

| File | Purpose |
|---|---|
| `index.html` | Dashboard layout, controls, tabs, and table structure |
| `styles.css` | Application styling and responsive layout |
| `app.js` | Data fetching, filtering, sorting, table rendering, and chart rendering logic |
| `config.js` | Runtime configuration for Supabase access |

The frontend Dockerfile used in an earlier containerized serving approach has been archived. The current production frontend is deployed as static assets through Cloudflare Pages.

---

## Data Source

The current frontend uses Supabase REST when configured with:

```javascript
window.APP_CONFIG = {
    SUPABASE_URL: "<supabase-url>",
    SUPABASE_ANON_KEY: "<supabase-anon-key>"
};
```

Only the Supabase anon/public key should be used in browser code.

Never expose the Supabase secret key in frontend files.

---

## Public API Views Used

The frontend reads from these Supabase views:

| View | Purpose |
|---|---|
| `api_worlds` | World selector |
| `api_guilds` | Guild selector |
| `api_snapshot_date_bounds_by_guild` | Date filter bounds |
| `api_guild_overview_by_snapshot` | Guild overview metrics |
| `api_historical_character_level_changes` | Level changes and time online |
| `api_historical_guild_joins` | Guild joins |
| `api_historical_guild_leaves` | Guild leaves |
| `api_historical_rank_changes` | Rank changes |
| `api_latest_guild_members` | Latest guild roster and last-connected estimate |

The frontend does not query raw database tables directly. The public API views provide a stable contract between the UI and the database.

---

## Dashboard Sections

The dashboard includes:

- Guild Overview
- Analysis by Vocation
- Level Changes and Time Online
- Guild Joins / Leaves
- Rank Changes
- Guild Members

The Guild Overview remains visible at the top. The analytical sections are organized into tabs for easier navigation.

---

## Key Frontend Behavior

### Guild Overview

Displays the latest summary metrics for the selected guild and world:

- Latest refresh age
- Member count
- Maximum level
- Minimum level
- Average level

### Analysis by Vocation

Uses the latest guild roster to show:

- Vocation distribution chart
- Character/vocation/level table
- Level range filter
- Multi-select vocation filter

Promoted and non-promoted vocations are normalized into base vocations:

| Source vocations | Base vocation |
|---|---|
| Monk variants | Monk |
| Knight / Elite Knight | Knight |
| Paladin / Royal Paladin | Paladin |
| Druid / Elder Druid | Druid |
| Sorcerer / Master Sorcerer | Sorcerer |

### Level Changes and Time Online

Displays detected character level changes and estimated observed online time within the selected date range.

### Guild Joins / Leaves

Displays detected guild movement events based on consecutive roster snapshots.

### Rank Changes

Displays detected guild-rank changes and the date the change was observed.

### Guild Members

Displays the latest cached roster for the selected guild, including current level and last-connected estimate.

---

## Local Development

From the project root:

```bash
cd frontend
python3 -m http.server 3000
```

Open:

```text
http://127.0.0.1:3000
```

Hard refresh after JavaScript or CSS changes:

```text
Cmd + Shift + R
```

---

## Configuration Notes

For local development, `config.js` should point to the appropriate Supabase project and use the anon/public key.

Example:

```javascript
window.APP_CONFIG = {
    SUPABASE_URL: "https://<project-ref>.supabase.co",
    SUPABASE_ANON_KEY: "<anon-public-key>"
};
```

Do not commit secrets.

---

## Legacy Note

Earlier versions of this frontend supported calling a local FastAPI backend. That backend is now archived and is not part of the current production architecture.

The current production frontend reads directly from Supabase REST API views.
