-- ============================================================
-- Normalize market price history to one observation per day.
-- ============================================================

ALTER TABLE public.market_price_history
ADD COLUMN IF NOT EXISTS observed_date DATE;


UPDATE public.market_price_history
SET observed_date = observed_at_utc::DATE
WHERE observed_date IS NULL;


ALTER TABLE public.market_price_history
ALTER COLUMN observed_date SET NOT NULL;


-- Keep the most recently loaded row for each world, item, and date.
DELETE FROM public.market_price_history AS older
USING public.market_price_history AS newer
WHERE older.world = newer.world
  AND older.item_id = newer.item_id
  AND older.observed_date = newer.observed_date
  AND (
      older.loaded_at_utc < newer.loaded_at_utc
      OR (
          older.loaded_at_utc = newer.loaded_at_utc
          AND older.id < newer.id
      )
  );


ALTER TABLE public.market_price_history
DROP CONSTRAINT IF EXISTS uq_market_price_history;


ALTER TABLE public.market_price_history
ADD CONSTRAINT uq_market_price_history_daily
UNIQUE (
    world,
    item_id,
    observed_date
);


CREATE INDEX IF NOT EXISTS idx_market_price_history_daily
ON public.market_price_history (
    world,
    item_id,
    observed_date
);