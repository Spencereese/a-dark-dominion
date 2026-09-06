# UPGRADE_R11 - Richer NG+ meta

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `8214388`
**Slice:** Expand NG+ beyond Memory shard: echo marks, data-driven legacies, challenge modes, prior-alignment flavor.

## What landed
1. **`data/ng_plus.json`** — echo marks by ending; shard bonus scale; 8 legacies; 3 challenges; alignment flavor knobs.
2. **`scripts/GameState.gd`** — load catalog; on seal award marks + unlock; on carry apply scaled shards + matched legacy + optional challenge; `ng_plus_prod_delta` / `ng_plus_raid_mod`; `get_ng_plus_summary()`.
3. **`scripts/Main.gd`** — ending overlay Echo/Legacy/Challenge lines; "Awaken Next Cycle (NG+)" when pending.
4. **`test_headless.gd`** — echo/legacy/challenge/deep-ash asserts; prior R5 one-shot carry retained.

## Verify
- Godot `--headless --quit --import`
- Godot `--headless -s res://test_headless.gd` — **RESULT: PASSED** (ObjectDB quit crash may still non-zero after PASSED).

## Notes / leftovers
- ObjectDB leak / crash-on-quit under headless `-s` (pre-existing).
- Deeper multi-base map/politics still Phase 4 aspirational.
- Challenge modes are soft modifiers (prod/raid); full alternate story beats still future.
