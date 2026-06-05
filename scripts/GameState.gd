# scripts/GameState.gd
# The heart of A Dark Dominion. Central simulation, resources, population, alignment, progression.
# All economy, unlocks, and state changes flow through here.
# Designed to be edited iteratively with Grok Build / subagents.

extends Node

# === Core State (serialized) ===
var resources: Dictionary = {
	"shards": 0.0,
	"resonance": 0.0,
	"vitalis": 0.0,
}

var rates: Dictionary = {
	"shards": 0.0,
	"resonance": 0.0,
	"vitalis": 0.0,
}

var buildings: Dictionary = {}  # id -> count
var unlocked_buildings: Array[String] = []

var population: int = 0
var assigned: Dictionary = {}  # job -> count  e.g. "gatherer": 2

var alignment: float = 0.0  # -1.0 (oppressive/tyrant) to +1.0 (benevolent)
var phase: String = "dark"  # dark, hearth, village, outlands, realm, dominion

# Phase 1+3+4 outlands/paths state (serialized)
var discovered_paths: Array[String] = []
var active_expeditions: Array[Dictionary] = []
var path_claims: Dictionary = {}
var path_data: Dictionary = {}

var flags: Dictionary = {}  # story flags, seen events, etc.

# Polish: early choice state for gut-punch reframe (stored so delayed revelations can reference exactly what player chose at the havens)
var early_choice: String = ""  # "shelter", "seal", "demand" etc.
var choice_history: Array = []  # list of {event, choice, time} for future narrative branches

var last_played_unix: int = 0
var total_play_time: float = 0.0

# Runtime only
var time_scale: float = 1.0
var is_paused: bool = false
var _accumulated_delta: float = 0.0
var _tick_interval: float = 1.0  # seconds per discrete tick for stability
var cooldowns: Dictionary = {}  # for data-driven cooldown actions (e.g. gather)

# Outlands defense timing (runtime, not critical for save but included for consistency)
var last_path_defense: float = 0.0  # total_play_time when paths last defended
var defense_strength: float = 0.0  # decays over time; built by Defend action + Watch Spire; makes raids less likely to bite (Phase 4 TD-lite)

# === Data-Driven Content ===
var building_data: Dictionary = {}  # loaded from data/buildings.json
var action_data: Dictionary = {}  # loaded from data/actions.json -- 100% data-driven actions


# === Balance / Tuning (will move to data/ or Balance resource later) ===
const STARTING_SHARDS := 0.0
const EMBER_DECAY_RATE := 0.8  # per tick when not nurtured (abstract "pulse")
var ember_pulse: float = 0.0  # 0-10 or so

# cooldowns dict (populated from action_data "cooldown") handles gather etc; old _last removed for data-driven


# Alignment effects (simple multipliers for prototype)
func get_prod_mult() -> float:
	if alignment <= -0.6:
		return 1.35  # tyrant efficiency
	elif alignment <= -0.2:
		return 1.15
	elif alignment >= 0.6:
		return 0.85  # benevolent more "fair", slower raw numbers
	elif alignment >= 0.2:
		return 0.95
	return 1.0

func get_unrest_risk() -> float:
	# Higher on extreme tyrant or if demanding more from the lost
	if alignment < -0.5:
		return 0.04
	return 0.01

# === Lifecycle ===
func _ready() -> void:
	_load_building_data()
	_load_paths_data()  # Phase 1+3+4: after building load, exact pattern
	_load_action_data()  # 100% data-driven actions
	_load_or_init()
	# Seed some starting flavor if brand new
	if resources["shards"] <= 0.1 and phase == "dark":
		_log("There is only ash and silence, broken by the pulse of embers.", "story")
		_log("A central ember pulses weakly before you. Others flicker at the edges of the darkness.", "story")

	GameEvents.available_actions_changed.emit()

	# Connect internal signals if needed
	# GameEvents.time_advanced.connect(_on_time_advanced)  # example hook for future systems

func _load_building_data() -> void:
	var path: String = "res://data/buildings.json"
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			building_data = parsed
			if OS.has_feature("editor"):
				print("[GameState] Loaded building data: ", building_data.keys())
		else:
			push_warning("Failed to parse buildings.json")
	else:
		push_warning("buildings.json not found at " + path)

func _load_paths_data() -> void:
	# Exact parallel to _load_building_data (lines 82-93 pattern)
	var path: String = "res://data/paths.json"
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			path_data = parsed
			if OS.has_feature("editor"):
				print("[GameState] Loaded paths data: ", path_data.keys())
		else:
			push_warning("Failed to parse paths.json")
	else:
		push_warning("paths.json not found at " + path)

func _load_action_data() -> void:
	# 100% data-driven actions (parallel to buildings/paths)
	var path: String = "res://data/actions.json"
	if FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			action_data = parsed
			if OS.has_feature("editor"):
				print("[GameState] Loaded actions data: ", action_data.keys())
		else:
			push_warning("Failed to parse actions.json")
	else:
		push_warning("actions.json not found at " + path)

func _process(delta: float) -> void:
	if is_paused or time_scale <= 0.0:
		return

	_accumulated_delta += delta * time_scale

	# Discrete ticks for stable idle math
	while _accumulated_delta >= _tick_interval:
		advance_time(_tick_interval)
		_accumulated_delta -= _tick_interval

	# Occasional passive checks (unlocks, random flavor)
	_check_unlocks()

