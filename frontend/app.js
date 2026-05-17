const API_BASE_URL = window.APP_CONFIG?.API_BASE_URL || "http://127.0.0.1:8000";

const apiStatusElement = document.getElementById("api-status");
const latestSnapshotElement = document.getElementById("latest-snapshot");
const previousSnapshotElement = document.getElementById("previous-snapshot");

const levelChangesCountElement = document.getElementById("level-changes-count");
const guildJoinsCountElement = document.getElementById("guild-joins-count");
const guildLeavesCountElement = document.getElementById("guild-leaves-count");
const rankChangesCountElement = document.getElementById("rank-changes-count");

const levelChangesTableElement = document.getElementById("level-changes-table");

const guildJoinsTableElement = document.getElementById("guild-joins-table");
const guildLeavesTableElement = document.getElementById("guild-leaves-table");
const rankChangesTableElement = document.getElementById("rank-changes-table");

const levelStartDateElement = document.getElementById("level-start-date");
const levelEndDateElement = document.getElementById("level-end-date");
const applyLevelFilterButton = document.getElementById("apply-level-filter");

const joinsStartDateElement = document.getElementById("joins-start-date");
const joinsEndDateElement = document.getElementById("joins-end-date");
const applyJoinsFilterButton = document.getElementById("apply-joins-filter");

const leavesStartDateElement = document.getElementById("leaves-start-date");
const leavesEndDateElement = document.getElementById("leaves-end-date");
const applyLeavesFilterButton = document.getElementById("apply-leaves-filter");

const rankStartDateElement = document.getElementById("rank-start-date");
const rankEndDateElement = document.getElementById("rank-end-date");
const applyRankFilterButton = document.getElementById("apply-rank-filter");

let currentLevelChanges = [];

const tableData = {
    level: [],
    joins: [],
    leaves: [],
    rank: []
};

const tableSortState = {
    level: {
        key: "level_gain",
        direction: "desc"
    },
    joins: {
        key: "latest_snapshot_time",
        direction: "desc"
    },
    leaves: {
        key: "latest_snapshot_time",
        direction: "desc"
    },
    rank: {
        key: "latest_snapshot_time",
        direction: "desc"
    }
};

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

function formatDateInputValue(date) {
    return date.toISOString().slice(0, 10);
}

function getDateDaysAgo(daysAgo) {
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);
    return date;
}

function getDateRange(startElement, endElement) {
    const startDate = startElement.value;
    const endDate = endElement.value;

    if (!startDate || !endDate) {
        return null;
    }

    return {
        startTimestamp: `${startDate}T00:00:00.000Z`,
        endTimestamp: `${endDate}T23:59:59.999Z`
    };
}

function timestampToDateInputValue(timestamp) {
    if (!timestamp) {
        return "";
    }

    return new Date(timestamp).toISOString().slice(0, 10);
}

function applyDateInputBounds(minDate, maxDate) {
    const dateInputs = [
        levelStartDateElement,
        levelEndDateElement,
        joinsStartDateElement,
        joinsEndDateElement,
        leavesStartDateElement,
        leavesEndDateElement,
        rankStartDateElement,
        rankEndDateElement
    ];

    dateInputs.forEach((input) => {
        input.min = minDate;
        input.max = maxDate;
    });
}

async function initializeDateBounds() {
    const bounds = await fetchSnapshotDateBounds();

    const minDate = timestampToDateInputValue(bounds.min_snapshot_time);
    const maxDate = timestampToDateInputValue(bounds.max_snapshot_time) || formatDateInputValue(new Date());

    if (minDate) {
        applyDateInputBounds(minDate, maxDate);
    }
}

function buildSupabaseDateRangeQuery(baseQuery, dateRange) {
    if (!dateRange) {
        return baseQuery;
    }

    return `${baseQuery}&latest_snapshot_time=gte.${dateRange.startTimestamp}&latest_snapshot_time=lte.${dateRange.endTimestamp}`;
}

function setDefaultDateRanges() {
    const defaultStartDate = formatDateInputValue(getDateDaysAgo(7));
    const defaultEndDate = formatDateInputValue(new Date());

    const minAllowedDate = levelStartDateElement.min;

    const safeStartDate =
        minAllowedDate && defaultStartDate < minAllowedDate
            ? minAllowedDate
            : defaultStartDate;

    levelStartDateElement.value = safeStartDate;
    levelEndDateElement.value = defaultEndDate;

    joinsStartDateElement.value = safeStartDate;
    joinsEndDateElement.value = defaultEndDate;

    leavesStartDateElement.value = safeStartDate;
    leavesEndDateElement.value = defaultEndDate;

    rankStartDateElement.value = safeStartDate;
    rankEndDateElement.value = defaultEndDate;
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
async function fetchSnapshotDateBounds() {
    if (DATA_SOURCE === "supabase") {
        const rows = await fetchSupabase("api_snapshot_date_bounds", "select=*");
        return rows[0] || {};
    }

    return {
        min_snapshot_time: null,
        max_snapshot_time: null
    };
}

async function fetchSummary() {
    if (DATA_SOURCE === "supabase") {
        const rows = await fetchSupabase("api_summary", "select=*");
        return rows[0] || {};
    }

    return fetchFastApi("/api/summary");
}

async function fetchLevelChanges(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        const query = buildSupabaseDateRangeQuery(
            "select=*&order=latest_snapshot_time.desc,level_gain.desc,current_level.desc",
            dateRange
        );

        return fetchSupabase("api_historical_character_level_changes", query);
    }

    return fetchFastApi("/api/level-changes");
}

