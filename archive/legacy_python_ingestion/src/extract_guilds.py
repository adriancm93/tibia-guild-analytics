from tibiadata_client import TibiaDataClient


def extract_guilds_by_world(world: str) -> dict:
    """Extract all guilds for a specific world from the TibiaData API."""
    client = TibiaDataClient()
    return client.get_guilds_by_world(world)