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
    } catch (error) {
        apiStatusElement.textContent = `Unable to load dashboard data: ${error.message}`;
        apiStatusElement.className = "error";

        levelChangesTableElement.innerHTML = `
            <tr>
                <td colspan="6">Unable to load level changes.</td>
            </tr>
        `;
    } finally {
        refreshButton.disabled = false;
        refreshButton.textContent = "Refresh Data";
    }
}

refreshButton.addEventListener("click", loadDashboard);

loadDashboard();