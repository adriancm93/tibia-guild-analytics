const API_BASE_URL = window.APP_CONFIG?.API_BASE_URL || "http://127.0.0.1:8000";

const worldSelectElement = document.getElementById("world-select");
const guildSelectElement = document.getElementById("guild-select");
const applyGuildSelectionButton = document.getElementById("apply-guild-selection");

const overviewGuildNameElement = document.getElementById("overview-guild-name");
const overviewWorldNameElement = document.getElementById("overview-world-name");
const overviewLatestRefreshElement = document.getElementById("overview-latest-refresh");
const overviewMemberCountElement = document.getElementById("overview-member-count");
const overviewMaxLevelElement = document.getElementById("overview-max-level");
const overviewMinLevelElement = document.getElementById("overview-min-level");
const overviewAverageLevelElement = document.getElementById("overview-average-level");

const levelChangesTableElement = document.getElementById("level-changes-table");
const guildJoinsTableElement = document.getElementById("guild-joins-table");
const guildLeavesTableElement = document.getElementById("guild-leaves-table");
const rankChangesTableElement = document.getElementById("rank-changes-table");
const guildMembersTableElement = document.getElementById("guild-members-table");

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

let selectedWorld = "Lobera";
let selectedGuild = "Black Clover";
let availableGuilds = [];

let currentLevelChanges = [];

const tableData = {
    level: [],
    joins: [],
    leaves: [],
    rank: [],
    members: []
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
    },
    members: {
        key: "current_level",
        direction: "desc"
    }
};

function encodeFilterValue(value) {
    return encodeURIComponent(value);
}

function buildGuildFilterQuery() {
    return `world=eq.${encodeFilterValue(selectedWorld)}&guild_name=eq.${encodeFilterValue(selectedGuild)}`;
}

