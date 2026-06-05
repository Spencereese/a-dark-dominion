# scripts/NarrativeSystem.gd
# Centralized narrative/revelation + text mutation system.
# Provides rule-based mutations for the slow "oh no, I did this" realization.
# Supports context-aware variants (alignment/Weight, early choices, flags, counts).
# Choice events route through here for prompts + delayed reframes that call back to early decisions.

extends Node

# Rule-based mutation table. Each entry can match on context and apply replaces or full variant.
# Expanded during polish for clean gut-punch landing.
var mutation_rules: Array = [
	# Tyrant extremes
	{"when": {"align_lt": -0.6}, "replaces": {"the lost": "the Bound", "The Lost": "The Bound", "lost ones": "Bound ones", "grateful": "resigned", "Grateful": "Resigned", "hands": "tools", "Hands": "Tools", "work the ash": "toil in the ash", "forager": "thrall", "Forager": "Thrall", "shelter": "contain", "Shelter": "Contain", "walk the ash": "march under the Will"}},
	# Harsh mid
	{"when": {"align_lt": -0.3}, "replaces": {"the lost": "the Bound", "The Lost": "The Bound", "grateful": "quiet", "Grateful": "Quiet", "hands": "labor", "Hands": "Labor", "forager": "bound hand", "Forager": "Bound hand"}},
	# Benevolent
	{"when": {"align_gt": 0.3}, "replaces": {"the lost": "the gathered", "The Lost": "The Gathered", "forager": "wanderer", "Forager": "Wanderer"}},
	# Neutral default kept
	{"when": {}, "replaces": {"the lost": "the lost", "The Lost": "The Lost"}},
	# Demand policy hardens language
	{"when": {"flag": "demand_more_policy"}, "replaces": {"forager": "thrall", "Forager": "Thrall", "work": "toil", "Work": "Toil", "hands": "labor"}},
	# After incursion handled, arrivals become Bound
	{"when": {"flag": "incursion_handled"}, "replaces": {"new arrivals": "new Bound", "New arrivals": "New Bound", "echo incursion": "remnant claim", "echoes": "remnants"}},
	# Foraging reframes to claiming once paths or low align
	{"when": {"or": ["outlands_reached", "align_lt:-0.5"]}, "replaces": {"foraging": "claiming", "Foraging": "Claiming", "Mark Foraging Lines": "Mark Claiming Veins", "Mark the Lines": "Mark Claiming Veins", "foraging lines": "claiming veins"}},
]

# Early choice memory for delayed reframes. Keyed by choice_id.
var early_choice_memories: Dictionary = {
	"shelter": "You opened the havens. You told yourself it was mercy. The pulse called, and they answered.",
	"seal": "You sealed them out. Their cries faded, and the ember steadied. The circle learned to close.",
	"demand": "They worked at once. No oath asked, only the pulse. Their eyes went quiet before they ever saw the ash.",
}

# Simple early event prompts (can expand to data later)
var early_events: Dictionary = {
	"echo_incursion": {
		"prompt": "An echo incursion approaches the havens. Broken figures from the ash, seeking the pulse. They are remnants, like the ones you foraged and sent before. What do you do with these new arrivals?",
		"options": [
			{"id": "shelter", "label": "Shelter them within the havens", "align": 0.08, "desc": "Cost shards. They join the circle... and their silence spreads to the ones already here."},
			{"id": "seal", "label": "Seal the havens. Let the ash claim them.", "align": -0.10, "desc": "No cost. Cries fade. The ember feels steadier."},
			{"id": "demand", "label": "Demand they work for the shelter of the pulse.", "align": -0.15, "desc": "Immediate shards. They toil from the first step. Eyes empty like those who came before."}
		]
	}
}

func _ready() -> void:
	GameEvents.action_performed.connect(_on_action_performed)
	GameEvents.phase_advanced.connect(_on_phase_advanced)
	GameEvents.alignment_changed.connect(_on_alignment_changed)
	GameEvents.building_built.connect(_on_building_built)
	# Could connect more

func _on_action_performed(action_id: String, success: bool) -> void:
	if not success: return
	pass

func _on_phase_advanced(new_phase: String) -> void:
	if new_phase == "outlands":
		pass

func _on_alignment_changed(new_val: float, delta: float, reason: String) -> void:
	if abs(delta) > 0.1:
		pass

func _on_building_built(building_id: String, count: int) -> void:
	pass

func trigger_revelation(text: String, category: String = "revelation") -> void:
	if text == "": return
	var flavored: String = get_flavored_text(text)
	GameEvents.log_message.emit(flavored, category)
	# Trigger specific sfx via GameEvents for key reframe / gold log moments (revelation swell)
	GameEvents.sfx_cue.emit("revelation_swell", {"strength": 1.0})

