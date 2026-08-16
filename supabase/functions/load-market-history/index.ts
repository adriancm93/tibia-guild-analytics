import { createClient } from "@supabase/supabase-js";

type MarketHistoryRequest = {
  world?: string;
  item_id?: number;
  days?: number;
};

type TibiaMarketHistoryRow = {
  id?: number;
  time?: number;
  is_full_data?: boolean;
  buy_offer?: number;
  sell_offer?: number;
};

type MarketHistoryInsert = {
  world: string;
  item_id: number;
  observed_at_utc: string;
  buy_offer: number;
  sell_offer: number;
  observed_date: string;
};

const SUPABASE_URL = Deno.env.get("PROJECT_SUPABASE_URL");
const SUPABASE_SECRET_KEY = Deno.env.get(
  "PROJECT_SUPABASE_SECRET_KEY",
);

const TIBIA_MARKET_BASE_URL = "https://api.tibiamarket.top";
const CACHE_DURATION_HOURS = 6;
const MAX_HISTORY_DAYS = 10_000;
const UPSERT_CHUNK_SIZE = 500;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

if (!SUPABASE_URL) {
  throw new Error("Missing PROJECT_SUPABASE_URL secret.");
}

if (!SUPABASE_SECRET_KEY) {
  throw new Error(
    "Missing PROJECT_SUPABASE_SECRET_KEY secret.",
  );
}

const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SECRET_KEY,
);

function createJsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

async function readRequestBody(
  request: Request,
): Promise<MarketHistoryRequest> {
  const contentType =
    request.headers.get("content-type") || "";

  if (!contentType.includes("application/json")) {
    throw new Error(
      "Content-Type must be application/json.",
    );
  }

  const body = await request.json();

  return body as MarketHistoryRequest;
}

function validateRequest(body: MarketHistoryRequest) {
  const world = String(body.world || "").trim();
  const itemId = Number(body.item_id);
  const days = Number(body.days ?? 365);

  if (!world) {
    throw new Error("world is required.");
  }

  if (world.length > 50) {
    throw new Error(
      "world cannot exceed 50 characters.",
    );
  }

  if (!/^[A-Za-z0-9 -]+$/.test(world)) {
    throw new Error(
      "world contains unsupported characters.",
    );
  }

  if (!Number.isInteger(itemId) || itemId <= 0) {
    throw new Error(
      "item_id must be a positive integer.",
    );
  }

  if (
    !Number.isInteger(days) ||
    days < 1 ||
    days > MAX_HISTORY_DAYS
  ) {
    throw new Error(
      `days must be an integer between 1 and ${MAX_HISTORY_DAYS}.`,
    );
  }

  return {
    world,
    itemId,
    days,
  };
}

async function validateItemExists(
  itemId: number,
): Promise<void> {
  const { data, error } = await supabase
    .from("market_items")
    .select("item_id")
    .eq("item_id", itemId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error(
      `Item ID ${itemId} does not exist in market_items.`,
    );
  }
}

async function getLatestLoadTimestamp(
  world: string,
  itemId: number,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("market_price_history")
    .select("loaded_at_utc")
    .eq("world", world)
    .eq("item_id", itemId)
    .order("loaded_at_utc", {
      ascending: false,
    })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return data?.loaded_at_utc || null;
}

function isCacheFresh(
  loadedAtUtc: string | null,
): boolean {
  if (!loadedAtUtc) {
    return false;
  }

  const loadedAt = new Date(loadedAtUtc);

  if (Number.isNaN(loadedAt.getTime())) {
    return false;
  }

  const cacheDurationMs =
    CACHE_DURATION_HOURS * 60 * 60 * 1000;

  return Date.now() - loadedAt.getTime() < cacheDurationMs;
}

async function fetchWithRetry(
  url: string,
  attempts = 3,
): Promise<Response> {
  for (
    let attempt = 1;
    attempt <= attempts;
    attempt += 1
  ) {
    try {
      const response = await fetch(
        url,
        {
          signal: AbortSignal.timeout(20_000),
        },
      );

      if (response.ok) {
        return response;
      }

      const retryableStatuses = [
        429,
        500,
        502,
        503,
        504,
      ];

      if (
        !retryableStatuses.includes(response.status) ||
        attempt === attempts
      ) {
        throw new Error(
          `TibiaMarket returned ${response.status} ${response.statusText}.`,
        );
      }
    } catch (error) {
      if (attempt === attempts) {
        throw error;
      }
    }

    const waitMilliseconds = attempt * 2_000;

    await new Promise((resolve) =>
      setTimeout(resolve, waitMilliseconds)
    );
  }

  throw new Error(
    "Unable to retrieve TibiaMarket history.",
  );
}

