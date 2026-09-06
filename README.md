# A Dark Dominion

**A slow-burn incremental strategy game about the last light in the ash, the will to grow it, and the terrible price of binding others to your cause.**

You begin with a single ember in a world reduced to ash.

Through care, foraging, and the hands of the lost who are drawn to the warmth, you raise havens, mark paths, and expand the circle of light.

Will the Hearth become a new harmony... or the seed of a dominion that finishes what the old fires started?

Clearly inspired by the slow, mechanical-revelation style and moral realization of certain classic incremental games (such as A Dark Room), but with original metaphors (the Ember, the Ash, the Lost, the Bound, Havens, Resonance), all-new text, and a distinct realization that you are repeating the pattern that scorched the world. The name "A Dark Dominion" is used.

## Current Status
Prototype foundation (Phase 3 MVP + early Phase 4): ashen dark → ember → early havens with polished early choice + delayed reframes → "Paths in the Ash" outlands map/expeditions + defense layer with mechanical teeth/visuals; audio skeleton + paths layer expansion (4th location). (See historical details in DESIGN.md for the list-based MVP.)

**Accelerated direction (per user request "less of a text game, and more of an rts/tower defense", "moral choices you make unknowingly set your faction", "maintain the mystery while making the story make more sense to the layman" — approved in current plan session)**: 
- Dedicated 2D schematic visual map for the outlands (veins/lanes with moving expedition and raid entities, visual defense/tower contributions, alignment and moral-weight visual "binding" consequences on claimed areas).
- Production queues (C&C flavor — several data-driven buildings like Labor Hall for Hands, Spire Works, with tyrant aggressive vs benevolent protective variants).
- Data-filtered faction branching (alignment "Weight" + early_choice + flags filter which defenses, towers, and production options are available — player sees different tools emerge from their moral choices without any explicit "faction" label).
- Memory system (tied to existing early_choice) that surfaces curated context from STORY in a new "Memory"/"Reflections" panel, making the world logic and your complicity clearer to a layman while the main log stays poetic and the big gut-punch reframe still lands exactly as designed.
- All built on the existing generic/data-driven foundation (dispatch/resolve/raid/defense/early_choice/unfurl patterns). Every addition is data-first, includes reframe + Memory entry, and advances the gradual realization that prior "helpful" actions were the first steps of dominion. Map visuals make consequences spatial and visible.

**Differentiation note**: Opening text, action names, building names, resource labels, and flavor have been rewritten to stand on their own (original ash/ember world). The name is "A Dark Dominion" as preferred. At most one exact quote from any source is permitted across the game. Actions and buildings are now 100% data-driven (data/actions.json + buildings.json); small NarrativeSystem centralizes revelations and the new Memory layer. See updated .grok/skills/a-dark-dominion/SKILL.md and the approved plan.md in the current session for the redesign details.

**Master Story File**: [STORY.md](STORY.md) — complete narrative bible with all branches, exact early choice options + immediate/delayed reframes (verbatim), every path revelation, alignment mutations, progression gates, full thematic meaning of choices ("you have been binding them from the first circle"), tracked state (early_choice/choice_history/flags/claims), and planned endings. Reference this when adding any new content (including new map visuals, production, faction options, or Memory entries).

Recent drive forward (foundation + acceleration start): defense_strength + raid mitigation with partial losses + "Paths watched" display + ash/ember flash visuals; 6 scattered ember sprites; audio buses + Generator cues; initial work on visual map, production, faction filters, and Memory per approved plan.

Next (per approved plan): Complete the visual schematic 2D map (moving elements on lanes), several production buildings with queues, data-filtered faction branching, Memory panel, full integration + audio hooks, polish, mental playtests on different moral paths, and final doc sync. (Defense system has real teeth + visual payoff; the new map makes your moral choices spatially consequential while Memory makes the story logic clearer to a layman without removing the mystery or the twist.)

