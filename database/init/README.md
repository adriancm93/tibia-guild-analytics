# Active Database Initialization Scripts

This folder contains the SQL files required to build the current production schema for Tibia Guild Analytics.

These scripts represent the current architecture:

1. Core raw snapshot tables
2. Snapshot uniqueness constraints
3. World/guild metadata and refresh queue tables
4. Public selector API views
5. Edge Function queue/RPC helpers
6. Per-guild frontend analytics cache tables
7. Current public API views used by the frontend

Legacy scripts were moved to `database/archive/`.
One-time cleanup/drop scripts were moved to `database/cleanup/`.