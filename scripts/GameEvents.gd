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
signal sfx_cue(cue: String, params: Dictionary)  # sparse triggers from GS/Narrative for audio: revelation, first_bound, expedition_*, reframe_sting etc. Decouples from Main impl.
