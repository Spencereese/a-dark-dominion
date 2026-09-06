# PLAN_R4.md — Round 4 major slice

**Date:** 2026-09-06 (America/New_York)  
**Repo tip at start:** `98a04d4`  
**Constraint:** ONE major slice. Godot 4 + JSON data-driven. Preserve headless + endings tests. Commit, do not push.

## Leftovers from UPGRADE_R3.md
- Deeper TD / multi-outpost logistics.
- Map choice hitboxes still approximate Label rects.
- Resonance Spire / Will Press natural faction unlock play (data `require`; headless force-appended).
- Full Phase-5 ending catalog / NG+ legacy meta.

## Chosen slice (highest playable-depth leverage)
**2 faction buildings + natural JSON unlocks with Memory consequences.**

Wire the moral production fork so aligned play unlocks faction structures without headless cheats:
- Add **Echo Choir** (nurture) and **Ash Binder** (harvest) in `buildings.json` with richer `require` (align + early_choice + min claims + path moral tally).
- Extend `meets_faction_requirements` to honor those JSON keys.
- On faction-gated unlock, write `faction_unlock_*` Memory tied to haven choice.
- Queue actions + production complete handlers + ending-score weights for the new buildings.
- Headless proves **natural** unlock (no force-append) for nurture and harvest forks; keep R3 ending asserts green.

## Non-goals this round
- Full TD lane combat / multi-outpost logistics.
- Map hitbox polish.
- Full 6-ending Phase-5 catalog / NG+.
- Rewrite of Main / GameState.

## Implementation sketch
1. `PLAN_R4.md` (this file).
2. `data/buildings.json` — `echo_choir`, `ash_binder`.
3. `data/actions.json` — `queue_echo_choir`, `queue_ash_binder`.
4. `GameState` — faction require keys; Memory on unlock; choir/binder production; ending weights; Memory text.
5. `test_headless.gd` — data asserts + natural unlock sims + Memory; keep endings.
6. headless PASS → commit → `UPGRADE_R4.md` (no push).

## Success criteria
- headless_verify / import PASS
- test_headless RESULT: PASSED (incl. natural faction unlocks + endings)
- Commit + UPGRADE_R4.md; no push
