# scripts/GameEvents.gd
# Global signal bus. Connect from anywhere. Emit only from authoritative systems (mostly GameState).
extends Node

signal resource_changed(resource: String, new_amount: float, delta: float)
signal rate_changed(resource: String, new_rate: float)
signal alignment_changed(new_alignment: float, delta: float, reason: String)
signal population_changed(total: int, free: int, delta: int)
signal building_unlocked(building_id: String)
signal building_built(building_id: String, count: int)
signal action_performed(action_id: String, success: bool)
signal narrative_event(event_id: String, text: String, alignment_impact: float)
signal phase_advanced(new_phase: String)
signal time_advanced(seconds: float)

# For UI hints
signal available_actions_changed()
signal log_message(text: String, category: String)  # category: "story", "system", "warning", "revelation"
signal choice_offered(event_key: String)  # polish: proper early choice events surface here for UI
signal choice_resolved(event_key: String, choice_id: String)
signal raid_occurred(mitigated: bool, pop_loss: int)  # for defense system: UI reactions, sounds, stronger narrative hooks on path threats
signal raid_encounter_offered(raid_id: String)
signal raid_encounter_resolved(raid_id: String, choice_id: String)
signal ending_reached(ending_id: String, outcome: String)  # R3: nurture/harvest win or collapse lose — Main shows overlay
signal sfx_cue(cue: String, params: Dictionary)  # sparse triggers from GS/Narrative for audio: revelation, first_bound, expedition_*, reframe_sting etc. Decouples from Main impl.

# Simple events system: Ash Whispers (creative adaptation of random/login "Dragon's Whispers" to theme: ash echoes, vein murmurs, ember calls.
# Temporary boosts (double drops/rates), special "echo manifestations" (abstract special mob/encounter with rare vitalis "gear" flavor).
# Tracked in active_whispers; tied to areas (paths/veins) or ascends (phase/alignment thresholds).
signal whisper_triggered(whisper_id: String, text: String)
signal whisper_expired(whisper_id: String, resolved_text: String)

