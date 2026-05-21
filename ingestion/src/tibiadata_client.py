import requests


class TibiaDataClient:
    """Small client for the TibiaData API."""

    def __init__(self, base_url: str = "https://api.tibiadata.com/v4"):
        self.base_url = base_url.rstrip("/")

    def _get(self, path: str) -> dict:
        """Run a GET request against TibiaData with simple retry handling."""
        import time

        url = f"{self.base_url}/{path.lstrip('/')}"
        max_attempts = 3

        for attempt in range(1, max_attempts + 1):
            try:
                response = requests.get(url, timeout=30)

                if response.status_code in [502, 503, 504]:
                    raise requests.exceptions.HTTPError(
                        f"{response.status_code} Server Error for url: {url}",
                        response=response,
                    )

                response.raise_for_status()
                return response.json()

            except requests.exceptions.RequestException:
                if attempt == max_attempts:
                    raise

                wait_seconds = attempt * 3
                print(
                    f"Request failed for {url}. "
                    f"Retrying in {wait_seconds} seconds... "
                    f"Attempt {attempt}/{max_attempts}"
                )
                time.sleep(wait_seconds)

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