async function fetchGuildJoins(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        const query = buildSupabaseDateRangeQuery(
            "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc",
            dateRange
        );

        return fetchSupabase("api_historical_guild_joins", query);
    }

    return fetchFastApi("/api/guild-joins");
}

async function fetchGuildLeaves(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        const query = buildSupabaseDateRangeQuery(
            "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc",
            dateRange
        );

        return fetchSupabase("api_historical_guild_leaves", query);
    }

    return fetchFastApi("/api/guild-leaves");
}

async function fetchRankChanges(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        const query = buildSupabaseDateRangeQuery(
            "select=*&order=latest_snapshot_time.desc,character_name.asc",
            dateRange
        );

        return fetchSupabase("api_historical_rank_changes", query);
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

function compareValues(a, b, direction) {
    if (a === null || a === undefined) return 1;
    if (b === null || b === undefined) return -1;

    const aNumber = Number(a);
    const bNumber = Number(b);

    if (!Number.isNaN(aNumber) && !Number.isNaN(bNumber)) {
        return direction === "asc" ? aNumber - bNumber : bNumber - aNumber;
    }

    const aDate = Date.parse(a);
    const bDate = Date.parse(b);

    if (!Number.isNaN(aDate) && !Number.isNaN(bDate)) {
        return direction === "asc" ? aDate - bDate : bDate - aDate;
    }

    const aValue = String(a).toLowerCase();
    const bValue = String(b).toLowerCase();

    if (aValue < bValue) {
        return direction === "asc" ? -1 : 1;
    }

    if (aValue > bValue) {
        return direction === "asc" ? 1 : -1;
    }

    return 0;
}

function getSortedTableData(tableName) {
    const { key, direction } = tableSortState[tableName];

    return [...tableData[tableName]].sort((a, b) => {
        return compareValues(a[key], b[key], direction);
    });
}

function updateSortHeaderStyles() {
    const sortableHeaders = document.querySelectorAll(".sortable");

    sortableHeaders.forEach((header) => {
        const tableName = header.dataset.table;
        const sortKey = header.dataset.sortKey;

        header.classList.remove("sort-asc", "sort-desc");

        if (
            tableSortState[tableName] &&
            tableSortState[tableName].key === sortKey
        ) {
            header.classList.add(
                tableSortState[tableName].direction === "asc"
                    ? "sort-asc"
                    : "sort-desc"
            );
        }
    });
}

function renderSortedTable(tableName) {
    const sortedData = getSortedTableData(tableName);

    if (tableName === "level") {
        renderLevelChangesTable(sortedData);
    } else if (tableName === "joins") {
        renderGuildJoinsTable(sortedData);
    } else if (tableName === "leaves") {
        renderGuildLeavesTable(sortedData);
    } else if (tableName === "rank") {
        renderRankChangesTable(sortedData);
    }

    updateSortHeaderStyles();
}

function handleTableSort(event) {
    const header = event.currentTarget;
    const tableName = header.dataset.table;
    const sortKey = header.dataset.sortKey;

    if (!tableName || !sortKey || !tableSortState[tableName]) {
        return;
    }

    if (tableSortState[tableName].key === sortKey) {
        tableSortState[tableName].direction =
            tableSortState[tableName].direction === "asc" ? "desc" : "asc";
    } else {
        tableSortState[tableName].key = sortKey;
        tableSortState[tableName].direction = "asc";
    }

    renderSortedTable(tableName);
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
    const dateRange = getDateRange(levelStartDateElement, levelEndDateElement);
    tableData.level = await fetchLevelChanges(dateRange);
    renderSortedTable("level");
}

async function loadGuildJoins() {
    const dateRange = getDateRange(joinsStartDateElement, joinsEndDateElement);
    tableData.joins = await fetchGuildJoins(dateRange);
    renderSortedTable("joins");
}

async function loadGuildLeaves() {
    const dateRange = getDateRange(leavesStartDateElement, leavesEndDateElement);
    tableData.leaves = await fetchGuildLeaves(dateRange);
    renderSortedTable("leaves");
}

async function loadRankChanges() {
    const dateRange = getDateRange(rankStartDateElement, rankEndDateElement);
    tableData.rank = await fetchRankChanges(dateRange);
    renderSortedTable("rank");
}

async function loadGuildMovementTables() {
    await loadGuildJoins();
    await loadGuildLeaves();
    await loadRankChanges();
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
    }
}

document.querySelectorAll(".sortable").forEach((header) => {
    header.addEventListener("click", handleTableSort);
});

applyLevelFilterButton.addEventListener("click", loadLevelChanges);
applyJoinsFilterButton.addEventListener("click", loadGuildJoins);
applyLeavesFilterButton.addEventListener("click", loadGuildLeaves);
applyRankFilterButton.addEventListener("click", loadRankChanges);

initializeDateBounds()
    .then(() => {
        setDefaultDateRanges();
        return loadDashboard();
    })
    .catch((error) => {
        apiStatusElement.textContent = `Unable to initialize dashboard: ${error.message}`;
        apiStatusElement.className = "error";
    });