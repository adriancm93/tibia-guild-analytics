import json
import os

import psycopg

from tibiamarket_client import get_item_metadata


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "tibia_analytics")
DB_USER = os.getenv("DB_USER", "tibia_user")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DATABASE_URL = os.getenv("DATABASE_URL")

def load_market_items():
    """
    Retrieve Tibia item metadata from the TibiaMarket API
    and upsert the records into PostgreSQL.
    """
    if not DATABASE_URL and not DB_PASSWORD:
        raise ValueError(
            "Neither DATABASE_URL nor DB_PASSWORD is set."
        )

    items = get_item_metadata()

    print(f"Items retrieved from API: {len(items)}")

    upsert_sql = """
        INSERT INTO public.market_items (
            item_id,
            name,
            category,
            tier,
            npc_sell,
            npc_buy,
            wiki_name,
            updated_at_utc
        )
        VALUES (
            %(item_id)s,
            %(name)s,
            %(category)s,
            %(tier)s,
            %(npc_sell)s::jsonb,
            %(npc_buy)s::jsonb,
            %(wiki_name)s,
            NOW()
        )
        ON CONFLICT (item_id)
        DO UPDATE SET
            name = EXCLUDED.name,
            category = EXCLUDED.category,
            tier = EXCLUDED.tier,
            npc_sell = EXCLUDED.npc_sell,
            npc_buy = EXCLUDED.npc_buy,
            wiki_name = EXCLUDED.wiki_name,
            updated_at_utc = NOW();
    """

    if DATABASE_URL:
        conn = psycopg.connect(DATABASE_URL)
    else:
        conn = psycopg.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )

    records = [
        {
            "item_id": item["id"],
            "name": item["name"],
            "category": item.get("category"),
            "tier": item.get("tier"),
            "npc_sell": json.dumps(item.get("npc_sell", [])),
            "npc_buy": json.dumps(item.get("npc_buy", [])),
            "wiki_name": item.get("wiki_name"),
        }
        for item in items
    ]

    print(f"Preparing to upsert {len(records)} items...")

    with conn.cursor() as cur:
        cur.executemany(
            upsert_sql,
            records
        )

    print("Upsert completed. Committing transaction...")

    conn.commit()

    print("Market item metadata loaded successfully.")


if __name__ == "__main__":
    load_market_items()