func advance_time(seconds: float) -> void:
	if seconds <= 0:
		return

	total_play_time += seconds

	# === Passive resource gain ===
	var mult: float = get_prod_mult()
	for res in rates:
		if rates[res] > 0:
			var gain: float = rates[res] * seconds * mult
			resources[res] += gain
			GameEvents.resource_changed.emit(res, resources[res], gain)

	# === Ember pulse simulation (early game "need") ===
	if phase == "dark" or phase == "hearth":
		ember_pulse = max(0.0, ember_pulse - EMBER_DECAY_RATE * (seconds / _tick_interval))
		if ember_pulse < 1.0 and randf() < 0.15:
			_log("The ember flickers. The ash presses closer.", "warning")

	# Defense strength decays (represents watchers tiring, ash "remembering" the paths)
	if defense_strength > 0.0:
		defense_strength = max(0.0, defense_strength - 0.04 * seconds)

	# === Population passive effects & moral drift ===
	if population > 0:
		# Very light drift toward 0 (or toward negative if tyrant policies active)
		var drift: float = 0.0
		if "demand_more_policy" in flags and flags["demand_more_policy"]:
			drift = -0.002 * seconds
		else:
			drift = 0.0005 * seconds * sign(alignment)  # slow return to center if not pushing
		set_alignment(alignment + drift, "time")

		# Unrest chance
		if randf() < get_unrest_risk() * (seconds / 60.0) * (population / 10.0):
			_trigger_unrest_event()

	_check_unlocks()  # data-driven action unlocks (e.g. when pop drifts or rates give pop)

	# === Phase advancement checks ===
	_check_phase_advancement()

	_check_unlocks()  # again after possible phase change (e.g. to outlands to unlock "defend_paths" etc via its unlocks_at)

	# Resolve any expeditions that reached eta (after phase check per plan)
	_resolve_expeditions()

	# Polish: dedicated early choice hook so the first real gut-punch can trigger cleanly at pop/haven threshold
	_check_early_choice_events()

	# Periodic path raid tease if outlands (scaled by foragers/foraging_lines/align, basic stub)
	if phase == "outlands" and population > 0:
		var raid_chance: float = 0.004 * (seconds / _tick_interval)
		raid_chance += assigned.get("forager", 0) * 0.0008
		raid_chance += buildings.get("foraging_lines", 0) * 0.0015
		if alignment < -0.4:
			raid_chance *= 1.3
		elif alignment > 0.3:
			raid_chance *= 0.7
		if randf() < raid_chance:
			_trigger_path_raid()

	GameEvents.time_advanced.emit(seconds)

	# Save occasionally
	if int(total_play_time) % 30 == 0:
		save_game()

func set_time_scale(new_scale: float) -> void:
	time_scale = clamp(new_scale, 0.0, 100.0)
	is_paused = (time_scale == 0.0)
	GameEvents.log_message.emit("Time scale: %sx" % time_scale if not is_paused else "Paused", "system")

func set_alignment(new_val: float, reason: String = "") -> void:
	var old: float = alignment
	alignment = clamp(new_val, -1.0, 1.0)
	var delta: float = alignment - old
	if abs(delta) > 0.001:
		GameEvents.alignment_changed.emit(alignment, delta, reason)
		# Subtle log on significant shifts
		if abs(delta) > 0.05:
			var txt: String = ""
			if alignment < -0.7:
				txt = "Something cold has settled in your chest."
			elif alignment < -0.3:
				txt = "The work is getting done faster. The faces are harder to meet."
			elif alignment > 0.3:
				txt = "You find yourself hesitating before giving orders."
			if txt != "":
				if NarrativeSystem:
					NarrativeSystem.trigger_revelation(txt)
				else:
					_log(txt, "revelation")

# === Data-driven helpers (for 100% data-driven actions + buildings) ===
func _meets_unlock_reqs(reqs: Dictionary) -> bool:
	if reqs.is_empty():
		return false
	var ok: bool = true
	if reqs.has("phase") and phase != reqs["phase"]:
		ok = false
	if reqs.has("resources"):
		var rreq: Dictionary = reqs["resources"]
		for r in rreq:
			if resources.get(r, 0.0) < rreq[r]:
				ok = false
				break
	if reqs.has("pop") and population < int(reqs["pop"]):
		ok = false
	return ok

func check_conditions(conds: Dictionary) -> bool:
	if conds.is_empty():
		return true
	for k in conds:
		var v = conds[k]
		match k:
			"phase", "phase_eq":
				if phase != str(v):
					return false
			"ember_pulse_lt":
				if ember_pulse >= float(v):
					return false
			"pop_gte":
				if population < int(v):
					return false
			"free_pop_gte":
				if _get_free_pop() < int(v):
					return false
			"assigned_forager_gte":
				if assigned.get("forager", 0) < int(v):
					return false
			"unlocked_building":
				if str(v) not in unlocked_buildings:
					return false
			"phase_outlands":
				if phase != "outlands":
					return false
	return true

func _check_cooldown(action_id: String, cooldown: float) -> bool:
	# Use game time (total_play_time) so cooldowns respect time_scale / speed controls.
	# This lets high speed make manual gathers (and defends) elapse their cooldowns faster too.
	# (Previously unix wall-clock, which blocked fast sim/playtest of gather-to-15 progression.)
	if not cooldowns.has(action_id):
		cooldowns[action_id] = 0.0
	var last: float = float(cooldowns[action_id])
	# Handle legacy saves that stored unix timestamps (large ints) -- treat as expired for this session
	if last > 1000000000.0:
		last = max(0.0, total_play_time - 100.0)  # generous grace so first post-load gather works
		cooldowns[action_id] = last
	var now: float = total_play_time
	return (now - last) > cooldown

func _mark_cooldown(action_id: String) -> void:
	cooldowns[action_id] = total_play_time

