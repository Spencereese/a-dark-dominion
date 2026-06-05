# A Dark Dominion - Game Design Document (Initial)

**Working Title:** A Dark Dominion (preferred name)

**Inspiration vs Originality Note:** Clearly inspired by the slow, systems-as-story, moral-revelation progression of A Dark Room (the gradual scope expansion, the way "helping" turns oppressive through mechanics, the start-alone-in-darkness to empire arc). However, the world, opening metaphor (ember in ash instead of room + fire), all player-facing text, building names (Havens, Resonance Spires, Will-Binders), resource language (shards, resonance, vitalis), the exact nature of the oppressive realization, and the C&C-style base-building integration are original. At most **one** exact quote from any source is allowed in the final game. The goal is "feels like the same *kind* of experience" without being a copy that invites "stealing" comments. The name "A Dark Dominion" is the preferred title.

**Genre / Vibe:** Slow-burn incremental / idle strategy with deep narrative integration. Starts as pure minimalist text-based survival (inspired by *A Dark Room*). Expands organically into village management, exploration, base-building (C&C style), light tower defense / outpost defense, and eventually grand strategy / world conquest (RTS-lite elements). 

**Core Fantasy:** You begin alone in total darkness with nothing but the cold and a spark. Through patient effort you build light, shelter, community... and an empire. The horror and brilliance is realizing — too late or just in time — the true cost of "progress." Your choices shape whether you become a benevolent unifier, a ruthless tyrant, a tragic figure, or something that loops the cycle of conquest.

**Key Inspirations (used as structural DNA only):**
- Slow-build incremental games with mechanical storytelling and scope creep (e.g. the way A Dark Room reveals the world and complicity through new systems and text drift rather than exposition). We take the *feeling* of gradual horrifying realization through "progress" buttons, but all surface details, metaphors, and the specific oppressive twist are original.
- *Command & Conquer* (and classic RTS): Meaningful base building (power, production, defense placement), tech progression via structures, economy driving military, build orders matter, forward bases/outposts. One or few resources for focus. Deliberate pacing for our "slow build".
- RTS / Tower Defense hybrids: Deliberate (slow) economy + periodic threats (raids/waves) that reward prepared defenses. Map control and chokepoints.
- Broader: Deep village/civ sims, choice-heavy incrementals with systemic narrative.

**Strict Rule:** No direct lifts of "the room is freezing", fire stoking language, "hut", "wood", "slaves" as player text. The realization must feel freshly earned for this world: you are not the hero preserving the last light — you are the one recreating the exact hierarchy and extraction that turned everything to ash, and the "grateful" lost are becoming the Bound.

**Design Pillars:**
1. **Revelation Through Systems**: No cutscenes or walls of text. New mechanics, UI elements, and text mutations *are* the plot. Player slowly pieces together the truth (and their complicity).
2. **Meaningful, Branching Choices**: Early choices feel small (stoke fire vs gather). Mid choices have visible tradeoffs (build more huts for pop boom but moral cost). Late choices reshape available content (benevolent tech tree vs tyrant conscription tree; alliances vs fear mechanics).
3. **Slow, Deliberate, Juicy Progression**: Everything starts manual and painful. Automation feels earned. "One more tick" addiction via visible rates, projected gains, and constant small unlocks. Support fast-forward for idle play.
4. **Scope Creep as Feature**: Game literally gets bigger on screen and in systems. Starts one panel in blackness. Ends with multiple tabs, map, production queues, global stats, legacy view.
5. **Moral Gravity Without Preachiness**: Alignment (benevolent <-> tyrant) is a hidden or semi-visible slider with mechanical teeth (production bonuses/penalties, event tables, ending variants). Overwork button tempts with power. "Good" path is often harder/slower but more stable or redemptive. Bad path is seductive for numbers but leads to internal rot (rebellions, builder leaving, pyrrhic wins).
6. **Surprise & Expansion**: Every few hours of play a new layer "unlocks" in a way that reframes everything prior (e.g., after building the first "mine", you realize where the ore/labor comes from; first "army" recruitment reveals conscripts; compass opens the "wasteland" that is actually previous conquest ruins).

**High-Level Progression Phases (Expandable)**

**Phase 0: The Ash (5-15 min first play)**
- Black / near-black screen, vast emptiness.
- "There is only ash and silence."
- Only action: "Nurture the Ember" (the last pulse of warmth/light/life).
- The ember has pulse that decays. "Feed the Ember" (manual, small shards cost or free at first).
- Gather "shards" by hand (cooldown button, very slow). They are still warm.
- Log narrates your actions and environment in cold, patient language.
- First "lost" event: A figure emerges from the ash, drawn to the pulse. Subtle.
- Goal: Stabilize the ember. Feel the loneliness and the weight of being the only light.

