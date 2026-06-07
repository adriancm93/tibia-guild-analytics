# Active Database Initialization Scripts

This folder contains the SQL files required to build the current production schema for Tibia Guild Analytics.

These scripts represent the current active architecture:

1. Core raw snapshot tables
2. Snapshot uniqueness constraints
3. World/guild metadata tables
4. Refresh queue and status functions
5. Public selector API views
6. Per-guild analytics cache tables
7. Public API views used by the frontend

Legacy scripts were moved to `database/archive/`.

One-time cleanup/drop scripts were moved to `database/cleanup/`.
