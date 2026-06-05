# A Dark Dominion — Master Story Bible

**Purpose**: This is the single source of truth for the game's narrative arc, all choice branches, mechanical + thematic meaning, progression beats, text mutations, reframes, and ending conditions. Use it when authoring new actions, paths, events, buildings, or endings so every addition advances the central realization.

The game is **systems-as-story**. The "oh no, I did this" gut-punch is not delivered by exposition but by:
- Mechanical expansion (more population, more "help", more claims) that later gets explicitly reframed as binding/domination.
- Delayed revelations that name the player's *specific early choice* as the origin of everything.
- Text mutations that quietly change language ("the lost" → "the Bound", "Mark the Lines" → "Mark Claiming Veins", "Haven" → "Binding") based on alignment and flags.
- Visual and audio reinforcement (scattered embers waking with the central pulse; dread tones on raids/tyrant choices).

**Core Theme / Full Meaning**  
You are the last keeper of light in a world reduced to ash. By tending the ember, gathering the lost, raising havens, and marking paths, you believe you are preserving life and community.  

In truth, you are recreating the exact hierarchy and extraction that turned the world to ash. The "pulse" is not pure salvation — it is a new center of Will / Dominion / Hearth. The lost who gather are not saved; they are bound. "Foraging" was always claiming. "Shelter" and "help" were practice for dominion. Every expansion of the circle is a tightening of control.  

The player can pursue "good" (slower, more fragile, higher cost) or "tyrant" (seductive numbers, internal rot, rebellions). Both paths lead to dominion over others; the difference is flavor of the Weight and the final legacy. The amnesia at the start hints that this may be a cycle — you (or someone like you) have done this before.

The game never lectures. It lets the systems and the delayed reframes do the work: after you have already sent people down paths and built the apparatus, the game calmly states "You have been binding them from the first circle."

---

## Opening Hook & Amnesia (Phase 0: The Ash)

**Exact awakening text (fresh game / reset)**:  
"You wake with a jolt. Your head throbs. Smoke stings your lungs. The ground is littered with embers — small glowing sparks scattered in the ash and debris. One brighter ember pulses near your hand, the strongest. You have no memory of how you got here."

**Initial logs**:  
"There is only ash and silence, broken by the pulse of embers."  
"A central ember pulses weakly before you. Others flicker at the edges of the darkness."

**Nurture the Ember (first action)**:  
"You cup the ember in your hands. It answers with a flare. Scattered embers around you brighten. Shards of forgotten light pulse in the ash."

**Thematic purpose**: Player is alone, injured (head wound + smoke = possible survivor or cycle participant), in total darkness. The central ember is the one you tend; the scattered ones respond/stir when you succeed. This sets up the visual system (central grows + camera "backs out" via margins; small scattered ember sprites populate as pulse + pop/havens rise). No memory = no inherited guilt or knowledge yet; the player must *discover* through play that they are repeating a pattern.

**Shard hint** (after ~12 shards):  
"Among the shards you sometimes find scraps of old cloth. Still warm. Not yours. Who were you before the ash?"

This is the only direct nod to personal lost identity early on.

---

## Progression & Phase Gates (Narrative + Mechanical Unfurl)

Phases are strict gates that add UI surface area and reframe prior play.

1. **Dark** (minutes)  
   - Only Nurture. Ember decays. Goal: stabilize the pulse.  
   - Feels: total isolation + fragility.  
   - Advance: first Nurture action sets phase "hearth", unlocks basic_sanctum.

2. **Hearth**  
   - Feed the Ember (costs shards, pulse <10 cap), Gather Shards (cooldown, base 5 + per pop), early buildings.  
   - First lost arrive (pop growth via haven later).  
   - Narrative: "The pulse has become a circle..." begins when village hits.  
   - Visual: ember grows, scattered embers start to appear, margins expand ("as light grows we see more").

