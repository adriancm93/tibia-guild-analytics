# Ingestion Utilities

This folder contains Python utilities used during development and administrative workflows.

Production ingestion currently runs through the Supabase Edge Function in:

```text
supabase/functions/refresh-guilds/
```

The Python ingestion code is retained for:

- Local experimentation
- Manual extraction tests
- World/guild metadata discovery
- Debugging API responses
- Historical project context

---

## Current Production Ingestion

Production ingestion is handled by:

```text
Supabase Cron
        ↓
Supabase Edge Function
        ↓
Supabase Postgres
```

The Python scripts are not the production scheduler.

---

## Typical Local Setup

Create and activate a virtual environment:

```bash
python3 -m venv ingestion/.venv
source ingestion/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r ingestion/requirements.txt
```

---

## Environment

Local scripts can use `.env` or `.env.supabase`.

Do not commit real environment files.

---

## Notes

Some scripts in this folder may reflect earlier phases of the project. The authoritative production ingestion path is the Supabase Edge Function.
