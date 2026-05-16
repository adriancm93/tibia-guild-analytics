const API_BASE_URL = window.APP_CONFIG?.API_BASE_URL || "http://127.0.0.1:8000";

const apiStatusElement = document.getElementById("api-status");
const latestSnapshotElement = document.getElementById("latest-snapshot");
const previousSnapshotElement = document.getElementById("previous-snapshot");

const levelChangesCountElement = document.getElementById("level-changes-count");
const guildJoinsCountElement = document.getElementById("guild-joins-count");
const guildLeavesCountElement = document.getElementById("guild-leaves-count");
const rankChangesCountElement = document.getElementById("rank-changes-count");

const levelChangesTableElement = document.getElementById("level-changes-table");
const refreshButton = document.getElementById("refresh-button");

const guildJoinsTableElement = document.getElementById("guild-joins-table");
const guildLeavesTableElement = document.getElementById("guild-leaves-table");
const rankChangesTableElement = document.getElementById("rank-changes-table");

function formatNullableDate(value) {
    if (!value) {
        return "Not available";
    }

    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
        return value;
    }

    return date.toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "2-digit",
    });
}

function renderGuildJoinsTable(guildJoins) {
    if (!guildJoins.length) {
        guildJoinsTableElement.innerHTML = `
            <tr>
                <td colspan="6">No guild joins found between the latest two snapshots.</td>
            </tr>
        `;
        return;
    }

    guildJoinsTableElement.innerHTML = guildJoins
        .map((row) => {
            return `
                <tr>
                    <td>${row.character_name}</td>
                    <td>${row.vocation}</td>
                    <td>${row.level}</td>
                    <td>${row.guild_rank}</td>
                    <td>${row.status}</td>
                    <td>${formatNullableDate(row.joined_date)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderGuildLeavesTable(guildLeaves) {
    if (!guildLeaves.length) {
        guildLeavesTableElement.innerHTML = `
            <tr>
                <td colspan="6">No guild leaves found between the latest two snapshots.</td>
            </tr>
        `;
        return;
    }

    guildLeavesTableElement.innerHTML = guildLeaves
        .map((row) => {
            return `
                <tr>
                    <td>${row.character_name}</td>
                    <td>${row.vocation}</td>
                    <td>${row.level}</td>
                    <td>${row.guild_rank}</td>
                    <td>${row.status}</td>
                    <td>${formatNullableDate(row.joined_date)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderRankChangesTable(rankChanges) {
    if (!rankChanges.length) {
        rankChangesTableElement.innerHTML = `
            <tr>
                <td colspan="5">No rank changes found between the latest two snapshots.</td>
            </tr>
        `;
        return;
    }

    rankChangesTableElement.innerHTML = rankChanges
        .map((row) => {
            return `
                <tr>
                    <td>${row.character_name}</td>
                    <td>${row.previous_guild_rank}</td>
                    <td>${row.current_guild_rank}</td>
                    <td>${formatTimestamp(row.previous_snapshot_time)}</td>
                    <td>${formatTimestamp(row.latest_snapshot_time)}</td>
                </tr>
            `;
        })
        .join("");
}

function formatTimestamp(timestamp) {
    if (!timestamp) {
        return "Not available";
    }

    const date = new Date(timestamp);

    return date.toLocaleString(undefined, {
        year: "numeric",
        month: "short",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
    });
}

const DATA_SOURCE = window.APP_CONFIG?.DATA_SOURCE || "fastapi";
const SUPABASE_URL = window.APP_CONFIG?.SUPABASE_URL || "";
const SUPABASE_ANON_KEY = window.APP_CONFIG?.SUPABASE_ANON_KEY || "";

async function fetchFastApi(endpoint) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`);

    if (!response.ok) {
        throw new Error(`FastAPI request failed: ${response.status}`);
    }

    return response.json();
}

async function fetchSupabase(viewName, queryString = "select=*") {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
        throw new Error("Supabase URL or anon key is missing from config.js");
    }

    const response = await fetch(`${SUPABASE_URL}/rest/v1/${viewName}?${queryString}`, {
        headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`
        }
    });

    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Supabase request failed: ${response.status} ${errorText}`);
    }

    return response.json();
}

async function fetchSummary() {
    if (DATA_SOURCE === "supabase") {
        const rows = await fetchSupabase("api_summary", "select=*");
        return rows[0] || {};
    }

    return fetchFastApi("/api/summary");
}

async function fetchLevelChanges() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase(
            "api_character_level_changes",
            "select=*&order=level_gain.desc,current_level.desc"
        );
    }

    return fetchFastApi("/api/level-changes");
}

async function fetchGuildJoins() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase(
            "api_guild_joins",
            "select=*&order=level.desc,character_name.asc"
        );
    }

    return fetchFastApi("/api/guild-joins");
}

async function fetchGuildLeaves() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase(
            "api_guild_leaves",
            "select=*&order=level.desc,character_name.asc"
        );
    }

    return fetchFastApi("/api/guild-leaves");
}

async function fetchRankChanges() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase(
            "api_rank_changes",
            "select=*&order=character_name.asc"
        );
    }

    return fetchFastApi("/api/rank-changes");
}

async function loadSummary() {
    const summary = await fetchSummary();

    latestSnapshotElement.textContent = formatTimestamp(summary.latest_snapshot_time);
    previousSnapshotElement.textContent = formatTimestamp(summary.previous_snapshot_time);

    levelChangesCountElement.textContent = summary.level_changes;
    guildJoinsCountElement.textContent = summary.guild_joins;
    guildLeavesCountElement.textContent = summary.guild_leaves;
    rankChangesCountElement.textContent = summary.rank_changes;
}

function formatLevelGain(value) {
    if (value > 0) {
        return `+${value}`;
    }

    return value;
}

function renderLevelChangesTable(levelChanges) {
    if (!levelChanges.length) {
        levelChangesTableElement.innerHTML = `
            <tr>
                <td colspan="6">No level changes found between the latest two snapshots.</td>
            </tr>
        `;
        return;
    }

    levelChangesTableElement.innerHTML = levelChanges
        .map((row) => {
            return `
                <tr>
                    <td>${row.character_name}</td>
                    <td>${row.vocation}</td>
                    <td>${row.guild_rank}</td>
                    <td>${row.previous_level}</td>
                    <td>${row.current_level}</td>
                    <td class="level-gain">${formatLevelGain(row.level_gain)}</td>
                </tr>
            `;
        })
        .join("");
}

async function loadLevelChanges() {
    const levelChanges = await fetchLevelChanges();
    renderLevelChangesTable(levelChanges);
}

async function loadGuildMovementTables() {
    const guildJoins = await fetchGuildJoins();
    const guildLeaves = await fetchGuildLeaves();
    const rankChanges = await fetchRankChanges();

    renderGuildJoinsTable(guildJoins);
    renderGuildLeavesTable(guildLeaves);
    renderRankChangesTable(rankChanges);
}

async function checkApiHealth() {
    if (DATA_SOURCE === "supabase") {
        const summary = await fetchSummary();

        if (summary.latest_snapshot_time) {
            apiStatusElement.textContent = "Connected to Supabase.";
            apiStatusElement.className = "success";
            return;
        }

        apiStatusElement.textContent = "Connected to Supabase, but no snapshot data was found.";
        apiStatusElement.className = "error";
        return;
    }

    const health = await fetchFastApi("/api/health");

    if (health.status === "ok") {
        apiStatusElement.textContent = "Connected to FastAPI backend.";
        apiStatusElement.className = "success";
    } else {
        apiStatusElement.textContent = "Backend responded, but status was unexpected.";
        apiStatusElement.className = "error";
    }
}

async function loadDashboard() {
    try {
        refreshButton.disabled = true;
        refreshButton.textContent = "Refreshing...";

        await checkApiHealth();
        await loadSummary();
        await loadLevelChanges();
        await loadGuildMovementTables();

    } catch (error) {
        apiStatusElement.textContent = `Unable to load dashboard data: ${error.message}`;
        apiStatusElement.className = "error";

        levelChangesTableElement.innerHTML = `
            <tr>
                <td colspan="6">Unable to load level changes.</td>
            </tr>
        `;

        guildJoinsTableElement.innerHTML = `
            <tr>
                <td colspan="6">Unable to load guild joins.</td>
            </tr>
        `;

        guildLeavesTableElement.innerHTML = `
            <tr>
                <td colspan="6">Unable to load guild leaves.</td>
            </tr>
        `;

        rankChangesTableElement.innerHTML = `
            <tr>
                <td colspan="5">Unable to load rank changes.</td>
            </tr>
        `;
    } finally {
        refreshButton.disabled = false;
        refreshButton.textContent = "Refresh Data";
    }
}

refreshButton.addEventListener("click", loadDashboard);

loadDashboard();