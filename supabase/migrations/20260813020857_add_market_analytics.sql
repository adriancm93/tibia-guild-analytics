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

CREATE OR REPLACE VIEW public.api_market_items AS
SELECT
    item_id,
    name,
    category,
    tier,
    wiki_name
FROM public.market_items;


CREATE OR REPLACE VIEW public.api_market_history AS
SELECT
    h.world,
    h.item_id,
    i.wiki_name AS item_name,
    h.observed_at_utc,
    h.buy_offer,
    h.sell_offer,

    h.sell_offer - h.buy_offer AS spread,

    ROUND(
        (
            (h.sell_offer - h.buy_offer)::NUMERIC
            / NULLIF(h.buy_offer, 0)
        ) * 100,
        2
    ) AS spread_pct

FROM public.market_price_history AS h

INNER JOIN public.market_items AS i
    ON h.item_id = i.item_id;