3. **Village** (the "helping" phase that will be reframed)  
   - Gate: population >=4 AND haven >=1.  
   - Unlocks "Mark the Lines" (foraging_lines building, cost 25 shards).  
   - "Raise a Haven" (40 shards, +2 pop + rates, taper after several, moral_weight).  
   - Demand More (pop 3+, shards per pop boost, align-, sets demand_more_policy flag, hardens language).  
   - Assign/unassign foragers ("Send Forager" / "Call Back").  
   - **The Early Choice trigger** (see dedicated section): at haven >=1 + population >=5 an "echo incursion" pending flag is set. UI shows gold "A Choice in the Havens" panel. Time pauses for weight.  
   - Narrative beat: "The pulse has become a circle of havens. More embers stir in the ash... or is it listening?"  
   - "The ash around the ember offers paths... and things that walk them." (foraging unlock)

4. **Outlands / Paths in the Ash** (the big reframe expansion)  
   - Gate: foraging_lines >0 AND population >=6 AND shards >=50 AND not yet reached.  
   - "The lines reach farther into the embers... The lost will walk them now."  
   - Discovers **all** paths from data/paths.json (currently 4). Panel unfurls in MainArea.  
   - Immediately fires delayed reframe: "first_outlands".  
   - Expeditions (dispatch with moral choice or auto-bias by alignment), live ETAs, resolve with rewards + pop delta + alignment + per-option "log" + revelation that reframes prior actions.  
   - First path claim: "The [name] is bound. What was foraged is now held." + unlocks Watch Spire + fires "path_claim" delayed reframe.  
   - "Defend the Paths" (now with defense_strength, cooldown, visible "Paths watched" value, mitigates raids).  
   - Raids become possible (higher chance with foragers + lines + negative align). "The ash moves along the old veins. The paths remember who marked them."  
   - Passive income from claimed paths.  
   - **This is the primary gut-punch delivery window**: many delayed reframes name the early haven choice as the true first act of binding.

Later planned phases (Phase 4 Realm, Phase 5 Dominion) will add queues, multiple bases, larger map, global campaigns, and full endings.

---

## The Pivotal Early Choice ("A Choice in the Havens")

**Trigger condition** (in `_check_early_choice_events` + phase check):  
buildings.get("haven", 0) >= 1 and population >= 5 and not incursion_handled.

Time auto-pauses. Dedicated gold-header panel appears. Prompt is flavored by NarrativeSystem using current context (prior demand, foragers, etc.).

**Exact base prompt** (flavored further by early_choice if somehow already set, or prior actions):  
"An echo incursion approaches the havens. Broken figures from the ash, seeking the pulse. They are remnants, like the ones you foraged and sent before. What do you do with these new arrivals?"

**The three options** (from early_events + apply_choice + Main UI):

1. **Shelter them within the havens** (choice_id: "shelter")  
   - Mech: +2 pop, -20 shards, +0.08 align.  
   - Immediate reframed_log: "You open the havens. They enter, eyes wide at first. 'The pulse... it calls.' But their silence spreads to the others you gathered before."  
   - early_choice_memories["shelter"] = "You opened the havens. You told yourself it was mercy. The pulse called, and they answered."  
   - Flavor variants: prompt becomes "...these who came seeking the same warmth you first offered the others?"

2. **Seal the havens. Let the ash claim them.** ("seal")  
   - Mech: align -0.10 (or set in apply), no pop gain, no cost.  
   - Immediate: "You seal the havens. Their cries fade into the ash. You feel the pulse steady... and something in you tighten."  
   - Memory: "You sealed them out. Their cries faded, and the ember steadied. The circle learned to close."  
   - Prompt flavor: "...more remnants the circle has already learned to turn away?"

3. **Demand they work for the shelter of the pulse.** ("demand")  
   - Mech: +15 shards, align -0.15.  
   - Immediate: "They work at once. No thanks, just toil for the pulse. The numbers rise, but their eyes... already empty like the Bound before them."  
   - Memory: "They worked at once. No oath asked, only the pulse. Their eyes went quiet before they ever saw the ash."  
   - Prompt flavor: "Will you repeat the demand you made of the first ones who stayed?"