func _apply_action_effects(action_id: String, def: Dictionary) -> void:
	var effects: Dictionary = def.get("effects", {})
	# Common effects
	if effects.has("ember_pulse"):
		ember_pulse = float(effects["ember_pulse"])
	if effects.has("ember_pulse_add"):
		ember_pulse = min(10.0, ember_pulse + float(effects["ember_pulse_add"]))
	if effects.has("ember_pulse_set"):
		ember_pulse = float(effects["ember_pulse_set"])
	if effects.has("shards_add"):
		var amt: float = float(effects["shards_add"])
		resources["shards"] = resources.get("shards", 0.0) + amt
		GameEvents.resource_changed.emit("shards", resources["shards"], amt)
	elif effects.has("shards_add_base") or effects.has("shards_add_per_pop"):
		var base: float = float(effects.get("shards_add_base", 0.0))
		var per: float = float(effects.get("shards_add_per_pop", 0.0))
		var amt: float = base + per * float(population)
		if amt > 0:
			resources["shards"] = resources.get("shards", 0.0) + amt
			GameEvents.resource_changed.emit("shards", resources["shards"], amt)
	if effects.has("phase"):
		phase = str(effects["phase"])
		GameEvents.phase_advanced.emit(phase)
	if effects.has("unlock_building"):
		_unlock_building(str(effects["unlock_building"]))
	if effects.has("log"):
		var txt: String = str(effects["log"])
		var cat: String = str(effects.get("log_category", "story"))
		if NarrativeSystem:
			txt = NarrativeSystem.get_flavored_text(txt)
		if cat == "revelation" and NarrativeSystem:
			NarrativeSystem.trigger_revelation(txt)
		else:
			_log(txt, cat)
	if effects.has("set_flag"):
		flags[str(effects["set_flag"])] = true
		if str(effects["set_flag"]) == "demand_more_policy" and early_choice != "":
			# Fire reframe immediately on first demand after the early choice — another vector for the punch
			_check_delayed_choice_reframe("demand_after")
	if effects.has("align_delta"):
		set_alignment(alignment + float(effects["align_delta"]), action_id)
	if effects.has("set_last_defend"):
		last_path_defense = total_play_time
	if effects.has("add_defense"):
		var add: float = float(effects["add_defense"])
		defense_strength = min(12.0, defense_strength + add)
	# Build delegation (for raise_haven etc)
	if effects.has("build"):
		_try_build_building(str(effects["build"]))
	# Assign/unassign jobs
	if effects.has("assign"):
		var job: String = str(effects["assign"])
		var delta: int = int(effects.get("delta", 1))
		assigned[job] = max(0, assigned.get(job, 0) + delta)
		_recalculate_rates()
		GameEvents.population_changed.emit(population, _get_free_pop(), 0)
	# Special call for hints etc (for gather)
	if effects.has("call_hint"):
		if effects["call_hint"] == "check_first_shard_hints":
			_check_first_shard_hints()

# === Actions (called by UI buttons) ===
func perform_action(action_id: String) -> bool:
	var success: bool = false

	if action_data.has(action_id):
		var def: Dictionary = action_data[action_id]
		# Cooldown check if specified (e.g. gather)
		if def.has("cooldown"):
			var cd: float = float(def["cooldown"])
			if not _check_cooldown(action_id, cd):
				_log("The ash clings. You need a moment.", "warning")
				return false
			_mark_cooldown(action_id)
		if action_id == "feed_ember" and ember_pulse >= 10.0:
			_log("The ember is full and steady. No more needed now.", "system")
			return false
		if check_conditions(def.get("conditions", {})):
			var cost: Dictionary = def.get("cost", {})
			var can_proceed: bool = true
			# For build-delegated actions like raise_haven / set_foraging: the real cost lives in buildings.json
			# (action cost is deliberately {} so UI can show via special case). Pre-validate the build cost
			# here so we don't falsely succeed the action (which caused UI juice/flash + no effect, only inner warn).
			# This was a block to smooth use of the newly appearing "raise_haven" option (shows at 15 shards via haven unlock, but costs 40).
			if def.get("effects", {}).has("build"):
				var bld: String = str(def["effects"]["build"])
				if bld in building_data:
					var bc: Dictionary = building_data[bld].get("cost", {})
					if not bc.is_empty() and not _can_afford(bc):
						_log("Not enough resources to build " + str(building_data[bld].get("name", bld)) + ".", "warning")
						can_proceed = false
			if can_proceed:
				if _can_afford(cost):
					_spend(cost)
					_apply_action_effects(action_id, def)
					success = true
				else:
					_log("Not enough resources.", "warning")
			# else: already logged the build-specific not-enough; do not succeed
		else:
			# conditions not met; silent or warning depending
			pass
	else:
		# Fallbacks for dynamic path dispatches (now 100% data-driven via paths.json; any new path id works with no code change)
		# + early choice events. Removed hardcoded dispatch ids per expansion to keep additions data-only.
		if action_id.begins_with("dispatch_"):
			var path_id: String = action_id.substr(8)
			if path_data.has(path_id):
				success = dispatch_expedition(path_id)
			else:
				_log("Unknown path in the ash: " + path_id, "warning")
		else:
			# Early choice event (echo incursion) now properly routed through NarrativeSystem.apply_choice
			# This removes the old inline match bloat. The real gut-punch lives in the delayed reframe logs + choice-aware mutations.
			match action_id:
				"choice_shelter_incursion", "choice_seal_havens", "choice_demand_work":
					var choice_id: String = ""
					if action_id == "choice_shelter_incursion": choice_id = "shelter"
					elif action_id == "choice_seal_havens": choice_id = "seal"
					else: choice_id = "demand"
					success = _resolve_early_choice("echo_incursion", choice_id)

				_:
					_log("Unknown action: " + action_id, "warning")

	if success:
		GameEvents.action_performed.emit(action_id, true)
		GameEvents.available_actions_changed.emit()
		_check_unlocks()

	return success

func _build_building(id: String, count: int) -> void:
	buildings[id] = buildings.get(id, 0) + count
	if id not in unlocked_buildings:
		unlocked_buildings.append(id)
		GameEvents.building_unlocked.emit(id)
	GameEvents.building_built.emit(id, count)
	_recalculate_rates()

func _try_build_building(id: String) -> bool:
	if id not in building_data:
		_log("Unknown building: " + id, "warning")
		return false

	var def: Dictionary = building_data[id]
	var cost: Dictionary = def.get("cost", {})
	if not _can_afford(cost):
		_log("Not enough resources to build " + def.get("name", id) + ".", "warning")
		return false

	_spend(cost)
	_build_building(id, 1)

	# Population / moral fully from data "effects" + top level (100% data-driven, no id hardcodes)
	var eff: Dictionary = def.get("effects", {})
	var pop_gain: int = int(eff.get("pop", 0))
	if pop_gain > 0:
		if id == "haven":
			var current: int = buildings.get(id, 0)
			if current >= 5:
				pop_gain = 0
			elif current >= 3:
				pop_gain = 1
		if pop_gain > 0:
			population += pop_gain
			GameEvents.population_changed.emit(population, _get_free_pop(), pop_gain)

	var moral: float = float(def.get("moral_weight", 0.0))
	if moral != 0.0:
		set_alignment(alignment + moral, "built_" + id)

	# Use unlock_log if present (data-driven), else desc
	var build_name: String = def.get("name", id)
	var log_text: String = "You raise a " + build_name.to_lower() + ". " + str(def.get("desc", ""))
	if def.has("unlock_log"):
		log_text = str(def["unlock_log"])
	_log(log_text, "story")

	_check_unlocks()
	return true

