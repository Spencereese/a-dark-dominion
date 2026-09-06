# PLAN_R3.md — Round 3 major slice

**Date:** 2026-09-06 (America/New_York)  
**Repo tip at start:** `71e0d65`  
**Constraint:** ONE major slice. Godot 4 + JSON data-driven. Preserve headless tests. Commit, do not push.

## Leftovers from UPGRADE.md (R2)
- Deeper TD / multi-outpost / endings still future.
- Map choice hitboxes are approximate Label rects.
- Resonance Spire / Will Press faction gates need aligned play to unlock naturally.

## Chosen slice (highest playable-depth leverage)
**Ending reckoning: nurture vs harvest with clear WIN/LOSE screen.**

Closes the moral core loop shipped in R2 (Memory + map agency + production) with a session terminus players can feel:
- Claim enough veins → reckoning evaluates nurture vs harvest trajectory.
- Ember dies / population wiped in outlands → Collapse lose.
- Full-screen ending overlay (title, outcome badge, body, stats, Restart).

## Non-goals this round
- Full TD lane combat / multi-base logistics.
- Map hitbox polish.
- Natural faction-gate playthrough polish (still data `require`).
- Full 6-ending Phase 5 catalog (only 3 endings: nurture win, harvest win, collapse lose).

## Implementation sketch
1. `data/endings.json` — titles, bodies, outcome (`win`/`lose`), trigger notes.
2. `GameState` — load endings; tally path morals; `_check_ending_conditions` / `trigger_ending`; pause on end; save/reset fields.
3. `GameEvents.ending_reached` — UI hook.
4. `Main` — ending overlay + Restart clears via existing reset path.
5. `test_headless.gd` — assert nurture win + collapse lose + endings.json loads.

## Success criteria
- headless_verify PASS
- test_headless PASS (incl. new ending assertions)
- Commit + UPGRADE_R3.md; no push
