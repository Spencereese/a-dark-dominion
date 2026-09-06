# UPGRADE_R8 - Projectile towers on TD lanes

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `206e4e2`
**Slice:** Schematic TD projectile towers on claimed veins; lane combat credit feeds raid mitigation. Keep R3-R7 green.

## What landed
1. **`data/towers.json`** - `watch_bolt` / `dread_spike` / `ward_pulse` profiles (cooldown, range, speed, push, credit, color, faction prefer).
2. **`scripts/GameState.gd`** - load tower data; `get_tower_profile_for_vein`; `register_tower_hit`; lane credit into `offer_raid_encounter` / consume on resolve; vein defense tower contrib; save/reset; Memory text for first shot / first repel.
3. **`scripts/OutlandsMap.gd`** - tower fire cooldowns, projectile nodes, hit pushback + GS credit + flash / full repel.
4. **`test_headless.gd`** - towers.json + profile/hit/raid-bonus asserts; prior rounds retained.

## Verify
- Godot `--headless --quit --import` - PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` - **RESULT: PASSED** (ObjectDB quit crash may still non-zero after PASSED).

## Notes / leftovers
- Multi-outpost logistics deferred (PLAN_R8 non-goal).
- ObjectDB leak / crash-on-quit under headless `-s` (pre-existing).
- Raid auto-timeout still deferred.