func dispatch_expedition(path_id: String, choice: String = "auto") -> bool:
	# Phase 3/4: send the lost along veins/paths in the ash. Follows _try_build_building patterns exactly.
	if phase != "outlands":
		_log("The ash has not yet opened to such walks.", "warning")
		return false
	if not path_data.has(path_id):
		_log("Unknown path in the ash: " + path_id, "warning")
		return false
	if path_claims.get(path_id, false):
		_log("That vein is already bound to the circle.", "warning")
		return false
	# Prevent duplicate active
	for exp in active_expeditions:
		if exp.get("path_id", "") == path_id:
			_log("An expedition is already walking that vein.", "warning")
			return false

	var pdef: Dictionary = path_data[path_id]
	var cost: Dictionary = pdef.get("cost", {})
	if not _can_afford(cost):
		_log("Not enough to send the lost along " + pdef.get("name", path_id) + ".", "warning")
		return false

	# Spend resources (pop handled separate like haven pop pattern)
	_spend(cost)  # handles shards/res etc, ignores pop key safely? wait we filter? but _spend uses keys present in res
	var pop_cost: int = int(cost.get("population", 0))
	if pop_cost > 0:
		population = max(0, population - pop_cost)
		GameEvents.population_changed.emit(population, _get_free_pop(), -pop_cost)

	# Resolve choice at dispatch for auto (alignment bias at decision time)
	var actual_choice: String = choice
	if choice == "auto" or choice == "":
		actual_choice = _pick_expedition_choice(pdef)

	var travel: float = float(pdef.get("travel_time", 30))
	var eta: float = total_play_time + travel
	var expedition: Dictionary = {
		"path_id": path_id,
		"choice": actual_choice,
		"eta": eta,
		"departed_at": total_play_time,
	}
	active_expeditions.append(expedition)

	var p_name: String = pdef.get("name", path_id)
	# Log specific to chosen moral intent (makes different choices feel distinct on dispatch; uses label from data)
	var chosen_label: String = actual_choice
	for optt in pdef.get("moral_options", []):
		if str(optt.get("id", "")) == actual_choice:
			chosen_label = str(optt.get("label", actual_choice))
			break
	_log("The lost walk the " + p_name.to_lower() + " into the ash. Intent: " + chosen_label + ".", "story")

	GameEvents.action_performed.emit("dispatch_" + path_id, true)
	GameEvents.available_actions_changed.emit()
	_check_unlocks()
	# Trigger sfx via GameEvents for expedition dispatch (eta feel starts; "step into ash")
	GameEvents.sfx_cue.emit("expedition_dispatched", {"path_id": path_id, "choice": actual_choice})
	return true

func _pick_expedition_choice(pdef: Dictionary) -> String:
	# Auto choice biased by alignment: tyrant favors volume/risk (neg align), benevolent favors return/accord (pos)
	var options: Array = pdef.get("moral_options", [])
	if options.is_empty():
		return ""
	var best_id: String = ""
	var best_score: float = -999.0
	for opt in options:
		var opt_align: float = float(opt.get("alignment", 0.0))
		var score: float = opt_align
		if alignment < -0.2:
			# Tyrant: prefer more negative (risk/volume) — invert for selection
			score = -opt_align
		# else benevolent prefers positive as-is
		if score > best_score:
			best_score = score
			best_id = opt.get("id", "")
	return best_id if best_id != "" else (options[0].get("id", "") if not options.is_empty() else "")

func _resolve_expeditions() -> void:
	# Called from advance_time and after load if expeditions may have resolved offline.
	# Resolve updates UI via signals (available_actions_changed for actions list + time_advanced for outlands panel etas)
	if active_expeditions.is_empty():
		return
	var still_active: Array[Dictionary] = []
	var resolved_any: bool = false
	for exp in active_expeditions:
		if total_play_time >= float(exp.get("eta", 0.0)):
			_resolve_one_expedition(exp)
			resolved_any = true
		else:
			still_active.append(exp)
	active_expeditions.clear()
	for e in still_active:
		active_expeditions.append(e)
	if resolved_any:
		GameEvents.available_actions_changed.emit()

