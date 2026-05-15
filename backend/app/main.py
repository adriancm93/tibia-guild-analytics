from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import fetch_all


app = FastAPI(
    title="Tibia Guild Analytics API",
    description="API for Tibia guild snapshot analytics.",
    version="0.1.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For local development. We will restrict this later.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root() -> dict:
    return {
        "message": "Tibia Guild Analytics API is running",
        "docs": "/docs",
    }


@app.get("/api/health")
def health_check() -> dict:
    return {
        "status": "ok",
    }


@app.get("/api/snapshot-pairs")
def get_snapshot_pairs() -> list[dict]:
    return fetch_all("""
        SELECT
            extracted_at_utc,
            snapshot_rank
        FROM analytics.snapshot_pairs
        ORDER BY snapshot_rank;
    """)


@app.get("/api/level-changes")
def get_level_changes() -> list[dict]:
    return fetch_all("""
        SELECT
            character_name,
            vocation,
            guild_rank,
            previous_level,
            current_level,
            level_gain,
            previous_snapshot_time,
            latest_snapshot_time
        FROM analytics.character_level_changes
        ORDER BY level_gain DESC, current_level DESC;
    """)


@app.get("/api/guild-joins")
def get_guild_joins() -> list[dict]:
    return fetch_all("""
        SELECT
            character_name,
            vocation,
            level,
            guild_rank,
            status,
            joined_date,
            latest_snapshot_time
        FROM analytics.guild_joins
        ORDER BY level DESC, character_name;
    """)


@app.get("/api/guild-leaves")
def get_guild_leaves() -> list[dict]:
    return fetch_all("""
        SELECT
            character_name,
            vocation,
            level,
            guild_rank,
            status,
            joined_date,
            previous_snapshot_time
        FROM analytics.guild_leaves
        ORDER BY level DESC, character_name;
    """)


@app.get("/api/rank-changes")
def get_rank_changes() -> list[dict]:
    return fetch_all("""
        SELECT
            character_name,
            previous_guild_rank,
            current_guild_rank,
            previous_snapshot_time,
            latest_snapshot_time
        FROM analytics.rank_changes
        ORDER BY character_name;
    """)