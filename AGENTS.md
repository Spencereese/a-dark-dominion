# A Dark Dominion - Project Rules for AI Assistants (Grok Build, etc.)

**Master Narrative Bible**: [STORY.md](STORY.md) contains the full meaning of every choice, exact text for the early haven incursion + all delayed reframes, every path revelation, alignment-driven mutations, progression story beats, and planned endings. All new content must be consistent with it and advance the gradual "I am the one binding them" realization.

This file is read by Grok Build and similar tools. Follow these conventions strictly when working in this repo.

## Game Vision (Non-Negotiable Spirit)
- Start **super basic and minimal** (vast ashen darkness, a single ember, one or two actions, almost nothing on screen). Clearly inspired by the slow, revelatory progression and moral realization of classic slow-build games, but the metaphors, opening, text, building names, and realization must be original so it does not feel like a copy.
- **Every expansion must feel surprising and reframe prior play.** New buttons, panels, resources, or mechanics should make the player go "oh... I see what I've been doing."
- **Moral weight is systemic**, not lectured. Text, rates, available options, and outcomes shift based on alignment. "Good" is often slower/harder. "Evil" is seductive for the numbers.
- The story is told through **mechanics and UI mutation** first, flavor text second. No walls of exposition. Use **at most one exact quote** from any inspirational source across the whole game.
- Keep the "slow build" feeling: deliberate, juicy, addictive idle + meaningful decisions. Support speed controls and offline progress from the start.
- Differentiation: The core fantasy is "you are the last light in the ash. You grow it by binding the lost to your will. The oppressive realization is that you are not saving anyone — you are recreating the exact structures that turned the world to ash, and the people have become extensions/fuel of the Hearth." Change all surface language (no "room", "freezing", "wood", "hut", "slaves" as direct lifts). Use Ember, Ash, the Bound, Havens, Resonance, the Will.
- The title of the game is "A Dark Dominion" (user preference). All documentation and the in-game title reflect this.

