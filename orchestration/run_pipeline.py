"""
Phase 6 Pipeline Runner

Runs the Tibia Guild Analytics pipeline in order:

1. Extract latest guild data
2. Load latest snapshot into Postgres
3. Refresh staging and analytics views
4. Run validation SQL checks
"""

import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]

POSTGRES_CONTAINER = "tibia_guild_postgres"
POSTGRES_USER = "tibia_user"
POSTGRES_DB = "tibia_analytics"


PYTHON_STEPS = [
    {
        "name": "Extract latest Tibia guild data",
        "script": PROJECT_ROOT / "ingestion" / "src" / "main.py",
    },
    {
        "name": "Load latest snapshot into Postgres",
        "script": PROJECT_ROOT / "ingestion" / "src" / "load_postgres.py",
    },
]


SQL_STEPS = [
    {
        "name": "Refresh staging views",
        "file": PROJECT_ROOT / "database" / "init" / "003_create_staging_views.sql",
    },
    {
        "name": "Refresh analytics views",
        "file": PROJECT_ROOT / "database" / "init" / "004_create_analytics_views.sql",
    },
    {
        "name": "Refresh snapshot comparison views",
        "file": PROJECT_ROOT / "database" / "init" / "005_create_snapshot_comparison_views.sql",
    },
    {
        "name": "Run pipeline validation checks",
        "file": PROJECT_ROOT / "database" / "validation" / "001_validate_guild_snapshot_pipeline.sql",
    },
    {
        "name": "Run Phase 4 analytics validation checks",
        "file": PROJECT_ROOT / "database" / "validation" / "validate_phase_4_analytics_views.sql",
    },
]


def run_command(command: list[str], step_name: str) -> None:
    print(f"\n=== {step_name} ===")
    print("Running:", " ".join(command))

    result = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        text=True,
        capture_output=True,
    )

    if result.stdout:
        print(result.stdout)

    if result.stderr:
        print(result.stderr)

    if result.returncode != 0:
        raise RuntimeError(f"Step failed: {step_name}")


def run_python_step(step: dict) -> None:
    script_path = step["script"]

    if not script_path.exists():
        raise FileNotFoundError(f"Python script not found: {script_path}")

    run_command(
        [sys.executable, str(script_path)],
        step["name"],
    )


def run_sql_step(step: dict) -> None:
    sql_file = step["file"]

    if not sql_file.exists():
        raise FileNotFoundError(f"SQL file not found: {sql_file}")

    print(f"\n=== {step['name']} ===")
    print(f"Running SQL file: {sql_file}")

    with sql_file.open("r", encoding="utf-8") as file:
        result = subprocess.run(
            [
                "docker",
                "exec",
                "-i",
                POSTGRES_CONTAINER,
                "psql",
                "-U",
                POSTGRES_USER,
                "-d",
                POSTGRES_DB,
            ],
            stdin=file,
            cwd=PROJECT_ROOT,
            text=True,
            capture_output=True,
        )

    if result.stdout:
        print(result.stdout)

    if result.stderr:
        print(result.stderr)

    if result.returncode != 0:
        raise RuntimeError(f"Step failed: {step['name']}")


def main() -> None:
    print("Starting Tibia Guild Analytics pipeline...")
    print(f"Project root: {PROJECT_ROOT}")

    for step in PYTHON_STEPS:
        run_python_step(step)

    for step in SQL_STEPS:
        run_sql_step(step)

    print("\nPipeline completed successfully.")


if __name__ == "__main__":
    main()