-- ============================================================
-- Upsert market history while preserving existing valid offers.
-- ============================================================

CREATE OR REPLACE FUNCTION public.upsert_market_history_observation(
    p_world TEXT,
    p_item_id INTEGER,
    p_observed_at_utc TIMESTAMPTZ,
    p_observed_date DATE,
    p_buy_offer BIGINT,
    p_sell_offer BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.market_price_history (
        world,
        item_id,
        observed_at_utc,
        observed_date,
        buy_offer,
        sell_offer,
        loaded_at_utc
    )
    VALUES (
        p_world,
        p_item_id,
        p_observed_at_utc,
        p_observed_date,
        p_buy_offer,
        p_sell_offer,
        NOW()
    )
    ON CONFLICT (
        world,
        item_id,
        observed_date
    )
    DO UPDATE SET
        observed_at_utc = EXCLUDED.observed_at_utc,
        buy_offer = COALESCE(
            EXCLUDED.buy_offer,
            market_price_history.buy_offer
        ),
        sell_offer = COALESCE(
            EXCLUDED.sell_offer,
            market_price_history.sell_offer
        ),
        loaded_at_utc = NOW();
END;
$$;