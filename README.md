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

## Status
Project initialized. First milestone: extract guild roster and save the first raw JSON snapshot.