/*
 * Tibia Guild Analytics frontend.
 *
 * This file is intentionally kept as a single browser script so the frontend
 * remains deployable as static HTML/CSS/JavaScript through Cloudflare Pages.
 * The code is organized by responsibility:
 *
 * 1. DOM references
 * 2. State and constants
 * 3. Formatting and query utilities
 * 4. Supabase data access
 * 5. Data preparation, filtering, and sorting
 * 6. Render functions
 * 7. Load/controller functions
 * 8. Event binding
 * 9. App initialization
 */

// ============================================================
// 1. DOM references
// ============================================================

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

const levelCharacterFilterElement = document.getElementById("level-character-filter");
const membersCharacterFilterElement = document.getElementById("members-character-filter");

const levelCharacterFilterMenuElement = document.getElementById("level-character-filter-menu");
const membersCharacterFilterMenuElement = document.getElementById("members-character-filter-menu");

const clearLevelCharacterFilterButton = document.getElementById("clear-level-character-filter");
const clearMembersCharacterFilterButton = document.getElementById("clear-members-character-filter");

const vocationMinLevelElement = document.getElementById("vocation-min-level");
const vocationMaxLevelElement = document.getElementById("vocation-max-level");
const applyVocationFilterButton = document.getElementById("apply-vocation-filter");

const vocationPieChartElement = document.getElementById("vocation-pie-chart");
const vocationChartLegendElement = document.getElementById("vocation-chart-legend");
const vocationAnalysisTableElement = document.getElementById("vocation-analysis-table");

const vocationAnalysisFilterMenuElement = document.getElementById("vocation-analysis-filter-menu");
const clearVocationAnalysisFilterButton = document.getElementById("clear-vocation-analysis-filter");

const dashboardTabButtons = document.querySelectorAll(".dashboard-tab");
const dashboardTabSections = document.querySelectorAll(".dashboard-tab-section");


// ============================================================
// 2. State and constants
// ============================================================

const SUPABASE_URL = window.APP_CONFIG?.SUPABASE_URL || "";
const SUPABASE_ANON_KEY = window.APP_CONFIG?.SUPABASE_ANON_KEY || "";

const BASE_VOCATIONS = ["Monk", "Knight", "Paladin", "Druid", "Sorcerer"];

let selectedWorld = "Lobera";
let selectedGuild = "Black Clover";
let availableGuilds = [];

const tableData = {
    level: [],
    joins: [],
    leaves: [],
    rank: [],
    members: [],
    vocationAnalysis: []
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
    },
    vocationAnalysis: {
        key: "current_level",
        direction: "desc"
    }
};


// ============================================================
// 3. Formatting and query utilities
// ============================================================

function encodeFilterValue(value) {
    return encodeURIComponent(value);
}

function buildGuildFilterQuery() {
    return `world=eq.${encodeFilterValue(selectedWorld)}&guild_name=eq.${encodeFilterValue(selectedGuild)}`;
}

function appendGuildFilters(baseQuery) {
    return `${baseQuery}&${buildGuildFilterQuery()}`;
}

function formatOnlineMinutes(minutes) {
    const totalMinutes = Number(minutes || 0);

    if (totalMinutes <= 0) {
        return "0m";
    }

    const hours = Math.floor(totalMinutes / 60);
    const remainingMinutes = totalMinutes % 60;

    if (hours > 0 && remainingMinutes > 0) {
        return `${hours}h ${remainingMinutes}m`;
    }

    if (hours > 0) {
        return `${hours}h`;
    }

    return `${remainingMinutes}m`;
}

function formatChicagoDate(timestamp) {
    if (!timestamp) {
        return "Not available";
    }

    const date = new Date(timestamp);

    return new Intl.DateTimeFormat("en-US", {
        timeZone: "America/Chicago",
        year: "numeric",
        month: "short",
        day: "2-digit"
    }).format(date);
}

function formatRefreshAge(timestamp) {
    if (!timestamp) {
        return "Not available";
    }

    const refreshedAt = new Date(timestamp);
    const now = new Date();

    const diffMilliseconds = now - refreshedAt;

    if (diffMilliseconds < 0) {
        return "Just now";
    }

    const totalMinutes = Math.floor(diffMilliseconds / 60000);
    const days = Math.floor(totalMinutes / 1440);
    const hours = Math.floor((totalMinutes % 1440) / 60);
    const minutes = totalMinutes % 60;

    if (days > 0) {
        return `${days}d ${hours}h ${minutes}m ago`;
    }

    if (hours > 0) {
        return `${hours}h ${minutes}m ago`;
    }

    return `${minutes}m ago`;
}

