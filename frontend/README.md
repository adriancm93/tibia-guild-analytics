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

The frontend is intentionally lightweight. Data transformation and performance optimization happen in PostgreSQL through cache tables and curated public API views.

---

## Main Files

| File | Purpose |
|---|---|
| `index.html` | Dashboard layout and sections |
| `styles.css` | Application styling |
| `app.js` | Data fetching, filtering, sorting, and rendering logic |
| `config.js` | Runtime configuration for Supabase access |
| `Dockerfile` | Optional local/containerized frontend serving |

---

## Data Source

The frontend uses Supabase REST when configured with:

```javascript
window.APP_CONFIG = {
    DATA_SOURCE: "supabase",
    SUPABASE_URL: "<supabase-url>",
    SUPABASE_ANON_KEY: "<supabase-anon-key>"
};
```

Only the Supabase anon/public key should be used in the browser.

Never expose the Supabase secret key in frontend code.

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
    DATA_SOURCE: "supabase",
    SUPABASE_URL: "https://<project-ref>.supabase.co",
    SUPABASE_ANON_KEY: "<anon-public-key>"
};
```

Do not commit secrets.

---

## Legacy Note

Earlier versions of this frontend called a local FastAPI backend. That is no longer the production architecture.

The current frontend reads directly from Supabase REST API views.
