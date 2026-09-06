# PLAN_R9 - Raid auto-timeout

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `b09a8fe`
**Focus (one leftover):** Raid auto-timeout — unanswered pending raids currently freeze the stack forever (and UI pauses game time). Biggest UX win for one slice.
**Non-goals this round:** Multi-outpost logistics, ObjectDB quit crash under `-s`, richer NG+ meta.

## Why this slice
R6–R8 left pending raids blocking new offers until the player answers. The encounter UI also pauses time, so an ignored prompt never clears. Auto-timeout restores flow: watchers act without orders after a short wait, pending clears, and new raids can fire.

## Deliverables
1. `data/raids.json` — `timeout_sec` + `timeout_choice` on `path_raid` (default hold_watch).
2. `GameState.gd` — stamp timeout fields on offer; real-delta tick while paused; game-time check in `advance_time`; `tick_pending_raid_timeout` / `timeout_pending_raid` / `get_raid_timeout_remaining`.
3. `Main.gd` — show remaining wait on encounter panel; keep hide/unpause on resolve signal.
4. `test_headless.gd` — timeout clears pending via hold_watch; early tick does not fire; keep prior rounds green.
5. `UPGRADE_R9.md` after green headless.

## Done when
- `test_headless.gd` prints `RESULT: PASSED`
- Commit on main, no push
