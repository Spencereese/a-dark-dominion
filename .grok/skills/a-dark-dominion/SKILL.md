---
name: a-dark-dominion
description: Project-specific workflows and rules for A Dark Dominion. Use in addition to godot-dev when actively working inside the a-dark-dominion project. Captures current prototype state, phase implementation order, recurring patterns, and strict differentiation rules so the game feels inspired by but clearly distinct from A Dark Room.
---

# A Dark Dominion - Project Skill

**Narrative Master Reference**: The complete story bible (all branches, verbatim choice/reframe text, thematic meaning of every action, progression, mutations, and planned endings) lives in [STORY.md](../STORY.md) at project root. Read it before authoring new content. The gut-punch only works if new systems explicitly or implicitly reframe prior "helpful" play as the origin of binding.

Active when CWD contains the a-dark-dominion project (under projects/).

## Current Prototype State (accelerated visual RTS/TD + emergent faction via moral choices + Memory for layman accessibility, per user-directed bigger redesign approved in plan session)
- Foundation (Phase 3 MVP + early Phase 4): Fully playable ashen-dark → ember → early havens (with gut-punch) → outlands (map with 4 paths) + early defense teeth + scattered ember world growth visuals + audio skeleton. Paths/outlands expanded with data-driven expeditions (moral choices, timed resolve, strong reframe revelations tying prior "helping" as first binding/claiming), defense_strength + raids (mitigated, claim-tied reframes, ash/ember flashes), early_choice persisted for delayed personal reframes. All generic/data-driven.
- Active focus (accelerated per user request "more of an rts/tower defense", "moral choices unknowingly set your faction", "maintain the mystery while making the story make more sense to the layman"): 
  - Dedicated 2D schematic visual map (veins/lanes with moving expedition and raid entities, visual tower/defense contributions along paths, alignment/moral-weight tinting for "binding" — e.g. harsh claims scar/dark en veins with Bound labor icons; benevolent steadier protective glows). Evolves the previous list-based "Paths in the Ash" panel into a hybrid visual + controls (unfurls like before).
  - Production queues (C&C flavor): Several data-driven buildings (Labor Hall for Hands that boost defense/expeditions, Spire Works, tyrant aggressive variants like Dread Foundry, benevolent protective like Sanctuary Ward). Simple generic queue system advanced in advance_time; player sees different options appear based on cumulative alignment + early_choice (unknowingly shaping "faction" playstyle without explicit labels).
  - Full data-filtered faction branching: alignment ("Weight") + early_choice + flags filter available defenses, towers, production options and behaviors via JSON "require" fields (tyrant: high-output risky aggressive; benevolent: stable protective/loyal). Emergent from moral play.
  - Memory system (tied to existing early_choice/choice_history): Surfaces curated STORY-sourced context + echoes over time in a new "Memory"/"Reflections" panel. Makes mechanics and world logic legible to layman (cause-effect on map + "this is what your demand at the first haven set in motion") while preserving poetic mystery in the main log and the big gut-punch reframes.
- All additions: Data-first, generic handlers extended (not bypassed), every new system gets reframe revelation + Memory entry (consult STORY.md), visual evolution that makes moral consequences spatial/visible, audio hooks per SOUND_DIRECTION.
- Polish on foundation + new layer: Rich mutations, dedicated choice prompt (gold, time-pause), alignment mechanical + narrative teeth, scattered embers, audio skeleton (now with map distance/threat layers).
- Differentiation: Strict (player text ash/ember/Bound/claiming/veins/Havens/Weight/pulse; docs reference the rule only). No forbidden lifts.
- The realization still lands exactly as designed: prior "helpful" actions (foraging, havens, dispatch, now production/claiming on the map) are reframed as the origin of dominion when the player sees the visual consequences and reads the Memory/reframes naming their specific early choice.
- Art/Sound: 6 placeholder jpgs (ember_pulse breathing, ash_field, veins, etc.) + dynamic use in map visuals. Buses + Generator cues extended for map (expedition walking by "distance", vein-specific raid threat, claim resonance tied to early_choice memory).
- See approved plan.md for the full redesign rationale, user clarifications, architectural choices, and detailed breakdown.

