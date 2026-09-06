# UPGRADE_R7 - Phase-5 ending catalog (3 → 6)

**Date:** 2026-09-06 (America/New_York)
**Slice:** Expand data-driven ending catalog to six Phase-5 variants with special reckoning paths; keep R3–R6 (raids, faction, NG+, headless) green.
**Base tip:** `fc45e98`

## What changed
1. **`data/endings.json`** — added `true_echo` (Hidden/True WIN), `sparse_hearth` (Minimalist WIN), `pyrrhic_crown` (Tragic WIN). Kept `nurture_circle`, `harvest_dominion`, `collapse_ash`.
2. **`scripts/GameState.gd`**
   - `_built_count`, `_compute_ending_scores`, `_has_nurture_faction_building`.
   - `_check_ending_conditions` priority after collapse: true_echo → sparse_hearth → pyrrhic_crown → nurture/harvest.
   - Path moral tally also recognizes `respect` / `parley`.
   - Memory lines + NG+ shard align/ember flavor for the three new endings.
3. **`test_headless.gd`** — catalog size/presence asserts; nurture path raises a Haven so sparse does not steal it; force-sims for true/sparse/pyrrhic + healthy-pop harvest still fires; memory key for true_echo.
4. **`PLAN_R7.md`** — locked this slice before implementation.

## Tests
- Godot `--headless --quit --import` — PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` — **RESULT: PASSED** (ObjectDB quit crash may still non-zero after PASSED).

## Leftovers (still future)
- Deeper TD lane combat / multi-outpost logistics / projectile towers.
- Richer NG+ legacy meta beyond Memory shard (+ ending flavor).
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing).
- Auto-timeout resolve if player never answers a pending raid.

## Non-goals kept
No full rewrite. Godot 4 + JSON data-driven preserved. No push.