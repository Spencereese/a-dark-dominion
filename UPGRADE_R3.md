# UPGRADE_R3 — Ending reckoning (nurture vs harvest + WIN/LOSE)

**Date:** 2026-09-06 (America/New_York)  
**Slice:** One ending path — nurture vs harvest with clear win/lose screen.  
**Base tip:** `71e0d65`

## What changed
1. **`data/endings.json`** — three endings: `nurture_circle` (WIN), `harvest_dominion` (WIN), `collapse_ash` (LOSE).
2. **`GameState`** — loads endings; tallies path morals (listen/respect vs harvest/claim); `_check_ending_conditions` after path claim / raid / tick; `trigger_ending` pauses time, writes Memory, emits `ending_reached`; save/load/reset fields.
3. **Reckoning rules** — after **2+ vein claims** + `early_choice` set: nurture score (shelter, listen-leaning morals, positive Weight, ward/spire buildings) vs harvest score (demand/seal, harvest-leaning morals, demand_more, negative Weight, press/foundry). Higher score wins. Collapse lose if pop ≤ 0 or ember dies in outlands with claims.
4. **`GameEvents.ending_reached`** + **`Main` ending overlay** — full-screen dim card with badge / title / body / stats / legacy + **Begin Again (Reset)**.
5. **`test_headless.gd`** — loads endings.json; asserts nurture WIN after 2 listen-leaning claims; collapse LOSE on pop wipe; harvest WIN via `trigger_ending`.
6. **`PLAN_R3.md`** — locked this slice before implementation.

## Tests
- `headless_verify` / Godot `--quit --import` — PASS (no parse errors).
- `Godot --headless -s res://test_headless.gd` — **RESULT: PASSED** (incl. ending assertions).

## Leftovers (still future)
- Deeper TD lane combat / multi-outpost logistics.
- Map choice hitboxes still approximate Label rects.
- Resonance Spire / Will Press natural faction unlock play (data `require` still; headless unlocks explicitly).
- Full Phase-5 ending catalog (only 3 endings shipped); New Game+ legacy meta.
- ObjectDB leak warning on headless exit (pre-existing Godot -s quirk; does not fail RESULT).

## Non-goals kept
No full rewrite. Godot 4 + JSON data-driven preserved. No push.