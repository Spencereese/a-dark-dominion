# PLAN — Major upgrade slice (2026-09-06)

Trust the code, not the docs. Audit of dirty WIP on `main` vs what still fails the core loop.

## What already works (WIP, uncommitted before this slice)
- **Phase 0–2 loop**: nurture/feed/gather, havens, foragers, Demand More — data-driven via `data/actions.json` + `GameState.perform_action`.
- **Early haven moral choice**: echo incursion UI + `_resolve_early_choice` + alignment deltas + delayed reframes in logs.
- **Outlands list**: 4 paths in `data/paths.json` with moral options, timed expeditions, claims, Watch Spire unlock, raids + `defense_strength`.
- **Production queues (C&C)**: `start_production` / `advance_production` / labor assign; buildings include labor_hall, spire_works, dread/sanctuary, vein_forge, spire_foundry, **resonance_spire / will_press / vein_ward**.
- **OutlandsMap.tscn + OutlandsMap.gd**: schematic veins, moving entities, towers, labor dots, whisper markers — wired from Main via SubViewport.
- **Memory panel UI**: exists in Main; GameState has `memory_entries` + `add_memory` calls at key sites.
- **Headless helpers**: `headless_verify.ps1`, `test_headless.gd`, `launch_godot.ps1`.

## What was stubbed / broken (blocking 20+ min playability)
1. **Memory was mostly empty** — `add_memory` only handled production/labor keys; calls for `early_choice`, `first_outlands`, `path_claim_*`, `demand_more`, `raid_loss`, ash whispers produced **no entries**. Early choice returned `memory` from NarrativeSystem but GS never stored it.
2. **Map moral choice auto-committed** — OutlandsMap click + Main handler auto-dispatched (first option / auto bias), skipping Listen vs Harvest agency.
3. **`production_built` delayed reframe** was called but ignored by `_check_delayed_choice_reframe` trigger filter.
4. **Memory panel** forced `visible = true` even in dark phase.
5. **Headless test** only checked loads; did not simulate build → choice → expedition → production consequences.
6. Godot binary was missing from PATH on PC-Culture (templates present; engine reinstalled under `C:\Users\PC\Tools\Godot`).

## Highest-leverage slice (this commit)
Finish the **core moral loop** already sketched in WIP — do not add a new genre pillar:
- Make Memory actually record moral choices + path claims + production.
- Make map/outlands moral choices player-selected (no auto-first).
- Wire production reframe into delayed memory.
- Strengthen headless test so the loop must pass.

## Non-goals (leftovers)
- Full TD lane combat / multi-base logistics / endings.
- Audio polish beyond existing skeleton.
- Rewriting Main.gd / GameState from scratch.
