# A Dark Dominion - Sound Direction (Placeholder / Early Phase)

**Overall Aesthetic (from DESIGN + AGENTS):**  
Sparse, lo-fi, austere, cold/patient. Starts almost silent (only the "pulse" and ash). High contrast in audio too: rare warm low tones for the Ember / benevolent moments, cold drones / scrapes / distant howls for tyranny, ash, dread, and the slow realization. No bright or "epic" music. Think wind through ruins, distant low bells, organic material sounds (stone/ash scrape, cloth, breath), processed and distant. Alignment (Weight) should audibly "color" the mix (more dissonance/harshness on negative, steadier/harmonic but still uneasy on positive).

**Key Rule (Differentiation):** All sound must support the ash/ember world. Avoid direct "fire crackle", "wood", "room tone" clichés even if evocative of source inspiration. Use "ember pulse hum", "ash hiss/scrape", "vein echo", "bound breath", "circle resonance". At most one exact quote ever in whole game (none in sound).

**Implementation Notes (Godot 4):**  
- Use AudioStreamPlayer (or Player2D later) + AudioBusLayout (create res://resources/audio_buses.tres).  
- Recommended buses: Master (with limiter), Ash (reverb + lowpass for distance/ash muffling), Ember (warm slight chorus + high shelf for pulse warmth), Dread (distortion + pitch shift down for tyrant/negative align or raids), UI (dry, short).  
- Dynamic mixing: In GameState/Main, on alignment change / phase / ember_pulse / flags, adjust bus volume or effects (e.g. more reverb on outlands, pitch down on low align). Use AudioServer.set_bus_volume_db etc.  
- Trigger from signals: GameEvents (action_performed, revelation, phase_advanced, choice_*, time_advanced for ambient, resource for "clink"). NarrativeSystem can have light hooks.  
- Performance: Few simultaneous players. Use one-shots for actions, looping players for ambient (fade in/out).  
- Placeholder strategy: Pure code-generated tones first (AudioStreamGenerator + sine/saw for hums, noise for ash), or free CC0 assets (freesound.org: "soft wind", "stone scrape", "distant bell", "low drone", "breath", "subtle click"). Later record or commission 8-12 core samples. Keep files small, mono where possible, 44.1k.  
- For Deck/Steam: Test with controller (no mouse hovers), low volume options, captions for important cues if narrative beats.

## Phase 0-2 (Current - Ash / Hearth / Village / Early Choice) - Sparse & Critical
Focus: Make the Ember feel alive and needy. Every action has weight. The first choice event must *feel* like a moral fork in the audio.

**Ambient / World:**
- Base: Very faint low continuous "ash wind / hiss" (brown noise + low filter, volume ~ -35dB, slow LFO on cutoff). Increases subtly with more havens / foragers / outlands open (more "footsteps in ash" layers?).
- Ember pulse: Low warm sine or soft saw hum (fundamental ~55-110Hz). Volume and slight pitch tied directly to ember_pulse (low pulse = quieter, slower, almost dying; high = stronger but still fragile). Occasional soft "heartbeat" double pulse when nurtured.
- When ember <1.0 and flickering warning: add very quiet high "thin crackle" (highpassed noise burst, rare) or cold air tone. Warning log should have audio sting.

**UI / Actions (very dry, close, material):**
- Nurture the Ember / Feed: Soft warm swell or rising low tone (0.6-1.2s), resolves with a gentle "glow" harmonic. Volume based on how much pulse restored.
- Gather Shards: Dry, short "scrape + small clink" (two layers: low friction + high glassy or stone tap). Cooldown feel: slightly different timbre on repeat. If first shards, warmer.
- Raise a Haven: Low thud + settling "ash shift" + faint resonance tail (the circle forming). Moral weight: if alignment negative, the tail is more dissonant.
- Demand More: Immediate low "pull" drone that cuts off abruptly + a "something quieted" reverse swell or breath out. Strong negative align sting.
- Assign / Send Forager: Footstep-like soft scuffs in ash (loop 2-3 variants), ending with distant "fade into wind".
- Mark Foraging Lines (later): Rhythmic marking sounds (stick on ground? but ash: soft repeated taps + line "drag").

**Narrative / Events / Choice (the gut-punch moments):**
- Revelation / log (gold text): Subtle low "resonance swell" or distant bell-like tone (very quiet, long decay, pitch related to alignment — warmer for + , colder for -). Intensity scales with importance (first haven, incursion, path claim).
- Early choice event (echo incursion prompt): When pending appears, a tense rising "approach" drone or layered breath/ash sounds (increases until choice made). Time pause makes this cue critical.
  - On resolve (any choice): The drone resolves differently per choice:
    - Shelter: soft major-ish resolve into warm tail (but uneasy undertone remains).
    - Seal: abrupt close + cold cutoff + faint distant cry (high thin tone fading into wind).
    - Demand: harsh low impact + "work rhythm" that continues briefly then quiets to empty.
  - Post-choice delayed reframe (the "oh no" when outlands opens or later dispatch): A strong, memorable low "recognition" chord or reversed memory sound that plays under the revelation text. This should make player feel the prior audio choices were foreshadowing.
- Unrest / loss of the lost: Muffled "gone" tone + wind increase.
- Phase advance (hearth, village, outlands): Slow building "unfurl" tone or layered resonance that matches the UI panel growth. Outlands entry especially should feel like the ash "opening" (wider reverb, new layer).

**Ember / Pulse specific (core loop sound):**
- Decay tick (when low): Very subtle "ebb" (volume dip + pitch down).
- Nurture success: Immediate "answer" — soft harmonic bloom.
- Critical low: Add a very slow, irregular "struggle" pulse (almost arrhythmic).

## Future Layers (Outlands+ , reference only)
- Paths / expeditions dispatch: "Step into ash" whoosh + rhythmic walking layer that plays during eta (volume by distance/align). On resolve: return sounds vary (joyful vs empty vs loss) + the vein "claim" resonance (ties back to early choice audio memory if implemented).
- Raids / defend: Rising threat layer (distant "ash moves" rumble), mitigated by defense action (cutoff). Tyrant path may have "conquered" aggressive sting.
- Watch Spire / defense buildings: Low "watch" tone or heartbeat that pulses with defense value.
- Alignment extremes: Global bus effects — tyrant adds slight distortion/grit to all ash layers; benevolent adds subtle sustaining harmonics but with "cost" (occasional sad tail).

## Technical TODOs / Placeholders to Add Next
1. Create res://resources/audio_buses.tres (or default + script tweaks).
2. Add AudioStreamPlayer nodes to Main.tscn (or code-instantiate in Main.gd): e.g. EmberPlayer (loop), AshAmbient (loop), OneShotPlayer (for actions), NarrativePlayer.
3. In GameState advance_time and perform_action: emit or directly play cues (or route all through new GameEvents like "sfx_play" with key + params {volume, pitch, bus}).
4. For now (pure placeholder): implement a couple using AudioStreamGenerator for sine + noise. Example in a small AudioManager autoload later.
5. Hook the choice prompt appearance + resolution (already has pause + special UI) to audio swells.
6. Test with speed controls (scale pitch? or keep musical).
7. Later: volume sliders in options, alignment-reactive mix, save bus settings?

## Quick Start for Placeholders (No Assets Yet)
- Use Godot's built-in: `AudioStreamGenerator` + script to fill buffer with low sine for ember + filtered noise for ash.
- Or download 3-5 short CC0 WAVs and assign to players triggered on key actions (nurture, gather, revelation, choice).
- Example trigger sketch (to be implemented in Main or new manager):
  ```gdscript
  # on nurture success
  ember_player.pitch_scale = 0.9 + (GameState.ember_pulse / 12.0)
  ember_player.play()
  ```
- When adding the first real cue, also add a matching revelation or log mutation if it reinforces the "I did this" feeling.

**References / Inspiration (structural only):** Sparse soundtracks like "A Dark Room" (if played), "The Banner Saga" wind, "Kentucky Route Zero" minimal tones, "Outer Wilds" distant signals, "Papers Please" oppressive stamps + tension. All re-skinned to ash/ember.

Update this doc as we add actual players, buses, or first samples. Every new system (expedition, raid, new building) must answer: "What does this sound like, and does it reframe prior sounds?"

Keep it cold. Keep it inevitable. The first time the choice reframe sting plays over a path resolve should land in the chest.

## Implemented (Phase 3+ audio polish per task)
- Buses (Ash/Ember/Dread/UI) in resources/audio_buses.tres + players + generator in Main._setup_audio (post initial changes).
- Ash ambient: improved reliable brown noise via lowpass integration (_ash_prev state, 0.91*prev + 0.09*white); slight LFO on ash_ambient.pitch_scale + volume_db (slow sin in _on_time_for_ui for cutoff/wind living feel); smart fill calls (avail>280 check, small caps + %5 fuller) no lag, ensure playing.
- Cue quality: _play_ember/gather/raid/choice now vary freq/dur/vol/pitch by pulse/align/strength (e.g. nurture stronger=lower freq~44-92 + longer dur tail; raid loss=low rumble noise longer dread bus vs mitigated higher shorter; choice tension per delta; gather 2 layers via added one_shot_dry player: low scrape noise + high sine clink).
- New cues (2-3+): _play_revelation_swell (low bell-like on gold logs, uses is_bell partials 57Hz+ inharmonics, align color, via Narrative/GS _log revelation); _play_first_bound_sting (special resonance on resolve if new path claim "first bound"); _play_expedition_cue (dispatch whoosh noise, resolve tone/noise by align_delta); _play_eta_tick_cue (sparse dry in time hook for active expeditions).
- Extended _generate_tone_burst(..., is_bell=false) for bell mode (fund + 2.37/4.05 partials).
- Phase hook: _on_phase_advanced outlands -> _play_outlands_unfurl (ash pitch down + bus vol, extra fill, new outlands_drone low sine 37Hz on Ash).
- Triggers: added GameEvents.sfx_cue(cue, params); Main connects + _on_sfx_cue dispatches to plays. GS/Narrative trigger via emit: revelation_swell (in trigger_revelation + GS._log if rev), first_bound (in _resolve_one if was_first), expedition_dispatched/resolved (in dispatch_expedition + _resolve_one), reframe_sting (in _check_delayed_choice_reframe for key reframe moments like path_claim/first_outlands).
- In Main: revelation via sfx from logs, action hooks (nurture/gather/defend), raid, choice offered/selected, alignment vol, time sparse, phase unfurl. No heavy _process.
- Strict ash/ember/vein/bound lexicon preserved (no forbidden); sparse/lo-fi generator only; typed/Dict patterns; signals.
- Mental test (post import clean 0 errs): nurture= warm swell (lower on strong); gather= dry 2layer scrape+clink; bad raid= dread rumble; choice= tension+resolve per align; outlands unfurl wider+drone; revelation gold bell; first claim sting; dispatch/resolve eta/return tones; reframe sting on delayed.

## Remaining TODOs (from SOUND_DIRECTION + future)
- Ember pulse loop tied to ember_pulse state (decay tick, heartbeat on nurture) - currently only on action cue.
- Full dynamic bus effects (reverb on outlands, distortion on tyrant extremes) - buses exist but no AudioEffect yet in .tres.
- Real samples later (CC0 wind/scrape/bell; replace generators).
- Volume/pitch scale with time_scale? (keep musical or not).
- More phase/building cues (e.g. haven raise thud, demand pull).
- Save bus vols? Options UI.
- Test with speed (20x) + offline resolve (cues may spam on catchup; gate?).
- Expedition whoosh during eta (currently only dispatch/resolve/tick).
- Raid mitigated vs loss more distinct + unrest tie.
- Every new system answer "what does this sound like + reframe prior?"

Update as Phase 4+ expands. Cold. Inevitable.
