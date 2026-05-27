import { createClient } from "npm:@supabase/supabase-js@2";

type ClaimedGuild = {
  guild_id: string;
  guild_name: string;
  world: string;
};

type TibiaMember = {
  name?: string;
  rank?: string;
  vocation?: string;
  level?: number;
  status?: string;
  joined?: string;
};

type TibiaGuildPayload = {
  guild?: {
    name?: string;
    world?: string;
    members?: TibiaMember[];
  };
};

type RefreshRequestBody = {
  world?: string;
  batch_size?: number;
};

const SUPABASE_URL = Deno.env.get("PROJECT_SUPABASE_URL");
const SUPABASE_SECRET_KEY = Deno.env.get("PROJECT_SUPABASE_SECRET_KEY");
const CRON_SECRET = Deno.env.get("GUILD_REFRESH_SECRET") || "";

if (!SUPABASE_URL) {
  throw new Error("Missing PROJECT_SUPABASE_URL secret.");
}

if (!SUPABASE_SECRET_KEY) {
  throw new Error("Missing PROJECT_SUPABASE_SECRET_KEY secret.");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SECRET_KEY);

function parseJoinedDate(value?: string): string | null {
  if (!value) {
    return null;
  }

  const parsed = new Date(value);

  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString().slice(0, 10);
}

function getRequestConfig(body: RefreshRequestBody | null) {
  const world = body?.world?.trim() || "Lobera";
  const batchSize = Number(body?.batch_size || 25);

  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > 100) {
    throw new Error("batch_size must be an integer between 1 and 100.");
  }

  return {
    world,
    batchSize,
  };
}

async function readRequestBody(request: Request): Promise<RefreshRequestBody | null> {
  const contentType = request.headers.get("content-type") || "";

  if (!contentType.includes("application/json")) {
    return null;
  }

  const text = await request.text();

  if (!text) {
    return null;
  }

  return JSON.parse(text);
}

async function fetchWithRetry(url: string, attempts = 3): Promise<Response> {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const response = await fetch(url);

    if (response.ok) {
      return response;
    }

    const retryableStatusCodes = [429, 502, 503, 504];

    if (!retryableStatusCodes.includes(response.status) || attempt === attempts) {
      throw new Error(`${response.status} ${response.statusText} for ${url}`);
    }

    const waitMs = attempt * 3000;

    console.log(
      `Request failed for ${url}. Retrying in ${waitMs}ms. Attempt ${attempt}/${attempts}`,
    );

    await new Promise((resolve) => setTimeout(resolve, waitMs));
  }

  throw new Error(`Failed to fetch ${url}`);
}

async function fetchGuild(guildName: string): Promise<TibiaGuildPayload> {
  const encodedGuildName = encodeURIComponent(guildName);
  const url = `https://api.tibiadata.com/v4/guild/${encodedGuildName}`;

  const response = await fetchWithRetry(url);
  return await response.json();
}

async function claimDueGuilds(world: string, batchSize: number): Promise<ClaimedGuild[]> {
  const { data, error } = await supabase.rpc("claim_due_guild_refresh_batch", {
    p_world: world,
    p_batch_size: batchSize,
  });

  if (error) {
    throw error;
  }

  return data || [];
}

async function markSuccess(guildId: string): Promise<void> {
  const { error } = await supabase.rpc("mark_guild_refresh_success", {
    p_guild_id: guildId,
  });

  if (error) {
    throw error;
  }
}

async function markFailure(guildId: string, errorMessage: string): Promise<void> {
  const { error } = await supabase.rpc("mark_guild_refresh_failure", {
    p_guild_id: guildId,
    p_error_message: errorMessage,
  });

  if (error) {
    console.error("Failed to mark guild failure:", error);
  }
}

async function applyRetention(): Promise<number | null> {
  const { data, error } = await supabase.rpc("apply_snapshot_retention", {
    retention_window: "3 months",
  });

  if (error) {
    console.error("Retention failed:", error);
    return null;
  }

  return data;
}

async function refreshTimeOnlineMaterializedView(): Promise<boolean> {
  const { error } = await supabase.rpc("refresh_character_estimated_online_minutes");

  if (error) {
    console.error("Failed to refresh time online materialized view:", error);
    return false;
  }

  return true;
}