# New: context-aware mutate. Callers can pass full context for choice-aware reframes.
func mutate_text(base: String, context: Dictionary = {}) -> String:
	return get_flavored_text(base, context)

# Build rich context from GameState for any mutation call.
func get_current_context() -> Dictionary:
	if not GameState:
		return {}
	var ctx: Dictionary = {
		"alignment": GameState.alignment,
		"phase": GameState.phase,
		"havens": GameState.buildings.get("haven", 0),
		"population": GameState.population,
		"foragers": GameState.assigned.get("forager", 0),
		"time": GameState.total_play_time,
		"demand_more": GameState.flags.get("demand_more_policy", false),
		"incursion_handled": GameState.flags.get("incursion_handled", false),
		"paths_opened": GameState.flags.get("outlands_reached", false) or GameState.phase == "outlands",
		"claims": (GameState.path_claims.keys().size() if typeof(GameState.path_claims) == TYPE_DICTIONARY else 0) if GameState and "path_claims" in GameState else 0,
	}
	if "early_choice" in GameState:
		ctx["early_choice"] = GameState.early_choice
	if "choice_history" in GameState:
		ctx["choice_history"] = GameState.choice_history
	return ctx

func get_flavored_text(base: String, context: Dictionary = {}) -> String:
	# Use passed context or build fresh. Supports early_choice for gut-punch reframes.
	var ctx: Dictionary = context
	if ctx.is_empty():
		ctx = get_current_context()
	var align: float = ctx.get("alignment", 0.0)
	var flags: Dictionary = {}
	if GameState and "flags" in GameState:
		flags = GameState.flags
	# Merge choice info into effective flags for rule matching
	var eff_flags: Dictionary = flags.duplicate()
	if ctx.has("early_choice") and ctx["early_choice"] != "":
		eff_flags["early_choice_" + ctx["early_choice"]] = true
	if ctx.get("demand_more", false):
		eff_flags["demand_more_policy"] = true
	if ctx.get("incursion_handled", false):
		eff_flags["incursion_handled"] = true
	if ctx.get("paths_opened", false):
		eff_flags["paths_in_ash_opened"] = true

	var result: String = base

	# Apply rule table (order matters: specific after broad)
	for rule in mutation_rules:
		var when: Dictionary = rule.get("when", {})
		if not _rule_matches(when, align, eff_flags, ctx):
			continue
		var reps: Dictionary = rule.get("replaces", {})
		for from in reps:
			result = result.replace(from, reps[from])

	# Additional context/choice-aware full phrase variants (for clean landing)
	# These catch whole strings or key substrings and swap for stronger variants.
	var early: String = str(ctx.get("early_choice", ""))
	if "new arrivals" in result or "echo incursion" in result or "remnants, like the ones you foraged" in result:
		if early == "shelter":
			result = result.replace("new arrivals", "new Bound who answered the same call you once answered yourself")
			result = result.replace("What do you do with these new arrivals?", "What do you do with these who came seeking the same warmth you first offered the others?")
		elif early == "demand":
			result = result.replace("new arrivals", "new hands already empty, like the ones you sent before")
			result = result.replace("What do you do with these new arrivals?", "Will you repeat the demand you made of the first ones who stayed?")
		elif early == "seal":
			result = result.replace("new arrivals", "more remnants the circle has already learned to turn away")
			result = result.replace("What do you do with these new arrivals?", "Will the havens stay sealed, as they were for the last who cried at the edge?")

	if "foraged and sent before" in result or "the ones you foraged" in result:
		if early != "":
			result += " The choice you made then still echoes in how they move now."

	# Strong delayed reframe hook (called with special base text from GS resolve/phase)
	if "You did this" in result or "from the start" in result or "the circle has always" in result:
		if early == "shelter":
			result = result.replace("You did this", "You chose to open the circle to them then. Every later claim followed from that mercy.")
		elif early == "demand":
			result = result.replace("You did this", "Demanding their labor at the first haven taught the ash what you truly wanted.")
		elif early == "seal":
			result = result.replace("You did this", "Closing the havens taught the circle how to keep what it takes.")

	# Pop status variants (used on the "The Lost: X" line)
	if "The Lost:" in result or "The Bound:" in result or "The Gathered:" in result:
		if align < -0.6:
			result = "The Bound: %s" % result.split(":")[1] if ":" in result else result
		elif align < -0.3 or early == "demand":
			result = result.replace("The Lost:", "The Bound:").replace("free", "claimed")
		elif align > 0.3:
			result = result.replace("The Lost:", "The Gathered:")

	# Haven / arrival specific
	if "Raise a Haven" in result or "a proper Haven" in result or "The lost may stay" in result:
		if align < -0.4 or early == "demand":
			result = result.replace("Haven", "Binding").replace("haven", "binding").replace("stay and offer their hands", "remain and offer what remains of their will")
		elif align > 0.2:
			result = result.replace("Haven", "Sanctuary").replace("offer their hands", "lend their strength")

	# Demand more variants
	if "Give more" in result or "Demand More" in result or "watching the lost work the ash" in result:
		if early == "demand":
			result = result.replace("Give more", "Give as the first ones gave")
		if align < -0.5:
			result = result.replace("A new thought occurs while watching the lost work the ash.", "The thought arrives again: they have always had more to give.")

	# Phase / outlands reframe tie-in
	if "foraging lines reach farther" in result.to_lower() or "The lost will walk them now" in result:
		if early != "":
			result += " The ones who came to the havens already knew the shape of the paths."

	return result

