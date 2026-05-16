# Tibia Guild Analytics Platform

An end-to-end data engineering project that extracts Tibia guild member data from the TibiaData API, stores historical snapshots, calculates member activity metrics, and serves the data through a web application.

## Project Goals

- Extract guild roster and character statistics from the TibiaData API.
- Store raw API snapshots for historical tracking.
- Build curated analytics tables for guild and member metrics.
- Estimate member online activity and experience gains over time.
- Serve analytics through a Python FastAPI backend.
- Build a public-facing web application for guild statistics.
- Manage deployment and CI/CD through GitHub Actions.

## Initial Metrics

- Character name
- Guild rank
- Vocation
- Level
- World
- Online status
- Experience
- Experience gained over time
- Estimated hours online

## Architecture

TibiaData API
    ↓
Python ingestion
    ↓
Raw JSON snapshots
    ↓
PostgreSQL
    ↓
dbt transformations
    ↓
FastAPI backend
    ↓
Frontend website
    ↓
GitHub Actions CI/CD

## Project Structure
```text
tibia-guild-analytics/
├── ingestion/
├── backend/
├── transformations/
├── frontend/
├── infra/
└── .github/workflows/
```

## Running the Full Application with Docker

This project can run locally with Docker Compose.

The Docker stack includes:

```text
PostgreSQL database
FastAPI backend API
nginx frontend website
```

### Services

```text
postgres   -> PostgreSQL database
backend    -> FastAPI API service
frontend   -> Static HTML/CSS/JavaScript site served by nginx
```

### Local URLs

After starting the stack, the application is available at:

```text
Frontend website: http://localhost:3000
Backend API docs: http://localhost:8000/docs
PostgreSQL:       localhost:5432
```

### Start the Docker Stack

From the project root:

```bash
docker compose up --build
```

This builds and starts the database, backend, and frontend services.

### Stop the Docker Stack

Press `Ctrl + C` in the terminal running Docker Compose.

To stop and remove the containers:

```bash
docker compose down
```

### Preserve Database Data

The PostgreSQL service uses a named Docker volume:

```text
tibia_postgres_data
```

This keeps database data available between container restarts.

### Reset the Database

To fully reset the local PostgreSQL database and remove the saved volume:

```bash
docker compose down -v
docker compose up --build
```

Warning: this deletes the local PostgreSQL data volume and recreates the database from the SQL files in `database/init`.

### Environment Notes

For local Docker Compose, the backend connects to PostgreSQL using the Docker service name:

```env
POSTGRES_HOST=postgres
```

For local development outside Docker, the backend usually connects with:

```env
POSTGRES_HOST=localhost
```

### Useful Docker Commands

Check running services:

```bash
docker compose ps
```

View backend logs:

```bash
docker logs tibia_guild_backend
```

View frontend logs:

```bash
docker logs tibia_guild_frontend
```

View database logs:

```bash
docker logs tibia_guild_postgres
```

## Live Website

The deployed frontend is available at:

```text
https://YOUR-CLOUDFLARE-PAGES-URL.pages.dev
```