func _resolve_one_expedition(exp: Dictionary) -> void:
	var path_id: String = exp.get("path_id", "")
	if not path_data.has(path_id) or path_claims.get(path_id, false):
		return
	var pdef: Dictionary = path_data[path_id]
	var choice: String = exp.get("choice", "")
	var options: Array = pdef.get("moral_options", [])
	var option: Dictionary = {}
	for o in options:
		if str(o.get("id", "")) == choice:
			option = o
			break
	if option.is_empty() and not options.is_empty():
		# Fallback: re-bias by current alignment (rare, for loaded past)
		var best_score: float = -999.0
		for o in options:
			var oa: float = float(o.get("alignment", 0.0))
			var sc: float = oa if alignment >= -0.2 else -oa
			if sc > best_score:
				best_score = sc
				option = o

	var foraging_lines_count: int = int(buildings.get("foraging_lines", 0))
	var forager_count: int = int(assigned.get("forager", 0))
	var mult: float = 1.0 + (foraging_lines_count * 0.2) + (forager_count * 0.05)
	# align bias per plan: tyrant volume/risk (extra on harsh), benevolent on returns/safety
	if alignment < -0.3:
		mult += 0.12
	elif alignment > 0.3:
		mult += 0.08

	# Apply rewards using exact 120-121 pattern (with mult)
	var rewards: Dictionary = option.get("rewards", {})
	for r in rewards:
		var base_amt: float = float(rewards[r])
		var amt: float = base_amt * mult
		resources[r] = resources.get(r, 0.0) + amt
		GameEvents.resource_changed.emit(r, resources[r], amt)

	# Use the (previously unused) 'log' field from moral_options on resolve for outcome flavor (e.g. "They return carrying faint songs.")
	# Logged here so resolve carries the moral-specific return note; fulfills gap fix in plan.
	if option.has("log"):
		var olog: String = str(option.get("log", ""))
		if olog != "":
			_log(olog, "story")

	# Alignment shift + revelation log that MUST reframe prior actions (foraging, havens, demand) as complicity/claiming/binding
	var align_delta: float = float(option.get("alignment", 0.0))
	if abs(align_delta) > 0.001:
		set_alignment(alignment + align_delta, "expedition_" + path_id)
	var rev: String = str(option.get("revelation", pdef.get("revelation", "")))
	if rev != "":
		_log(rev, "revelation")

	# Pop return or loss logic (the lost who walked)
	var cost_dict: Dictionary = pdef.get("cost", {})
	var pop_sent: int = int(cost_dict.get("population", 0))
	var returned_pop: int = pop_sent
	var loss: int = 0
	if pop_sent > 0:
		if align_delta < -0.05 or (alignment < -0.4 and randf() < 0.5):
			loss = max(1, int(pop_sent * randf_range(0.3, 0.7)))
			returned_pop = max(0, pop_sent - loss)
		if returned_pop > 0:
			population += returned_pop
			GameEvents.population_changed.emit(population, _get_free_pop(), returned_pop)
		if loss > 0:
			# already accounted in returned, loss is permanent
			_log(str(loss) + " of the lost did not return from the vein. The ash keeps its due.", "warning")
		else:
			_log("Those who walked " + pdef.get("name", path_id).to_lower() + " return to the circle.", "story")

	# Mark claimed
	var was_first: bool = true
	for k in path_claims.keys():
		if path_claims[k]:
			was_first = false
			break
	path_claims[path_id] = true
	if was_first and "watch_spire" not in unlocked_buildings:
		_unlock_building("watch_spire")
		# unlock_log now logged immediately below via _check_unlocks (was deferred comment)

	# First bound special sfx sting via GameEvents (path claim "first bound" for new vein)
	if was_first:
		GameEvents.sfx_cue.emit("first_bound", {"path_id": path_id})

	# Pick up passive rates from this claim (and trigger any unlock logs like watch_spire immediately)
	_recalculate_rates()
	_check_unlocks()

	# Re-log return / dominion note (via Narrative for flavor)
	if NarrativeSystem:
		NarrativeSystem.trigger_revelation("The " + pdef.get("name", path_id).to_lower() + " is bound. What was foraged is now held.")
	else:
		_log("The " + pdef.get("name", path_id).to_lower() + " is bound. What was foraged is now held.", "revelation")

	# Polish: delayed gut-punch reframe that references the early choice explicitly.
	# This is the "oh no, I did this" moment — when the player has sent people out on paths, the game names the haven choice as the origin.
	_check_delayed_choice_reframe("path_claim", path_id)

	# sfx for resolve (use dispatch/resolve_expeditions hook); first_bound already emitted above if applicable
	GameEvents.sfx_cue.emit("expedition_resolved", {"path_id": path_id, "align_delta": align_delta})

func _check_delayed_choice_reframe(trigger: String, detail: String = "") -> void:
	# Called from resolve, phase advance, demand_more etc. Only fires once per major trigger if early choice exists.
	if early_choice == "" or flags.get("choice_reframe_fired_" + trigger, false):
		return
	# Support all documented polish hooks for delayed reframe (path on claim, first_outlands on phase, demand_after, and choice_made when outlands already reached on choice resolve)
	if trigger == "path_claim" or trigger == "first_outlands" or trigger == "demand_after" or trigger == "choice_made":
		flags["choice_reframe_fired_" + trigger] = true
		var mem: String = ""
		if NarrativeSystem:
			mem = NarrativeSystem.get_choice_reframe(early_choice)
		var base: String = "When the echoes first came to the havens, you chose what you chose. "
		if mem != "":
			base += mem + " "
		base += "Every vein you mark, every lost you send, follows the same shape. You have been doing this since the first circle closed around the ember."
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation(base)
		else:
			_log(base, "revelation")
		# Trigger specific sfx via GameEvents for key reframe moment (per task; "oh no" sting on delayed memory)
		GameEvents.sfx_cue.emit("reframe_sting", {"early_choice": early_choice, "trigger": trigger, "strength": 0.9})

func _resolve_early_choice(event_key: String, choice_id: String) -> bool:
	# Central handler for the polished early choice. Uses NarrativeSystem for effects + reframe memory.
	# Records early_choice + history so later reframes (in _resolve_one_expedition etc) can name the decision.
	if flags.get("incursion_handled", false):
		return false
	if not NarrativeSystem:
		_log("The ash is silent. No one answers the choice.", "warning")
		return false

	var ctx: Dictionary = _get_narrative_context()
	var effects: Dictionary = NarrativeSystem.apply_choice(choice_id, event_key, ctx)
	if not effects.get("applied", false):
		_log("The choice has no hold here.", "warning")
		return false

	# Pre-afford for choices that cost (shelter) — the prompt options describe cost, but enforce here like old perform path
	if choice_id == "shelter":
		var cost_shards: float = 20.0
		if resources.get("shards", 0.0) < cost_shards:
			_log("Not enough shards to open the havens to them.", "warning")
			return false
		# spend will be handled by the effects shards negative below

	# Apply mechanical results
	if effects.get("shards", 0.0) != 0.0:
		var sd: float = float(effects["shards"])
		resources["shards"] = resources.get("shards", 0.0) + sd
		GameEvents.resource_changed.emit("shards", resources["shards"], sd)
	if effects.get("pop_gain", 0) > 0:
		var pg: int = int(effects["pop_gain"])
		population += pg
		GameEvents.population_changed.emit(population, _get_free_pop(), pg)
	var ad: float = float(effects.get("align_delta", 0.0))
	if ad != 0.0:
		set_alignment(alignment + ad, "choice_" + choice_id)

	# Core flags + state
	flags["incursion_pending"] = false
	flags["incursion_handled"] = true
	for fk in effects.get("flags", {}):
		flags[fk] = true

	# Record for delayed reframes (the key to clean gut-punch)
	early_choice = choice_id
	choice_history.append({"event": event_key, "choice": choice_id, "time": total_play_time, "align": alignment})

	# Immediate reframe log from Narrative (the choice itself)
	var imm: String = str(effects.get("reframed_log", ""))
	if imm != "":
		_log(imm, "revelation")

	# If prior actions already taken (foragers, demand, paths), fire an immediate "you have been doing this" line
	var prior: bool = flags.get("demand_more_policy", false) or assigned.get("forager", 0) > 0 or flags.get("paths_in_ash_opened", false) or path_claims.size() > 0
	if prior:
		var mem: String = ""
		if NarrativeSystem:
			mem = NarrativeSystem.get_choice_reframe(choice_id)
		var extra: String = "These new Bound... you sent the previous ones out the same way. "
		if mem != "": extra += mem + " "
		extra += "The circle has always been claiming them. You did this."
		_log(extra, "revelation")

	# Also check for a delayed-style one right now if outlands already open (rare but possible on load)
	_check_delayed_choice_reframe("choice_made")

	GameEvents.choice_offered.emit(event_key)
	GameEvents.choice_resolved.emit(event_key, choice_id)

	return true

