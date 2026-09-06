# UPGRADE_R4 — Faction buildings + natural unlocks with Memory

**Date:** 2026-09-06 (America/New_York)  
**Slice:** Two faction buildings (Echo Choir / Ash Binder) + JSON-wired natural unlocks with Memory consequences.  
**Base tip:** `98a04d4`

## What changed
1. **`data/buildings.json`** — `echo_choir` (nurture: align_gt + early_choice shelter + min_claims + path_moral_nurture_gte) and `ash_binder` (harvest: align_lt + early_choice demand + min_claims + path_moral_harvest_gte).
2. **`data/actions.json`** — `queue_echo_choir`, `queue_ash_binder` (data-driven UI unlock once buildings unlock).
3. **`GameState.meets_faction_requirements`** — honors `min_claims`, `path_moral_nurture_gte`, `path_moral_harvest_gte`, `building` in addition to align / early_choice gates.
4. **`GameState._unlock_building`** — faction-gated (`require`) unlocks write `faction_unlock_*` Memory tied to haven choice.
5. **Production** — `choir` / `binder` queue complete handlers (resonance return + loss_reduction vs shards + raid_retaliation).
6. **Ending scores** — `echo_choir` counts nurture; `ash_binder` counts harvest.
7. **`add_memory`** — text for `faction_unlock_*` and production_complete for the new buildings.
8. **`test_headless.gd`** — asserts new data; natural unlock (no force-append) for nurture + harvest forks; wrong early_choice blocks Echo Choir; R3 endings still green.
9. **`PLAN_R4.md`** — locked this slice before implementation.

## Tests
- Godot `--headless --quit --import` — PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` — **RESULT: PASSED** (incl. natural faction unlocks + ending reckoning). Process exit may still show ObjectDB / access-violation quirk on `-s` quit (pre-existing; does not fail RESULT).

## Leftovers (still future)
- Deeper TD lane combat / multi-outpost logistics (raid stub remains; no player-facing encounter UI this round).
- Map choice hitboxes still approximate Label rects.
- Full Phase-5 ending catalog (still 3 endings); New Game+ legacy meta.
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing Godot quirk).

## Non-goals kept
No full rewrite. Godot 4 + JSON data-driven preserved. No push.
