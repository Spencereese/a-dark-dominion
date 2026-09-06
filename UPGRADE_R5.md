# UPGRADE_R5 - Map choice hitboxes + NG+ Memory shard carry

**Date:** 2026-09-06 (America/New_York)
**Slice:** Font-measured map moral-choice hitboxes + one NG+ meta (carry Memory shard into next run).
**Base tip:** `7310a65`

## What changed
1. **`scripts/OutlandsMap.gd`**
   - Added `compute_choice_hit_rect()` — ThemeDB font string size + padding + minimum click target (replaces fixed ~180x16 Label approx).
   - Moral choice offer UI now uses flat `Button`s sized from measured hitrects; `_choice_option_hits` stays in sync for `_input` fallback; `pressed` dispatches the moral id.
2. **`scripts/GameState.gd`**
   - NG+ meta file `user://ng_plus_meta.json` (survives `save_auto` wipe / editor fresh).
   - `_seal_memory_shard()` on `trigger_ending` — pending shard with ending_id / outcome / early_choice / tallies / run count + history.
   - `_apply_memory_shard_carry()` on fresh `_load_or_init` — one-shot: +3 starting shards, soft alignment/ember echo, `ng_plus_memory_shard` Memory entry, clear pending.
   - Save/load mirrors `ng_plus_run`, `memory_shard_active`, `memory_shard_last`; reset clears runtime flags but keeps meta.
3. **`test_headless.gd`** — clears meta for clean runs; asserts measured hitbox sizing; seal→reset→carry→one-shot; keeps R3 endings + R4 faction unlocks green.
4. **`PLAN_R5.md`** — locked this slice before implementation.

## Tests
- Godot `--headless --quit --import` — PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` — **RESULT: PASSED** (hitboxes + NG+ carry + natural faction unlocks + ending reckoning). Exit 0 this run.

## Leftovers (still future)
- Deeper TD lane combat / multi-outpost logistics (raid stub remains; no dedicated player-facing raid encounter UI this round).
- Full Phase-5 ending catalog (still 3 endings).
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing Godot quirk; not observed as non-zero exit this run).

## Non-goals kept
No full rewrite. Godot 4 + JSON data-driven preserved. No push.