func _recalculate_rates() -> void:
	# Prototype: mix of hard-coded + data-driven from building_data
	rates["shards"] = 0.0
	rates["resonance"] = 0.0
	rates["vitalis"] = 0.0

	var foragers: int = int(assigned.get("forager", 0))
	rates["shards"] += 0.12 * foragers

	# Buildings contribute via their data definitions when present (100% from effects.rates in json)
	for b_id in buildings:
		var count: int = buildings[b_id]
		if count <= 0 or not building_data.has(b_id):
			continue
		var def: Dictionary = building_data[b_id]
		var eff: Dictionary = def.get("effects", {})
		var brates: Dictionary = eff.get("rates", {})
		for r in brates:
			rates[r] = rates.get(r, 0.0) + float(brates[r]) * count

	# Passive rates from claimed paths/veins (explicit implementation of prior TODO, simple + within MVP scope per subagent brief).
	# Gives expansion "Weight" a mechanical reward (small ongoing trickle), tying claimed outlands back into economy without new data fields.
	# Recalced on claim (in _resolve_one) and on load/assigns.
	var claimed_count: int = 0
	for k in path_claims:
		if path_claims[k]:
			claimed_count += 1
	if claimed_count > 0:
		rates["resonance"] = rates.get("resonance", 0.0) + 0.04 * claimed_count
		rates["vitalis"] = rates.get("vitalis", 0.0) + 0.02 * claimed_count

	# Apply current alignment mult later in advance_time

	for res in rates:
		GameEvents.rate_changed.emit(res, rates[res])

func _get_free_pop() -> int:
	var assigned_total: int = 0
	for c in assigned.values():
		assigned_total += c
	return max(0, population - assigned_total)

func _can_afford(cost: Dictionary) -> bool:
	# Extended for pop costs (e.g. expeditions) following haven pop handling pattern (277-282)
	for key in cost:
		if key == "population":
			if _get_free_pop() < int(cost[key]):
				return false
		elif resources.get(key, 0.0) < cost[key]:
			return false
	return true

func _spend(cost: Dictionary) -> void:
	# Safe for mixed costs (resources + "population" etc from path expeditions)
	for key in cost:
		if key in resources:
			resources[key] -= cost[key]
			GameEvents.resource_changed.emit(key, resources[key], -cost[key])
		# pop handled by caller (see dispatch_expedition, _try_build_building haven pattern)

func _unlock_building(id: String) -> void:
	if id not in unlocked_buildings:
		unlocked_buildings.append(id)
		GameEvents.building_unlocked.emit(id)
		GameEvents.available_actions_changed.emit()

# === Unlocks & Progression ===
func _check_unlocks() -> void:
	# Fully data-driven unlocks for buildings and actions (using shared _meets_unlock_reqs helper)
	# Buildings
	for b_id in building_data.keys():
		if b_id in unlocked_buildings:
			continue
		var def: Dictionary = building_data[b_id]
		var reqs: Dictionary = def.get("unlocks_at", {})
		var should_unlock: bool = _meets_unlock_reqs(reqs)

		# Watch spire still gated by first claim (business rule in data+code)
		if b_id == "watch_spire":
			var has_claim: bool = false
			for v in path_claims.values():
				if v:
					has_claim = true
					break
			if not has_claim:
				should_unlock = false

		if should_unlock:
			_unlock_building(b_id)
			var ulog: String = str(def.get("unlock_log", ""))
			if ulog != "":
				_log(ulog, "story")
			else:
				# fallback to desc if no specific unlock_log
				_log("You could now raise " + str(def.get("name", b_id)).to_lower() + ".", "story")

	# Actions (100% data-driven unlocks too, reuse unlocked_buildings list for compatibility with UI checks)
	for a_id in action_data.keys():
		if a_id in unlocked_buildings:
			continue
		var adef: Dictionary = action_data[a_id]
		var reqs: Dictionary = adef.get("unlocks_at", {})
		if _meets_unlock_reqs(reqs):
			unlocked_buildings.append(a_id)
			var ulog: String = str(adef.get("unlock_log", ""))
			if ulog != "":
				_log(ulog, "revelation")
			GameEvents.available_actions_changed.emit()  # so UI data-driven loop sees the new in unlocked_buildings immediately

	if population >= 1 and rates["shards"] < 0.1:
		# Make sure rates are set once we have people
		_recalculate_rates()

	# Proper early choice event for gut-punch: echo incursion when havens and pop sufficient (Phase 2)
	# Triggers the first real 'oh no, I did this' by forcing choice on 'new' lost, reframing prior 'help' (foraging, demand, havens)
	# Now delegated to dedicated method (see _check_early_choice_events)
	if not flags.get("incursion_triggered", false) and buildings.get("haven", 0) >= 1 and population >= 5:
		flags["incursion_triggered"] = true
		flags["incursion_pending"] = true
		if NarrativeSystem:
			var ctx: Dictionary = _get_narrative_context()
			var ev: Dictionary = NarrativeSystem.trigger_choice_event("echo_incursion", ctx)
			var p: String = str(ev.get("prompt", "An echo incursion approaches the havens..."))
			_log(p, "revelation")
		else:
			_log("An echo incursion approaches the havens. Broken figures from the ash, seeking the pulse. They are remnants, like the ones you foraged and sent before. What do you do with these new arrivals?", "revelation")