func _rule_matches(when: Dictionary, align: float, flags: Dictionary, ctx: Dictionary) -> bool:
	if when.is_empty(): return true
	if when.has("align_lt") and align >= float(when["align_lt"]): return false
	if when.has("align_gt") and align <= float(when["align_gt"]): return false
	if when.has("flag"):
		var f: String = str(when["flag"])
		if not flags.get(f, false): return false
	if when.has("or"):
		var ors = when["or"]
		if typeof(ors) == TYPE_ARRAY:
			for o in ors:
				var ok: bool = false
				if typeof(o) == TYPE_STRING and o.begins_with("align_lt:"):
					if align < float(o.split(":")[1]): ok = true
				elif flags.get(str(o), false): ok = true
				if ok: return true
			return false
	return true

# === Choice event support (for proper early gut-punch event) ===
func trigger_choice_event(event_key: String, gs_context: Dictionary = {}) -> Dictionary:
	# Returns the event def so UI can show prompt + options without hardcoding strings in Main.
	# GS should call this, set pending flags, and UI reacts.
	if not early_events.has(event_key):
		return {}
	var ev: Dictionary = early_events[event_key].duplicate(true)
	# Flavor the prompt immediately
	ev["prompt"] = get_flavored_text(ev.get("prompt", ""), gs_context)
	for opt in ev.get("options", []):
		opt["label"] = get_flavored_text(opt.get("label", ""), gs_context)
		opt["desc"] = get_flavored_text(opt.get("desc", ""), gs_context)
	return ev

func apply_choice(choice_id: String, event_key: String, extra_context: Dictionary = {}) -> Dictionary:
	# Apply mechanical + narrative outcome for a choice. Returns effects for GS to apply (pop, align, flags, logs).
	# This centralizes so delayed reframes can look up what was chosen.
	var result: Dictionary = {"applied": false, "align_delta": 0.0, "pop_gain": 0, "shards": 0.0, "reframed_log": "", "flags": {}}
	if not early_events.has(event_key):
		return result
	var opts: Array = early_events[event_key].get("options", [])
	var chosen: Dictionary = {}
	for o in opts:
		if o.get("id") == choice_id:
			chosen = o
			break
	if chosen.is_empty():
		return result

	result["applied"] = true
	result["align_delta"] = float(chosen.get("align", 0.0))
	# Specifics per known choice (shelter/demand/seal for echo_incursion)
	match choice_id:
		"shelter":
			result["pop_gain"] = 2
			result["shards"] = -20.0
			result["reframed_log"] = "You open the havens. They enter, eyes wide at first. 'The pulse... it calls.' But their silence spreads to the others you gathered before."
			result["flags"] = {"incursion_sheltered": true}
		"seal":
			result["align_delta"] = -0.10
			result["reframed_log"] = "You seal the havens. Their cries fade into the ash. You feel the pulse steady... and something in you tighten."
			result["flags"] = {"incursion_sealed": true}
		"demand":
			result["shards"] = 15.0
			result["align_delta"] = -0.15
			result["reframed_log"] = "They work at once. No thanks, just toil for the pulse. The numbers rise, but their eyes... already empty like the Bound before them."
			result["flags"] = {"incursion_demanded": true}
		_:
			result["reframed_log"] = chosen.get("desc", "")

	# Add the memory for later delayed reframe
	if early_choice_memories.has(choice_id):
		result["memory"] = early_choice_memories[choice_id]

	return result

func get_choice_reframe(choice_id: String) -> String:
	# For use in delayed gut-punch logs in GS resolve/phase.
	return early_choice_memories.get(choice_id, "")

func _log(text: String, category: String = "story") -> void:
	var flavored: String = get_flavored_text(text)
	GameEvents.log_message.emit(flavored, category)
