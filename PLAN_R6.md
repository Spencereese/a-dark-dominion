# PLAN_R6.md - Round 6 major slice

**Date:** 2026-09-06 (America/New_York)
**Repo tip at start:** `1b92685`
**Constraint:** ONE heavy slice. Godot 4 + JSON data-driven. Preserve headless + endings + faction + NG+. Commit, do not push.

## Leftovers from UPGRADE_R5.md
- Deeper TD / multi-outpost logistics (raid stub auto-resolved; no player-facing encounter UI).
- Full Phase-5 ending catalog / richer NG+ legacy.
- ObjectDB leak / crash-on-quit warning under headless `-s` (pre-existing).

## Chosen slice (highest playable-depth leverage)
**Simple raid/defense encounter UI using existing data/JSON — playable, affects GameState + Memory.**

1. **`data/raids.json`** — one `path_raid` encounter with 4 responses (Hold Watch / Pull Them Back / Strike the Ash / Abandon the Line). Costs + effects data-driven.
2. **GameState** — raids become *pending encounters* instead of instant resolve. `offer_raid_encounter` / `resolve_raid_encounter(choice_id)` apply defense, pop/shards, alignment, Memory, then emit `raid_occurred`. Skip stacking while pending. Persist `pending_raid` in save.
3. **Main** — dark encounter panel (choice-prompt pattern): pause on offer, buttons from JSON, refresh Memory/map/status on resolve.
4. **test_headless** — force offer + each response path asserts; keep R3 endings + R4 faction + R5 hitboxes/NG+ green.

## Non-goals this round
- Full TD lane combat / multi-outpost logistics / projectile towers.
- Full 6-ending Phase-5 catalog.
- Rewrite of Main / GameState architecture.
- Fixing ObjectDB quit quirk.

## Success criteria
- headless import PASS
- test_headless RESULT: PASSED (raid encounter + Memory + prior rounds)
- Commit + UPGRADE_R6.md; no push