func _check_phase_advancement() -> void:
	if phase == "hearth" and population >= 4 and buildings.get("haven", 0) >= 1:
		phase = "village"
		GameEvents.phase_advanced.emit(phase)
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation("The pulse has become a circle of havens. More embers stir in the ash... or is it listening?")
		else:
			_log("The pulse has become a circle of havens. More embers stir in the ash... or is it listening?", "revelation")
		_unlock_building("foraging_lines")
		var fdef: Dictionary = building_data.get("foraging_lines", {})
		var ul: String = str(fdef.get("unlock_log", "The ash around the ember offers paths... and things that walk them."))
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation(ul)
		else:
			_log(ul, "revelation")

	# Outlands trigger (exact extension of village block pattern at original 385-390)
	if phase == "village" and buildings.get("foraging_lines", 0) > 0 and population >= 6 and resources.get("shards", 0.0) >= 50.0 and not flags.get("outlands_reached", false):
		phase = "outlands"
		flags["outlands_reached"] = true
		GameEvents.phase_advanced.emit(phase)
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation("The lines reach farther into the embers... The lost will walk them now.")
		else:
			_log("The lines reach farther into the embers... The lost will walk them now.", "revelation")
		discovered_paths.clear()
		# Data-driven discovery: any paths present in data/paths.json are seeded on first outlands entry.
		# (Implementation Order + "When adding..." followed: paths additions stay in data/paths.json; no hardcoded ids.)
		for pid in path_data:
			discovered_paths.append(pid)
		# Polish: fire the delayed choice reframe here so the gut-punch can land exactly when the map opens
		_check_delayed_choice_reframe("first_outlands")
		# Note: watch_spire unlock deferred to first path claim in resolution (per plan)

func _check_first_shard_hints() -> void:
	if resources["shards"] > 12 and not flags.get("saw_warm_scrap_hint", false):
		flags["saw_warm_scrap_hint"] = true
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation("Among the shards you sometimes find scraps of old cloth. Still warm. Not yours.")
		else:
			_log("Among the shards you sometimes find scraps of old cloth. Still warm. Not yours. Who were you before the ash?", "revelation")

# Polish: dedicated early choice event checker. Called every advance_time + after load/unlocks.
# Keeps the trigger condition (haven + pop) but centralizes the "proper" handling.
# The gut-punch is not the choice itself — it is the later reframe that names the choice as the origin of all later binding.
func _check_early_choice_events() -> void:
	if flags.get("incursion_pending", false) and not flags.get("incursion_handled", false):
		# Still waiting on player; UI will show the prompt (Main handles via flag)
		# We could auto-log a reminder here on low chance, but for clean landing we let the pending state drive UI
		pass
	# Future early choices can be added here with their own flags (e.g. "first_forager_choice")

# Helper for Narrative context (used by mutate + choice trigger)
func _get_narrative_context() -> Dictionary:
	if NarrativeSystem:
		return NarrativeSystem.get_current_context()
	# Fallback minimal
	return {
		"alignment": alignment,
		"phase": phase,
		"havens": buildings.get("haven", 0),
		"population": population,
		"foragers": assigned.get("forager", 0),
		"demand_more": flags.get("demand_more_policy", false),
		"incursion_handled": flags.get("incursion_handled", false),
		"paths_opened": flags.get("outlands_reached", false) or phase == "outlands",
		"early_choice": early_choice,
		"choice_history": choice_history,
	}

# === Events ===
func _trigger_unrest_event() -> void:
	if alignment > -0.4:
		_log("Murmurs among the lost. Someone didn't return from the ash.", "warning")
		population = max(1, population - 1)
		GameEvents.population_changed.emit(population, _get_free_pop(), -1)
	else:
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation("One of the lost does not return from the ash. No one speaks of it.")
		else:
			_log("One of the lost does not return from the ash. No one speaks of it.", "revelation")
		# Tyrant path sometimes gains from fear (dark)
		resources["shards"] += 2
		GameEvents.resource_changed.emit("shards", resources["shards"], 2)

func _trigger_path_raid() -> void:
	# Deepened for Phase 4 TD-lite start. Defense_strength (built by Defend action, decays, +watch_spire) now provides real mitigation + partial losses.
	# Reframes tie back to claims / early marks when paths have been opened. Emits signal for UI/sound reactions.
	_log("The ash moves along the old veins. The paths remember who marked them.", "warning")
	var foragers: int = int(assigned.get("forager", 0))
	var f_lines: int = int(buildings.get("foraging_lines", 0))
	var watch: int = int(buildings.get("watch_spire", 0))
	var time_since_defend: float = total_play_time - last_path_defense
	var def_val: float = defense_strength + (watch * 1.8) + (1.5 if time_since_defend < 75.0 else 0.0)
	var mitigated: bool = false
	var pop_loss: int = 0
	if def_val >= 2.5 or (def_val > 0.8 and randf() < (def_val / 5.0)):
		mitigated = true
	elif alignment > 0.2 and randf() < 0.5:
		mitigated = true
	if mitigated:
		_log("The circle holds against the raid from the ash. For now.", "story")
		if alignment > 0.0:
			set_alignment(alignment + 0.01, "defend_raid")
	else:
		pop_loss = 1
		if population > 5:
			pop_loss = 1 + int(min(3.0, float(population) / 8.0))
		# Partial mitigation from residual defense
		if def_val > 0.5:
			pop_loss = int(max(1.0, float(pop_loss) * (1.0 - clamp(def_val / 9.0, 0.0, 0.7))))
		population = max(1, population - pop_loss)
		GameEvents.population_changed.emit(population, _get_free_pop(), -pop_loss)
		# Small resource bite too
		var shard_loss: float = 4.0 + foragers * 0.8
		resources["shards"] = max(0.0, resources["shards"] - shard_loss)
		GameEvents.resource_changed.emit("shards", resources["shards"], -shard_loss)
		var rev: String = "The lost on the paths do not all return. Something in the ash took them."
		if path_claims.size() > 0 or phase == "outlands":
			rev = "Veins you claimed answer back. Not all who walked the lines return."
			if early_choice != "" and NarrativeSystem:
				# Use existing reframe hook if a specific one exists; otherwise the claim-tied line stands as the gut reminder.
				if NarrativeSystem.has_method("get_choice_reframe"):
					var r: String = NarrativeSystem.get_choice_reframe("raid_loss")
					if r != "":
						rev = r
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation(rev)
		else:
			_log(rev, "revelation")
	GameEvents.raid_occurred.emit(mitigated, pop_loss)