**Mechanical + narrative teeth**:
- Records `early_choice` and appends to `choice_history` (persisted in save).
- Sets incursion_handled + specific incursion_* flags.
- If player has already done demand/foragers/paths, immediately fires an extra "The circle has always been claiming them. You did this." line.
- Sets up **all future delayed reframes**.

**Delayed reframe** (the real punch, in `_check_delayed_choice_reframe`):  
Fires (once per trigger) on:
- "first_outlands" (phase advance to outlands)
- "path_claim" (first or any claim in _resolve_one_expedition)
- "demand_after" (first Demand More after the choice)
- "choice_made" (if outlands already open when choice resolved)

Base text (always):  
"When the echoes first came to the havens, you chose what you chose. [memory] Every vein you mark, every lost you send, follows the same shape. You have been doing this since the first circle closed around the ember."

Special swaps in get_flavored_text for "You did this" etc. depending on early_choice.

**Meaning of the choice**: It is not just "what kind of person are you?" It is the moment the player (often unknowingly) teaches the ash and the lost the rules of the new order. Later expeditions and raids will explicitly say the paths/foraging/havens were never new — they continued the pattern set at the first haven.

Note in UI: "This decision will be remembered by the ash."

---

## Alignment / "Weight" System

Float -1.0 (tyrant / the Will / Dominion) to +1.0 (benevolent / Harmony).

**Mechanical teeth** (`get_prod_mult`, unrest, raid chance, expedition mult/returns, pop risk on harsh options, defense value):
- <= -0.6: +35% production (tyrant efficiency), higher raid chance.
- <= -0.2: +15%.
- >= +0.6: -15% production (benevolent "fairer", slower raw numbers).
- >= +0.2: -5%.
- Unrest risk higher on extreme negative.
- Expedition: tyrant bias toward volume/risk (more shards sometimes, more loss); benevolent toward safe/loyal returns + allies.
- Raids: negative align increases chance and severity; positive or defense mitigates.

**Narrative teeth** (via NarrativeSystem mutation_rules + get_flavored_text special cases + context):
- align_lt -0.6: the lost → the Bound, grateful → resigned, hands → tools, forager → thrall, etc. "march under the Will".
- align_lt -0.3: lost → Bound, grateful → quiet, forager → bound hand.
- align_gt 0.3: lost → the gathered, forager → wanderer.
- demand_more_policy flag: hardens further (forager → thrall, work → toil).
- outlands_reached or align_lt -0.5: "Mark Foraging Lines" → "Mark Claiming Veins", foraging → claiming.
- incursion_handled: new arrivals → new Bound, echoes → remnants.
- Haven names mutate (Haven → Binding on harsh/demand; Sanctuary on positive).
- Pop line: "The Lost: X" → "The Bound: X" or "The Gathered: X", "free" → "claimed".
- Many action logs and revelations get choice-specific swaps (e.g. demand log references "the ones who stayed at the first haven already knew this demand").

Alignment also colors logs (revelation gold, warning red) and affects bus mix in audio.

Drift: slow return toward 0 unless demand policy or major actions.

---

## Key Recurring Choices & Their Thematic Meaning

**Nurture / Feed the Ember**  
Tending the last light. Scattered embers respond. Pure survival at first; later the pulse is the heart of the new order you are building.

**Gather Shards**  
"Pull warm shards from the embers scattered in the ash." Early: innocent scavenging. Later reframed as feeding the machine with remnants of the old world (and eventually the lost themselves).

**Raise a Haven** (and later buildings)  
"A place for the lost to stay near the ember... The circle begins here."  
Moral weight negative. Taper on pop gain. Desc mutates to "Binding" on tyrant path. This is the first major act of *containment / centralization*. The early choice happens inside the havens you built.