## Implementation Order (Follow This — accelerated per user direction)
1. **Polish current core** (DONE — foundation): Early gut-punch + mutations + choice event + delayed reframes land cleanly.
2. **Data-driven everything** (COMPLETED — foundation): actions/buildings/paths 100% data, generic apply/unlocks/refresh.
3. **First map / expeditions** (COMPLETED as MVP list + expanded to 4 paths with generic support + reframe — foundation).
4. **Defense / first TD-lite** (deepened with strength/decay/partial losses/visual flashes/claim-tied reframes — foundation; now evolving into visual TD on map).
5. **Visual RTS/TD map + production queues + faction branching + Memory** (ACTIVE — user-directed bigger redesign): Dedicated 2D schematic map scene with moving elements (expeditions/raids on lanes/veins), visual defense/towers, alignment/moral tinting for binding consequences. Several production buildings with C&C queues (Hands, Spire works, faction variants). Data-filtered faction trees (alignment + early_choice branch available defenses/production without naming "faction"). Memory system (tied to early_choice) for layman context while mystery + reframe gut-punch preserved. Builds directly on 3+4; data-first + generic + reframe-every-addition.
6. **More buildings/jobs + deeper branching** (will incorporate into the above as faction trees expand; C&C queues, multi-outpost flavor).
7. **Endings + full world layer** (later; multiple variants based on alignment trajectory + flags + map state; cycle hint preserved).

Never jump ahead without explicit designer sign-off. User has explicitly directed this acceleration of visual TD + faction emergence + accessibility layer as the current milestone (see approved plan.md). We evolve the implemented paths + defense foundation rather than starting from zero. All new map/production/faction content must still deliver ≥1 reframe + Memory entry and advance the gradual realization.

## Specific Patterns for This Game (extended for new systems)
- When adding a building or action: (existing rules 1-5 remain; now also consider faction reqs + production queue_type + memory entry + map visual impact).
- When adding visual map elements, production queues, or faction-branched content:
  1. Add visual metadata to paths.json (e.g. "visual": {"angle_deg", "radius", "length"}) or new/ extended entries in buildings.json/actions.json (queue_type, boost, "require": {"align_lt": -0.2, "early_choice": "demand"} or faction_tag).
  2. Extend generic handlers only (GameState queue advance like expeditions, faction filter in _meets_unlock_reqs / _refresh_actions / check_conditions, map helpers for progress/state from eta/claims/defense; no per-path or per-building hardcodes).
  3. New 2D scene (OutlandsMap.tscn Node2D) or UI panel follows existing unfurl/dynamic patterns (MapPanel like outlands/choice). Memory population on events (choice, claim, raid, production, align shift).
  4. Add narrative trigger + Memory entry via NarrativeSystem (consult STORY.md for exact branch meaning, early_choice reframes, path revelations, "does this make prior actions feel complicit?").
  5. Update flavor in data or NarrativeSystem.get_flavored_text; map visuals must evolve with moral weight/alignment (vein tint, tower icons, "binding" overlays).
  6. Hook sfx_cue + new map signals (expedition walking by distance, vein-specific threat, claim resonance tied to early_choice) per SOUND_DIRECTION.md.
  7. Every addition must advance the gradual realization (reframes name prior "help" + early_choice as origin of dominion; Memory makes the "why the map/vein looks this way" legible to layman without spoiling the twist).
  8. Mental playtest + reframe check ("after first Haven + claim on kind vs harsh: what does the map show? What new options appear? What does Memory say? Does the gut-punch still land?"). Explicitly check differentiation (grep player text).
