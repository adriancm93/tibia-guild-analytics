import requests


BASE_URL = "https://api.tibiamarket.top"


def get_item_metadata():
    """
    Retrieve all Tibia item metadata from the TibiaMarket API.

    Returns:
        list[dict]: A list containing metadata for all available items.
    """
    response = requests.get(
        f"{BASE_URL}/item_metadata",
        timeout=30
    )

    response.raise_for_status()

    return response.json()


def get_item_history(
    server,
    item_id,
    start_days_ago=30,
    end_days_ago=-1
):
    """
    Retrieve historical market data for a Tibia item.

    Args:
        server (str): Tibia game world name.
        item_id (int): Tibia item identifier.
        start_days_ago (int): Number of days in the past to start the query.
        end_days_ago (int): Number of days in the past to end the query.

    Returns:
        list[dict]: Historical market observations for the item.
    """
    params = {
        "server": server,
        "item_id": item_id,
        "start_days_ago": start_days_ago,
        "end_days_ago": end_days_ago,
    }

    response = requests.get(
        f"{BASE_URL}/item_history",
        params=params,
        timeout=30
    )

    response.raise_for_status()

    return response.json()

if __name__ == "__main__":
    history = get_item_history(
        server="Lobera",
        item_id=34152,
        start_days_ago=365,
        end_days_ago=-1
    )

    print(f"History rows returned: {len(history)}")

    for row in history[:5]:
        print(row)