**Mark the Lines / Set Foraging** (foraging_lines)  
"Send them along marked lines in the ash. They return with more."  
Vague early label. Once outlands or low align: becomes "Mark Claiming Veins". The first explicit "claiming" language. All path revelations will say "the paths you marked for foraging led straight here" or "Foraging was never just gathering—it was the first claim."

**Demand More**  
"Push them for more now."  
Immediate shards boost, align hit, sets flag that hardens all future language. Log: "You reach deeper into them. 'Give more.' ... The ones who stayed at the first haven already knew this demand."  
Fires immediate reframe if early_choice already made. This is the seductive tyrant button — numbers feel good, language gets crueler.

**Send Forager / Assign**  
"Put a lost one to work the ash." / "Return them to the ember's light."  
Early: practical. Later: "thrall", "bound hand". The act of sending them out is what the paths later reveal was always the first step of dominion.

**Defend the Paths**  
"Spend shards to watch the paths. Holds back ash threats for a while. (strength fades over time)"  
Now builds defense_strength (visible). Positive align small bonus. Thematically: you are now explicitly *guarding what you have claimed*. Raids become "the paths remember who marked them."

**Expedition moral choices** (see Paths section) — the big explicit reframes.

---

## The Paths / Expeditions (Current 4 Locations)

**Fully data-driven** (post-expansion): All paths live only in `data/paths.json`. Discovery is dynamic (`for pid in path_data` on outlands phase gate + load ensure for old saves). Dispatch is generic (any `dispatch_<id>` action falls through to `dispatch_expedition(path_id)` with no per-path code). UI (`_refresh_outlands`), resolve, rewards, claims, first-claim Watch Spire unlock, reframe hooks (`_check_delayed_choice_reframe("path_claim")`), and Narrative flavoring are all generic. 

To add future locations: edit only `data/paths.json` (add id, name, desc, cost, travel_time, moral_options array with alignment/rewards/log/revelation). The system handles the rest. This keeps additions pure data per SKILL/AGENTS "When adding..." and "data-driven" rules.

All discovered on outlands entry. Dispatch costs shards (+ sometimes pop). Travel time 5-8 ticks. Moral choice at dispatch (or auto by alignment bias). On resolve: rewards * mult (lines + foragers + align), pop return/loss logic, specific "log" flavor, alignment delta, the **revelation** (the reframe), "is bound" line, first-claim unlock of Watch Spire, delayed choice reframe.

**1. Vein of Fading Echoes**  
Desc: "A seam where old voices still hum. The foragers spoke of warmth along lines like this."  
- Listen and Offer Passage (+0.06, resonance+vitalis): "They return carrying faint songs." Revelation: "The echoes were not lost. They were waiting. The paths you marked for foraging only ever heard the edge of it."  
- Cut the Vein for Quick Shards (-0.09, shards+res): "The ash here is richer, but quieter now." Revelation: "The lines you marked for foraging led straight here. You did not find new ground—you followed the old scars to their source. The first claim was made long before any foot stepped on this vein."

**2. Shattered Crossing**  
Desc: "Where paths once met. Remnants of the lost who never reached a Haven." (costs 1 pop)  
- Respectful Salvage (+0.04, vitalis+res): "Some walk back with them." Revelation: "These crossings were always part of the circle. Foraging was never just gathering—it was the first claim."  
- Strip What Remains (-0.08, shards): "Quick gain. The crossing is silent now." Revelation: "You sent the lost to take what the ash had already taken. The pattern repeats."

**3. Hollow of the Silent Bound**  
Desc: "A depression that pulls at the Will. Echoes of those who chose the ember too completely."  
- Parley with the Echoes (+0.07, resonance): "An uneasy accord. They return changed but whole." Revelation: "The Bound here recognize the Hearth's pull. You are not the first to offer warmth in the ash."  
- Overwhelm and Bind (-0.11, shards+vitalis): "They submit. The hollow is yours." Revelation: "Demanding more from those within the circle was practice. Here it becomes dominion. The choice at the havens taught everyone what the ash already knew."

