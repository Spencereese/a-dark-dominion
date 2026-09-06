# PLAN_R10 - Multi-outpost logistics

**Date:** 2026-09-06 (America/New_York)
**Base tip:** `3c7d490`
**Focus (one leftover):** Multi-outpost logistics - claimed veins stockpile locally; supply convoys travel to the hearth with ash-tax risk. Biggest remaining gameplay leftover.
**Non-goals this round:** ObjectDB quit crash under `-s`, richer NG+ meta.

## Why this slice
R3-R9 built claims, raids, towers, and endings, but claimed veins still poured straight into hearth rates. DESIGN calls for supply lines that must travel or risk loss. Routing outpost production through stockpiles + convoys makes multi-claim dominion feel like logistics, not free passive income.

## Deliverables
1. `data/logistics.json` - outpost rates, stockpile cap, auto-dispatch threshold, loss/mitigation knobs.
2. `GameState.gd` - load logistics; outpost stockpiles + active convoys; tick production/auto-dispatch/resolve; manual `dispatch_convoy`; save/reset; Memory for first convoy + loss.
3. `Main.gd` - claimed-vein status shows stockpile / convoy ETA; Call Supply Line button.
4. `test_headless.gd` - logistics data + stockpile/dispatch/delivery/loss asserts; keep prior rounds green.
5. `UPGRADE_R10.md` after green headless.

## Done when
- `test_headless.gd` prints `RESULT: PASSED`
- Commit on main, no push