function formatDateInputValue(date) {
    return date.toISOString().slice(0, 10);
}

function getDateDaysAgo(daysAgo) {
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);
    return date;
}

function timestampToDateInputValue(timestamp) {
    if (!timestamp) {
        return "";
    }

    return new Date(timestamp).toISOString().slice(0, 10);
}

function getDateRange(startElement, endElement) {
    const startDate = startElement.value;
    const endDate = endElement.value;

    if (!startDate || !endDate) {
        return null;
    }

    return {
        startDate,
        endDate,
        startTimestamp: `${startDate}T00:00:00.000Z`,
        endTimestamp: `${endDate}T23:59:59.999Z`
    };
}

function buildSupabaseDateRangeQuery(baseQuery, dateRange, dateColumn = "latest_snapshot_time") {
    if (!dateRange) {
        return baseQuery;
    }

    return `${baseQuery}&${dateColumn}=gte.${dateRange.startTimestamp}&${dateColumn}=lte.${dateRange.endTimestamp}`;
}

function buildSupabaseDateOnlyRangeQuery(baseQuery, dateRange, dateColumn = "activity_date") {
    if (!dateRange) {
        return baseQuery;
    }

    return `${baseQuery}&${dateColumn}=gte.${dateRange.startDate}&${dateColumn}=lte.${dateRange.endDate}`;
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


// ============================================================
// 4. Supabase data access
// ============================================================

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

async function fetchWorlds() {
    return fetchSupabase("api_worlds", "select=*&order=world_name.asc");
}

async function fetchGuilds() {
    return fetchSupabase("api_guilds", "select=*&order=world.asc,guild_name.asc");
}

async function fetchSnapshotDateBounds() {
    const query = appendGuildFilters("select=*");
    const rows = await fetchSupabase("api_snapshot_date_bounds_by_guild", query);

    return rows[0] || {};
}

async function fetchGuildOverview() {
    const query = appendGuildFilters(
        "select=*&order=snapshot_time.desc&limit=1"
    );

    return fetchSupabase("api_guild_overview_by_snapshot", query);
}

async function fetchLevelChanges(dateRange = null) {
    let query = appendGuildFilters(
        "select=*&order=latest_snapshot_time.desc,level_gain.desc,current_level.desc"
    );

    query = buildSupabaseDateRangeQuery(query, dateRange);

    return fetchSupabase("api_historical_character_level_changes", query);
}

async function fetchCharacterOnlineMinutesByDay(dateRange = null) {
    let query = appendGuildFilters(
        "select=character_name,activity_date,estimated_online_minutes,online_interval_rows&order=activity_date.desc,character_name.asc"
    );

    query = buildSupabaseDateOnlyRangeQuery(query, dateRange);

    return fetchSupabase("api_character_online_minutes_by_day", query);
}

async function fetchGuildJoins(dateRange = null) {
    let query = appendGuildFilters(
        "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc"
    );

    query = buildSupabaseDateRangeQuery(query, dateRange);

    return fetchSupabase("api_historical_guild_joins", query);
}

async function fetchGuildLeaves(dateRange = null) {
    let query = appendGuildFilters(
        "select=*&order=latest_snapshot_time.desc,level.desc,character_name.asc"
    );

    query = buildSupabaseDateRangeQuery(query, dateRange);

    return fetchSupabase("api_historical_guild_leaves", query);
}

async function fetchRankChanges(dateRange = null) {
    let query = appendGuildFilters(
        "select=*&order=latest_snapshot_time.desc,character_name.asc"
    );

    query = buildSupabaseDateRangeQuery(query, dateRange);

    return fetchSupabase("api_historical_rank_changes", query);
}

async function fetchGuildMembers() {
    const query = appendGuildFilters(
        "select=*&order=current_level.desc,character_name.asc"
    );

    return fetchSupabase("api_latest_guild_members", query);
}


// ============================================================
// 5. Data preparation, filtering, and sorting
// ============================================================

function normalizeVocation(vocation) {
    const value = String(vocation || "").toLowerCase();

    if (value.includes("monk")) {
        return "Monk";
    }

    if (value.includes("knight")) {
        return "Knight";
    }

    if (value.includes("paladin")) {
        return "Paladin";
    }

    if (value.includes("druid")) {
        return "Druid";
    }

    if (value.includes("sorcerer")) {
        return "Sorcerer";
    }

    return "Unknown";
}

function getSelectedVocationFilters() {
    const checkedOptions = document.querySelectorAll(
        '#vocation-analysis-filter-menu input[type="checkbox"]:checked'
    );

    return Array.from(checkedOptions).map((option) => {
        return option.value;
    });
}

function getVocationLevelRange() {
    const minLevel = Number(vocationMinLevelElement?.value || 0);
    const maxLevel = Number(vocationMaxLevelElement?.value || 0);

    return {
        minLevel: minLevel > 0 ? minLevel : null,
        maxLevel: maxLevel > 0 ? maxLevel : null
    };
}

function prepareVocationAnalysisRows(members) {
    const { minLevel, maxLevel } = getVocationLevelRange();

    return members
        .map((member) => {
            return {
                character_name: member.character_name,
                vocation: member.vocation,
                base_vocation: normalizeVocation(member.vocation),
                current_level: Number(member.current_level || 0)
            };
        })
        .filter((member) => {
            if (!BASE_VOCATIONS.includes(member.base_vocation)) {
                return false;
            }

            if (minLevel !== null && member.current_level < minLevel) {
                return false;
            }

            if (maxLevel !== null && member.current_level > maxLevel) {
                return false;
            }

            return true;
        });
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
                estimated_online_minutes: 0,
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

function aggregateOnlineMinutesByCharacter(onlineMinuteRows) {
    const onlineMinutesByCharacter = new Map();

    onlineMinuteRows.forEach((row) => {
        const characterName = row.character_name;
        const currentMinutes = Number(
            onlineMinutesByCharacter.get(characterName) || 0
        );
        const rowMinutes = Number(row.estimated_online_minutes || 0);

        onlineMinutesByCharacter.set(characterName, currentMinutes + rowMinutes);
    });

    return onlineMinutesByCharacter;
}

function mergeOnlineMinutesIntoLevelChanges(levelChanges, onlineMinutesByCharacter) {
    return levelChanges.map((levelChange) => {
        return {
            ...levelChange,
            estimated_online_minutes: Number(
                onlineMinutesByCharacter.get(levelChange.character_name) || 0
            )
        };
    });
}

function filterRowsByCharacterName(rows, searchValue) {
    const normalizedSearch = String(searchValue || "").trim().toLowerCase();

    if (!normalizedSearch) {
        return rows;
    }

    return rows.filter((row) => {
        return String(row.character_name || "")
            .toLowerCase()
            .includes(normalizedSearch);
    });
}

function getFilteredTableData(tableName) {
    let rows = [...tableData[tableName]];

    if (tableName === "level") {
        rows = filterRowsByCharacterName(
            rows,
            levelCharacterFilterElement?.value
        );
    }

    if (tableName === "members") {
        rows = filterRowsByCharacterName(
            rows,
            membersCharacterFilterElement?.value
        );
    }

    if (tableName === "vocationAnalysis") {
        const selectedVocations = getSelectedVocationFilters();

        rows = rows.filter((row) => {
            return selectedVocations.includes(row.base_vocation);
        });
    }

    return rows;
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
    const rows = getFilteredTableData(tableName);

    return rows.sort((a, b) => {
        return compareValues(a[key], b[key], direction);
    });
}

function getLevelGainClass(levelGain) {
    const gain = Number(levelGain || 0);

    if (gain > 0) {
        return "positive";
    }

    if (gain < 0) {
        return "negative";
    }

    return "";
}

function getVocationCounts(rows) {
    const counts = {};

    BASE_VOCATIONS.forEach((vocation) => {
        counts[vocation] = 0;
    });

    rows.forEach((row) => {
        if (BASE_VOCATIONS.includes(row.base_vocation)) {
            counts[row.base_vocation] += 1;
        }
    });

    return counts;
}

function getVocationChartColor(index) {
    const colors = [
        "#22c55e",
        "#60a5fa",
        "#f59e0b",
        "#a78bfa",
        "#f87171"
    ];

    return colors[index % colors.length];
}


// ============================================================
// 6. Render functions
// ============================================================

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
    overviewLatestRefreshElement.textContent = formatRefreshAge(overview.snapshot_time);
    overviewMemberCountElement.textContent = overview.number_of_members;
    overviewMaxLevelElement.textContent = overview.max_level;
    overviewMinLevelElement.textContent = overview.min_level;
    overviewAverageLevelElement.textContent = overview.average_level;
}

function renderLevelChangesTable(levelChanges) {
    if (!levelChanges.length) {
        levelChangesTableElement.innerHTML = `
            <tr>
                <td colspan="7">No level changes found within the selected date range.</td>
            </tr>
        `;
        return;
    }

    levelChangesTableElement.innerHTML = levelChanges
        .map((levelChange) => {
            return `
                <tr>
                    <td>${levelChange.character_name}</td>
                    <td>${levelChange.vocation || ""}</td>
                    <td>${levelChange.guild_rank || ""}</td>
                    <td>${levelChange.previous_level ?? ""}</td>
                    <td>${levelChange.current_level ?? ""}</td>
                    <td class="${getLevelGainClass(levelChange.level_gain)}">
                        ${Number(levelChange.level_gain) > 0 ? "+" : ""}${levelChange.level_gain}
                    </td>
                    <td>${formatOnlineMinutes(levelChange.estimated_online_minutes)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderGuildJoinsTable(guildJoins) {
    if (!guildJoins.length) {
        guildJoinsTableElement.innerHTML = `
            <tr>
                <td colspan="5">No guild joins found within the selected date range.</td>
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
                    <td>${formatChicagoDate(guildJoin.latest_snapshot_time)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderGuildLeavesTable(guildLeaves) {
    if (!guildLeaves.length) {
        guildLeavesTableElement.innerHTML = `
            <tr>
                <td colspan="5">No guild leaves found within the selected date range.</td>
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
                    <td>${formatChicagoDate(guildLeave.latest_snapshot_time)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderRankChangesTable(rankChanges) {
    if (!rankChanges.length) {
        rankChangesTableElement.innerHTML = `
            <tr>
                <td colspan="4">No rank changes found within the selected date range.</td>
            </tr>
        `;
        return;
    }

    rankChangesTableElement.innerHTML = rankChanges
        .map((rankChange) => {
            return `
                <tr>
                    <td>${rankChange.character_name}</td>
                    <td>${rankChange.previous_guild_rank || ""}</td>
                    <td>${rankChange.current_guild_rank || ""}</td>
                    <td>${formatChicagoDate(rankChange.latest_snapshot_time)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderGuildMembersTable(members) {
    if (!members.length) {
        guildMembersTableElement.innerHTML = `
            <tr>
                <td colspan="5">No guild members found.</td>
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
                    <td>${formatChicagoDate(member.last_connected_at)}</td>
                </tr>
            `;
        })
        .join("");
}

function renderVocationPieChart(rows) {
    if (!vocationPieChartElement || !vocationChartLegendElement) {
        return;
    }

    const context = vocationPieChartElement.getContext("2d");
    const width = vocationPieChartElement.width;
    const height = vocationPieChartElement.height;
    const centerX = width / 2;
    const centerY = height / 2;
    const radius = Math.min(width, height) / 2 - 20;

    context.clearRect(0, 0, width, height);

    const counts = getVocationCounts(rows);
    const entries = BASE_VOCATIONS.map((vocation, index) => {
        return {
            vocation,
            count: counts[vocation],
            color: getVocationChartColor(index)
        };
    });

    const total = entries.reduce((sum, entry) => {
        return sum + entry.count;
    }, 0);

    if (total === 0) {
        context.fillStyle = "#9ca3af";
        context.font = "18px sans-serif";
        context.textAlign = "center";
        context.fillText("No data", centerX, centerY);

        vocationChartLegendElement.innerHTML = "";
        return;
    }

    let startAngle = -Math.PI / 2;

    entries.forEach((entry) => {
        if (entry.count === 0) {
            return;
        }

        const sliceAngle = (entry.count / total) * Math.PI * 2;
        const endAngle = startAngle + sliceAngle;

        context.beginPath();
        context.moveTo(centerX, centerY);
        context.arc(centerX, centerY, radius, startAngle, endAngle);
        context.closePath();
        context.fillStyle = entry.color;
        context.fill();

        startAngle = endAngle;
    });

    vocationChartLegendElement.innerHTML = entries
        .map((entry) => {
            const percentage = total > 0
                ? Math.round((entry.count / total) * 100)
                : 0;

            return `
                <div class="vocation-legend-item">
                    <div class="vocation-legend-left">
                        <span
                            class="vocation-legend-swatch"
                            style="background: ${entry.color};"
                        ></span>
                        <span>${entry.vocation}</span>
                    </div>
                    <strong>${entry.count} (${percentage}%)</strong>
                </div>
            `;
        })
        .join("");
}

function renderVocationAnalysisTable(rows) {
    if (!vocationAnalysisTableElement) {
        return;
    }

    if (!rows.length) {
        vocationAnalysisTableElement.innerHTML = `
            <tr>
                <td colspan="3">No characters found for the selected level/vocation filters.</td>
            </tr>
        `;
        return;
    }

    vocationAnalysisTableElement.innerHTML = rows
        .map((row) => {
            return `
                <tr>
                    <td>${row.character_name}</td>
                    <td>${row.base_vocation}</td>
                    <td>${row.current_level}</td>
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
    } else if (tableName === "vocationAnalysis") {
        renderVocationAnalysisTable(sortedData);
        renderVocationPieChart(sortedData);
    }

    updateSortHeaderStyles();
}

function renderDashboardErrorState(error) {
    console.error(error);

    overviewGuildNameElement.textContent = "Unable to load guild overview";
    overviewWorldNameElement.textContent = "";
    overviewLatestRefreshElement.textContent = "Not available";

    levelChangesTableElement.innerHTML = `
        <tr>
            <td colspan="7">Unable to load level changes and time online.</td>
        </tr>
    `;

    guildJoinsTableElement.innerHTML = `
        <tr>
            <td colspan="5">Unable to load guild joins.</td>
        </tr>
    `;

    guildLeavesTableElement.innerHTML = `
        <tr>
            <td colspan="5">Unable to load guild leaves.</td>
        </tr>
    `;

    rankChangesTableElement.innerHTML = `
        <tr>
            <td colspan="4">Unable to load rank changes.</td>
        </tr>
    `;

    guildMembersTableElement.innerHTML = `
        <tr>
            <td colspan="5">Unable to load guild members.</td>
        </tr>
    `;
}


// ============================================================
// 7. UI behavior helpers
// ============================================================

function closeAllColumnFilterMenus() {
    levelCharacterFilterMenuElement?.classList.remove("open");
    membersCharacterFilterMenuElement?.classList.remove("open");
    vocationAnalysisFilterMenuElement?.classList.remove("open");
}

function toggleColumnFilterMenu(tableName) {
    let targetMenu = null;

    if (tableName === "level") {
        targetMenu = levelCharacterFilterMenuElement;
    }

    if (tableName === "members") {
        targetMenu = membersCharacterFilterMenuElement;
    }

    if (tableName === "vocationAnalysis") {
        targetMenu = vocationAnalysisFilterMenuElement;
    }

    const isOpen = targetMenu?.classList.contains("open");

    closeAllColumnFilterMenus();

    if (!isOpen) {
        targetMenu?.classList.add("open");

        if (tableName === "level") {
            levelCharacterFilterElement?.focus();
        }

        if (tableName === "members") {
            membersCharacterFilterElement?.focus();
        }
    }
}

function clearCharacterFilter(tableName) {
    if (tableName === "level" && levelCharacterFilterElement) {
        levelCharacterFilterElement.value = "";
        renderSortedTable("level");
    }

    if (tableName === "members" && membersCharacterFilterElement) {
        membersCharacterFilterElement.value = "";
        renderSortedTable("members");
    }
}

function activateDashboardTab(targetSectionId) {
    dashboardTabButtons.forEach((button) => {
        const isActive = button.dataset.tabTarget === targetSectionId;
        button.classList.toggle("active", isActive);
    });

    dashboardTabSections.forEach((section) => {
        const isActive = section.id === targetSectionId;
        section.classList.toggle("active", isActive);
    });
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


// ============================================================
// 8. Load/controller functions
// ============================================================

async function initializeDateBounds() {
    const bounds = await fetchSnapshotDateBounds();

    const minDate = timestampToDateInputValue(bounds.min_snapshot_time);
    const maxDate = timestampToDateInputValue(bounds.max_snapshot_time) || formatDateInputValue(new Date());

    if (minDate) {
        applyDateInputBounds(minDate, maxDate);
    }
}

async function loadGuildOverview() {
    const overviewRows = await fetchGuildOverview();
    renderGuildOverview(overviewRows);
}

async function loadLevelChanges() {
    const dateRange = getDateRange(levelStartDateElement, levelEndDateElement);

    const [rawLevelChanges, onlineMinuteRows] = await Promise.all([
        fetchLevelChanges(dateRange),
        fetchCharacterOnlineMinutesByDay(dateRange)
    ]);

    const aggregatedLevelChanges = aggregateLevelChangesByCharacter(rawLevelChanges);
    const onlineMinutesByCharacter = aggregateOnlineMinutesByCharacter(onlineMinuteRows);

    tableData.level = mergeOnlineMinutesIntoLevelChanges(
        aggregatedLevelChanges,
        onlineMinutesByCharacter
    );

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

async function loadVocationAnalysis() {
    const members = await fetchGuildMembers();

    tableData.vocationAnalysis = prepareVocationAnalysisRows(members);

    renderSortedTable("vocationAnalysis");
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

async function loadDashboard() {
    try {
        await loadGuildOverview();
        await loadLevelChanges();
        await loadGuildMovementTables();
        await loadGuildMembers();
        await loadVocationAnalysis();
    } catch (error) {
        renderDashboardErrorState(error);
    }
}


// ============================================================
// 9. Event binding
// ============================================================

function bindTableSortEvents() {
    document.querySelectorAll(".sortable").forEach((header) => {
        header.addEventListener("click", handleTableSort);
    });
}

function bindGuildSelectorEvents() {
    worldSelectElement.addEventListener("change", () => {
        selectedWorld = worldSelectElement.value;
        renderGuildOptions();
    });

    guildSelectElement.addEventListener("change", () => {
        selectedGuild = guildSelectElement.value;
    });

    applyGuildSelectionButton.addEventListener("click", applySelectedGuild);
}

function bindDateFilterEvents() {
    applyLevelFilterButton.addEventListener("click", loadLevelChanges);
    applyJoinsFilterButton.addEventListener("click", loadGuildJoins);
    applyLeavesFilterButton.addEventListener("click", loadGuildLeaves);
    applyRankFilterButton.addEventListener("click", loadRankChanges);
}

function bindCharacterFilterEvents() {
    document.querySelectorAll(".column-filter-button").forEach((button) => {
        button.addEventListener("click", (event) => {
            event.stopPropagation();

            const tableName = button.dataset.filterTable;
            toggleColumnFilterMenu(tableName);
        });
    });

    levelCharacterFilterElement?.addEventListener("input", () => {
        renderSortedTable("level");
    });

    membersCharacterFilterElement?.addEventListener("input", () => {
        renderSortedTable("members");
    });

    clearLevelCharacterFilterButton?.addEventListener("click", (event) => {
        event.stopPropagation();
        clearCharacterFilter("level");
    });

    clearMembersCharacterFilterButton?.addEventListener("click", (event) => {
        event.stopPropagation();
        clearCharacterFilter("members");
    });

    document.addEventListener("click", (event) => {
        const clickedInsideFilterMenu = event.target.closest(".column-filter-menu");
        const clickedFilterButton = event.target.closest(".column-filter-button");

        if (!clickedInsideFilterMenu && !clickedFilterButton) {
            closeAllColumnFilterMenus();
        }
    });

    document.querySelectorAll(".column-filter-menu").forEach((menu) => {
        menu.addEventListener("click", (event) => {
            event.stopPropagation();
        });
    });
}

function bindVocationAnalysisEvents() {
    applyVocationFilterButton?.addEventListener("click", loadVocationAnalysis);

    vocationMinLevelElement?.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            loadVocationAnalysis();
        }
    });

    vocationMaxLevelElement?.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
            loadVocationAnalysis();
        }
    });

    document
        .querySelectorAll('#vocation-analysis-filter-menu input[type="checkbox"]')
        .forEach((checkbox) => {
            checkbox.addEventListener("change", () => {
                renderSortedTable("vocationAnalysis");
            });
        });

    clearVocationAnalysisFilterButton?.addEventListener("click", (event) => {
        event.stopPropagation();

        document
            .querySelectorAll('#vocation-analysis-filter-menu input[type="checkbox"]')
            .forEach((checkbox) => {
                checkbox.checked = true;
            });

        renderSortedTable("vocationAnalysis");
    });
}

function bindDashboardTabEvents() {
    dashboardTabButtons.forEach((button) => {
        button.addEventListener("click", () => {
            activateDashboardTab(button.dataset.tabTarget);
        });
    });
}

function bindEventListeners() {
    bindTableSortEvents();
    bindGuildSelectorEvents();
    bindDateFilterEvents();
    bindCharacterFilterEvents();
    bindVocationAnalysisEvents();
    bindDashboardTabEvents();
}


// ============================================================
// 10. App initialization
// ============================================================

async function initializeApp() {
    try {
        bindEventListeners();

        await loadGuildSelectors();
        await initializeDateBounds();

        setDefaultDateRanges();

        await loadDashboard();
    } catch (error) {
        console.error("Unable to initialize dashboard:", error);
    }
}

initializeApp();
