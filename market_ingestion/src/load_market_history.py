import os
from datetime import datetime, timezone

import psycopg

from tibiamarket_client import get_item_history


DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "tibia_analytics")
DB_USER = os.getenv("DB_USER", "tibia_user")
DB_PASSWORD = os.getenv("DB_PASSWORD")


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


def load_market_history(
    server,
    item_id,
    start_days_ago=365,
    end_days_ago=-1
):
    """
    Retrieve and load valid market price observations into PostgreSQL.

    Only complete market snapshots containing valid buy and sell offers
    are stored.

    Args:
        server (str): Tibia game world name.
        item_id (int): Tibia item identifier.
        start_days_ago (int): Number of days in the past to start the query.
        end_days_ago (int): Number of days in the past to end the query.
    """
    if not DB_PASSWORD:
        raise ValueError(
            "DB_PASSWORD environment variable is not set."
        )

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

    with psycopg.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    ) as conn:

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


if __name__ == "__main__":
    load_market_history(
        server="Lobera",
        item_id=34152,
        start_days_ago=365,
        end_days_ago=-1
    )