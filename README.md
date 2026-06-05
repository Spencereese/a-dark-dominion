# A Dark Dominion

**A slow-burn incremental strategy game about the last light in the ash, the will to grow it, and the terrible price of binding others to your cause.**

You begin with a single ember in a world reduced to ash.

Through care, foraging, and the hands of the lost who are drawn to the warmth, you raise havens, mark paths, and expand the circle of light.

Will the Hearth become a new harmony... or the seed of a dominion that finishes what the old fires started?

Clearly inspired by the slow, mechanical-revelation style and moral realization of certain classic incremental games (such as A Dark Room), but with original metaphors (the Ember, the Ash, the Lost, the Bound, Havens, Resonance), all-new text, and a distinct realization that you are repeating the pattern that scorched the world. The name "A Dark Dominion" is used.

## Current Status
Prototype through Phase 3 MVP + early Phase 4 (ashen dark → ember → early havens with polished early choice + delayed reframes → "Paths in the Ash" outlands map/expeditions + defense layer with mechanical teeth/visuals; audio skeleton) + paths layer expansion (4th location). 

Core loop + first scope expansion (Phase 3 MVP per approved plan.md + Phase 3/4 paths expansion): dynamic "Paths in the Ash" panel unfurls in MainArea; 4 locations (data/paths.json, new "Vein of Broken Circles" added for expedition choice + reframe) with moral choice expeditions (Listen and Offer Passage vs Cut the Vein; etc. + Listen/Mend vs Claim); timed resolution via eta in advance_time + _resolve (offline catch-up, modifiers from alignment Weight/foraging_lines/foragers); ≥1 reframe revelation per outcome that explicitly calls back to prior "foraging"/Havens/"Demand More"/early choice/"first ember" as the first claims/binding (e.g. new: "The broken circles waited for the lines you marked. The choice in the havens only named what the weight of the first ember had already bound before."; "You bound them here as the first were bound... retraced what was claimed long before any foot stepped..."; old + delayed: "When the echoes first came to the havens, you chose [your shelter/demand/seal]... Every vein you mark... You have been binding them from the first circle."); raid/defense tease ("The ash moves along the old veins"); first claim unlocks Watch Spire (C&C outpost tease). Full integration (data-driven paths modeled on buildings, GameState dispatch/resolve/phase/raid/save now generic for paths, Main dynamic panel + live eta + sidebar "Defend", signals, Narrative flavored logs + mutations + early_choice context for gut-punch). Speed/offline/save/Reset. Alignment "Weight" affects rates, choices, text, raids. Strict differentiation throughout.

**Differentiation note**: Opening text, action names, building names, resource labels, and flavor have been rewritten to stand on their own (original ash/ember world). The name is "A Dark Dominion" as preferred. At most one exact quote from any source is permitted across the game. Actions and buildings are now 100% data-driven (data/actions.json + buildings.json); small NarrativeSystem stub centralizes revelations. Phase 3 map layer per approved implementation plan (full record of code, tests, subagents, audit at /Users/spencereese/.grok/sessions/%2FUsers%2Fspencereese/019e8999-9119-7e50-a0ac-7997b1d4204e/plan.md ; see also updated .grok/skills/a-dark-dominion/SKILL.md).

**Master Story File**: [STORY.md](STORY.md) — complete narrative bible with all branches, exact early choice options + immediate/delayed reframes (verbatim), every path revelation, alignment mutations, progression gates, full thematic meaning of choices ("you have been binding them from the first circle"), tracked state (early_choice/choice_history/flags/claims), and planned endings. Reference this when adding any new content.

Recent drive forward: defense_strength + raid mitigation with partial losses + "Paths watched" display + ash/ember flash visuals on raids (defend now has clear payoff); 6 scattered ember sprites populate around central as pulse/pop/havens grow (pure visual "as light grows we see more" + plural embers/amnesia reinforcement); audio buses (Ash/Ember/Dread/UI) + AudioStreamGenerator cues for nurture swell, gather scrape, raid dread, choice tension/resolve stings + alignment-reactive mix + sparse ash hiss fill.

Next: Full audio integration + refinement (more cues, reliable ambient, expedition/claim stings), deepen raids into reactive events or choice responses, C&C queues for spires/buildings, more locations + branching content (Phase 4). (Defense system now has real teeth + visual payoff; scattered ember visuals expand the "light grows, we see more" world purely visually.)

## How to Run (Godot 4.3+)

**Critical after edits (the recent parse/type fixes included):** always clean the cache.

Easiest way:

```bash
cd projects/a-dark-dominion
./launch_godot.sh
```

The `launch_godot.sh` script does `rm -rf .godot` for you + launches Godot using the confirmed path on this machine (`~/Downloads/Godot.app`).

Manual steps (if not using the script):

1. Fully quit Godot.
2. `rm -rf projects/a-dark-dominion/.godot`
3. Launch:
   - `"/Users/spencereese/Downloads/Godot.app/Contents/MacOS/Godot" --path projects/a-dark-dominion`
   - Or double-click the Godot.app in `~/Downloads/` and open this project folder.

4. In the editor, open `scenes/Main.tscn` and press Play (F5 or play button).

The game starts in the ash with a single weak ember.

