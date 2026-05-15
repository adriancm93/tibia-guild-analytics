import os

import pandas as pd
import streamlit as st
from sqlalchemy import create_engine


st.set_page_config(
    page_title="Tibia Guild Analytics",
    page_icon="🛡️",
    layout="wide",
)


@st.cache_resource
def get_engine():
    db_user = os.getenv("POSTGRES_USER", "tibia_user")
    db_password = os.getenv("POSTGRES_PASSWORD", "tibia_password")
    db_host = os.getenv("POSTGRES_HOST", "localhost")
    db_port = os.getenv("POSTGRES_PORT", "5432")
    db_name = os.getenv("POSTGRES_DB", "tibia_analytics")

    connection_string = (
        f"postgresql+psycopg://{db_user}:{db_password}"
        f"@{db_host}:{db_port}/{db_name}"
    )

    return create_engine(connection_string)


@st.cache_data(ttl=300)
def read_sql(query: str) -> pd.DataFrame:
    engine = get_engine()
    return pd.read_sql(query, engine)


st.title("Tibia Guild Analytics")
st.caption("Snapshot comparison dashboard powered by PostgreSQL and Streamlit")

snapshot_pairs = read_sql("""
    SELECT
        extracted_at_utc,
        snapshot_rank
    FROM analytics.snapshot_pairs
    ORDER BY snapshot_rank
""")

level_changes = read_sql("""
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
    ORDER BY level_gain DESC, current_level DESC
""")

guild_joins = read_sql("""
    SELECT
        character_name,
        vocation,
        level,
        guild_rank,
        status,
        joined_date,
        latest_snapshot_time
    FROM analytics.guild_joins
    ORDER BY level DESC, character_name
""")

guild_leaves = read_sql("""
    SELECT
        character_name,
        vocation,
        level,
        guild_rank,
        status,
        joined_date,
        previous_snapshot_time
    FROM analytics.guild_leaves
    ORDER BY level DESC, character_name
""")

rank_changes = read_sql("""
    SELECT
        character_name,
        previous_guild_rank,
        current_guild_rank,
        previous_snapshot_time,
        latest_snapshot_time
    FROM analytics.rank_changes
    ORDER BY character_name
""")


latest_snapshot_time = snapshot_pairs.loc[
    snapshot_pairs["snapshot_rank"] == 1,
    "extracted_at_utc"
].iloc[0]

previous_snapshot_time = snapshot_pairs.loc[
    snapshot_pairs["snapshot_rank"] == 2,
    "extracted_at_utc"
].iloc[0]


st.subheader("Snapshot Window")

col1, col2 = st.columns(2)

with col1:
    st.metric("Latest Snapshot", str(latest_snapshot_time))

with col2:
    st.metric("Previous Snapshot", str(previous_snapshot_time))


st.subheader("Change Summary")

col1, col2, col3, col4 = st.columns(4)

with col1:
    st.metric("Level Changes", len(level_changes))

with col2:
    st.metric("Guild Joins", len(guild_joins))

with col3:
    st.metric("Guild Leaves", len(guild_leaves))

with col4:
    st.metric("Rank Changes", len(rank_changes))


st.subheader("Character Level Changes")

st.dataframe(
    level_changes,
    use_container_width=True,
    hide_index=True,
)

st.subheader("Guild Joins")

st.dataframe(
    guild_joins,
    use_container_width=True,
    hide_index=True,
)

st.subheader("Guild Leaves")

st.dataframe(
    guild_leaves,
    use_container_width=True,
    hide_index=True,
)

st.subheader("Rank Changes")

st.dataframe(
    rank_changes,
    use_container_width=True,
    hide_index=True,
)