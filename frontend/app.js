const API_BASE_URL = "http://127.0.0.1:8000";

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

    return value;
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

async function fetchJson(endpoint) {
    const response = await fetch(`${API_BASE_URL}${endpoint}`);

    if (!response.ok) {
        throw new Error(`Request failed: ${response.status}`);
    }

    return response.json();
}

async function loadSummary() {
    const summary = await fetchJson("/api/summary");

    latestSnapshotElement.textContent = formatTimestamp(summary.latest_snapshot_time);
    previousSnapshotElement.textContent = formatTimestamp(summary.previous_snapshot_time);

    levelChangesCountElement.textContent = summary.level_changes;
    guildJoinsCountElement.textContent = summary.guild_joins;
    guildLeavesCountElement.textContent = summary.guild_leaves;
    rankChangesCountElement.textContent = summary.rank_changes;
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
                    <td class="level-gain">+${row.level_gain}</td>
                </tr>
            `;
        })
        .join("");
}

async function loadLevelChanges() {
    const levelChanges = await fetchJson("/api/level-changes");
    renderLevelChangesTable(levelChanges);
}

async function loadGuildMovementTables() {
    const guildJoins = await fetchJson("/api/guild-joins");
    const guildLeaves = await fetchJson("/api/guild-leaves");
    const rankChanges = await fetchJson("/api/rank-changes");

    renderGuildJoinsTable(guildJoins);
    renderGuildLeavesTable(guildLeaves);
    renderRankChangesTable(rankChanges);
}

async function checkApiHealth() {
    const health = await fetchJson("/api/health");

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