func _log(text: String, category: String = "story") -> void:
	if NarrativeSystem:
		# Use flavored (e.g. alignment mutations) for all logs
		GameEvents.log_message.emit( NarrativeSystem.get_flavored_text(text) , category)
	else:
		GameEvents.log_message.emit(text, category)
	if category == "revelation":
		# Trigger via GameEvents so gold logs (even direct _log) get revelation swell (covers all paths)
		GameEvents.sfx_cue.emit("revelation_swell", {"strength": 0.95})

# === Save / Load ===
func _load_or_init() -> void:
	# When playing the scene directly from the Godot editor (common for testing start screen),
	# always force a fresh game so you reliably see the initial darkness + "Nurture the Ember" button.
	# This prevents old saves (with advanced phase/ember) from hiding the starter action.
	# Normal runs / exported builds keep saves.
	if OS.has_feature("editor"):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save_auto.json")
			# also try backup if any
			dir.remove("save_auto.json.bak")

	last_played_unix = int(Time.get_unix_time_from_system())
	if not load_game():
		# Fresh start
		resources = {"shards": STARTING_SHARDS, "resonance": 0.0, "vitalis": 0.0}
		rates = {"shards": 0.0, "resonance": 0.0, "vitalis": 0.0}
		buildings = {}
		unlocked_buildings.clear()
		population = 0
		assigned = {}
		alignment = 0.0
		phase = "dark"
		flags = {}
		flags["incursion_pending"] = false
		flags["incursion_handled"] = false
		flags["incursion_triggered"] = false
		ember_pulse = 0.0
		cooldowns = {}
		# New path/outlands state defaults for fresh
		discovered_paths.clear()
		active_expeditions.clear()
		path_claims = {}
		last_path_defense = 0.0
		defense_strength = 0.0
		early_choice = ""
		choice_history.clear()
		# path_data populated by _load_paths_data, not reset here
		_log("You wake with a jolt. Your head throbs. Smoke stings your lungs. The ground is littered with embers — small glowing sparks scattered in the ash and debris. One brighter ember pulses near your hand, the strongest. You have no memory of how you got here.", "story")

	# Ensure newly added paths (from data/paths.json Phase 3/4 expansions) appear for saves that already reached outlands.
	# Keeps old progress intact while making location additions data-only (no code list updates needed after this).
	# Called here on load (fresh starts are dark, discovery seeds dynamically on phase advance using path_data.keys()).
	if phase == "outlands":
		for pid in path_data:
			if not (pid in discovered_paths):
				discovered_paths.append(pid)

	# Apply offline progress
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - last_played_unix
	if elapsed > 5 and last_played_unix > 0:
		var offline: int = int(min(elapsed, 60 * 60 * 8))  # cap at 8 hours for kindness
		advance_time(offline)
		_log("You return after some time. The embers are low but the work continued.", "system")

	_check_unlocks()  # ensure data-driven action unlocks (e.g. demand_more) after offline or fresh pop

	GameEvents.available_actions_changed.emit()

	last_played_unix = now
	save_game()

func save_game(slot: String = "auto") -> void:
	var save_data: Dictionary = {
		"version": 1,
		"resources": resources,
		"rates": rates,
		"buildings": buildings,
		"unlocked_buildings": unlocked_buildings,
		"population": population,
		"assigned": assigned,
		"alignment": alignment,
		"phase": phase,
		"flags": flags,
		"last_played_unix": last_played_unix,
		"total_play_time": total_play_time,
		"ember_pulse": ember_pulse,
		"cooldowns": cooldowns,
		# Phase 1+3+4 state
		"discovered_paths": discovered_paths,
		"active_expeditions": active_expeditions,
		"path_claims": path_claims,
		"last_path_defense": last_path_defense,
		"defense_strength": defense_strength,
		# Polish early choice state (for persistent delayed reframes across sessions)
		"early_choice": early_choice,
		"choice_history": choice_history,
		# path_data is always from data/paths.json on load, not persisted
	}
	var path: String = "user://save_%s.json" % slot
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func load_game(slot: String = "auto") -> bool:
	var path: String = "user://save_%s.json" % slot
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	var text: String = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	resources = data.get("resources", resources)
	rates = data.get("rates", rates)
	buildings = data.get("buildings", buildings)
	var _ub: Array = data.get("unlocked_buildings", [])
	unlocked_buildings.clear()
	if _ub is Array:
		for item in _ub:
			unlocked_buildings.append(str(item))
	population = data.get("population", population)
	assigned = data.get("assigned", assigned)
	alignment = data.get("alignment", alignment)
	phase = data.get("phase", phase)
	flags = data.get("flags", flags)
	last_played_unix = data.get("last_played_unix", last_played_unix)
	total_play_time = data.get("total_play_time", total_play_time)
	ember_pulse = data.get("ember_pulse", ember_pulse)
	cooldowns = data.get("cooldowns", {})
	# Restore new state vars (path_data reloaded via _load_paths_data in _ready)
	var _dp: Array = data.get("discovered_paths", [])
	discovered_paths.clear()
	if _dp is Array:
		for item in _dp:
			discovered_paths.append(str(item))
	var _ae: Array = data.get("active_expeditions", [])
	active_expeditions.clear()
	if _ae is Array:
		for item in _ae:
			active_expeditions.append(item)
	path_claims = data.get("path_claims", path_claims)
	last_path_defense = data.get("last_path_defense", last_path_defense)
	defense_strength = float(data.get("defense_strength", defense_strength))
	# Polish: restore choice memory so reframes survive reload/offline
	early_choice = data.get("early_choice", early_choice)
	choice_history.clear()
	var _ch: Array = data.get("choice_history", [])
	for item in _ch:
		choice_history.append(item)

	_recalculate_rates()
	GameEvents.available_actions_changed.emit()

	# Resolve expeditions that may have passed eta during offline (per plan)
	if not active_expeditions.is_empty():
		_resolve_expeditions()
	return true

func reset_to_new_game() -> void:
	# For testing / challenge runs
	var dir: DirAccess = DirAccess.open("user://")
	if dir:
		dir.remove("save_auto.json")
	# Clear new state vars to defaults before re-init (per plan)
	discovered_paths.clear()
	active_expeditions.clear()
	path_claims = {}
	last_path_defense = 0.0
	defense_strength = 0.0
	cooldowns = {}
	# Polish: clear choice memory on full reset
	early_choice = ""
	choice_history.clear()
	# Re-init (will call _load_paths_data + _load_or_init fresh)
	_ready()
