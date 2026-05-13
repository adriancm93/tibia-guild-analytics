import os
from dotenv import load_dotenv


def main():
    load_dotenv()

    guild_name = os.getenv("TIBIA_GUILD_NAME")
    world = os.getenv("TIBIA_WORLD")
    raw_data_dir = os.getenv("RAW_DATA_DIR")

    print("Tibia Guild Analytics - Ingestion Test")
    print(f"Guild Name: {guild_name}")
    print(f"World: {world}")
    print(f"Raw Data Directory: {raw_data_dir}")


if __name__ == "__main__":
    main()