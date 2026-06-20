from tibiadata_client import TibiaDataClient


def extract_worlds() -> dict:
    """Extract all worlds from the TibiaData API."""
    client = TibiaDataClient()
    return client.get_worlds()