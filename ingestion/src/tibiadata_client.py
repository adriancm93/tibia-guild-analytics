import requests


class TibiaDataClient:
    """Small client for the TibiaData API."""

    def __init__(self, base_url: str = "https://api.tibiadata.com/v4"):
        self.base_url = base_url.rstrip("/")

    def _get(self, path: str) -> dict:
        """Run a GET request against TibiaData."""
        url = f"{self.base_url}/{path.lstrip('/')}"

        response = requests.get(url, timeout=30)
        response.raise_for_status()

        return response.json()

    def get_worlds(self) -> dict:
        """Pull all Tibia worlds from TibiaData."""
        return self._get("/worlds")

    def get_guilds_by_world(self, world: str) -> dict:
        """Pull guild list for a specific world from TibiaData."""
        return self._get(f"/guilds/{world}")

    def get_guild(self, guild_name: str) -> dict:
        """
        Pull detailed guild information from TibiaData.

        Example endpoint:
        https://api.tibiadata.com/v4/guild/Black%20Clover
        """
        return self._get(f"/guild/{guild_name}")