Core loop + first scope expansion (Phase 3 MVP per approved plan.md + Phase 3/4 paths expansion): dynamic "Paths in the Ash" panel unfurls in MainArea; 4 locations (data/paths.json, new "Vein of Broken Circles" added for expedition choice + reframe) with moral choice expeditions (Listen and Offer Passage vs Cut the Vein; etc. + Listen/Mend vs Claim); timed resolution via eta in advance_time + _resolve (offline catch-up, modifiers from alignment Weight/foraging_lines/foragers); ≥1 reframe revelation per outcome that explicitly calls back to prior "foraging"/Havens/"Demand More"/early choice/"first ember" as the first claims/binding (e.g. new: "The broken circles waited for the lines you marked. The choice in the havens only named what the weight of the first ember had already bound before."; "You bound them here as the first were bound... retraced what was claimed long before any foot stepped..."; old + delayed: "When the echoes first came to the havens, you chose [your shelter/demand/seal]... Every vein you mark... You have been binding them from the first circle."); raid/defense tease ("The ash moves along the old veins"); first claim unlocks Watch Spire (C&C outpost tease). Full integration (data-driven paths modeled on buildings, GameState dispatch/resolve/phase/raid/save now generic for paths, Main dynamic panel + live eta + sidebar "Defend", signals, Narrative flavored logs + mutations + early_choice context for gut-punch). Speed/offline/save/Reset. Alignment "Weight" affects rates, choices, text, raids. Strict differentiation throughout.

**Differentiation note**: Opening text, action names, building names, resource labels, and flavor have been rewritten to stand on their own (original ash/ember world). The name is "A Dark Dominion" as preferred. At most one exact quote from any source is permitted across the game. Actions and buildings are now 100% data-driven (data/actions.json + buildings.json); small NarrativeSystem stub centralizes revelations. Phase 3 map layer per approved implementation plan (full record of code, tests, subagents, audit at /Users/spencereese/.grok/sessions/%2FUsers%2Fspencereese/019e8999-9119-7e50-a0ac-7997b1d4204e/plan.md ; see also updated .grok/skills/a-dark-dominion/SKILL.md).

**Master Story File**: [STORY.md](STORY.md) — complete narrative bible with all branches, exact early choice options + immediate/delayed reframes (verbatim), every path revelation, alignment mutations, progression gates, full thematic meaning of choices ("you have been binding them from the first circle"), tracked state (early_choice/choice_history/flags/claims), and planned endings. Reference this when adding any new content.

Recent drive forward: defense_strength + raid mitigation with partial losses + "Paths watched" display + ash/ember flash visuals on raids (defend now has clear payoff); 6 scattered ember sprites populate around central as pulse/pop/havens grow (pure visual "as light grows we see more" + plural embers/amnesia reinforcement); audio buses (Ash/Ember/Dread/UI) + AudioStreamGenerator cues for nurture swell, gather scrape, raid dread, choice tension/resolve stings + alignment-reactive mix + sparse ash hiss fill.

Next: Full audio integration + refinement (more cues, reliable ambient, expedition/claim stings), deepen raids into reactive events or choice responses, C&C queues for spires/buildings, more locations + branching content (Phase 4). (Defense system now has real teeth + visual payoff; scattered ember visuals expand the "light grows, we see more" world purely visually.)

## How to Run (Godot 4.6+)

**Critical after edits (the recent parse/type fixes included):** always clean the cache.

### Windows (PowerShell - this machine / any Windows dev)
Use the dedicated PowerShell helpers (created per approved plan for Windows launch + headless verification):

```powershell
cd C:\Users\PC\Projects\a-dark-dominion
# Normal play (cleans .godot, fresh save for "first ember", detects/launches Godot):
.\launch_godot.ps1

# Keep your save/progress (no wipe):
.\launch_godot.ps1 -NoCleanSave

# Or set env for your Godot install (recommended; put in $PROFILE for permanence):
$env:GODOT_PATH = "C:\Path\To\Godot.exe"
.\launch_godot.ps1
```

- **Godot detection**: Checks `$env:GODOT_PATH` first, then common spots (Program Files\Godot, %LOCALAPPDATA%\Programs\Godot, ~/Downloads variants, C:\Godot). If missing, prompts for full path to Godot.exe.
- Download: https://godotengine.org/download/windows (4.6+ recommended, matching `project.godot` "4.6").
- Graceful: clear error + link if Godot not found.