async function fetchTibiaMarketHistory(
  world: string,
  itemId: number,
  days: number,
): Promise<TibiaMarketHistoryRow[]> {
  const url = new URL(
    `${TIBIA_MARKET_BASE_URL}/item_history`,
  );

  url.searchParams.set("server", world);
  url.searchParams.set(
    "item_id",
    String(itemId),
  );
  url.searchParams.set(
    "start_days_ago",
    String(days),
  );
  url.searchParams.set(
    "end_days_ago",
    "-1",
  );

  const response = await fetchWithRetry(
    url.toString(),
  );

  const payload = await response.json();

  if (!Array.isArray(payload)) {
    throw new Error(
      "TibiaMarket returned an unexpected response.",
    );
  }

  return payload;
}

function prepareValidRows(
  history: TibiaMarketHistoryRow[],
  world: string,
  itemId: number,
): MarketHistoryInsert[] {
  return history
    .filter((row) => {
      return (
        row.is_full_data === true &&
        Number(row.buy_offer) > 0 &&
        Number(row.sell_offer) > 0 &&
        Number(row.time) > 0
      );
    })
    .map((row) => {
      const observedAtUtc = new Date(
        Number(row.time) * 1000,
      );

      if (
        Number.isNaN(observedAtUtc.getTime())
      ) {
        throw new Error(
          "TibiaMarket returned an invalid timestamp.",
        );
      }

      const observedAtIso = observedAtUtc.toISOString();

      return {
        world,
        item_id: itemId,
        observed_at_utc: observedAtIso,
        observed_date: observedAtIso.slice(0, 10),
        buy_offer: Number(row.buy_offer),
        sell_offer: Number(row.sell_offer),
      };
    });
}

async function upsertMarketHistory(
  rows: MarketHistoryInsert[],
): Promise<void> {
  for (
    let index = 0;
    index < rows.length;
    index += UPSERT_CHUNK_SIZE
  ) {
    const chunk = rows.slice(
      index,
      index + UPSERT_CHUNK_SIZE,
    );

    const { error } = await supabase
      .from("market_price_history")
      .upsert(
        chunk,
        {
          onConflict: "world,item_id,observed_date",
          ignoreDuplicates: false,
        },
      );

    if (error) {
      throw error;
    }
  }
}

async function getStoredObservationCount(
  world: string,
  itemId: number,
): Promise<number> {
  const { count, error } = await supabase
    .from("market_price_history")
    .select("*", {
      count: "exact",
      head: true,
    })
    .eq("world", world)
    .eq("item_id", itemId);

  if (error) {
    throw error;
  }

  return count || 0;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(
      "ok",
      {
        headers: corsHeaders,
      },
    );
  }

  if (request.method !== "POST") {
    return createJsonResponse(
      {
        success: false,
        error: "Method not allowed.",
      },
      405,
    );
  }

  try {
    const body = await readRequestBody(request);

    const {
      world,
      itemId,
      days,
    } = validateRequest(body);

    await validateItemExists(itemId);

    const latestLoadTimestamp =
      await getLatestLoadTimestamp(
        world,
        itemId,
      );

    if (isCacheFresh(latestLoadTimestamp)) {
      const observationCount =
        await getStoredObservationCount(
          world,
          itemId,
        );

      return createJsonResponse({
        success: true,
        cached: true,
        world,
        item_id: itemId,
        requested_days: days,
        observations: observationCount,
        message:
          "Market history is already up to date.",
      });
    }

    const history =
      await fetchTibiaMarketHistory(
        world,
        itemId,
        days,
      );

    const validRows = prepareValidRows(
      history,
      world,
      itemId,
    );

    if (validRows.length === 0) {
      return createJsonResponse({
        success: true,
        cached: false,
        world,
        item_id: itemId,
        requested_days: days,
        rows_received: history.length,
        rows_loaded: 0,
        observations: 0,
        message:
          "TibiaMarket returned no valid complete market observations.",
      });
    }

    await upsertMarketHistory(validRows);

    const observationCount =
      await getStoredObservationCount(
        world,
        itemId,
      );

    return createJsonResponse({
      success: true,
      cached: false,
      world,
      item_id: itemId,
      requested_days: days,
      rows_received: history.length,
      rows_loaded: validRows.length,
      observations: observationCount,
      message:
        "Market history loaded successfully.",
    });
  } catch (error) {
    console.error(
      "Unable to load market history:",
      error,
    );

    const errorMessage =
      error instanceof Error
        ? error.message
        : "Unknown error.";

    return createJsonResponse(
      {
        success: false,
        error: errorMessage,
      },
      400,
    );
  }
});