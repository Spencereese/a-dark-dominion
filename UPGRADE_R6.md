# UPGRADE_R6 - Raid/defense encounter UI (data-driven)

**Date:** 2026-09-06 (America/New_York)
**Slice:** Simple player-facing raid/defense encounter using `data/raids.json` — playable responses affect GameState + Memory; prior endings/faction/NG+/headless stay green.
**Base tip:** `1b92685`

## What changed
1. **`data/raids.json`** — `path_raid` encounter with 4 responses: Hold the Watch, Pull Them Back, Strike the Ash, Abandon the Line (costs + effects data-driven).
2. **`scripts/GameState.gd`**
   - Loads raid data; `_trigger_path_raid` now *offers* a pending encounter instead of auto-resolving.
   - `offer_raid_encounter` / `resolve_raid_encounter` / `get_pending_raid` / `has_pending_raid`.
   - Responses spend defense/shards, shift alignment, set retaliation, force mitigate/loss, write Memory (`raid_response_*` + `raid_loss`), emit `raid_occurred`, check endings.
   - `pending_raid` saved/loaded; cleared on reset. Fallback `_resolve_raid_auto` if JSON missing.
3. **`scripts/GameEvents.gd`** — `raid_encounter_offered` / `raid_encounter_resolved`.
4. **`scripts/Main.gd`** — dark Raid Encounter panel (choice-prompt pattern): pause on offer, buttons from pending snapshot, refresh Memory/map/status on resolve.
5. **`test_headless.gd`** — raids.json asserts + offer/resolve paths for all 4 responses + cost-fail pending keep; R3–R5 still green.
6. **`PLAN_R6.md`** — locked this slice before implementation.

## Tests
- Godot `--headless --quit --import` — PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` — **RESULT: PASSED** (raid encounter + Memory + endings + faction unlocks + NG+ hitboxes/carry). Process exit may still show ObjectDB quit crash (pre-existing; non-zero ACCESS_VIOLATION after PASSED).

## Leftovers (still future)
- Deeper TD lane combat / multi-outpost logistics / projectile towers.
- Full Phase-5 ending catalog (still 3 endings).
- Richer NG+ legacy meta beyond Memory shard.
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing Godot quirk).
- Auto-timeout resolve if player never answers a pending raid (currently blocks stacking only).

## Non-goals kept
No full rewrite. Godot 4 + JSON data-driven preserved. No push.
