---
name: a-dark-dominion
description: Project-specific workflows and rules for A Dark Dominion. Use in addition to godot-dev when actively working inside the a-dark-dominion project. Captures current prototype state, phase implementation order, recurring patterns, and strict differentiation rules so the game feels inspired by but clearly distinct from A Dark Room.
---

# A Dark Dominion - Project Skill

**Narrative Master Reference**: The complete story bible (all branches, verbatim choice/reframe text, thematic meaning of every action, progression, mutations, and planned endings) lives in [STORY.md](../STORY.md) at project root. Read it before authoring new content. The gut-punch only works if new systems explicitly or implicitly reframe prior "helpful" play as the origin of binding.

Active when CWD contains the a-dark-dominion project (under projects/).

## Current Prototype State (as of paths layer expansion Phase 3/4 + defense + visuals + audio start)
- Fully playable ashen-dark → ember → early havens (with gut-punch) → outlands (map with 4 paths) + early defense teeth + scattered ember world growth visuals + audio skeleton.
- Paths/outlands expanded with 1 new location ("vein_of_broken_circles") for more expedition choice + reframe opportunities. Data-driven per SKILL "Implementation Order" (item 3) + "When adding a building or action" adapted: added only to data/paths.json (cost/shards, travel_time=7, 2 moral_options with benevolent/listen vs harsh, mixed rewards, logs, strong revelation tying "the lines you marked", "the choice in the havens", "weight of the first ember", "bound before"); GS minor generic tweaks (dispatch_ prefix handler, seeding from path_data.keys() + load ensure for prior saves) so future paths require zero code; UI/Main already fully generic via discovered + path_data; discovery auto on outlands phase or retro on load; Narrative flavor applied. Mental play confirms reframe on dispatch/resolve calls back to early actions/choice. (See DESIGN/AGENTS updates.)
- Polish complete for current phase (early hearth/village): more text mutations + proper early choice event so the first real "oh no, I did this" lands cleanly.
  - NarrativeSystem now has rich mutate_text + get_flavored_text(context) with mutation_rules table (alignment bands, flag/choice or-conditions), early_events + early_choice_memories, trigger_choice_event + apply_choice (returns pop/align/shards/reframed_log/memory), get_choice_reframe, get_current_context(). Variants for pop status, havens/bindings, demand, foraging->claiming, incursion prompt (choice-aware), delayed "you did this" phrases.
  - GameState: early_choice + choice_history state (persisted in save/load/reset), _check_early_choice_events() hook in advance_time, _resolve_early_choice (delegates to Narrative, records history, sets flags), _check_delayed_choice_reframe(trigger) called from path resolve, outlands phase entry, demand_more, choice itself. Cleansed the choice_* out of perform_action match into clean delegation. Incursion trigger now uses Narrative prompt.
  - Main: dedicated choice prompt UI (_show/_hide/_refresh_choice_prompt + _ensure) that creates a distinct gold-header "A Choice in the Havens" panel with flavored prompt + 3 prominent options (inserted in MainArea). Pauses time on show for weight. Auto shows/hides on flag + signals (choice_offered/resovled added to GameEvents + connected). Still surfaces fallback action buttons (now flavored). Refreshes everywhere needed.
  - Data: actions/buildings/paths have enhanced base strings that mutations hit harder (e.g. demand log now references "first haven", haven desc "the circle begins here", path revelations extended with "first claim... before any foot stepped", "taught everyone what the ash already knew").
  - Delayed reframes explicitly name the player's early choice ("When the echoes first came to the havens, you chose [shelter/demand/seal]. ... You have been binding them from the first circle.") + fire on outlands open, first path claim, post-choice if prior actions, post-demand. This makes the gut-punch land when scope expands.
- Core actions, systems, data-driven, outlands UI same as before.
- Differentiation: still strict (all player text ash/ember/Bound/claiming/veins/Havens; docs only reference the rule). No forbidden lifts in code.
- The early phase now delivers: after first Haven + pop~5 the choice prompt appears (time pauses), options have mechanical teeth + immediate reframe; later when you reach outlands/dispatch, the resolve + phase logs make prior "helping" actions feel like the origin of dominion. Different choices produce different memory phrases in the punch.
- Art: 6 generated placeholder images (via image_gen tool) now in assets/art/: ember_pulse.jpg (used for live pulsing visual in TopBar, brightness/alpha + gentle scale tied to GameState.ember_pulse), ash_field.jpg (subtle full-screen low-opacity tiled bg texture), haven_shelter.jpg, paths_veins.jpg, bound_figure.jpg, weight_accent.jpg. Added dynamically in Main.gd _setup_placeholder_art + _update_ember_visual (called on time + key actions). Matches DESIGN "AI-generated minimalist... via image_gen. Or pure text + shapes first." No scene bloat.
- Sound: assets/sound/SOUND_DIRECTION.md + initial impl (resources/audio_buses.tres with Ash/Ember/Dread/UI; Main _setup_audio + players + AudioStreamGenerator for cues + fill; _play_*_cue hooked to nurture/feed/gather/defend/raid/choice-offer/resolve + alignment bus vol tweaks + phase entry; _generate_tone_burst + _fill_ash_ambient for audible lo-fi placeholder tones without assets). Cues: warm swells for ember, dry noise for gather, dread rumbles for raids (mitigated vs loss), tension/resolve stings for choices (per align). Dynamic mix started. Matches direction; still sparse (more fills/eta/claim stings/reverb stubs remain per TODO in doc). See recent drive in README.

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
