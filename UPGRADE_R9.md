# UPGRADE_R9 - Raid auto-timeout

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `b09a8fe`
**Slice:** Pending raids auto-resolve after a short wait (default Hold the Watch) so ignored prompts no longer freeze the stack. Keep R3-R8 green.

## What landed
1. **`data/raids.json`** - `timeout_sec` (30) + `timeout_choice` (`hold_watch`) on `path_raid`.
2. **`scripts/GameState.gd`** - stamp timeout fields on offer; real-delta tick in `_process` while paused; game-time check in `advance_time`; `tick_pending_raid_timeout` / `timeout_pending_raid` / `get_raid_timeout_remaining`.
3. **`scripts/Main.gd`** - countdown label on encounter panel; hide/unpause still driven by resolve signal.
4. **`test_headless.gd`** - early tick keeps pending; real-delta + game-time timeout clear via hold_watch; prior rounds retained.
5. **`PLAN_R9.md`** - matches this slice.

## Verify
- Godot `--headless --quit --import` - PASS (exit 0).
- Godot `--headless -s res://test_headless.gd` - **RESULT: PASSED** (ObjectDB quit crash may still non-zero after PASSED).

## Notes / leftovers
- Multi-outpost logistics deferred.
- ObjectDB leak / crash-on-quit under headless `-s` (pre-existing).
- Richer NG+ meta deferred.
