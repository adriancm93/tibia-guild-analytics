CREATE TABLE IF NOT EXISTS raw_guild_snapshot (
    snapshot_id UUID PRIMARY KEY,
    guild_name TEXT NOT NULL,
    source TEXT NOT NULL,
    extracted_at_utc TIMESTAMPTZ NOT NULL,
    raw_json JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS guild_member_snapshot (
    snapshot_id UUID NOT NULL,
    extracted_at_utc TIMESTAMPTZ NOT NULL,
    guild_name TEXT NOT NULL,
    world TEXT,
    character_name TEXT NOT NULL,
    guild_rank TEXT,
    vocation TEXT,
    level INTEGER,
    status TEXT,
    joined DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_guild_member_snapshot_raw
        FOREIGN KEY (snapshot_id)
        REFERENCES raw_guild_snapshot(snapshot_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_character_name
    ON guild_member_snapshot(character_name);

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_extracted_at
    ON guild_member_snapshot(extracted_at_utc);

CREATE INDEX IF NOT EXISTS idx_guild_member_snapshot_guild_name
    ON guild_member_snapshot(guild_name);