async function loadGuildSnapshot(guild: ClaimedGuild): Promise<number> {
  const payload = await fetchGuild(guild.guild_name);

  const extractedAtUtc = new Date().toISOString();
  const snapshotId = crypto.randomUUID();

  const wrappedPayload = {
    metadata: {
      source: "tibiadata",
      entity_type: "guild",
      entity_name: guild.guild_name,
      extracted_at_utc: extractedAtUtc,
    },
    data: payload,
  };

  const { error: rawError } = await supabase
    .from("raw_guild_snapshot")
    .insert({
      snapshot_id: snapshotId,
      guild_name: guild.guild_name,
      source: "tibiadata",
      extracted_at_utc: extractedAtUtc,
      raw_json: wrappedPayload,
    });

  if (rawError) {
    throw rawError;
  }

  const members = payload.guild?.members || [];
  const worldFromPayload = payload.guild?.world || guild.world;

  const memberRows = members
    .filter((member) => member.name)
    .map((member) => {
      return {
        snapshot_id: snapshotId,
        extracted_at_utc: extractedAtUtc,
        guild_name: guild.guild_name,
        world: worldFromPayload,
        character_name: member.name,
        guild_rank: member.rank || null,
        vocation: member.vocation || null,
        level: member.level || null,
        status: member.status || null,
        joined: parseJoinedDate(member.joined),
      };
    });

  if (memberRows.length === 0) {
    return 0;
  }

  const chunkSize = 500;

  for (let index = 0; index < memberRows.length; index += chunkSize) {
    const chunk = memberRows.slice(index, index + chunkSize);

    const { error: memberError } = await supabase
      .from("guild_member_snapshot")
      .upsert(chunk, {
        onConflict: "guild_name,world,character_name,extracted_at_utc",
        ignoreDuplicates: true,
      });

    if (memberError) {
      throw memberError;
    }
  }

  return memberRows.length;
}

Deno.serve(async (request) => {
  try {
    if (CRON_SECRET) {
      const providedSecret = request.headers.get("x-cron-secret");

      if (providedSecret !== CRON_SECRET) {
        return new Response(
          JSON.stringify({ success: false, error: "Unauthorized" }),
          {
            status: 401,
            headers: { "Content-Type": "application/json" },
          },
        );
      }
    }

    const body = await readRequestBody(request);
    const { world, batchSize } = getRequestConfig(body);

    const releasedCountResponse = await supabase.rpc(
      "release_stale_running_guild_refreshes",
      { p_stale_after: "15 minutes" },
    );

    if (releasedCountResponse.error) {
      console.error("Failed to release stale running guilds:", releasedCountResponse.error);
    }

    const dueGuilds = await claimDueGuilds(world, batchSize);

    let successCount = 0;
    let failureCount = 0;
    let memberRowsInserted = 0;

    console.log(`World: ${world}`);
    console.log(`Batch size: ${batchSize}`);
    console.log(`Claimed guilds: ${dueGuilds.length}`);

    for (const guild of dueGuilds) {
      try {
        console.log(`Refreshing ${guild.guild_name} / ${guild.world}`);

        const memberCount = await loadGuildSnapshot(guild);

        await markSuccess(guild.guild_id);

        successCount += 1;
        memberRowsInserted += memberCount;

        console.log(`Success ${guild.guild_name}. Members: ${memberCount}`);
      } catch (error) {
        failureCount += 1;

        const message = error instanceof Error ? error.message : String(error);

        console.error(`Failed ${guild.guild_name}: ${message}`);

        await markFailure(guild.guild_id, message);
      }
    }

    const deletedSnapshots = await applyRetention();
    const timeOnlineRefreshSucceeded = await refreshTimeOnlineMaterializedView();

    return new Response(
      JSON.stringify({
        success: true,
        world,
        batch_size: batchSize,
        claimed: dueGuilds.length,
        success_count: successCount,
        failure_count: failureCount,
        member_rows_inserted: memberRowsInserted,
        stale_running_released: releasedCountResponse.data ?? null,
        deleted_snapshots: deletedSnapshots,
        time_online_refresh_succeeded: timeOnlineRefreshSucceeded,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    console.error(message);

    return new Response(
      JSON.stringify({
        success: false,
        error: message,
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});