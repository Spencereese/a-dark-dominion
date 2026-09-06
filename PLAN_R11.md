# PLAN_R11 - Richer NG+ meta

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `8214388`
**Constraint:** ONE heavy leftover slice. Tokens expiring. Commit, do not push. Keep `test_headless.gd` RESULT: PASSED.

## Slice
Richer NG+ meta (biggest remaining gameplay leftover after R10 logistics).

## Non-goals
- ObjectDB quit crash under `-s` (pre-existing; skip unless easy).
- Deeper multi-base map/politics (still Phase 4 aspirational).

## Deliver
1. `data/ng_plus.json` — echo marks, legacies, challenge modes, shard-bonus scaling.
2. `GameState.gd` — seal unlocks + apply legacies/challenges; prior-alignment raid flavor; summary API.
3. `Main.gd` — ending overlay shows echo/legacy/challenge; NG+ restart label.
4. `test_headless.gd` — R11 asserts; keep R3–R10 green.