**4. Vein of Broken Circles** (added in expansion)  
Desc: "Fractures where gatherings once held. The ash remembers circles closed too tightly."  
- Listen and Mend the Circles (+0.05, res+vitalis): "They return carrying shared silences." Revelation: "The broken circles waited for the lines you marked. The choice in the havens only named what the weight of the first ember had already bound before."  
- Claim the Fractures (-0.09, shards+res): "The fractures yield. Quiet follows the gain." Revelation: "You bound them here as the first were bound. The paths you marked were never new ground—they retraced what was claimed long before any foot stepped on this vein."

**On every claim**: "The [name] is bound. What was foraged is now held." + delayed reframe naming the haven choice.

**Meaning of expeditions**: The outlands are not "new" discovery. They are the logical continuation and exposure of what you were already doing inside the circle. The "remnants" and "echoes" are previous victims/cycles. Choosing harshly here makes the tyranny explicit; choosing "better" still participates in the claiming.

---

## Raids & Ash Answering Back

"The ash moves along the old veins. The paths remember who marked them."  

Now uses defense_strength (built by Defend, decays, + watch_spire). Mitigated = "The circle holds against the raid from the ash. For now." (small positive align if benevolent).  
Unmitigated / partial: pop and shard loss. "Veins you claimed answer back. Not all who walked the lines return." (or stronger if early_choice).  

Narrative role: The world pushes back against your expansion. Defense is you protecting what you have taken. Tyrant path invites more raids (and may "profit" via unrest mechanics in future). Visual flash on ash/ember when raid hits (stronger on loss).

---

## Text Mutation Examples (NarrativeSystem)

- "The Lost: 7" → "The Bound: 7" (tyrant or demand) or "The Gathered: 7" (benevolent).
- "Mark the Lines" button → "Mark Claiming Veins" once outlands or very negative.
- "Raise a Haven" / haven desc → "Binding", "remain and offer what remains of their will".
- Demand log: "The ones who stayed at the first haven already knew this demand."
- Path resolve: "Foraging was never just gathering—it was the first claim."
- Delayed: "When the echoes first came to the havens, you chose [shelter/demand/seal]. [memory]. ... You have been doing this since the first circle closed around the ember."
- "You did this" becomes choice-specific: "You chose to open the circle to them then. Every later claim followed from that mercy." etc.

Mutations are applied in get_flavored_text, which is called on almost every log, prompt, button label, and revelation. Context always carries early_choice, claims count, demand flag, phase, alignment, etc.

---

## Ending Branches (Planned — Phase 5+)

Multiple distinct endings based on alignment trajectory + key flags (havens built, demand_more used, early_choice, path_claims count, total_demand or overwork equivalents, never used certain harsh options, respected certain echoes/ruins, etc.). Post-game stats + "What will the next wanderer find?" + New Game+ meta (prior alignment affects starting flavor/difficulty).