**Phase 1: The Ember's Circle (~30-90 min)**
- Unlock "mark foraging lines" or early outposts after enough shards.
- Foraging returns resonance/vitalis + occasional "warm scraps" or "old voices" (first hints that the ash has history and the "fuel" has owners).
- More resources appear.
- First structures: Basic Sanctum around the Ember.
- Population: "A lost one stumbles into the pulse. They stay." Then more.
- Assignment: Turn the lost into foragers / resonators. Manual at first.
- Moral seed: "Demand More" button (temp boost, alignment hit, risk of "emptiness" state in them).
- UI: Resources panel + Actions column + Event log. Subtle text evolution ("the lost are grateful for the warmth" → "their hands move even when they sleep").

**Phase 2: The Havens (hours)**
- Havens (core "lost" growth). Each Haven increases capacity and passive production but shifts alignment negative if overbuilt or with certain policies.
- More buildings: Resonance Chamber (jobs), Waystation (new resources via "echoes"), Will-Binder (tools that boost rates / control).
- "The lost" terminology appears and mutates ("the willing", "the Bound", "the Choir" depending on alignment).
- First major choice point: How to handle an "ash-storm" or "echo incursion" — spend to shelter everyone, or seal the havens and let the outer ones be claimed (boost to you, loss of trust or "voices").
- Exploration teaser: "The ash thins in one direction. There are shapes that were once places." (Pathfinding cost).

**Phase 3: The Outlands / First Expansions (RTS/TD lite introduction) — IMPLEMENTED (MVP paths/expeditions per approved plan) + continued drive (defense strength + raid visuals + scattered embers + audio) + Phase 3/4 expansion (4th path location for more expedition choice + reframe opportunities)**
- "Paths in the Ash" / "Veins in the Ash" map unlocks as simple dynamic list (4 static locations in data/paths.json, expandable data-only; no grid/2D/TD yet). Panel "unfurls" in MainArea UI on phase advance. One new location added following SKILL Implementation Order + "When adding..." (data/paths.json entry with cost/travel/moral_options + strong revelation reframing "lines you marked"/"choice in the havens"/"first ember"; discovery auto via path_data on outlands + load ensure; GS generic dispatch + dynamic seed so no per-id wire; UI already generic).
- Send expeditions/dispatch the lost (spend shards + "the lost"/pop or free foragers; moral choice buttons per location: e.g. Listen vs Harvest, Respectful vs Strip, Parley vs Overwhelm).
- Resolution (timed via eta in advance_time + resolve on ticks/load): auto or choice-driven with modifiers (alignment "Weight", foraging_lines count, forager pop); gains shards/resonance/vitalis + pop return/loss.
- Discoveries/reframes: Ruined "veins"/"crossings"/"hollows" (scavenge with moral: respectful salvage vs strip); hostile "echoes"/"bound" (parley/intimidate). First "Watch Spire" (C&C outpost tease: defense/scouting rates) unlocks on first claim.
- Raids/defense tease: Periodic "ash answers back" / path raids (scaled by foragers/foraging_lines/align; mitigated by "Defend the Paths" action or recent defense flag + buildings). "Watch Spire" contributes.
- Alignment matters hugely here: Tyrant path gets faster volume + risk (resistance, emptiness, pop loss); benevolent slower/loyal returns + allies (positive reframe potential). All outcomes include revelation logs that reframe prior "foraging" / Havens / "the lost" as the first claims/binding ("the paths you marked for foraging led straight here..."; "Foraging was never just gathering—it was the first claim"; "Demanding more within the circle was practice. Here it becomes dominion.").
- UI: Compact "Paths in the Ash" panel (dynamic entries: name/desc/status with live eta via time ticks; moral choice buttons using _add_action_button patterns; "Defend the Paths" in actions sidebar). Refreshes on phase_advanced, time_advanced (etas), dispatch success, relevant resource/pop signals. Grows visible surface area ("unfurl").
- Integration: Extends existing (GameState: outlands phase gate in _check_phase_advancement after village/foraging + pop/shards threshold, dispatch_expedition + _resolve_expeditions in advance_time, new state discovered/active/claims + save, _trigger_path_raid tease, watch_spire in data/buildings; Main: _ensure/_refresh_outlands + handlers mirroring resources/actions rebuilds exactly; signals reused; data/paths.json modeled on buildings.json).
- Differentiation + reframe: All text original ash/ember/the lost/Havens/paths/veins/Weight language. Revelations explicitly call back to early game complicity. No direct "Dusty Path"/"March"/room/fire/hut lifts.
- Scope: MVP simple list + dispatch + resolve + raid tease + first outpost unlock. Prepares for Phase 4 multi-outposts/queues/larger map/full TD. One surprising reframe per addition. (See approved implementation plan for exact line refs, code sketches, data examples, subagent briefs, and testing criteria.)
- Continued drive (post cooldown visualizer): defense now uses decaying defense_strength (built by Defend action + watch_spire, shown in resources when active, mitigates + reduces raid pop/shard losses with partials); raid triggers ash/ember visual flashes (tween) + signal + claim-tied reframes; "Paths watched" live label; scattered small ember sprites (up to 6) appear/scale/position around central as pulse + pop/havens rise (visual "light grows we see more", reinforces plural embers story); audio skeleton (buses, generators, cues on key actions/events, alignment mix, ash fill).