## Technical Conventions
- **Godot 4.3+**, GDScript 2.0.
- **Primary UI is code-driven for the prototype phase** (easier for rapid AI edits). Use scene instancing for reusable bits (ActionButton, ResourceRow). Move to pure .tscn when stable.
- **Central state**: GameState autoload is the single source of truth. All systems read/write through it or via GameEvents signals. Never duplicate resource/pop counts in UI.
- **Data-driven content**: 100% for actions (data/actions.json with conditions/cost/effects/log/unlocks_at) and buildings (enhanced data/buildings.json). Generic _check_conditions / _apply_action_effects / _meets_unlock_reqs in GameState. UI _refresh_actions loops action_data. NarrativeSystem stub for revelations. Prefer data/*.json . Load at runtime.
- **Signals over polling**: GameEvents singleton for cross-system communication (`resource_changed`, `alignment_shifted`, `action_performed`, `phase_advanced`, `narrative_event`).
- **Tick-based simulation**: Use discrete time advancement (GameState.advance_time(secs)) called from a Timer or accumulated delta in _process. Support `time_scale` (0 = paused, 1, 5, 30, etc.). Never rely on per-frame for economy.
- **Save everything that matters**: GameState + key managers must serialize cleanly to JSON. Include last_played_unix for offline calc. Support slots + "New Game+" meta.
- **Phases**: String or enum `current_phase`. Gate content behind it. New phases should add visible UI surface area (new panel, tab, map area).
- **Alignment**: float -1.0 (tyrant/oppressive) to +1.0 (benevolent). Affects production multipliers, event tables, text flavor lookups, and ending branches. Changing it should be felt immediately in UI text where possible.
- **Narrative first**: When adding a building, action, or system, also add at least one associated revelation or text evolution that hints at the cost. The master reference for all branches, verbatim reframes (early choice + paths), mutations, and "does prior play now feel like the first claim?" logic is [STORY.md](STORY.md). Read it first.

## Code Style & Organization
- Scripts in `scripts/`: Managers at root (GameState.gd, NarrativeSystem.gd, MapSystem.gd), small components in subfolders if needed.
- Scenes in `scenes/`. Keep Main.tscn lightweight; it orchestrates panels.
- `resources/`: Custom Resource classes + .tres for balance or complex defs.
- `data/`: JSON content. Edit these with care; they drive unlocks and balance.
- Use typed variables and return types where it doesn't slow prototyping.
- Prefer composition. Small focused nodes/scripts.
- Comments: Explain *why* a moral or narrative hook exists, not just what the code does.
- Error handling: For prototype, use asserts or prints in debug. Production paths should degrade gracefully.

## UI / Feel Rules
- Dark, austere, high-contrast. Black or near-black backgrounds. Text in off-white, warm accents only for the ember / rare positive moments.
- All core actions are big, clear buttons or rich text links that appear/disappear.
- Event log is sacred: chronological, skimmable, with BBCode for emphasis and color by alignment impact (green for benevolent, red for tyranny).
- Numbers should "pop" on change (Tween scale or modulate).
- Always visible: Current resources with rates, current phase hint, alignment "temperature" (subtle — maybe just in advanced stats or log).
- Speed controls always available once past the very first minutes.

## Workflow with Grok Build
- Use **plan mode** before designing or implementing a new phase or major system.
- Use **subagents** (parallel worktrees) for independent pieces once the skeleton is stable (e.g., one agent on new buildings + data, one on map prototype, one on a specific event chain).
- After edits: Describe the change, then suggest or run a "mental playtest" (what buttons are available, what text the player sees after 10/30/60 min).
- When balancing: Provide before/after numbers and projected play impact.
- For new content (building, event): Always update DESIGN.md briefly and add to data/ if applicable.
- Test the "revelation" feeling: After adding something, ask "does this make previous actions feel different in hindsight?"

## Scope Discipline
- Ruthlessly cut. The power is in the *gradual* reveal.
- Prototype order (updated per user-directed acceleration in approved plan session): Ashen dark & the Ember (perfect) → Foraging & basic survival → Outposts & first hints → Havens & population with moral seed → First major choice event that reframes the "help" → Simple map/expedition tease + early defense (Phase 3/4 MVP, implemented) → **Visual RTS/TD map evolution + production queues (C&C flavor) + data-filtered faction branching via moral choices + Memory system for layman accessibility** (current active milestone; see approved plan.md for full rationale, user clarifications on schematic moving-elements map, data branching for "unknowingly set your faction", Memory tied to early_choice, and bigger redesign scope). Only after the visual TD + faction + Memory layer feels magical with strong reframe do we add deeper multi-outpost / full grand strategy.
- Every feature must answer: "How does this advance the story of 'I am becoming something monstrous or something great'?" (now also: "How does this make the binding visible on the map and legible in Memory while keeping the mystery until the reframe lands?")
- When adding first map/expedition layer (historical Phase 3, now evolved): (the original detailed wireframe for the list MVP remains the foundation record; see the 2025 plan.md link in this file for the exact implemented state).
  **Current record for foundation (Phase 3 MVP + paths expansion + early defense + early choice polish)**: Fully implemented + verified (Narrative/tests/docs subagent run, reframe/early_choice integration with polish, mental play criteria passed per plan, full diff audit via grep — zero player-text violations). See historical approved plan.md (/Users/spencereese/.grok/sessions/%2FUsers%2Fspencereese/019e8999-9119-7e50-a0ac-7997b1d4204e/plan.md) for exact code state at impl, subagent briefs, test results, completion notes. Line numbers in this spec are historical; current code (post-polish) has minor shifts e.g. in _check_delayed_choice_reframe / _check_phase_advancement but follows patterns exactly.
- **When adding visual map elements, production queues, or faction-branched content (current accelerated phase per approved plan)**: 
  1. Add visual metadata to paths.json (e.g. "visual": {"angle_deg", "radius", "length", "control_offset"}) or new/extended entries in buildings.json/actions.json (queue_type, boost_amount, "require": {"align_lt": -0.2, "early_choice": "demand"} or faction_tag, unlock_log, desc).
  2. Extend generic handlers only (GameState: lightweight production queue advanced in advance_time like expeditions; faction filter method used in _meets_unlock_reqs / _refresh_actions / check_conditions; map helpers for vein progress/state from eta/claims/defense; no per-id hardcodes).
  3. New dedicated 2D scene (scenes/OutlandsMap.tscn Node2D with schematic veins from data visual, moving expedition/raid entities using eta/total_play_time progress, tower nodes for Watch + faction variants, central Hearth). UI integration follows existing unfurl/dynamic panel patterns (new MapPanel in MainArea like outlands/choice; hybrid visual + compact list/buttons).
  4. Memory system (ledger in GameState, populated on choice/claim/raid/production/align events with STORY texts + get_flavored_text using early_choice context). New Memory/Reflections panel in Main (curated, progressive).
  5. Map visuals must evolve with moral weight/alignment (vein tint/scar/thorn vs protective glow; tower icons change appearance; claimed areas "remember" the choice). Every addition gets ≥1 reframe revelation + Memory entry (consult STORY.md for exact branch meaning, early_choice reframes, path revelations, and "does this make prior actions feel complicit?").
  6. Hook sfx_cue + new map signals (expedition walking by "distance" on path, vein-specific raid threat rumble, claim resonance tied to early_choice memory) per SOUND_DIRECTION.md.
  7. Audit differentiation strictly (ash/ember/the lost/Bound/Havens/paths/veins/claiming/Weight; no room/fire/hut/wood/slaves). Test reframe feeling + Memory clarity explicitly (after dispatch/claim/production on kind vs harsh: does the map show different visual state? Do different faction options appear? What does Memory say about your past choices? Does the gut-punch still land cleanly?).
  8. Use subagents with clear briefs referencing the approved plan.md + "follow exact generic dispatch/resolve/unlock patterns from current paths code", "data-first", "add reframe + memory entry for every addition".
  9. Update DESIGN/AGENTS/SKILL/README immediately.
- Always check against the differentiation rules above before adding text or names.

**Current record for accelerated phase**: See the plan.md in the current session directory (the one created during plan mode for this redesign) for the detailed breakdown, user clarifications, architectural choices, and implementation order. Update that plan.md or create follow-up notes on any tweaks.

- Always check against the differentiation rules above before adding text or names.

## Ending & Replay
- Multiple distinct endings based on alignment trajectory + key flags (havens built, "push" used, specific choices, "respected the old echoes", etc.).
- Support a "no havens / pure solo" challenge run with different story beats (harder, different moral weight).
- Post-game: Stats + "The next keeper..." hint at the cycle or legacy.

## Steam / Release Notes (Future)
- Focus on wishlists with a strong vertical slice (to first major revelation + map tease).
- Achievements for mechanical + narrative milestones ("Stoke the Fire", "First Laborers", "The Cloth in the Trap", "No Slaves Run", "The World Bows", specific endings).
- Controller friendly UI (focus, big hit areas).
- Offline + speed controls = perfect for Deck.

If something in this file conflicts with new discoveries during play, update the file and note why.

Build slowly. Reveal carefully. Make every click feel like it matters more than the player yet knows.
