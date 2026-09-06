# UPGRADE_R10 - Multi-outpost logistics

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `3c7d490`
**Slice:** Claimed veins stockpile locally; supply convoys travel to the hearth with ash-tax risk. Keep R3-R9 green.

## What landed
1. **`data/logistics.json`** - outpost rates, stockpile cap, auto-dispatch threshold, loss/mitigation knobs.
2. **`scripts/GameState.gd`** - load logistics; outpost stockpiles + active convoys; tick production/auto-dispatch/resolve; manual `dispatch_convoy`; save/reset; Memory for first convoy + loss. Claimed veins no longer pour straight into hearth rates.
3. **`scripts/Main.gd`** - claimed-vein status shows stockpile / convoy ETA; Call Supply Line button.
4. **`test_headless.gd`** - logistics data + stockpile/dispatch/delivery/loss/auto-dispatch/cap asserts; prior rounds retained.
5. **`PLAN_R10.md`** - matches this slice.

## Verify
- Godot `--headless --quit --import` - PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` - **RESULT: PASSED** (ObjectDB quit crash may still non-zero after PASSED).

## Notes / leftovers
- ObjectDB leak / crash-on-quit under headless `-s` (pre-existing).
- Richer NG+ meta deferred.
- Deeper multi-base map/politics still Phase 4 aspirational.