Current high-level variants from DESIGN (to be implemented with specific conditions and unique text):
- **Tyrant Eternal**: World under your boot. Bitter, cracks showing (eternal rebellions, builder's ghost, alone again?).
- **Benevolent / Redemptive Order**: Harder path. Fragile alliance or enlightened rule. Costly in lives/resources. You may step down or the "builder" (original?) returns.
- **Collapse / Cycle**: Overreach leads to fall. You "wake" in a new dark room (loop hint, like the inspirational source but original). Possible regardless of alignment if you push too far.
- **No-Havens / Minimalist Challenge**: Harder numbers, different story beats (no "builder leaves in disgust"; different final transmission or sacrifice). Requires never raising a haven.
- **Pyrrhic / Tragic**: You win the world but lose everything human (including yourself). High claims + extreme negative or extreme "success" at any cost.
- **Hidden / True**: Depending on cumulative alignment + specific flags (e.g. never used demand/overwork, respected ruins/echoes, low total claims, certain early_choice + positive align). Perhaps the cycle can be broken or understood.

Legacy screen will surface the tracked state (early_choice, alignment history via choice_history, claims, demand flag, etc.).

---

## How Branches Are Tracked & Persisted (for Devs)

In GameState (serialized in save):
- `early_choice: String` ("shelter" | "seal" | "demand" | "")
- `choice_history: Array` of {event, choice, time, align}
- `alignment: float`
- `flags`: demand_more_policy, incursion_*, outlands_reached, saw_warm_scrap_hint, choice_reframe_fired_*, etc.
- `path_claims: Dictionary` (id -> true)
- `buildings`, `population`, `assigned`, `discovered_paths`, `active_expeditions`, `last_path_defense`, `defense_strength`, `total_demand` (future?), etc.

NarrativeSystem reads these via `get_current_context()` and `get_flavored_text` / mutation rules.

All major choice points should:
1. Record in choice_history or a dedicated flag.
2. Change alignment.
3. Produce an immediate flavored log.
4. Set up at least one delayed reframe that references the early choice or prior "innocent" actions.
5. Have text variants in mutation_rules or special cases in get_flavored_text.

When adding new content: update this file, the relevant JSON (with revelation + moral_weight), and NarrativeSystem if a new mutation rule or early_event is needed.

---

## Current Implemented Narrative Beats (as of this version)

- Full opening + amnesia + plural embers + "who were you".
- Early choice event with pause, 3 options, immediate + prior-action reframes.
- Paths layer: 4 locations (Vein of Broken Circles added for deeper choice + reframe callbacks to "lines you marked", "choice in the havens", "weight of the first ember"); fully data-driven discovery/dispatch (future paths = JSON only, no code changes); all with 2 moral options + reframe revelations + "bound" line + first-claim Watch Spire unlock + delayed early_choice reframe on claim.
- Demand More + language hardening.
- "Mark the Lines" mutation to claiming on outlands.
- Phase advance logs that feel ominous in hindsight.
- Raid logs + "veins you claimed answer back".
- Delayed reframe on outlands entry + every first path claim + post-demand.
- Pop / haven / action text mutations across alignment + flags.
- Visual (scattered embers) + audio (cues + mix) support for the emotional weight. Recent audio expansion adds dedicated sparse generator cues/stings for key story beats: revelation bell swell (on gold logs + reframes), first-bound resonance on initial path claim, expedition dispatch/resolve tones (by moral/align delta), eta ticks during travel, outlands unfurl drone, and reframe_sting on delayed "You have been doing this since the first circle" moments (via sfx_cue signal from GS/Narrative).

Future work (per DESIGN + SKILL impl order): more buildings/jobs with alignment branching, reactive raid choice events, production queues that feel like conscription vs willing, larger map events, full 4-6 endings with unique text and conditions, New Game+ legacies.

---

**How to use this file**  
- Before adding any new action, building, path, or event, ask: "How does this make previous play feel different in hindsight? Does it name the early choice or the first haven/foraging as complicity?"
- For new paths specifically: add only to data/paths.json with strong revelation(s) that reframe prior "foraging"/havens/early_choice/"first ember" as the origin of binding/claiming. The generic code + Narrative will surface it in UI, resolve, delayed reframes, and mutations automatically. Test with mental play (dispatch + resolve with different early_choices) and confirm reframe fires on claim.
- Keep all player-facing text in the ash/ember/vein/bound/haven/circle/claiming/Weight/lost/scattered lexicon.
- At most one exact quote from any inspirational source in the entire game.
- The power is in the *gradual* reveal. Ruthlessly cut anything that gives the twist away too early or too explicitly.

This document should be updated whenever new branches, revelations, or major mechanics with narrative weight are added. The game only feels magical when every button press matters more than the player yet knows.