**Headless verification (after edits, to catch parse / missing dep / load errors like the recent .gd fixes):**

```powershell
# Dedicated verify script (recommended for CI / post-edit checks):
.\headless_verify.ps1

# With full Godot output:
.\headless_verify.ps1 -VerboseOutput

# Extra checks (basic run-test note + optional export):
.\headless_verify.ps1 -RunTest -ExportCheck

# Convenience via launcher (also cleans + verifies):
.\launch_godot.ps1 -Headless
```

See `headless_verify.ps1` (and `launch_godot.ps1`) for all params, error capture, and manual fallback steps.

**Configurable save wipe**: The userdata dir is `%APPDATA%\Godot\app_userdata\A Dark Dominion\` (from `project.godot` name). Override with `-SaveName "My Test"` or `$env:GODOT_SAVEDATA_NAME=MyTest` .

### Mac / Linux
```bash
cd projects/a-dark-dominion
./launch_godot.sh
```

(The .sh is the original Mac/zsh version; it does `rm -rf .godot` + launches using `~/Downloads/Godot.app`. On Windows use the .ps1 scripts instead. See comment at top of launch_godot.sh.)

Manual (any OS, including if scripts can't find your Godot):
1. Fully quit Godot.
2. Delete the `.godot` folder in the project root (or `rm -rf .godot` / `Remove-Item -Recurse -Force .godot`).
3. Launch:
   - Windows: `"C:\Path\To\Godot.exe" --path C:\Users\PC\Projects\a-dark-dominion`
   - Mac: `"/Users/you/Downloads/Godot.app/Contents/MacOS/Godot" --path projects/a-dark-dominion`
   - Or double-click Godot and "Import" / open the project folder.
4. In editor: open `scenes/Main.tscn` and Play (F5 or play button).
5. For headless verify only: `Godot.exe --headless --path . --quit --import` (check output for errors).

In game: right sidebar for Actions (Nurture, Gather, Raise Haven, Demand More, queues for production once unlocked, Defend). Use speed buttons or Esc. Reach outlands to see the new 2D schematic map with moving expeditions/raids, defense towers (different looks by faction), and the Memory panel for story context tied to your choices. Use Reset often for kind vs harsh moral paths (affects visuals, available production, Memory).

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

Headless verification (`--headless --quit --import`) via `.\headless_verify.ps1` (or `launch_godot.ps1 -Headless`, or Mac equivalent) now shows clean loads (the 3 data JSONs + map/resources) and no parse/resource errors for scripts or theme. (Run it after edits; it forces a fresh .godot reimport and reports ERROR/Parse lines.)

If you ever hit parse / "missing dependency" / load errors after future edits: quit Godot completely, `rm -rf .godot` (or run a launch/verify script), reopen the folder. The editor (or headless) will re-analyze with a fresh cache. The verify scripts make this easy + scriptable on Windows.

**For your friend playing (Windows or Mac):**
- Run the launcher for your OS: Windows `.\launch_godot.ps1`  (or Mac `./launch_godot.sh`, or manual steps above).
- It starts in darkness with only one button on the right: "Nurture the Ember".
- Click buttons on the right sidebar (under "Actions"). The left side is the story log.
- Use "Reset (New Game)" at bottom anytime to try again or different choices.
- Watch the log for the story of waking up among embers with no memory.
- The central ember visual grows (scale and glow) as you nurture; the ash "world" expands visually (content area shrinks revealing more background) when strong, shrinks if neglected. (New: schematic 2D map shows expeditions, raids, towers colored by your moral alignment/claims.)
- Resources are whole numbers, rates per minute.
- Right sidebar (Actions) for buttons + production queues (once unlocked); sidebar Defend; use speed to advance—expeditions/paths resolve with rewards, logs, and revelations (short times now). Memory panel (tied to your early choice) + map visuals make consequences legible.
- The game reveals more (resources, actions, meaning, map) as the ember grows. Choices matter for later revelations + visual "binding" state on the outlands map.
- After edits by devs: the launcher/verify scripts ensure no stale cache issues.

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
