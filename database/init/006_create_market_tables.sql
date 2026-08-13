-- ============================================================
-- Tibia Guild Analytics
-- Market Analytics tables
--
-- This script creates the core tables used to store:
-- 1. Tibia item metadata.
-- 2. Historical market price observations by world and item.
-- ============================================================


-- ============================================================
-- Table: market_items
--
-- Stores item metadata retrieved from the TibiaMarket API.
-- Each Tibia item is uniquely identified by item_id.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.market_items (
    item_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    tier INTEGER,
    npc_sell JSONB,
    npc_buy JSONB,
    wiki_name TEXT,
    updated_at_utc TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================
-- Table: market_price_history
--
-- Stores historical market observations for each item/world.
--
-- Each row represents one observation returned by the
-- TibiaMarket item history endpoint.
--
-- Invalid source values such as -1 or 0 should be handled
-- during ingestion rather than stored as valid prices.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.market_price_history (
    id BIGSERIAL PRIMARY KEY,

    world TEXT NOT NULL,
    item_id INTEGER NOT NULL,

    observed_at_utc TIMESTAMPTZ NOT NULL,

    buy_offer BIGINT,
    sell_offer BIGINT,

    loaded_at_utc TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_market_price_history_item
        FOREIGN KEY (item_id)
        REFERENCES public.market_items(item_id),

    CONSTRAINT uq_market_price_history
        UNIQUE (
            world,
            item_id,
            observed_at_utc
        )
);


-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_market_price_history_world_item_time
ON public.market_price_history (
    world,
    item_id,
    observed_at_utc
);


CREATE INDEX IF NOT EXISTS idx_market_items_name
ON public.market_items (
    name
);