- Alignment changes + moral choices should come with log/revelation + Memory entry + visible map consequence.
- Every new pop/labor/production feature must consider "free vs bound" and "demand more" risk (and surface it in Memory/map).
- Save impact: New state (queues, memory_entries, map progress if any) goes into the save dict.
- Testing: After changes, "play" mentally or have user describe 10-15 min from start on different choice paths. Note map state, available faction options, Memory content, whether prior actions now feel like the first claims. Use `@scenes/OutlandsMap.tscn @scripts/GameState.gd @scripts/Main.gd` when changing map + logic together.
- Use subagents for isolated pieces (e.g. "implement the 2D map scene + entity movement against the approved plan's visual spec and existing eta/state patterns").

## Useful Commands / Habits (updated)
- In Godot editor: Run the scene (open scenes/Main.tscn or the new OutlandsMap.tscn), use Reset often for different moral paths. Inspect the map visually for binding consequences.
- With Grok: `@scenes/OutlandsMap.tscn @scenes/Main.tscn @scripts/GameState.gd @scripts/Main.gd` when asking for map + UI + logic changes together. Reference the approved plan.md for the exact vision (schematic moving elements, data-filtered faction, Memory tied to early_choice, reframe on every addition).
- Use subagents for "implement the dedicated 2D map scene with moving expeditions/raids + tower visuals in an isolated tree, following the approved plan and generic patterns from current paths code".
- Example brief (map visual + faction + Memory): "Evolve the outlands defense/paths into the approved visual schematic 2D map (Node2D veins from path_data visual metadata, moving entities for active_expeditions and raids using eta/total_play_time progress, tower nodes for Watch + new faction variants, tint/overlay by claim moral + alignment). Add generic production queue in GameState (data-driven start/complete like expeditions, several Labor Hall / Spire Works / tyrant-benevolent variants with require fields). Implement faction filter (data reqs on align/early_choice) used in unlocks and _refresh_actions so different options appear based on past moral play without naming 'faction'. Add Memory ledger + UI panel (tied to early_choice, populated on claim/raid/production with STORY texts + get_flavored_text). Every addition must call reframe + add_memory and have visual consequence on map. Follow exact generic dispatch/resolve/unlock patterns from current paths code (lines ~501, ~581, ~862 etc.). Data-first. Update visuals for moral weight. Mental play different early choices and describe what the map shows after first claim + what new production/defense options appear + what Memory says. Reference approved plan.md + current SKILL 'When adding...' + SOUND_DIRECTION for audio hooks."
- Keep DESIGN.md, AGENTS.md, and this SKILL updated when big decisions are made (this session's plan updated them to reflect the accelerated visual TD + faction + Memory direction).

## Tone Reminders (unchanged)
The game should feel cold, patient, inevitable, and original. The player should be able to play "optimally" for numbers and still feel uneasy by the time the central Hearth is thriving — uneasy specifically because the language, systems, *and now the visual map and Memory* have made them complicit in something that feels freshly horrifying, not like a retread of another game's twist. The title is "A Dark Dominion" as requested. The map makes the binding spatial and visible; Memory makes the "why" legible to a layman; the reframe still delivers the personal gut-punch.

This skill should be updated after every major milestone (use /skillify on sessions that added significant new systems such as the visual map, production queues, or faction branching).

## Implementation Order (Follow This)
1. **Polish current core** (DONE): "I think I am the monster" / first "oh no, I did this" gut-punch now lands cleanly in early phase via more mutations + proper early choice event. (See "Current Prototype State" for details on Narrative context/mutate/choice events, GS delayed reframe + early_choice state, Main dedicated prompt UI with pause, data enhancements, and cross-calls from outlands resolve/phase/demand.)
   - More dynamic text mutations based on alignment and flags (e.g. "the lost are grateful" → "they no longer speak unless the Will moves them").
   - Better unlock triggers and first major choice event that makes prior "helping" feel wrong.
   - Juice: number pops, button unlock animations, ember "pulse" visual (simple modulate or particles later).
2. **Data-driven everything** for buildings, actions, events. (COMPLETED: actions.json + buildings enhanced, generic apply/check in GameState, UI refresh now loops action_data + conditions; NarrativeSystem stub added for triggers/flavor.)
3. **First map / expeditions** (simple list of locations with resolution that feeds resources + alignment; 4 now via data/paths.json). Use original location flavor (ruined resonance sites, not "dusty path"). **COMPLETED as MVP + expanded** (Paths in the Ash panel, expeditions with moral choices, timed resolve + reframe revelations that call back to foraging/Havens/early choice/"first ember" as first claims, raid tease, Watch Spire unlock, full UI integration + signals; new locations added data-only after genericing dispatch/seed). See approved plan + SKILL "Current State" for details.
4. **Defense / first TD-lite** (periodic ash-storms or "echo raids" on the central Hearth or outposts, resolved with modifiers from buildings + alignment). (Basic tease in 3; deepened: defense_strength var + decay + add via defend action + watch contrib + partial loss + "Paths watched" UI + raid signal + ash/ember flash visuals + richer claim-tied reframes. Ongoing.)
5. **More buildings/jobs** with real C&C flavor (production building that queues "Hands", "Resonators", "Watchers").
6. **Branching content**: Different available buildings/actions per alignment band.
7. **Endings** (at least 3-4 variants + no-havens pure solo challenge path).

Never jump ahead of the current phase without explicit player/designer sign-off. (Outlands/paths was the next after polish 0-2 + data; do not add Phase 4 multi-outposts until 3 feels magical with reframe.)

## Specific Patterns for This Game
- When adding a building or action: 
  1. Add to data/buildings.json or data/actions.json (100% data-driven: conditions, cost, effects {pop, rates, moral_weight, log, unlock_log, assign, build, align_delta, ...}, unlocks_at).
  2. No (or minimal) wire in GameState -- generic check_conditions / _apply_action_effects / _meets_unlock_reqs / _try_build interpret data. UI _refresh_actions loops action_data.
  3. Add narrative trigger via NarrativeSystem.trigger_revelation (central stub for revelations + get_flavored_text based on alignment).
  4. Update flavor in data or NarrativeSystem.get_flavored_text so text changes with alignment.
  5. Consult [STORY.md](../STORY.md) (the master story bible) for exact branch meaning, early_choice reframes, path revelations, and "does this make prior actions feel complicit?" criteria. Every addition must advance the gradual realization.
- Alignment changes should usually come with a log line in "revelation" category.
- Every new pop-related feature must consider the "free vs bound" and "demand more" risk.
- Save impact: If you add state, make sure it goes into the save dict in GameState and is restored.
- Testing: After changes, "play" mentally or suggest the user runs and describes 10 minutes of play. Note what text they see after raising the first Haven on a "kind" vs "harsh" run. Explicitly check it does not feel like a direct lift.

## Useful Commands / Habits
- In Godot editor: Run the scene, use the Reset button often for different paths.
- With Grok: `@scenes/Main.tscn @scripts/GameState.gd` when asking for UI + logic changes together.
- Use subagents for "implement the full traps + first expedition system in an isolated tree".
- Example brief for map layer (from approved plan): "Implement Phase 1+3+4 in GameState.gd: paths data load (exact _load_building_data pattern), new state vars (discovered/active/claims), dispatch_expedition + _resolve_expeditions (moral lookup, mults from alignment/foraging_lines/foragers, pop like haven, reframe revelations from data that reframe foraging/Havens as binding), extend _check_phase_advancement (exact village block), advance_time, perform_action for defend + dispatch, save/load, _trigger_path_raid (unrest pattern), _check_unlocks for watch_spire. Follow foraging_lines/haven exactly. Include basic raid tease. Test with mental play + logs. Reference plan for exact text/data ids/lines." Similar for Main UI (dynamic panel using resources/actions patterns, eta via time, etc.).
- Keep DESIGN.md and AGENTS.md updated when big decisions are made.

## Tone Reminders
The game should feel cold, patient, inevitable, and original. The player should be able to play "optimally" for numbers and still feel uneasy by the time the central Hearth is thriving — uneasy specifically because the language and systems have made them complicit in something that feels freshly horrifying, not like a retread of another game's twist. The title is "A Dark Dominion" as requested.

This skill should be updated after every major milestone (use /skillify on sessions that added significant new systems).
