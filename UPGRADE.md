# UPGRADE — Core moral loop playable (Memory + map agency + headless)

**Date:** 2026-09-06 (America/New_York)  
**Slice:** Finish dirty WIP so build → gather → moral choice → consequence holds for a 20+ minute session.

## Dirty tree handling
Working tree was already heavily modified (GameState/Main/OutlandsMap, JSON, docs, headless scripts). **Did not wipe or stash-discard.** Folded carefully into this upgrade commit with an honest message covering both prior WIP and this slice’s fixes.

## What changed in this slice
1. **`GameState.add_memory`** — now handles early_choice, first_outlands, path_claim_*, demand_more, raid_loss, ash_whisper_*, delayed_reframe_*, production_*, labor_* (deduped by key).
2. **`_resolve_early_choice`** — writes NarrativeSystem memory into `memory_entries` immediately.
3. **`_check_delayed_choice_reframe`** — accepts `production_built`; also records a delayed_reframe memory entry.
4. **OutlandsMap** — vein click offers moral options; **no auto-dispatch**. Clicking a hint label (or Main map buttons) commits that choice.
5. **Main** — `_on_map_moral_choice_offered` shows map-panel buttons; Memory panel visibility gated to outlands / existing memories / early_choice.
6. **`test_headless.gd`** — simulates nurture → early demand choice → outlands expedition (harvest) → vein_ward production; asserts memories + claim + building.
7. **PLAN.md** — audit of works vs stubbed (code-trusted).

## Tests
- `headless_verify.ps1` (import/parse).
- `Godot … -s res://test_headless.gd` (core loop assertions).

## Leftovers
- Deeper TD / multi-outpost / endings still future.
- Map choice hitboxes are approximate Label rects; fine for prototype.
- Resonance Spire / Will Press faction gates still need aligned play to unlock naturally (covered by data `require`; headless unlocks explicitly for sim).
