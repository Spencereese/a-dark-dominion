# PLAN_R7.md - Round 7 major slice

**Date:** 2026-09-06 (America/New_York)
**Repo tip at start:** `fc45e98`
**Constraint:** ONE heavy slice. Godot 4 + JSON data-driven. Preserve headless + raids + faction + NG+. Commit, do not push.

## Leftovers from UPGRADE_R6.md
- Deeper TD lane combat / multi-outpost logistics / projectile towers.
- Full Phase-5 ending catalog (still 3 endings).
- Richer NG+ legacy meta beyond Memory shard.
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing).
- Auto-timeout resolve if player never answers a pending raid.

## Chosen slice (highest playable-depth leverage)
**Phase-5 ending catalog expansion: 3 → 6 data-driven endings with special reckoning paths.**

Per DESIGN.md Phase 5 (at least 4–6 variants), keep the three R3 endings and add:
1. **true_echo** (Hidden / True WIN) — shelter early choice, never Demand More, high alignment, zero harvest tallies, nurture faction building present.
2. **sparse_hearth** (No-Huts / Minimalist WIN) — nurture-leaning reckoning with zero buildings raised (circle claimed veins without raising the ash into walls).
3. **pyrrhic_crown** (Pyrrhic / Tragic WIN) — harvest-leaning reckoning while the circle is nearly emptied (population 1–2).

Scoring priority on path_claim/force after collapse checks:
true_echo → sparse_hearth → pyrrhic_crown → nurture_circle / harvest_dominion.

## Non-goals this round
- Full TD lane combat / multi-outpost logistics / projectile towers.
- Auto-timeout for unanswered raids.
- Fixing ObjectDB quit quirk.
- Broader NG+ meta beyond ending-flavor shard apply.

## Success criteria
- headless import PASS
- test_headless RESULT: PASSED (6 endings + special paths + prior R3–R6)
- Commit + UPGRADE_R7.md; no push
