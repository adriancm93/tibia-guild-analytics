-- Phase 3C
-- Create analytics views for guild snapshot reporting.

CREATE OR REPLACE VIEW analytics_current_guild_roster AS
SELECT
    guild_name,
    world,
    character_name,
    guild_rank,
    vocation,
    level,
    status,
    joined_date,
    extracted_at_utc
FROM stg_guild_member_snapshot
WHERE extracted_at_utc = (
    SELECT MAX(extracted_at_utc)
    FROM stg_guild_member_snapshot
);


CREATE OR REPLACE VIEW analytics_guild_summary_by_vocation AS
SELECT
    guild_name,
    world,
    vocation,
    COUNT(*) AS character_count,
    ROUND(AVG(level), 2) AS avg_level,
    MIN(level) AS min_level,
    MAX(level) AS max_level
FROM analytics_current_guild_roster
GROUP BY
    guild_name,
    world,
    vocation;


CREATE OR REPLACE VIEW analytics_top_characters AS
SELECT
    guild_name,
    world,
    character_name,
    guild_rank,
    vocation,
    level,
    status,
    joined_date,
    extracted_at_utc
FROM analytics_current_guild_roster;


CREATE OR REPLACE VIEW analytics_level_distribution AS
SELECT
    guild_name,
    world,
    CASE
        WHEN level < 50 THEN '001-049'
        WHEN level < 100 THEN '050-099'
        WHEN level < 150 THEN '100-149'
        WHEN level < 200 THEN '150-199'
        WHEN level < 300 THEN '200-299'
        WHEN level < 500 THEN '300-499'
        ELSE '500+'
    END AS level_band,
    COUNT(*) AS character_count
FROM analytics_current_guild_roster
GROUP BY
    guild_name,
    world,
    CASE
        WHEN level < 50 THEN '001-049'
        WHEN level < 100 THEN '050-099'
        WHEN level < 150 THEN '100-149'
        WHEN level < 200 THEN '150-199'
        WHEN level < 300 THEN '200-299'
        WHEN level < 500 THEN '300-499'
        ELSE '500+'
    END;