**Phase 4: The Realm / Regional Power**
- Multiple outposts/bases you manage (supply lines simulated: resources must "travel" or risk loss).
- Full production queues (C&C style): Choose what "militia", "builders", "enforcers" to train. They take time and pop/food.
- Tech tree via key buildings (Smithy → better weapons; Granary → pop growth stability; "Hall of Records" or "Propaganda Spire" for alignment flavor).
- Larger map with hexes or nodes. "Conquer" or "Integrate" small settlements. Each has a short event chain with choice.
- Defense: Wave/raid defense on a chosen front (lite TD: lanes or abstract "front strength" vs enemy strength, towers contribute fixed power).
- Internal politics: Happiness/unrest meter. Low unrest on tyrant path requires constant "examples" (costly). Benevolent path has natural growth but external threats exploit "weakness".

**Phase 5: The World & Dominion**
- Global layer: "The Known Lands" map or strategic view. Other "powers" or last free peoples.
- You have a "capital" (the evolved original room/hearth/village now a city) + forward bases.
- Endgame push: Series of campaigns or a final "unification war". Choices compound (previous decisions unlock special units, events, or penalties).
- Multiple endings (at least 4-6 variants):
  - Tyrant Eternal: World under your boot. Bitter, with cracks showing (rebellions forever, builder's ghost, you alone again?).
  - Benevolent (or Redemptive) Order: Harder path. A fragile alliance or enlightened rule. Costly in lives/resources. Perhaps you step down or the builder returns.
  - Collapse / Cycle: Overreach leads to fall. You "wake" in a new dark room (loop hint, like ADR).
  - No-Huts / Minimalist Challenge: Harder numbers, different story (builder doesn't leave in disgust; different final transmission or sacrifice).
  - Pyrrhic / Tragic: You win the world but lose everything human (including yourself).
  - Hidden / True: Depending on cumulative alignment + specific flags (e.g., never used overwork, respected ruins, etc.).
- Post-credits or legacy: Stats screen + "What will the next wanderer find?" New Game+ with persistent meta (previous alignment affects starting flavor or difficulty).

**Core Systems (All Must Support Moral Branching & Save)**
- **Resources**: Shards (early fuel/ash-matter), Resonance (mid, "echoes"/will), Vitalis (life-force), later "Dominion" or "Harmony" abstract currency.
- **Population & Labor**: Total "the lost", free vs bound/assigned. Jobs produce rates. Over-assignment or "Demand More" policies cause "emptiness", "silence", or "loyalty".
- **Buildings**: Data-driven. Cost (resources + time or pop commitment). Effects (rates, capacity, unlocks, defense value). Moral weight on construction and operation. Names: Haven, Resonance Spire, Will-Binder, Watch Spire, etc.
- **Alignment / Legacy**: Float -1 (the Will / Dominion) to +1 (the Harmony). Changed by actions, policies, event choices. Affects multipliers, available actions/buildings, text everywhere, ending.
- **Events & Narrative**: Priority queue or trigger-based. Some one-time revelations. Some recurring with variation by alignment. The realization builds: "we are saving them" → "they are part of the Hearth now" → "there is no 'they' left".
- **Map & Expeditions**: Locations have state (unexplored ash, claimed, integrated, broken). Resolution uses bound/units + alignment/tech modifiers.
- **Defense / TD Elements**: Global "ash-storm" or "echo incursion" threat. Spires/outposts contribute. Failure = loss of the lost, shards, alignment shift (or tyrant "strength").
- **Tech / Progression Gates**: Mostly building-driven (C&C style). Some long research actions (idle friendly). Later full production queues for "Hands", "Resonators", "Watchers".

**UI / Presentation Philosophy (Critical for the feel)**
- Start: Almost nothing on screen. High contrast text. Very slow reveal.
- Every expansion adds a new persistent UI element (new column, tab, panel that slides in, or world map that "unfurls").
- Text is poetic, cold, matter-of-fact, then increasingly bureaucratic or cruel depending on path.
- Subtle animations: Fire flickers (Tween + modulate), numbers pop on gain, buttons "unlock" with a glow or particle.
- Accessibility: Full keyboard nav, large click targets, readable fonts, colorblind-friendly (text + symbols), speed controls essential for the "slow" genre.
- Dark, desaturated palette with rare warm accents (the fire, benevolent gold, tyrant blood red).
- Sound: Sparse at first (wind, crackle). Later subtle drones, distant hammers, marching. Use Godot Audio + perhaps procedural or few samples. Lo-fi aesthetic.

**Technical & Scope Notes for Solo + Grok Build**
- **Start ultra-scoped**: Phase 0 + Phase 1 fully polished (resources, actions, basic huts, first moral temptation, log, save) before any map.
- Godot 4 + GDScript. Heavy use of Control UI for first 3 phases. Introduce 2D/Node2D only when map makes sense.
- Data-driven from day 1 (JSON or Resources): actions fully in data/actions.json (conditions, costs, effects, logs, unlocks), buildings enhanced in data/buildings.json. GameState has generic check/apply. NarrativeSystem stub for revelations/flavor. Content expandable by editing JSON.
- Save everything important. Offline progress is a feature.
- Use subagents heavily once skeleton exists: "Implement the full village assignment system and 5 buildings in one worktree."
- Art: AI-generated minimalist pixel / low-fi / ink style via image_gen. Or pure text + shapes first. Sound similar (or free assets + code gen).
- Steam-friendly: Short-to-medium sessions (check in, let idle, make choices), high replay via paths, achievements for "Pacifist Hearth", "No Slaves", "World Uniter", "Iron Dominion", specific revelations. Controller support later. Deck verified (UI scales).
- Risks to mitigate: Scope creep (ruthlessly cut to "one new surprising thing per phase"). Balance (data files + playtest loops with AI). Narrative subtlety (test "does this feel earned or on the nose?").

**MVP Definition (First Ship-able Slice for Playtest / Wishlist)**
- Complete, juicy Phase 0-2 (ash → stable ember → small circle of havens with 4-6 structures, assignment of the lost, first 2-3 choice events, alignment affecting text and one major branch point that makes prior "saving" feel wrong).
- Solid core loop: Gather/feed/raise → watch rates → react to events → feel the slow dread or hope.
- Save/load + offline.
- Basic "paths in the ash" / "veins in the ash" tease that opens a very simple dynamic list map (3-4 locations from data/paths.json) with expeditions (moral choices, timed resolve via eta in advance_time, reframe revelations, raid tease, Watch Spire unlock on first claim; no full TD/grid yet). Panel unfurls in UI. (Fully implemented per approved plan; see Phase 3 for details.)
- Polished log, beautiful dark UI, speed controls.
- One full "circle" to a small ending or "the first voice answers back" scene.
- Then expand outward with C&C base building and defense.
- Title throughout: "A Dark Dominion".

**Future Expansions (Post-Launch or Stretch)**
- Full procedural map generation.
- Deeper TD (actual lane-based wave defense mini-game with placeable towers).
- Multi-base management with logistics (C&C supply lines).
- More tech trees with visual "research" mini.
- Multiplayer? Async "empires" or shared world (very late).
- New Game+ legacies, challenge modes (no overwork, speedrun to dominion, etc.).
- Mod support via data files or GDScript plugins.

This is a living document. Update as we prototype and discover what sings. The magic is in the *gradual* realization and the weight of every button press.

**Master Story & Branch Reference**: See [STORY.md](STORY.md) for the authoritative compilation of all implemented and planned narrative branches, exact choice text (early haven incursion + all path moral options + delayed reframes), mutation examples, full thematic meaning, progression gates, and ending conditions. Always cross-reference when authoring new systems or content so every expansion reframes prior play.

Next milestone: Deepen Phase 4 (multi-outposts/queues/larger map/full TD-lite defense) only after Phase 3 MVP feels magical with reframe (per plan + SKILL). Phase 3 complete: see approved plan.md for record of impl, subagents (incl. Narrative/tests/docs), mental tests, diff audit, docs updates. Polish early choice + delayed reframes on outlands/claim fully integrated. (See /Users/spencereese/.grok/sessions/%2FUsers%2Fspencereese/019e8999-9119-7e50-a0ac-7997b1d4204e/plan.md + updated SKILL.md / README / AGENTS notes.)
