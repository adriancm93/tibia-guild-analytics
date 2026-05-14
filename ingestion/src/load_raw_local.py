import json
from datetime import datetime, timezone
from pathlib import Path


def save_raw_json(data: dict, raw_data_dir: str, entity_name: str, source_name: str = "tibiadata") -> Path:
    """
    Save raw API response as a timestamped JSON file.

    Example path:
    data/raw/tibiadata/guild/2026/05/13/black_clover_20260513T223000Z.json
    """
    extracted_at = datetime.now(timezone.utc)
    date_path = extracted_at.strftime("%Y/%m/%d")
    timestamp = extracted_at.strftime("%Y%m%dT%H%M%SZ")

    safe_entity_name = entity_name.lower().replace(" ", "_")

    output_dir = Path(raw_data_dir) / source_name / "guild" / date_path
    output_dir.mkdir(parents=True, exist_ok=True)

    output_path = output_dir / f"{safe_entity_name}_{timestamp}.json"

    payload = {
        "metadata": {
            "source": source_name,
            "entity_type": "guild",
            "entity_name": entity_name,
            "extracted_at_utc": extracted_at.isoformat(),
        },
        "data": data,
    }

    with output_path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, ensure_ascii=False)

    return output_path