function appendGuildFilters(baseQuery) {
    return `${baseQuery}&${buildGuildFilterQuery()}`;
}

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
                <td colspan="6">No guild joins found within the selected date range.</td>
            </tr>
        `;
        return;
    }

    guildJoinsTableElement.innerHTML = guildJoins
        .map((guildJoin) => {
            return `
                <tr>
                    <td>${guildJoin.character_name}</td>
                    <td>${guildJoin.vocation || ""}</td>
                    <td>${guildJoin.level ?? ""}</td>
                    <td>${guildJoin.guild_rank || ""}</td>
                    <td>${guildJoin.status || ""}</td>
                    <td>${formatTimestamp(guildJoin.latest_snapshot_time)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderGuildLeavesTable(guildLeaves) {
    if (!guildLeaves.length) {
        guildLeavesTableElement.innerHTML = `
            <tr>
                <td colspan="6">No guild leaves found within the selected date range.</td>
            </tr>
        `;
        return;
    }

    guildLeavesTableElement.innerHTML = guildLeaves
        .map((guildLeave) => {
            return `
                <tr>
                    <td>${guildLeave.character_name}</td>
                    <td>${guildLeave.vocation || ""}</td>
                    <td>${guildLeave.level ?? ""}</td>
                    <td>${guildLeave.guild_rank || ""}</td>
                    <td>${guildLeave.status || ""}</td>
                    <td>${formatTimestamp(guildLeave.latest_snapshot_time)}</td>
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

function buildSupabaseDateRangeQuery(baseQuery, dateRange, dateColumn = "latest_snapshot_time") {
    if (!dateRange) {
        return baseQuery;
    }

    return `${baseQuery}&${dateColumn}=gte.${dateRange.startTimestamp}&${dateColumn}=lte.${dateRange.endTimestamp}`;
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
    return fetchSnapshotDateBoundsForSelectedGuild();
}

async function fetchWorlds() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase("api_worlds", "select=*&order=world_name.asc");
    }

    return [];
}

async function fetchGuilds() {
    if (DATA_SOURCE === "supabase") {
        return fetchSupabase("api_guilds", "select=*&order=world.asc,guild_name.asc");
    }

    return [];
}

async function fetchSnapshotDateBoundsForSelectedGuild() {
    if (DATA_SOURCE === "supabase") {
        const query = appendGuildFilters("select=*");
        const rows = await fetchSupabase("api_snapshot_date_bounds_by_guild", query);
        return rows[0] || {};
    }

    return {
        min_snapshot_time: null,
        max_snapshot_time: null
    };
}

async function fetchLevelChanges(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        let query = appendGuildFilters(
            "select=*&order=latest_snapshot_time.desc,level_gain.desc,current_level.desc"
        );

        query = buildSupabaseDateRangeQuery(query, dateRange);

        return fetchSupabase("api_historical_character_level_changes", query);
    }

    return fetchFastApi("/api/level-changes");
}

async function fetchGuildJoins(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        let query = appendGuildFilters(
            "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc"
        );

        query = buildSupabaseDateRangeQuery(query, dateRange);

        return fetchSupabase("api_historical_guild_joins", query);
    }

    return fetchFastApi("/api/guild-joins");
}

async function fetchGuildLeaves(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        let query = appendGuildFilters(
            "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc"
        );

        query = buildSupabaseDateRangeQuery(query, dateRange);

        return fetchSupabase("api_historical_guild_leaves", query);
    }

    return fetchFastApi("/api/guild-leaves");
}

async function fetchRankChanges(dateRange = null) {
    if (DATA_SOURCE === "supabase") {
        let query = appendGuildFilters(
            "select=*&order=latest_snapshot_time.desc,character_name.asc"
        );

        query = buildSupabaseDateRangeQuery(query, dateRange);

        return fetchSupabase("api_historical_rank_changes", query);
    }

    return fetchFastApi("/api/rank-changes");
}

async function fetchGuildMembers() {
    if (DATA_SOURCE === "supabase") {
        const query = appendGuildFilters(
            "select=*&order=current_level.desc,character_name.asc"
        );

        return fetchSupabase("api_latest_guild_members", query);
    }

    return [];
}

async function fetchGuildOverview() {
    if (DATA_SOURCE === "supabase") {
        const query = appendGuildFilters(
            "select=*&order=snapshot_time.desc&limit=1"
        );

        return fetchSupabase("api_guild_overview_by_snapshot", query);
    }

    return [];
}

function renderGuildOverview(rows) {
    const overview = rows[0];

    if (!overview) {
        overviewGuildNameElement.textContent = "No guild data found";
        overviewWorldNameElement.textContent = "";
        overviewLatestRefreshElement.textContent = "Not available";
        overviewMemberCountElement.textContent = "0";
        overviewMaxLevelElement.textContent = "0";
        overviewMinLevelElement.textContent = "0";
        overviewAverageLevelElement.textContent = "0";
        return;
    }

    overviewGuildNameElement.textContent = overview.guild_name;
    overviewWorldNameElement.textContent = overview.world;
    overviewLatestRefreshElement.textContent = formatTimestamp(overview.snapshot_time);
    overviewMemberCountElement.textContent = overview.number_of_members;
    overviewMaxLevelElement.textContent = overview.max_level;
    overviewMinLevelElement.textContent = overview.min_level;
    overviewAverageLevelElement.textContent = overview.average_level;
}

async function loadGuildOverview() {
    const overviewRows = await fetchGuildOverview();
    renderGuildOverview(overviewRows);
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
    } else if (tableName === "members") {
        renderGuildMembersTable(sortedData);
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

function aggregateLevelChangesByCharacter(levelChanges) {
    const characterMap = new Map();

    levelChanges.forEach((row) => {
        const characterName = row.character_name;

        if (!characterMap.has(characterName)) {
            characterMap.set(characterName, {
                character_name: row.character_name,
                vocation: row.vocation,
                guild_rank: row.guild_rank,
                previous_level: row.previous_level,
                current_level: row.current_level,
                level_gain: Number(row.level_gain) || 0,
                first_snapshot_time: row.previous_snapshot_time,
                latest_snapshot_time: row.latest_snapshot_time
            });

            return;
        }

        const existing = characterMap.get(characterName);

        existing.level_gain += Number(row.level_gain) || 0;

        const rowPreviousTime = new Date(row.previous_snapshot_time).getTime();
        const existingFirstTime = new Date(existing.first_snapshot_time).getTime();

        if (rowPreviousTime < existingFirstTime) {
            existing.previous_level = row.previous_level;
            existing.first_snapshot_time = row.previous_snapshot_time;
        }

        const rowLatestTime = new Date(row.latest_snapshot_time).getTime();
        const existingLatestTime = new Date(existing.latest_snapshot_time).getTime();

        if (rowLatestTime > existingLatestTime) {
            existing.current_level = row.current_level;
            existing.guild_rank = row.guild_rank;
            existing.vocation = row.vocation;
            existing.latest_snapshot_time = row.latest_snapshot_time;
        }
    });

    return Array.from(characterMap.values());
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

function renderGuildMembersTable(members) {
    if (!members.length) {
        guildMembersTableElement.innerHTML = `
            <tr>
                <td colspan="4">No guild members found.</td>
            </tr>
        `;
        return;
    }

    guildMembersTableElement.innerHTML = members
        .map((member) => {
            return `
                <tr>
                    <td>${member.character_name}</td>
                    <td>${member.vocation || ""}</td>
                    <td>${member.guild_rank || ""}</td>
                    <td>${member.current_level ?? ""}</td>
                </tr>
            `;
        })
        .join("");
}

function renderWorldOptions(worlds) {
    worldSelectElement.innerHTML = worlds
        .map((world) => {
            const selected = world.world_name === selectedWorld ? "selected" : "";

            return `
                <option value="${world.world_name}" ${selected}>
                    ${world.world_name}
                </option>
            `;
        })
        .join("");
}

function renderGuildOptions() {
    const guildsForWorld = availableGuilds.filter((guild) => {
        return guild.world === selectedWorld;
    });

    if (
        !guildsForWorld.some((guild) => guild.guild_name === selectedGuild) &&
        guildsForWorld.length
    ) {
        selectedGuild = guildsForWorld[0].guild_name;
    }

    guildSelectElement.innerHTML = guildsForWorld
        .map((guild) => {
            const selected = guild.guild_name === selectedGuild ? "selected" : "";

            return `
                <option value="${guild.guild_name}" ${selected}>
                    ${guild.guild_name}
                </option>
            `;
        })
        .join("");
}

async function loadGuildSelectors() {
    const [worlds, guilds] = await Promise.all([
        fetchWorlds(),
        fetchGuilds()
    ]);

    availableGuilds = guilds;

    renderWorldOptions(worlds);
    renderGuildOptions();
}

async function applySelectedGuild() {
    selectedWorld = worldSelectElement.value;
    selectedGuild = guildSelectElement.value;

    await initializeDateBounds();
    setDefaultDateRanges();
    await loadDashboard();
}

async function loadLevelChanges() {
    const dateRange = getDateRange(levelStartDateElement, levelEndDateElement);
    const rawLevelChanges = await fetchLevelChanges(dateRange);

    tableData.level = aggregateLevelChangesByCharacter(rawLevelChanges);

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

async function loadGuildMembers() {
    tableData.members = await fetchGuildMembers();
    renderSortedTable("members");
}

async function loadDashboard() {
    try {
        await loadGuildOverview();
        await loadLevelChanges();
        await loadGuildMovementTables();
        await loadGuildMembers();
    } catch (error) {
        console.error(error);

        overviewGuildNameElement.textContent = "Unable to load guild overview";
        overviewWorldNameElement.textContent = "";
        overviewLatestRefreshElement.textContent = "Not available";

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
        
        guildMembersTableElement.innerHTML = `
            <tr>
                <td colspan="4">Unable to load guild members.</td>
            </tr>
`;
    }
}

document.querySelectorAll(".sortable").forEach((header) => {
    header.addEventListener("click", handleTableSort);
});

worldSelectElement.addEventListener("change", () => {
    selectedWorld = worldSelectElement.value;
    renderGuildOptions();
});

guildSelectElement.addEventListener("change", () => {
    selectedGuild = guildSelectElement.value;
});

applyLevelFilterButton.addEventListener("click", loadLevelChanges);
applyJoinsFilterButton.addEventListener("click", loadGuildJoins);
applyLeavesFilterButton.addEventListener("click", loadGuildLeaves);
applyRankFilterButton.addEventListener("click", loadRankChanges);
applyGuildSelectionButton.addEventListener("click", applySelectedGuild);


loadGuildSelectors()
    .then(() => initializeDateBounds())
    .then(() => {
        setDefaultDateRanges();
        return loadDashboard();
    })
    .catch((error) => {
        console.error("Unable to initialize dashboard:", error);
    });