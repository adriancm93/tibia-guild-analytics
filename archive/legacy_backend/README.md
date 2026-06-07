# Backend API

FastAPI backend for the Tibia Guild Analytics project.

The backend exposes PostgreSQL analytics views as JSON endpoints for the future frontend website.

## Setup

From the project root:

```bash
python3 -m venv backend/.venv
source backend/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r backend/requirements.txt
```

## Environment Variables

The backend reads database configuration from the root `.env` file.

Required variables:

```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=tibia_analytics
POSTGRES_USER=tibia_user
POSTGRES_PASSWORD=your_password_here
```

Do not commit the real `.env` file.

## Run the API

Make sure the PostgreSQL Docker container is running.

From the project root:

```bash
source backend/.venv/bin/activate
uvicorn app.main:app --reload --app-dir backend
```

The API will run at:

```text
http://127.0.0.1:8000
```

Interactive API docs:

```text
http://127.0.0.1:8000/docs
```

## Endpoints

```text
GET /
GET /api/health
GET /api/summary
GET /api/snapshot-pairs
GET /api/level-changes
GET /api/guild-joins
GET /api/guild-leaves
GET /api/rank-changes
```

## Main Frontend Endpoint

The most useful endpoint for dashboard summary cards is:

```text
GET /api/summary
```

Example response:

```json
{
  "latest_snapshot_time": "2026-05-14T23:53:33.052680Z",
  "previous_snapshot_time": "2026-05-14T23:02:10.231618Z",
  "level_changes": 1,
  "guild_joins": 0,
  "guild_leaves": 0,
  "rank_changes": 0
}
```

## Notes

This API is currently configured for local development.

For production deployment, CORS settings, database credentials, and environment configuration should be reviewed and restricted.