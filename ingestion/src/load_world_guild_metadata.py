import os
import time
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from extract_guilds import extract_guilds_by_world
from extract_worlds import extract_worlds


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


def extract_world_names(worlds_payload: dict[str, Any]) -> list[str]:
    """Extract world names from the TibiaData worlds payload."""
    worlds = worlds_payload.get("worlds", {}).get("regular_worlds", [])

    world_names = []

    for world in worlds:
        name = world.get("name")

        if name:
            world_names.append(name)

    return sorted(set(world_names))


def extract_guild_names(guilds_payload: dict[str, Any]) -> list[str]:
    """Extract guild names from the TibiaData guilds-by-world payload."""
    guilds = guilds_payload.get("guilds", {}).get("active", [])

    guild_names = []

    for guild in guilds:
        name = guild.get("name")

        if name:
            guild_names.append(name)

    return sorted(set(guild_names))


def upsert_worlds(engine: Engine, world_names: list[str]) -> None:
    """Insert or update discovered worlds."""
    if not world_names:
        print("No worlds found to upsert.")
        return

    with engine.begin() as connection:
        for world_name in world_names:
            connection.execute(
                text(
                    """
                    INSERT INTO tibia_world (
                        world_name,
                        is_active,
                        discovered_at_utc,
                        updated_at_utc
                    )
                    VALUES (
                        :world_name,
                        true,
                        now(),
                        now()
                    )
                    ON CONFLICT (world_name)
                    DO UPDATE SET
                        is_active = true,
                        updated_at_utc = now();
                    """
                ),
                {"world_name": world_name},
            )

    print(f"Upserted {len(world_names)} worlds.")


def upsert_guilds(engine: Engine, world: str, guild_names: list[str]) -> None:
    """Insert or update discovered guilds for one world."""
    if not guild_names:
        print(f"No guilds found to upsert for world: {world}")
        return

    with engine.begin() as connection:
        for guild_name in guild_names:
            connection.execute(
                text(
                    """
                    INSERT INTO tibia_guild (
                        guild_name,
                        world,
                        is_active,
                        refresh_interval_minutes,
                        next_refresh_after_utc,
                        last_refresh_status,
                        discovered_at_utc,
                        updated_at_utc
                    )
                    VALUES (
                        :guild_name,
                        :world,
                        true,
                        120,
                        now(),
                        'discovered',
                        now(),
                        now()
                    )
                    ON CONFLICT (world, guild_name)
                    DO UPDATE SET
                        is_active = true,
                        updated_at_utc = now();
                    """
                ),
                {
                    "guild_name": guild_name,
                    "world": world,
                },
            )

    print(f"Upserted {len(guild_names)} guilds for world: {world}")


def discover_worlds_and_guilds(
    max_worlds: int | None = None,
    sleep_seconds: float = 1.0,
) -> None:
    """
    Discover worlds and guilds, then load metadata into Postgres.

    max_worlds is useful for testing without scanning every world.
    """
    engine = get_database_engine()

    print("Extracting worlds...")
    worlds_payload = extract_worlds()
    world_names = extract_world_names(worlds_payload)

    if max_worlds is not None:
        world_names = world_names[:max_worlds]

    print(f"Found {len(world_names)} worlds.")

    upsert_worlds(engine, world_names)

    total_guilds = 0

    for index, world in enumerate(world_names, start=1):
        print(f"[{index}/{len(world_names)}] Extracting guilds for world: {world}")

        try:
            guilds_payload = extract_guilds_by_world(world)
            guild_names = extract_guild_names(guilds_payload)
            upsert_guilds(engine, world, guild_names)
            total_guilds += len(guild_names)
        except Exception as error:
            print(f"Failed to process world {world}: {error}")

        time.sleep(sleep_seconds)

    print(f"Discovery complete. Worlds: {len(world_names)}. Guilds: {total_guilds}.")


if __name__ == "__main__":
    max_worlds_value = os.getenv("DISCOVERY_MAX_WORLDS")

    max_worlds = int(max_worlds_value) if max_worlds_value else None

    discover_worlds_and_guilds(max_worlds=max_worlds)