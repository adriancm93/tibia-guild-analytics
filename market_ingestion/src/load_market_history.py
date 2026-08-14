import os
from datetime import datetime, timezone

import psycopg

from tibiamarket_client import get_item_history


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "tibia_analytics")
DB_USER = os.getenv("DB_USER", "tibia_user")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DATABASE_URL = os.getenv("DATABASE_URL")

def unix_timestamp_to_utc(timestamp):
    """
    Convert a Unix timestamp to a timezone-aware UTC datetime.

    Args:
        timestamp (float): Unix timestamp returned by the TibiaMarket API.

    Returns:
        datetime: Timezone-aware UTC datetime.
    """
    return datetime.fromtimestamp(
        timestamp,
        tz=timezone.utc
    )

def get_item_id_by_name(conn, item_name):
    """
    Resolve a Tibia item ID from the local market item catalog.

    Args:
        conn: Active PostgreSQL connection.
        item_name (str): Item name to search for.

    Returns:
        int: Tibia item identifier.

    Raises:
        ValueError: If the item cannot be found or the name is ambiguous.
    """
    query = """
        SELECT item_id, name, wiki_name
        FROM public.market_items
        WHERE LOWER(name) = LOWER(%s)
           OR LOWER(wiki_name) = LOWER(%s);
    """

    with conn.cursor() as cur:
        cur.execute(query, (item_name, item_name))
        matches = cur.fetchall()

    if not matches:
        raise ValueError(
            f"Item not found in market_items: {item_name}"
        )

    if len(matches) > 1:
        match_details = ", ".join(
            f"{row[0]} ({row[2]})"
            for row in matches
        )

        raise ValueError(
            f"Multiple items matched '{item_name}': {match_details}"
        )

    return matches[0][0]

def load_market_history(
    server,
    item_name,
    start_days_ago=365,
    end_days_ago=-1
):
    """
    Retrieve and load valid market price observations into PostgreSQL.

    Args:
        server (str): Tibia game world name.
        item_name (str): Tibia item name.
        start_days_ago (int): Number of days in the past to start the query.
        end_days_ago (int): Number of days in the past to end the query.
    """
    if not DATABASE_URL and not DB_PASSWORD:
        raise ValueError(
            "Neither DATABASE_URL nor DB_PASSWORD is set."
        )

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

    with conn:

        item_id = get_item_id_by_name(
            conn,
            item_name
        )

        print(f"Item: {item_name}")
        print(f"Item ID: {item_id}")
        print(f"Server: {server}")

        history = get_item_history(
            server=server,
            item_id=item_id,
            start_days_ago=start_days_ago,
            end_days_ago=end_days_ago
        )

        print(f"Rows retrieved from API: {len(history)}")

        valid_rows = [
            row
            for row in history
            if row.get("is_full_data") is True
            and row.get("buy_offer", -1) > 0
            and row.get("sell_offer", -1) > 0
        ]

        print(f"Valid market observations: {len(valid_rows)}")

        upsert_sql = """
            INSERT INTO public.market_price_history (
                world,
                item_id,
                observed_at_utc,
                buy_offer,
                sell_offer,
                loaded_at_utc
            )
            VALUES (
                %(world)s,
                %(item_id)s,
                %(observed_at_utc)s,
                %(buy_offer)s,
                %(sell_offer)s,
                NOW()
            )
            ON CONFLICT (
                world,
                item_id,
                observed_at_utc
            )
            DO UPDATE SET
                buy_offer = EXCLUDED.buy_offer,
                sell_offer = EXCLUDED.sell_offer,
                loaded_at_utc = NOW();
        """

        with conn.cursor() as cur:
            for row in valid_rows:
                cur.execute(
                    upsert_sql,
                    {
                        "world": server,
                        "item_id": item_id,
                        "observed_at_utc": unix_timestamp_to_utc(
                            row["time"]
                        ),
                        "buy_offer": row["buy_offer"],
                        "sell_offer": row["sell_offer"],
                    }
                )

        conn.commit()

    print("Market price history loaded successfully.")


import argparse


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Load Tibia market price history into PostgreSQL."
    )

    parser.add_argument(
        "--world",
        required=True,
        help="Tibia world name."
    )

    parser.add_argument(
        "--item",
        required=True,
        help="Tibia item name."
    )

    parser.add_argument(
        "--days",
        type=int,
        default=365,
        help="Number of days of history to retrieve."
    )

    args = parser.parse_args()

    load_market_history(
        server=args.world,
        item_name=args.item,
        start_days_ago=args.days,
        end_days_ago=-1
    )