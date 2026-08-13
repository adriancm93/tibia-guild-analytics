-- ============================================================
-- Tibia Guild Analytics
-- Market Analytics API views
--
-- These views expose market item metadata and historical
-- market prices in a frontend-friendly structure.
-- ============================================================


-- ============================================================
-- View: api_market_items
--
-- Provides searchable item metadata for the Market Analytics
-- item selector.
-- ============================================================

CREATE OR REPLACE VIEW public.api_market_items AS
SELECT
    item_id,
    name,
    category,
    tier,
    wiki_name
FROM public.market_items;


-- ============================================================
-- View: api_market_history
--
-- Provides historical buy/sell market prices together with
-- derived spread metrics.
--
-- Spread percentage is calculated relative to the best
-- available buy offer.
-- ============================================================

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