**Play flow (to experience the current prototype + first gut-punch):**
- Nurture the Ember → Gather Shards → Raise Haven(s) → get foragers + use Demand More.
- At the pop + haven threshold a special "A Choice in the Havens" prompt appears (time auto-pauses). Pick shelter / seal / demand. This is persisted.
- Push resources/pop to the outlands gate (foraging_lines built + pop >= 6 + shards >= 50). The third panel "Paths in the Ash" unfurls with art + live expedition entries. (Now 4 paths.)
- Dispatch via moral choice buttons (or sidebar) — try the new "Vein of Broken Circles". Watch live ETAs. On return you get outcome logs + revelations that reframe earlier actions/choice as the "first claim" (e.g. calls back to lines marked, havens choice, weight of first ember).
- The delayed gut-punch fires on outlands entry / first claim etc., explicitly naming *your* early choice: "When the echoes first came to the havens, you chose [shelter/demand/seal].... You have been binding them from the first circle."
- Use Pause/1x/5x/20x (or Esc), idle, save/load, and the Reset button to try different branches. Alignment (Weight) changes rates, text mutations, raid chances, and expedition results.

The recent "Failed to load script "res://scripts/GameState.gd" with error "Parse error"" (and same for Main.gd) has been resolved:
- All inference-prone `:=` replaced with explicit `: Type =`.
- Typed arrays now declare with `= []` and are always restored via `.clear() + append()` loops.
- Theme resource ordering fixed + richer austere styles added.
- .godot cache + asset imports refreshed using your Godot binary.

Headless verification (`--headless --quit` + `--import`) with `/Users/spencereese/Downloads/Godot.app/Contents/MacOS/Godot` now shows clean loads (the 3 data JSONs) and no parse/resource errors for scripts or theme.

If you ever hit parse / "missing dependency" / load errors after future edits: quit Godot completely, `rm -rf .godot`, reopen the folder (or re-run the launch script). The editor will re-analyze with a fresh cache.

**For your friend playing:**
- Run `./launch_godot.sh` (or the manual steps).
- It starts in darkness with only one button on the right: "Nurture the Ember".
- Click buttons on the right sidebar (under "Actions"). The left side is the story log.
- Use "Reset (New Game)" at bottom anytime to try again or different choices.
- Watch the log for the story of waking up among embers with no memory.
- The central ember visual grows (scale and glow) as you nurture; the ash "world" expands visually (content area shrinks revealing more background) when strong, shrinks if neglected.
- Resources are whole numbers, rates per minute.
- Right sidebar (Actions) for buttons; use speed to advance—expeditions resolve with rewards, logs, and revelations (short times now).
- The game reveals more (resources, actions, meaning) as the ember grows. Choices matter for later revelations.

No need to look at code or output panel. Just play and note what feels unclear, exciting, or confusing. Ask them after 15-30 min: "Did the opening story hook you? When did 'shards' or 'ember' start making sense? Did any choice feel meaningful? Did visuals help the growth feel?"

Use Reset often to try kind vs harsh paths.

## Controls
- Mouse only for prototype.
- Speed buttons or `Esc` to pause.
- Everything else is clicking the action buttons as they appear.

## Key Design Goals
- Every new system or button should make previous actions feel different in hindsight.
- Alignment (oppressive ↔ benevolent) has real mechanical teeth and changes available content + flavor text.
- The "twist" is earned through play, not told.
- Slow, deliberate, juicy. Excellent for short sessions + long idles.

## Next Milestones (see DESIGN.md)
- Polish Phase 0–2 until the first major revelation lands hard. (Achieved + extended: echo incursion choice prompt at haven+pop5 with time pause + distinct UI; rich context mutations + early_choice memory persisted; delayed reframes on outlands entry + path resolve/claim that name *your specific haven choice* as origin of all binding/claiming. Different choices branch reframe text + mutations. Phase 3 outlands adds the expansion reframe layer making prior actions feel like first dominion steps. See plan.md for full test results.)
- Placeholder art & sound direction: 6 generated minimalist images now live in assets/art/ (ember_pulse visual that breathes with the sim's ember_pulse value + subtle ash texture bg + icons for haven/paths/bound/weight). Integrated dynamically in Main (see _setup_placeholder_art + _update_ember_visual). assets/sound/SOUND_DIRECTION.md with detailed cues, style, Godot bus/mix notes, and how audio can reinforce the gut-punch (e.g. choice resolution stings that foreshadow the later reframe). Matches "use image_gen for art, sparse lo-fi for sound" in DESIGN.
- Data-driven buildings and events.
- Simple map / first expeditions (Phase 3 MVP "Paths in the Ash" + reframe revelations + raid tease + Phase 3/4 expansion to 4 locations in data/paths.json with generic support). **COMPLETED per approved plan.md + subagent verification (Narrative/tests/docs) + this drive.**
- More buildings, jobs, and choice events that branch the experience.

## Tools & AI Workflow
This project is being built with heavy assistance from Grok Build.
- The `godot-dev` skill is installed globally and should be active when the CWD is this project.
- `AGENTS.md` contains project-specific rules.
- Use plan mode before new phases.
- Subagents are encouraged for parallel feature work.

See [DESIGN.md](./DESIGN.md) for the full vision and phase breakdown. Full record of Phase 3 implementation (including subagent briefs for GS/UI/Narrative-tests-docs, mental play criteria, differentiation audit, docs updates) is in the approved plan: /Users/spencereese/.grok/sessions/%2FUsers%2Fspencereese/019e8999-9119-7e50-a0ac-7997b1d4204e/plan.md (update plan.md with test/audit results on future work). Project skill state at ~/.grok/skills/a-dark-dominion/SKILL.md .

## License / Notes
Personal project. Open to inspiration from A Dark Room (Doublespeak Games) and classic RTS base-building, but the specific moral/systemic storytelling and slow empire scope are original.

Play responsibly. Every click is a choice.
