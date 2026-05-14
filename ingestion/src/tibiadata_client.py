import requests


class TibiaDataClient:
    """Small client for the TibiaData API."""

    def __init__(self, base_url: str = "https://api.tibiadata.com/v4"):
        self.base_url = base_url.rstrip("/")

    def get_guild(self, guild_name: str) -> dict:
        """
        Pull detailed guild information from TibiaData.

        Example endpoint:
        https://api.tibiadata.com/v4/guild/Black%20Clover
        """
        url = f"{self.base_url}/guild/{guild_name}"

        response = requests.get(url, timeout=30)
        response.raise_for_status()

        return response.json()