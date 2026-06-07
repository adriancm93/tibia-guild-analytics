import os
from pathlib import Path

from dotenv import load_dotenv

from extract_guild import extract_guild
from load_raw_local import save_raw_json


def main() -> None:
    project_root = Path(__file__).resolve().parents[2]
    env_path = project_root / ".env"

    load_dotenv(env_path)

    guild_name = os.getenv("TIBIA_GUILD_NAME")
    raw_data_dir = os.getenv("RAW_DATA_DIR", "data/raw")

    if not guild_name:
        raise ValueError("Missing TIBIA_GUILD_NAME in .env file.")

    raw_data_path = project_root / raw_data_dir

    print("Starting Tibia guild ingestion...")
    print(f"Guild: {guild_name}")
    print(f"Raw data directory: {raw_data_path}")

    guild_data = extract_guild(guild_name)

    output_path = save_raw_json(
        data=guild_data,
        raw_data_dir=str(raw_data_path),
        entity_name=guild_name,
    )

    print("Guild snapshot saved successfully.")
    print(f"Output file: {output_path}")


if __name__ == "__main__":
    main()