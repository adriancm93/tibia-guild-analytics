# Pipeline Orchestration

This folder contains the local pipeline runner for the Tibia Guild Analytics project.

## Run the Pipeline

From the project root:

```bash
source ingestion/.venv/bin/activate
python orchestration/run_pipeline.py
```
## Pipeline Steps
The runner performs the following steps:

1- Extract latest Tibia guild data.
2- Load latest snapshot into PostgreSQL.
3- Refresh staging views.
4- Refresh analytics views.
5- Refresh snapshot comparison views.
6- Run pipeline validation checks.
7- Run Phase 4 analytics validation checks.

## Requirements

Before running the pipeline:

- Docker must be running.
- The PostgreSQL container must be running.
- The ingestion virtual environment must be activated.
- Ingestion dependencies must be installed.

## PostgreSQL Container

The script currently expects the PostgreSQL container name to be: tibia_guild_postgres
