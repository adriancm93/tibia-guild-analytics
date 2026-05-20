import os
import sys
import traceback
from datetime import datetime, timezone
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from extract_guild import extract_guild
from load_raw_local import save_raw_json
from load_postgres import load_latest_snapshot_to_postgres


def get_database_engine() -> Engine:
    """Create a SQLAlchemy engine from environment variables."""
    load_dotenv()

    host = os.getenv("POSTGRES_HOST")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB")
    user = os.getenv("POSTGRES_USER")
    password = os.getenv("POSTGRES_PASSWORD")

    if not all([host, port, database, user, password]):
        raise ValueError("Missing one or more required Postgres environment variables.")

    database_url = f"postgresql+psycopg://{user}:{password}@{host}:{port}/{database}"
    return create_engine(database_url)


def get_batch_size() -> int:
    """Read batch size from env, defaulting to 5."""
    value = os.getenv("GUILD_BATCH_SIZE", "5")
    return int(value)


def get_due_guilds(engine: Engine, batch_size: int) -> list[dict[str, Any]]:
    """
    Select guilds that are due for refresh.

    Uses FOR UPDATE SKIP LOCKED so future parallel/concurrent jobs do not select
    the same guilds at the same time.
    """
    with engine.begin() as connection:
        rows = connection.execute(
            text(
                """
                SELECT
                    guild_id,
                    guild_name,
                    world
                FROM tibia_guild
                WHERE is_active = true
                  AND (
                        next_refresh_after_utc IS NULL
                        OR next_refresh_after_utc <= now()
                  )
                ORDER BY
                    refresh_priority ASC,
                    COALESCE(next_refresh_after_utc, timestamp with time zone '1970-01-01') ASC,
                    world ASC,
                    guild_name ASC
                LIMIT :batch_size
                FOR UPDATE SKIP LOCKED;
                """
            ),
            {"batch_size": batch_size},
        ).mappings().all()

        guilds = [dict(row) for row in rows]

        for guild in guilds:
            connection.execute(
                text(
                    """
                    UPDATE tibia_guild
                    SET
                        last_refresh_started_at_utc = now(),
                        last_refresh_status = 'running',
                        last_refresh_error = NULL,
                        updated_at_utc = now()
                    WHERE guild_id = :guild_id;
                    """
                ),
                {"guild_id": guild["guild_id"]},
            )

    return guilds


def mark_guild_success(engine: Engine, guild_id: str) -> None:
    """Mark a guild refresh as successful and schedule the next refresh."""
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                UPDATE tibia_guild
                SET
                    last_refresh_completed_at_utc = now(),
                    last_refresh_status = 'success',
                    last_refresh_error = NULL,
                    next_refresh_after_utc =
                        now() + make_interval(mins => refresh_interval_minutes),
                    updated_at_utc = now()
                WHERE guild_id = :guild_id;
                """
            ),
            {"guild_id": guild_id},
        )


def mark_guild_failure(engine: Engine, guild_id: str, error_message: str) -> None:
    """
    Mark a guild refresh as failed.

    Failed guilds are retried later instead of immediately blocking every run.
    """
    trimmed_error = error_message[:1000]

    with engine.begin() as connection:
        connection.execute(
            text(
                """
                UPDATE tibia_guild
                SET
                    last_refresh_completed_at_utc = now(),
                    last_refresh_status = 'failed',
                    last_refresh_error = :error_message,
                    next_refresh_after_utc = now() + interval '30 minutes',
                    updated_at_utc = now()
                WHERE guild_id = :guild_id;
                """
            ),
            {
                "guild_id": guild_id,
                "error_message": trimmed_error,
            },
        )


def apply_retention(engine: Engine) -> None:
    """Apply 3-month snapshot retention."""
    with engine.begin() as connection:
        deleted_count = connection.execute(
            text(
                """
                SELECT public.apply_snapshot_retention(interval '3 months') AS deleted_snapshots;
                """
            )
        ).scalar_one()

    print(f"Retention applied. Deleted raw snapshots: {deleted_count}")


def refresh_one_guild(engine: Engine, guild: dict[str, Any]) -> None:
    """Extract and load one guild snapshot."""
    guild_name = guild["guild_name"]
    world = guild["world"]

    print(f"Refreshing guild: {guild_name} / {world}")

    os.environ["TIBIA_GUILD_NAME"] = guild_name
    os.environ["TIBIA_WORLD"] = world

    payload = extract_guild(guild_name)

    raw_data_dir = os.getenv("RAW_DATA_DIR", "data/raw")

    save_raw_json(
        data=payload,
        raw_data_dir=raw_data_dir,
        entity_name=guild_name,
    )

    load_latest_snapshot_to_postgres()

    mark_guild_success(engine, guild["guild_id"])

    print(f"Success: {guild_name} / {world}")


def run_batch_guild_ingestion() -> None:
    """Run a batch of due guild refreshes."""
    engine = get_database_engine()
    batch_size = get_batch_size()

    print(f"Starting batch guild ingestion. Batch size: {batch_size}")

    due_guilds = get_due_guilds(engine, batch_size)

    if not due_guilds:
        print("No due guilds found.")
        apply_retention(engine)
        return

    print(f"Found {len(due_guilds)} due guilds.")

    success_count = 0
    failure_count = 0

    for guild in due_guilds:
        try:
            refresh_one_guild(engine, guild)
            success_count += 1
        except Exception as error:
            failure_count += 1

            print(f"Failed: {guild['guild_name']} / {guild['world']}")
            print(error)
            traceback.print_exc()

            mark_guild_failure(
                engine=engine,
                guild_id=guild["guild_id"],
                error_message=str(error),
            )

    apply_retention(engine)

    print(
        "Batch guild ingestion complete. "
        f"Success: {success_count}. Failed: {failure_count}."
    )


if __name__ == "__main__":
    try:
        run_batch_guild_ingestion()
    except Exception as error:
        print(f"Batch ingestion failed: {error}")
        traceback.print_exc()
        sys.exit(1)