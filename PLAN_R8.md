# PLAN_R8 - Projectile towers on TD lanes

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `206e4e2`
**Focus (one leftover):** Projectile towers — biggest gameplay win on the existing schematic TD map.
**Non-goals this round:** Multi-outpost logistics, richer NG+ meta, ObjectDB quit crash, raid auto-timeout.

## Why this slice
Towers already render on claimed veins and raids already crawl inward. Wiring real projectiles that push raids back and feed combat credit into raid mitigation turns the visual tease into playable TD.

## Deliverables
1. `data/towers.json` — watch_bolt / dread_spike / ward_pulse profiles (cooldown, push, credit, colors, faction prefer).
2. `GameState.gd` — load tower data; `get_tower_profile_for_vein`; `register_tower_hit`; lane combat credit into `offer_raid_encounter` def_val; save/reset.
3. `OutlandsMap.gd` — tower fire cooldowns, projectile nodes, hit pushback + GS credit + brief flash.
4. `test_headless.gd` — towers.json + profile/hit/raid-bonus asserts; keep prior rounds green.
5. `UPGRADE_R8.md` after green headless.

## Done when
- `test_headless.gd` prints `RESULT: PASSED`
- Commit on main, no push
