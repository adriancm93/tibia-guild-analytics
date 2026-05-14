import json
import os
import uuid
from pathlib import Path
from typing import Any
import polars as pl
from datetime import datetime
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine


def get_project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_environment() -> None:
    project_root = get_project_root()
    env_path = project_root / ".env"
    load_dotenv(env_path)


def get_postgres_engine() -> Engine:
    load_environment()

    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB", "tibia_analytics")
    user = os.getenv("POSTGRES_USER", "tibia_user")
    password = os.getenv("POSTGRES_PASSWORD", "tibia_password")

    connection_url = (
        f"postgresql+psycopg://{user}:{password}@{host}:{port}/{database}"
    )

    return create_engine(connection_url)


def find_latest_raw_guild_snapshot() -> Path:
    project_root = get_project_root()
    raw_guild_dir = project_root / "data" / "raw" / "tibiadata" / "guild"

    snapshot_files = sorted(raw_guild_dir.rglob("*.json"))

    if not snapshot_files:
        raise FileNotFoundError(
            f"No raw guild snapshot files found under: {raw_guild_dir}"
        )

    return snapshot_files[-1]


def read_raw_snapshot(snapshot_path: Path) -> dict[str, Any]:
    with snapshot_path.open("r", encoding="utf-8") as file:
        return json.load(file)

def parse_joined_date(joined_value: str | None) -> str | None:
    """
    Convert TibiaData joined date strings to YYYY-MM-DD.

    Example input:
    'May 13 2024'

    If parsing fails, return None so the database load does not break.
    """
    if not joined_value:
        return None

    try:
        return datetime.strptime(joined_value, "%b %d %Y").date().isoformat()
    except ValueError:
        return None
    
def extract_member_rows(
    snapshot_id: str,
    extracted_at_utc: str,
    guild_name: str,
    guild_data: dict[str, Any],
) -> list[dict[str, Any]]:
    guild = guild_data.get("guild", {})
    world = guild.get("world")
    members = guild.get("members", [])

    rows = []

    for member in members:
        rows.append(
            {
                "snapshot_id": snapshot_id,
                "extracted_at_utc": extracted_at_utc,
                "guild_name": guild_name,
                "world": world,
                "character_name": member.get("name"),
                "guild_rank": member.get("rank"),
                "vocation": member.get("vocation"),
                "level": member.get("level"),
                "status": member.get("status"),
                "joined": parse_joined_date(member.get("joined")),
            }
        )

    return rows


def insert_raw_snapshot(
    engine: Engine,
    snapshot_id: str,
    guild_name: str,
    source: str,
    extracted_at_utc: str,
    raw_json: dict[str, Any],
) -> None:
    query = text(
        """
        INSERT INTO raw_guild_snapshot (
            snapshot_id,
            guild_name,
            source,
            extracted_at_utc,
            raw_json
        )
        VALUES (
            :snapshot_id,
            :guild_name,
            :source,
            :extracted_at_utc,
            CAST(:raw_json AS JSONB)
        )
        """
    )

    with engine.begin() as connection:
        connection.execute(
            query,
            {
                "snapshot_id": snapshot_id,
                "guild_name": guild_name,
                "source": source,
                "extracted_at_utc": extracted_at_utc,
                "raw_json": json.dumps(raw_json),
            },
        )


def insert_member_snapshot_rows(
    engine: Engine,
    member_rows: list[dict[str, Any]],
) -> None:
    if not member_rows:
        print("No member rows found to insert.")
        return

    query = text(
        """
        INSERT INTO guild_member_snapshot (
            snapshot_id,
            extracted_at_utc,
            guild_name,
            world,
            character_name,
            guild_rank,
            vocation,
            level,
            status,
            joined
        )
        VALUES (
            :snapshot_id,
            :extracted_at_utc,
            :guild_name,
            :world,
            :character_name,
            :guild_rank,
            :vocation,
            :level,
            :status,
            :joined
        )
        """
    )

    with engine.begin() as connection:
        connection.execute(query, member_rows)


def load_latest_snapshot_to_postgres() -> None:
    snapshot_path = find_latest_raw_guild_snapshot()
    payload = read_raw_snapshot(snapshot_path)

    metadata = payload["metadata"]
    guild_data = payload["data"]

    snapshot_id = str(uuid.uuid4())
    guild_name = metadata["entity_name"]
    source = metadata["source"]
    extracted_at_utc = metadata["extracted_at_utc"]

    print("Loading raw guild snapshot to PostgreSQL...")
    print(f"Snapshot file: {snapshot_path}")
    print(f"Snapshot ID: {snapshot_id}")
    print(f"Guild: {guild_name}")
    print(f"Extracted at UTC: {extracted_at_utc}")

    engine = get_postgres_engine()

    insert_raw_snapshot(
        engine=engine,
        snapshot_id=snapshot_id,
        guild_name=guild_name,
        source=source,
        extracted_at_utc=extracted_at_utc,
        raw_json=payload,
    )

    member_rows = extract_member_rows(
        snapshot_id=snapshot_id,
        extracted_at_utc=extracted_at_utc,
        guild_name=guild_name,
        guild_data=guild_data,
    )

    insert_member_snapshot_rows(
        engine=engine,
        member_rows=member_rows,
    )

    print("Snapshot loaded successfully.")
    print(f"Inserted member rows: {len(member_rows)}")


if __name__ == "__main__":
    load_latest_snapshot_to_postgres()