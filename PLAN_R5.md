# PLAN_R5.md - Round 5 major slice

**Date:** 2026-09-06 (America/New_York)
**Repo tip at start:** `7310a65`
**Constraint:** ONE heavy slice. Godot 4 + JSON data-driven. Preserve headless + endings + faction buildings. Commit, do not push.

## Leftovers from UPGRADE_R4.md
- Deeper TD / multi-outpost logistics.
- Map choice hitboxes still approximate Label rects.
- Full Phase-5 ending catalog / NG+ legacy meta.
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing).

## Chosen slice (highest playable-depth leverage)
**Map choice hitboxes + one NG+ meta: carry Memory shard into next run.**

1. **Map hitboxes** — Replace approximate fixed `Rect2(180,16)` choice labels on OutlandsMap with font-measured hitrects (+ padding). Prefer clickable Button controls for moral options so GUI clicks land reliably; keep `_choice_option_hits` in sync for `_input` fallback. Expose a small helper for headless size asserts.
2. **NG+ Memory shard** — On ending seal, write `user://ng_plus_meta.json` (survives save wipe / editor fresh). On `reset_to_new_game` / fresh `_load_or_init`, apply one-shot carry: starting shards bonus, `ng_plus_memory_shard` Memory entry naming prior ending + early_choice, bump `ng_plus_run`. Clear pending after apply. Do not wipe meta history.

## Non-goals this round
- Full TD lane combat / multi-outpost logistics / player-facing raid encounter UI.
- Full 6-ending Phase-5 catalog.
- Rewrite of Main / GameState.
- Fixing ObjectDB quit quirk.

## Implementation sketch
1. `PLAN_R5.md` (this file).
2. `OutlandsMap.gd` — measured hitrects + Button moral options + `compute_choice_hit_rect`.
3. `GameState.gd` — seal/apply Memory shard meta; Memory text; save fields for run awareness.
4. `test_headless.gd` — hitbox size asserts + NG+ seal→reset→carry asserts; keep R3/R4 green.
5. headless PASS → commit → `UPGRADE_R5.md` (no push).

## Success criteria
- headless import PASS
- test_headless RESULT: PASSED (hitboxes + NG+ carry + endings + faction unlocks)
- Commit + UPGRADE_R5.md; no push
