from tibiadata_client import TibiaDataClient


def extract_guild(guild_name: str) -> dict:
    """Extract guild data from the TibiaData API."""
    client = TibiaDataClient()
    return client.get_guild(guild_name)