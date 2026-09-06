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

# Accelerated visual TD / production / faction phase (per approved plan)
var production_queue: Array[Dictionary] = []  # {id, type ("labor"|"spire"|...), eta, contrib}
var memory_entries: Array[Dictionary] = []  # {key, text, time, context} â€” tied to early_choice for Memory panel
var labor_boost: float = 0.0  # legacy compat from early labor queues (decays; new system uses production_labor + labor_assigned)

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
# R6 raid/defense encounter (player-facing; pending until resolve_raid_encounter)
var raid_data: Dictionary = {}  # loaded from data/raids.json
var pending_raid: Dictionary = {}  # snapshot while encounter UI is open

# Production queues labor (C&C flavor per approved plan): labor from completed halls auto/boost assigned to defense/expeditions (like foragers but from production)
var production_labor: float = 0.0
var labor_assigned: Dictionary = {}  # role -> amount e.g. "defense", "expedition" (unassigned portion still gives global contrib)
var build_speed_bonus: float = 0.0  # from spire_works etc; reduces eta of active/ new queues (C&C build speed feel)

# Simple Ash Whispers events system (tracks temporary theme-fitting events: random or on-load/"login", boosts, area-tied "echo" special encounters).
# "Dragon's Whispers" adapted creatively to ash/veins/ember/echoes to obey differentiation (no dragons/generic fantasy). Ties to areas (path ids) or ascends (phase advances).
var active_whispers: Dictionary = {}  # whisper_id -> { "type": "double_drops"|"echo_manifest"|"resonance_surge", "expires": float(total_play_time), "area": String (path or ""), "desc": String }


# R3 ending reckoning (nurture vs harvest + collapse lose)
var ending_data: Dictionary = {}  # loaded from data/endings.json
var game_ended: bool = false
var ending_id: String = ""
var ending_outcome: String = ""  # "win" | "lose"
var path_moral_nurture: int = 0  # listen/mend/positive path options
var path_moral_harvest: int = 0  # harvest/cut/claim/negative path options
const ENDING_CLAIM_THRESHOLD := 2  # veins claimed before reckoning can fire
# R5 NG+ meta: Memory shard carried across runs (persisted separately from save_auto)
var ng_plus_run: int = 0  # how many completed cycles have been carried
var memory_shard_active: bool = false  # true this run if a shard was applied at start
var memory_shard_last: Dictionary = {}  # last sealed/applied shard snapshot (runtime mirror of meta)
const MEMORY_SHARD_START_SHARDS := 3.0
const NG_PLUS_META_PATH := "user://ng_plus_meta.json"
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
	_load_endings_data()
	_load_raid_data()
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


func _load_endings_data() -> void:
	# R3: data-driven ending catalog (nurture win / harvest win / collapse lose)
	var path: String = "res://data/endings.json"
	if ResourceLoader.exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			ending_data = parsed
			print("[GameState] Loaded endings data: ", ending_data.keys())
			return
	ending_data = {}
	push_warning("Failed to load endings.json")

func _load_raid_data() -> void:
	# R6: player-facing raid/defense encounter definitions (data-driven responses)
	var file := FileAccess.open("res://data/raids.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			raid_data = parsed
			print("[GameState] Loaded raid data: ", raid_data.keys())
			return
	raid_data = {}
	print("[GameState] WARN: raids.json missing or invalid")

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
	if game_ended:
		return

	total_play_time += seconds

	# === Passive resource gain ===
	var mult: float = get_prod_mult()
	for res in rates:
		if rates[res] > 0:
			var gain: float = rates[res] * seconds * mult
			# Apply active Ash Whispers temp boosts (area-agnostic for global rates; whispers on specific veins can be extended)
			gain *= get_whisper_mult(res, "")
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

	# Accelerated: production queues (like expeditions, advanced on game time for speed/offline support)
	advance_production(seconds)

	# Production labor from queues (labor_hall etc): auto boost to defense over time (C&C "workers on the walls"), using assigned or total
	# (expands prior simple labor_boost; assigned like foragers but for production output; unassigned still contributes base)
	_apply_production_labor_boosts(seconds)

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

	# Ash Whispers: random + expiration checks (simple events)
	_check_whispers(seconds)

	GameEvents.time_advanced.emit(seconds)

	# Save occasionally
	if int(total_play_time) % 30 == 0:
		save_game()

	_check_ending_conditions("tick")

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
			"production_labor_gte":
				if production_labor < float(v):
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
			# Fire reframe immediately on first demand after the early choice â€” another vector for the punch
			_check_delayed_choice_reframe("demand_after")
			add_memory("demand_more", {})
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
	# Labor assignment from production (C&C: direct the output of halls/works; like forager assign but for queue labor)
	if effects.has("assign_labor"):
		var role: String = str(effects["assign_labor"])
		var delta: float = float(effects.get("delta", 1.0))
		assign_labor(role, delta)
		if effects.has("log"):
			var ltxt: String = str(effects["log"])
			var lcat: String = str(effects.get("log_category", "story"))
			_log(ltxt, lcat)
	# Production queue start (data-driven from new queue_* actions and building effects)
	if effects.has("start_production"):
		start_production(str(effects["start_production"]))
	# Special call for hints etc (for gather)
	if effects.has("call_hint"):
		if effects["call_hint"] == "check_first_shard_hints":
			_check_first_shard_hints()

# === Actions (called by UI buttons) ===
func perform_action(action_id: String) -> bool:
	if game_ended:
		return false
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
			# Tyrant: prefer more negative (risk/volume) â€” invert for selection
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
	# Production labor from queues (labor_hall etc) boosts expeditions (similar to foragers but production output; assigned or total)
	var exp_labor: float = float(labor_assigned.get("expedition", 0.0))
	if exp_labor > 0.0:
		mult += exp_labor * 0.08
	elif production_labor > 0.0:
		mult += production_labor * 0.015  # base unassigned labor trickle
	if flags.has("expedition_bonus"):
		mult += float(flags.get("expedition_bonus", 0.0))
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

	# Accelerated: Memory entry for the claim (ties the visual "binding" on map to the player's specific early_choice)
	add_memory("path_claim_" + path_id, {"path": path_id, "choice": choice, "moral": option.get("id", "")})

	# Polish: delayed gut-punch reframe that references the early choice explicitly.
	# This is the "oh no, I did this" moment â€” when the player has sent people out on paths, the game names the haven choice as the origin.
	_check_delayed_choice_reframe("path_claim", path_id)

	# R3: tally nurture vs harvest moral from this claim, then check ending reckoning
	_tally_path_moral(str(option.get("id", choice)), float(option.get("alignment", 0.0)))
	choice_history.append({"event": "path_claim", "choice": str(option.get("id", choice)), "path": path_id, "time": total_play_time, "align": alignment})
	_check_ending_conditions("path_claim")

	# sfx for resolve (use dispatch/resolve_expeditions hook); first_bound already emitted above if applicable
	GameEvents.sfx_cue.emit("expedition_resolved", {"path_id": path_id, "align_delta": align_delta})

func _check_delayed_choice_reframe(trigger: String, detail: String = "") -> void:
	# Called from resolve, phase advance, demand_more etc. Only fires once per major trigger if early choice exists.
	if early_choice == "" or flags.get("choice_reframe_fired_" + trigger, false):
		return
	# Support all documented polish hooks for delayed reframe (path on claim, first_outlands on phase, demand_after, and choice_made when outlands already reached on choice resolve)
	if trigger == "path_claim" or trigger == "first_outlands" or trigger == "demand_after" or trigger == "choice_made" or trigger == "production_built":
		flags["choice_reframe_fired_" + trigger] = true
		add_memory("delayed_reframe_" + trigger, {"detail": detail, "early_choice": early_choice})
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

	# Pre-afford for choices that cost (shelter) â€” the prompt options describe cost, but enforce here like old perform path
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

	# Persist into Memory panel (apply_choice returns memory text; without this Memory stays empty until production)
	var mem_text: String = str(effects.get("memory", ""))
	if mem_text == "" and NarrativeSystem:
		mem_text = NarrativeSystem.get_choice_reframe(choice_id)
	add_memory("early_choice_" + choice_id, {"event": event_key, "choice": choice_id, "memory": mem_text})

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

	# Production labor boosts (from queues/labor_hall etc): global trickle + assigned directed (update _recalculate when assign/complete)
	if production_labor > 0.0:
		var pbase: float = production_labor * 0.012
		rates["shards"] = rates.get("shards", 0.0) + pbase
		rates["resonance"] = rates.get("resonance", 0.0) + pbase * 0.6
		# assigned "production" role if any would add more, but defense/exp directed elsewhere

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
		# R4: faction-gated buildings (data "require") write Memory when they unlock naturally
		if building_data.has(id) and building_data[id].has("require"):
			add_memory("faction_unlock_" + id, {"building": id, "require": building_data[id]["require"]})

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
			# Faction gate for accelerated buildings (data "require" on align/early_choice)
			if def.has("require") and not meets_faction_requirements(def["require"]):
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
		add_memory("first_outlands", {})
		# Ash Whisper on "ascend" to outlands (creative tie to areas/ascends per task)
		if randf() < 0.45:
			trigger_ash_whisper("ascend")
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
# The gut-punch is not the choice itself â€” it is the later reframe that names the choice as the origin of all later binding.
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

# === Simple Ash Whispers events system (random or "login"/load-based; temp boosts e.g. double drops 10min game time; special echo "mob" for rare gear/vitalis) ===
# Creative tie: prefers active path areas (veins) when outlands/claims; also on phase ascends ("ascend" the dominion/weight).
# All text uses ash/vein/echo/ember language per differentiation. Adds memory/reframe hook on trigger/resolve.
func _check_whispers(delta_seconds: float = 0.0) -> void:
	# Expire finished whispers (use game time for speed/offline respect)
	var now_t: float = total_play_time
	var expired: Array = []
	for wid in active_whispers.keys():
		var w: Dictionary = active_whispers[wid]
		if now_t >= float(w.get("expires", 0.0)):
			_resolve_whisper(wid)
			expired.append(wid)
	for wid in expired:
		active_whispers.erase(wid)

	# Periodic random trigger chance (low, only in outlands+ with activity; "random" events)
	if phase == "outlands" and population > 2 and active_whispers.is_empty() and randf() < (0.0015 * (delta_seconds / _tick_interval)):
		trigger_ash_whisper("random")

func _login_whisper_check() -> void:
	# "login-based": on load or session start (after offline calc), small chance of a lingering whisper from the ash.
	# Ties to prior play (claims or time) for "the ash remembers your last steps".
	if active_whispers.size() > 0:
		return
	if phase != "outlands" or total_play_time < 120.0:
		return
	if randf() < 0.28:  # ~28% chance on qualifying loads for a "whisper since you were last here"
		trigger_ash_whisper("login")

func trigger_ash_whisper(source: String = "random") -> void:
	# Core logic: pick type and optional area (tie to paths/areas or "ascend" context)
	if active_whispers.size() >= 2:
		return  # limit concurrent simple
	var types: Array = ["double_drops", "resonance_surge", "echo_manifest"]
	var wtype: String = types[randi() % types.size()]
	var area: String = ""
	# Creative area tie: if paths claimed, pick one for the whisper to "echo from that vein"
	if not path_claims.is_empty():
		var claimed: Array = []
		for p in path_claims:
			if path_claims[p]:
				claimed.append(p)
		if not claimed.is_empty():
			area = claimed[randi() % claimed.size()]
	elif not discovered_paths.is_empty():
		area = discovered_paths[randi() % discovered_paths.size()]

	# Ascend tie: if recent phase advance context or high alignment "weight", bias type
	if source == "ascend" or (phase == "outlands" and alignment > 0.4):
		if randf() < 0.6:
			wtype = "resonance_surge"  # benevolent-leaning surge on "ascend"

	var wid: String = "ash_whisper_" + str(int(total_play_time)) + "_" + wtype
	var duration: float = 600.0  # 10 game minutes
	var expires: float = total_play_time + duration
	var desc: String = ""
	match wtype:
		"double_drops":
			desc = "A vein surges with old warmth. Shards come easier for a time." + ("" if area == "" else " (" + _get_path_name(area) + ")")
		"resonance_surge":
			desc = "The ash hums an old resonance. Echoes answer more readily." + ("" if area == "" else " From " + _get_path_name(area) + ".")
		"echo_manifest":
			desc = "Something in the ash takes form along the old lines â€” a resonant echo. Rare remnants may surface." + ("" if area == "" else " (" + _get_path_name(area) + ")")
			# Special "mob"/encounter flavor: on resolve will yield rare vitalis "gear"

	active_whispers[wid] = {
		"type": wtype,
		"expires": expires,
		"area": area,
		"desc": desc,
		"source": source
	}

	# Narrative + state tracking: log, signal UI, memory entry (advances reframe like other events)
	_log(desc, "revelation")
	GameEvents.whisper_triggered.emit(wid, desc)
	if area != "":
		# Tie memory to specific area claim history
		add_memory("ash_whisper_" + wtype, {"area": area, "type": wtype})
	else:
		add_memory("ash_whisper_" + wtype, {"type": wtype})
	# Small alignment nudge on some (echoes remember your weight)
	if wtype == "echo_manifest" and alignment < 0.0:
		set_alignment(alignment + 0.02, "whisper_echo")

func _resolve_whisper(wid: String) -> void:
	if not active_whispers.has(wid):
		return
	var w: Dictionary = active_whispers[wid]
	var wtype: String = str(w.get("type", ""))
	var area: String = str(w.get("area", ""))
	var resolved: String = ""
	match wtype:
		"double_drops":
			resolved = "The surge fades. The ash settles, but the memory of easier shards lingers."
		"resonance_surge":
			resolved = "The hum quiets. Resonance still faintly clings to the veins."
		"echo_manifest":
			# Special mob resolved: grant rare "gear" (vitalis burst) + possible small cost or gift per moral weight
			var bonus: float = 8.0 + randf() * 6.0
			resources["vitalis"] = resources.get("vitalis", 0.0) + bonus
			GameEvents.resource_changed.emit("vitalis", resources["vitalis"], bonus)
			resolved = "The echo fades into the ash, leaving rare remnants (vitalis)." 
			if area != "" and randf() < 0.4:
				# "mob" interaction flavor: slight pop risk or gain based on align (creative)
				if alignment < -0.3:
					var pl: int = 1
					population = max(1, population - pl)
					GameEvents.population_changed.emit(population, _get_free_pop(), -pl)
					resolved += " One of the Bound did not return unchanged."
				else:
					resolved += " The circle holds a little more tightly for it."
			add_memory("echo_manifest_resolved", {"area": area, "vitalis": bonus})
	GameEvents.whisper_expired.emit(wid, resolved)
	if resolved != "":
		_log(resolved, "story")

func _get_path_name(pid: String) -> String:
	if path_data.has(pid):
		return str(path_data[pid].get("name", pid))
	return pid

func get_active_whispers() -> Dictionary:
	return active_whispers.duplicate(true)

func get_whisper_mult(resource: String, for_area: String = "") -> float:
	# Used by advance_time / economy to apply temp boosts from active whispers (e.g. double drops)
	var m: float = 1.0
	for wid in active_whispers:
		var w: Dictionary = active_whispers[wid]
		if float(w.get("expires", 0)) <= total_play_time:
			continue
		var wt: String = str(w.get("type", ""))
		var wa: String = str(w.get("area", ""))
		if for_area != "" and wa != "" and wa != for_area:
			continue  # area-specific whispers only affect their vein if specified
		if wt == "double_drops" and resource == "shards":
			m *= 2.0
		elif wt == "resonance_surge" and resource == "resonance":
			m *= 1.6
	return m

func _trigger_path_raid() -> void:
	# R6: offer a player-facing encounter instead of silently auto-resolving.
	# Random ticks skip if an encounter is already pending.
	if game_ended:
		return
	if not pending_raid.is_empty():
		return
	offer_raid_encounter()

func offer_raid_encounter(path_id: String = "") -> bool:
	# Build pending encounter snapshot from raid_data + current defense. Returns true if offered.
	if game_ended:
		return false
	if not pending_raid.is_empty():
		return false
	if raid_data.is_empty():
		_load_raid_data()
	var defn: Dictionary = raid_data.get("path_raid", {})
	if defn.is_empty():
		# Fallback: keep old auto-resolve behavior if data missing
		_resolve_raid_auto()
		return false
	var pid: String = path_id
	if pid == "" or (not path_claims.has(pid) and not discovered_paths.has(pid)):
		# Prefer a claimed vein; else any discovered; else empty
		pid = ""
		for cpid in path_claims.keys():
			if bool(path_claims.get(cpid, false)):
				pid = str(cpid)
				break
		if pid == "" and discovered_paths.size() > 0:
			pid = str(discovered_paths[0])
	var foragers: int = int(assigned.get("forager", 0))
	var watch: int = int(buildings.get("watch_spire", 0))
	var time_since_defend: float = total_play_time - last_path_defense
	var def_val: float = defense_strength + (watch * 1.8) + (1.5 if time_since_defend < 75.0 else 0.0)
	pending_raid = {
		"raid_id": "path_raid",
		"path_id": pid,
		"def_val": def_val,
		"foragers": foragers,
		"offered_at": total_play_time,
		"title": str(defn.get("title", "Ash Along the Veins")),
		"prompt": str(defn.get("prompt", "The ash moves along the old veins.")),
		"options": defn.get("options", []).duplicate(true) if typeof(defn.get("options", [])) == TYPE_ARRAY else [],
	}
	_log("The ash moves along the old veins. The paths remember who marked them. Watchers await orders.", "warning")
	GameEvents.raid_encounter_offered.emit("path_raid")
	return true

func get_pending_raid() -> Dictionary:
	return pending_raid.duplicate(true)

func has_pending_raid() -> bool:
	return not pending_raid.is_empty()

func resolve_raid_encounter(choice_id: String) -> Dictionary:
	# Apply data-driven response, then resolve mitigation / losses. Clears pending_raid.
	var result: Dictionary = {"ok": false, "mitigated": false, "pop_loss": 0, "choice_id": choice_id}
	if pending_raid.is_empty():
		return result
	if game_ended:
		pending_raid.clear()
		return result
	var snap: Dictionary = pending_raid.duplicate(true)
	var raid_id: String = str(snap.get("raid_id", "path_raid"))
	var def_val: float = float(snap.get("def_val", defense_strength))
	var foragers: int = int(snap.get("foragers", assigned.get("forager", 0)))
	var opt: Dictionary = {}
	var opts = snap.get("options", [])
	if typeof(opts) == TYPE_ARRAY:
		for o in opts:
			if str(o.get("id", "")) == choice_id:
				opt = o
				break
	if opt.is_empty() and raid_data.has(raid_id):
		var dopts = raid_data[raid_id].get("options", [])
		if typeof(dopts) == TYPE_ARRAY:
			for o in dopts:
				if str(o.get("id", "")) == choice_id:
					opt = o
					break
	if opt.is_empty():
		_log("No clear order reaches the watchers.", "warning")
		return result

	# Pay cost (shards etc.)
	var cost: Dictionary = opt.get("cost", {})
	if typeof(cost) == TYPE_DICTIONARY:
		for res_name in cost.keys():
			var need: float = float(cost[res_name])
			if float(resources.get(res_name, 0.0)) < need:
				_log("Not enough " + str(res_name) + " to answer the raid that way.", "warning")
				return result
		for res_name in cost.keys():
			var need2: float = float(cost[res_name])
			resources[res_name] = float(resources.get(res_name, 0.0)) - need2
			GameEvents.resource_changed.emit(str(res_name), resources[res_name], -need2)

	var effects: Dictionary = opt.get("effects", {})
	if typeof(effects) != TYPE_DICTIONARY:
		effects = {}

	# Apply pre-resolution effect modifiers
	if effects.has("use_defense"):
		var used: float = float(effects["use_defense"])
		defense_strength = max(0.0, defense_strength - used)
		def_val = max(0.0, def_val - used * 0.35)  # committed watch still helps this fight
		last_path_defense = total_play_time
	if effects.has("add_defense"):
		defense_strength = min(12.0, defense_strength + float(effects["add_defense"]))
	if effects.has("raid_retaliation_add"):
		flags["raid_retaliation"] = float(flags.get("raid_retaliation", 0.0)) + float(effects["raid_retaliation_add"])
	if effects.has("align_delta"):
		set_alignment(alignment + float(effects["align_delta"]), "raid_" + choice_id)
	if effects.has("log"):
		_log(str(effects["log"]), str(effects.get("log_category", "story")))

	var force_mitigated: bool = bool(effects.get("force_mitigated", false))
	var force_loss: bool = bool(effects.get("force_loss", false))
	var mit_bonus: float = float(effects.get("mitigation_bonus", 0.0))
	var mit_pen: float = float(effects.get("mitigation_penalty", 0.0))
	var effective_def: float = def_val + mit_bonus * 5.0 - mit_pen * 4.0

	var mitigated: bool = false
	var pop_loss: int = 0
	if force_mitigated:
		mitigated = true
	elif force_loss:
		mitigated = false
	elif effective_def >= 2.5 or (effective_def > 0.8 and randf() < (effective_def / 5.0)):
		mitigated = true
	elif alignment > 0.2 and randf() < 0.5:
		mitigated = true

	if mitigated:
		_log("The circle holds against the raid from the ash. For now.", "story")
		if alignment > 0.0 and not force_mitigated:
			set_alignment(alignment + 0.01, "defend_raid")
		if effects.has("shards_on_mitigated"):
			var gain: float = float(effects["shards_on_mitigated"])
			resources["shards"] = float(resources.get("shards", 0.0)) + gain
			GameEvents.resource_changed.emit("shards", resources["shards"], gain)
	else:
		pop_loss = 1
		if population > 5:
			pop_loss = 1 + int(min(3.0, float(population) / 8.0))
		if effective_def > 0.5 and not force_loss:
			pop_loss = int(max(1.0, float(pop_loss) * (1.0 - clamp(effective_def / 9.0, 0.0, 0.7))))
		var loss_red: float = float(flags.get("loss_reduction", 0.0))
		if loss_red > 0.0:
			pop_loss = int(max(0.0, float(pop_loss) * (1.0 - min(0.6, loss_red))))
		var retal: float = float(flags.get("raid_retaliation", 0.0))
		if retal > 0.0:
			pop_loss = int(pop_loss * (1.0 + min(0.8, retal * 2.0)))
		if effects.has("pop_loss_bonus"):
			pop_loss += int(effects["pop_loss_bonus"])
		population = max(1, population - pop_loss) if population > 0 else 0
		if population == 0 and pop_loss > 0:
			population = 0
		GameEvents.population_changed.emit(population, _get_free_pop(), -pop_loss)
		var shard_loss: float = 4.0 + foragers * 0.8
		resources["shards"] = max(0.0, float(resources.get("shards", 0.0)) - shard_loss)
		GameEvents.resource_changed.emit("shards", resources["shards"], -shard_loss)
		var rev: String = "The lost on the paths do not all return. Something in the ash took them."
		if path_claims.size() > 0 or phase == "outlands":
			rev = "Veins you claimed answer back. Not all who walked the lines return."
			if early_choice != "" and NarrativeSystem and NarrativeSystem.has_method("get_choice_reframe"):
				var r: String = NarrativeSystem.get_choice_reframe("raid_loss")
				if r != "":
					rev = r
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation(rev)
		else:
			_log(rev, "revelation")
		if pop_loss > 0:
			add_memory("raid_loss", {"pop_loss": pop_loss, "def_val": effective_def, "choice_id": choice_id})

	# Memory for the response itself (always)
	var mem_key: String = str(effects.get("memory_key", "raid_response_" + choice_id))
	add_memory(mem_key, {
		"choice_id": choice_id,
		"mitigated": mitigated,
		"pop_loss": pop_loss,
		"path_id": str(snap.get("path_id", "")),
		"def_val": effective_def,
	})

	pending_raid.clear()
	result["ok"] = true
	result["mitigated"] = mitigated
	result["pop_loss"] = pop_loss
	GameEvents.raid_encounter_resolved.emit(raid_id, choice_id)
	GameEvents.raid_occurred.emit(mitigated, pop_loss)
	_check_ending_conditions("raid")
	return result

func _resolve_raid_auto() -> void:
	# Legacy/fallback auto-resolve when raids.json missing (keeps headless/old paths safe).
	_log("The ash moves along the old veins. The paths remember who marked them.", "warning")
	var foragers: int = int(assigned.get("forager", 0))
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
		if def_val > 0.5:
			pop_loss = int(max(1.0, float(pop_loss) * (1.0 - clamp(def_val / 9.0, 0.0, 0.7))))
		var loss_red: float = float(flags.get("loss_reduction", 0.0))
		if loss_red > 0.0:
			pop_loss = int(max(0.0, float(pop_loss) * (1.0 - min(0.6, loss_red))))
		var retal: float = float(flags.get("raid_retaliation", 0.0))
		if retal > 0.0:
			pop_loss = int(pop_loss * (1.0 + min(0.8, retal * 2.0)))
		population = max(1, population - pop_loss)
		GameEvents.population_changed.emit(population, _get_free_pop(), -pop_loss)
		var shard_loss: float = 4.0 + foragers * 0.8
		resources["shards"] = max(0.0, resources["shards"] - shard_loss)
		GameEvents.resource_changed.emit("shards", resources["shards"], -shard_loss)
		var rev: String = "The lost on the paths do not all return. Something in the ash took them."
		if path_claims.size() > 0 or phase == "outlands":
			rev = "Veins you claimed answer back. Not all who walked the lines return."
			if early_choice != "" and NarrativeSystem and NarrativeSystem.has_method("get_choice_reframe"):
				var r: String = NarrativeSystem.get_choice_reframe("raid_loss")
				if r != "":
					rev = r
		if NarrativeSystem:
			NarrativeSystem.trigger_revelation(rev)
		else:
			_log(rev, "revelation")
		if not mitigated and pop_loss > 0:
			add_memory("raid_loss", {"pop_loss": pop_loss, "def_val": def_val})
	GameEvents.raid_occurred.emit(mitigated, pop_loss)
	_check_ending_conditions("raid")

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
		game_ended = false
		ending_id = ""
		ending_outcome = ""
		path_moral_nurture = 0
		path_moral_harvest = 0
		production_queue.clear()
		memory_entries.clear()
		production_labor = 0.0
		labor_assigned.clear()
		build_speed_bonus = 0.0
		labor_boost = 0.0
		active_whispers.clear()
		# path_data populated by _load_paths_data, not reset here
		_log("You wake with a jolt. Your head throbs. Smoke stings your lungs. The ground is littered with embers â€” small glowing sparks scattered in the ash and debris. One brighter ember pulses near your hand, the strongest. You have no memory of how you got here.", "story")
		_apply_memory_shard_carry()

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

	# Login-based Ash Whisper check (after offline catch-up so "the ash has had time to murmur")
	_login_whisper_check()

	_check_unlocks()  # ensure data-driven action unlocks (e.g. demand_more) after offline or fresh pop

	GameEvents.available_actions_changed.emit()

	last_played_unix = now
	save_game()

# === Accelerated Phase Helpers (production queues, faction filtering, Memory ledger, map support) ===
# All generic / data-driven per approved plan and SKILL patterns. Every addition must advance reframe + Memory.

func start_production(building_id: String) -> bool:
	if not building_data.has(building_id):
		_log("Unknown production target: " + building_id, "warning")
		return false
	var def: Dictionary = building_data[building_id]
	if not def.has("effects") or not def["effects"].has("queue_type"):
		_log("Building does not support production queue: " + building_id, "warning")
		return false
	var eff: Dictionary = def["effects"]
	var qtype: String = str(eff.get("queue_type", ""))
	var qtime: float = float(eff.get("queue_time", 60.0))
	# Simple faction gate (data "require" on the building)
	if def.has("require") and not meets_faction_requirements(def["require"]):
		_log("The ash does not offer this work to one who has shaped their will this way.", "warning")
		return false
	# C&C build_speed: apply current bonus from completed spire_works etc to this queue's time (reduce eta)
	var effective_qtime: float = qtime * (1.0 - build_speed_bonus)
	if effective_qtime < 5.0:
		effective_qtime = 5.0
	var eta: float = total_play_time + effective_qtime
	production_queue.append({
		"id": building_id,
		"type": qtype,
		"eta": eta,
		"started_at": total_play_time,
		"base_time": qtime
	})
	_log("You set the work in motion at the " + def.get("name", building_id) + ". It will be some time.", "story")
	# Memory entry for queue start (C&C orders feel, shows in Memory panel as progress marker)
	add_memory("production_queued_" + building_id, {"building": building_id, "type": qtype, "eta": eta})
	GameEvents.action_performed.emit("queue_" + building_id, true)
	GameEvents.available_actions_changed.emit()
	return true

func advance_production(seconds: float) -> void:
	if production_queue.is_empty():
		return
	var still_active: Array[Dictionary] = []
	var completed_any: bool = false
	for q in production_queue:
		if total_play_time >= float(q.get("eta", 0.0)):
			_complete_production(q)
			completed_any = true
		else:
			still_active.append(q)
	production_queue.clear()
	for q in still_active:
		production_queue.append(q)
	if completed_any:
		GameEvents.available_actions_changed.emit()

# Apply C&C build speed retroactively to remaining queues (called when spire_works etc complete and raise bonus)
func _apply_build_speed_to_queues(delta_bonus: float) -> void:
	if delta_bonus <= 0.0 or production_queue.is_empty():
		return
	build_speed_bonus = min(0.75, build_speed_bonus + delta_bonus)
	for q in production_queue:
		var eta: float = float(q.get("eta", total_play_time))
		var rem: float = max(5.0, eta - total_play_time)
		var new_rem: float = rem * (1.0 - delta_bonus)
		q["eta"] = total_play_time + new_rem

# Labor assignment (like foragers, but from production queue output of labor_hall etc). Auto on complete; manual via effects/actions.
func _get_total_assigned_labor() -> float:
	var tot: float = 0.0
	for v in labor_assigned.values():
		tot += float(v)
	return tot

func assign_labor(role: String, delta: float) -> void:
	if production_labor <= 0.0:
		return
	var total_ass: float = _get_total_assigned_labor()
	if delta > 0.0:
		var avail: float = production_labor - total_ass
		if avail <= 0.0:
			return
		delta = min(delta, avail)
	else:
		var curr: float = float(labor_assigned.get(role, 0.0))
		delta = max(delta, -curr)
	labor_assigned[role] = max(0.0, float(labor_assigned.get(role, 0.0)) + delta)
	_recalculate_rates()
	# Reuse pop signal for UI refresh (labor is separate but triggers status/actions)
	GameEvents.population_changed.emit(population, _get_free_pop(), 0)
	# Memory for labor direction (C&C choice visible in panel, reframes prior haven/claim)
	add_memory("labor_assigned_" + role, {"role": role, "delta": delta})

func _auto_assign_labor(gain: float) -> void:
	# Auto-assign new labor from queue complete (per plan: auto in advance based on queues; player can reassign via actions)
	if gain <= 0.0:
		return
	var def_share: float = gain * 0.65
	var exp_share: float = gain * 0.35
	labor_assigned["defense"] = float(labor_assigned.get("defense", 0.0)) + def_share
	labor_assigned["expedition"] = float(labor_assigned.get("expedition", 0.0)) + exp_share
	_recalculate_rates()

func _apply_production_labor_boosts(seconds: float) -> void:
	if production_labor <= 0.0:
		return
	# Base from total labor (ongoing "production" hands working), plus directed from assigned (player or auto)
	var base_labor: float = production_labor * 0.5
	var def_labor: float = base_labor + float(labor_assigned.get("defense", 0.0))
	if def_labor > 0.0:
		var dboost: float = def_labor * 0.006 * (seconds / _tick_interval)
		defense_strength = min(18.0, defense_strength + dboost)
	# Note: expedition labor boosts applied at resolve time (mult); also used in get_vein_defense etc.
	# Decay any legacy labor_boost for compat (will fade); main labor now in production_labor/labor_assigned from queues
	if labor_boost > 0.0:
		labor_boost = max(0.0, labor_boost - 0.008 * seconds)

func _complete_production(q: Dictionary) -> void:
	var bid: String = str(q.get("id", ""))
	if not building_data.has(bid):
		return
	var def: Dictionary = building_data[bid]
	var eff: Dictionary = def.get("effects", {})
	var qtype: String = str(eff.get("queue_type", ""))
	var was_built: bool = buildings.get(bid, 0) > 0
	# Ensure the production facility counts as built (increments for map visuals, faction checks like dread in OutlandsMap, etc.)
	# Queue action pays the "construction" cost+time; this makes buildings.get("dread_foundry") etc true after first complete.
	if not was_built:
		_build_building(bid, 1)
	# Apply effects (boost defense, expedition returns, etc.) + actual labor tracking + C&C + faction branching
	if qtype == "labor" or bid == "labor_hall":
		var labor_gain: float = float(eff.get("labor_output", eff.get("boost_defense", 2.0) * 1.5))
		production_labor += labor_gain
		_auto_assign_labor(labor_gain)
		if eff.has("boost_defense"):
			defense_strength = min(12.0, defense_strength + float(eff["boost_defense"]))
		if eff.has("boost_expedition"):
			labor_assigned["expedition"] = float(labor_assigned.get("expedition", 0.0)) + float(eff["boost_expedition"])
	elif qtype == "spire" or bid == "spire_works":
		if eff.has("build_speed"):
			var spd: float = float(eff["build_speed"])
			_apply_build_speed_to_queues(spd)
		if eff.has("defense"):
			defense_strength = min(12.0, defense_strength + float(eff["defense"]))
	elif qtype == "aggressive_defense" or bid == "dread_foundry":
		# Faction integrate: tyrant-specific on complete (higher defense output but raid_retaliation risk per plan)
		var def_add: float = float(eff.get("defense", 0.0))
		if def_add > 0:
			defense_strength = min(15.0, defense_strength + def_add * 1.15)  # aggressive more
		if eff.has("raid_retaliation"):
			var ret: float = float(eff["raid_retaliation"])
			flags["raid_retaliation"] = float(flags.get("raid_retaliation", 0.0)) + ret
		if eff.has("build_speed"):
			_apply_build_speed_to_queues(float(eff["build_speed"]))
	elif qtype == "protective" or bid == "sanctuary_ward":
		# Faction: sanctuary loss_reduction (benevolent)
		if eff.has("defense"):
			defense_strength = min(12.0, defense_strength + float(eff["defense"]))
		if eff.has("loss_reduction"):
			flags["loss_reduction"] = float(flags.get("loss_reduction", 0.0)) + float(eff["loss_reduction"])
	elif qtype == "resonance" or bid == "resonance_spire":
		# Benevolent resonance: labor + expedition return flavor + small defense
		var labor_gain: float = float(eff.get("labor_output", 1.5))
		production_labor += labor_gain
		_auto_assign_labor(labor_gain * 0.5)
		if eff.has("boost_resonance"):
			# Apply as rate bonus via recalculate or flag for resolve; here simple labor + defense
			defense_strength = min(12.0, defense_strength + 0.5)
		if eff.has("expedition_return"):
			flags["expedition_bonus"] = float(flags.get("expedition_bonus", 0.0)) + float(eff["expedition_return"])
		if eff.has("defense"):
			defense_strength = min(12.0, defense_strength + float(eff["defense"]))
	elif qtype == "extract" or bid == "will_press":
		# Tyrant extract: high labor + immediate shards on complete, retaliation
		var labor_gain: float = float(eff.get("labor_output", 2.5))
		production_labor += labor_gain
		_auto_assign_labor(labor_gain * 0.3)
		if eff.has("shards_on_complete"):
			resources["shards"] = float(resources.get("shards", 0.0)) + float(eff["shards_on_complete"])
		if eff.has("raid_retaliation"):
			var ret: float = float(eff["raid_retaliation"])
			flags["raid_retaliation"] = float(flags.get("raid_retaliation", 0.0)) + ret
	elif qtype == "ward" or bid == "vein_ward":
		# Gentle ward: defense + loss reduction
		if eff.has("defense"):
			defense_strength = min(12.0, defense_strength + float(eff["defense"]))
		if eff.has("loss_reduction"):
			flags["loss_reduction"] = float(flags.get("loss_reduction", 0.0)) + float(eff["loss_reduction"])
	elif qtype == "choir" or bid == "echo_choir":
		# R4 nurture faction: resonance return + soft defense + loss reduction
		var labor_gain_c: float = float(eff.get("labor_output", 1.8))
		production_labor += labor_gain_c
		_auto_assign_labor(labor_gain_c * 0.45)
		if eff.has("boost_resonance"):
			defense_strength = min(12.0, defense_strength + 0.6)
		if eff.has("expedition_return"):
			flags["expedition_bonus"] = float(flags.get("expedition_bonus", 0.0)) + float(eff["expedition_return"])
		if eff.has("loss_reduction"):
			flags["loss_reduction"] = float(flags.get("loss_reduction", 0.0)) + float(eff["loss_reduction"])
		if eff.has("defense"):
			defense_strength = min(12.0, defense_strength + float(eff["defense"]))
	elif qtype == "binder" or bid == "ash_binder":
		# R4 harvest faction: labor + shards + raid retaliation
		var labor_gain_b: float = float(eff.get("labor_output", 2.8))
		production_labor += labor_gain_b
		_auto_assign_labor(labor_gain_b * 0.35)
		if eff.has("shards_on_complete"):
			resources["shards"] = float(resources.get("shards", 0.0)) + float(eff["shards_on_complete"])
		if eff.has("raid_retaliation"):
			var ret_b: float = float(eff["raid_retaliation"])
			flags["raid_retaliation"] = float(flags.get("raid_retaliation", 0.0)) + ret_b
		if eff.has("defense"):
			defense_strength = min(15.0, defense_strength + float(eff["defense"]) * 1.1)
	# Update rates/boosts from new labor/facility
	_recalculate_rates()
	# Log + Memory + reframe (every production advances the realization)
	var log_text: String = "The work at the " + def.get("name", bid) + " is complete. The circle has new hands."
	if def.has("unlock_log"):
		log_text = str(def["unlock_log"])
	_log(log_text, "story")
	add_memory("production_complete_" + bid, {"building": bid, "type": qtype})
	# Reframe hook (names the pattern)
	_check_delayed_choice_reframe("production_built", bid)
	GameEvents.sfx_cue.emit("production_completed", {"building": bid, "type": qtype})

func add_memory(event_key: String, extra: Dictionary = {}) -> void:
	# Populate Memory / Reflections panel. Every call site must produce text (or be a no-op intentionally).
	# Tied to early_choice so moral decisions echo in later systems (paths, production, raids).
	var base: String = ""
	var choice: String = early_choice

	if event_key.begins_with("early_choice_"):
		base = str(extra.get("memory", ""))
		if base == "":
			if choice == "shelter":
				base = "You opened the havens. You told yourself it was mercy. The pulse called, and they answered."
			elif choice == "seal":
				base = "You sealed them out. Their cries faded, and the ember steadied. The circle learned to close."
			elif choice == "demand":
				base = "They worked at once. No oath asked, only the pulse. Their eyes went quiet before they ever saw the ash."
			else:
				base = "At the havens you made a choice. The ash will remember it."
	elif event_key == "first_outlands":
		if choice == "shelter":
			base = "The lines reach farther. The shelter you first offered now walks the veins with them."
		elif choice == "demand":
			base = "The lines reach farther. The demand you made at the first haven already taught the ash what walking them means."
		elif choice == "seal":
			base = "The lines reach farther. The circle that learned to close now marks what it will keep."
		else:
			base = "The lines reach farther into the embers. What you mark now continues whatever you began in the circle."
	elif event_key.begins_with("path_claim_"):
		var pname: String = str(extra.get("path", event_key))
		if path_data.has(pname):
			pname = str(path_data[pname].get("name", pname))
		if choice == "shelter":
			base = "You bound the " + pname + ". When the echoes first came, you opened the havens; every claim follows that mercy."
		elif choice == "demand":
			base = "You bound the " + pname + ". Demanding work at the first haven taught the ash this shape of claim."
		elif choice == "seal":
			base = "You bound the " + pname + ". Sealing taught the circle to keep what it takes; this vein is now held."
		else:
			base = "The " + pname + " is bound. What was foraged is now held."
	elif event_key == "demand_more":
		if choice == "demand":
			base = "You reach deeper again. The ones who stayed at the first haven already knew this demand."
		elif choice == "shelter":
			base = "You ask more of those you once sheltered. The circle remembers both the opening and the asking."
		elif choice == "seal":
			base = "You demand more from a circle that learned to close. The ash answers both lessons."
		else:
			base = "You push them for more. The pulse takes what they give."
	elif event_key == "raid_response_hold":
		var held: bool = bool(extra.get("mitigated", true))
		if choice == "shelter":
			base = "You held the watch. The same mercy that opened the havens now stands on the veins" + (" — and holds." if held else " — and still the ash bit.")
		elif choice == "demand":
			base = "You held the watch with the firmness you first demanded. The Bound felt eyes on them" + ("." if held else ", yet not all returned.")
		else:
			base = "You ordered the watch to hold. Defense spent so the lines might endure."
	elif event_key == "raid_response_shelter":
		if choice == "shelter":
			base = "You pulled them back. Shards spent so the Bound you once sheltered might live again."
		elif choice == "demand":
			base = "You pulled them back despite the demand that taught them to walk. The circle paid in shards."
		else:
			base = "You spent shards to pull walkers from the ash. The hearth took them in."
	elif event_key == "raid_response_strike":
		var sm: bool = bool(extra.get("mitigated", false))
		if choice == "demand":
			base = "You struck the ash as you once demanded work. The veins answered" + (" with silence and shards." if sm else " with blood and shards.")
		elif choice == "shelter":
			base = "You struck the ash though you once opened havens. Mercy and the fist share the same pulse now."
		else:
			base = "You ordered a strike. Retaliation hardens the circle" + ("." if sm else "; not all who struck returned.")
	elif event_key == "raid_response_abandon":
		var pl: int = int(extra.get("pop_loss", 0))
		if choice == "seal":
			base = "You abandoned the line. The circle that learned to seal also learned what to leave to the ash (" + str(pl) + ")."
		elif choice == "shelter":
			base = "You abandoned the line. Those you once sheltered were left to the veins (" + str(pl) + ")."
		else:
			base = "You abandoned the line to spare the hearth. The ash took " + str(pl) + " who walked."
	elif event_key == "raid_loss":
		var ploss: int = int(extra.get("pop_loss", 0))
		if choice == "shelter":
			base = "A raid took " + str(ploss) + " who walked the lines. They answered with the same silence you first offered when you sheltered them."
		elif choice == "demand":
			base = "A raid took " + str(ploss) + ". The demand you taught at the havens did not spare them on the veins."
		elif choice == "seal":
			base = "A raid took " + str(ploss) + ". The circle that learned to seal also learned what the ash takes back."
		else:
			base = "The ash answered along the veins. Not all who walked the lines return (" + str(ploss) + ")."
	elif event_key.begins_with("ash_whisper_"):
		var area: String = str(extra.get("area", ""))
		var wtype: String = str(extra.get("type", event_key))
		if area != "":
			base = "A whisper from the ash touches " + area + " (" + wtype + "). The veins remember what you chose at the havens."
		else:
			base = "A whisper from the ash (" + wtype + "). The pulse listens; so do those bound to it."
	elif event_key.begins_with("delayed_reframe_"):
		var trig: String = event_key.replace("delayed_reframe_", "")
		var mem: String = ""
		if NarrativeSystem:
			mem = NarrativeSystem.get_choice_reframe(choice)
		base = "When the echoes first came to the havens, you chose what you chose. "
		if mem != "":
			base += mem + " "
		base += "Every vein you mark follows the same shape. (reframe: " + trig + ")"
	elif event_key.begins_with("production_complete_"):
		var bid: String = str(extra.get("building", ""))
		if choice == "shelter":
			base = "The " + bid + " you raised now stands where the first haven once stood in your mind. The work it does is the work you first asked of the ones who stayed."
		elif choice == "demand":
			base = "Demanding more at the first haven taught the ash that will could be imposed. The " + bid + " answers with the same rhythm you first set."
		elif choice == "seal":
			base = "When you sealed the havens, the circle learned to close what it takes. The " + bid + " now does the same work in stone and will."
		else:
			base = "The work at the " + bid + " continues what you began when you first chose how to answer the echoes."
		if bid == "resonance_spire":
			if choice == "shelter":
				base = "The Resonance Spire you raised now stands where the first haven gathered those who answered the pulse. The voices that return now sing the silence you first offered."
			elif choice == "demand":
				base = "The demand at the first haven taught the ash that voices can be called to work. The Resonance Spire now calls them with the same will."
			else:
				base = "The Resonance Spire sings with the circle you first closed or opened at the havens."
		elif bid == "will_press":
			if choice == "demand":
				base = "The Will Press forges what the demand at the first haven first asked. The ash yields because you taught it to."
			else:
				base = "The Will Press remembers the weight you first placed on the circle when you chose how to answer the echoes."
		elif bid == "vein_ward":
			if choice == "shelter":
				base = "The Vein Ward holds the lines the way you first held the havens open. Those who walk them feel the circle differently now."
			else:
				base = "The Vein Ward stands where the choice at the havens taught the ash what shelter or silence means."
		elif bid == "echo_choir":
			if choice == "shelter":
				base = "The Echo Choir sings with the voices you first sheltered. Every vein they soften remembers the open circle."
			else:
				base = "The Echo Choir rises anyway. Listening along the veins remade what the first haven choice began."
		elif bid == "ash_binder":
			if choice == "demand":
				base = "The Ash Binder seals what the first demand taught: the ash yields when will does not ask."
			else:
				base = "The Ash Binder closes the claimed ground. Harvest along the veins taught this shape of dominion."
	elif event_key.begins_with("ending_"):
		var eid: String = event_key.replace("ending_", "")
		var outcome: String = str(extra.get("outcome", ""))
		if eid == "nurture_circle":
			base = "Memory closes on an open circle. You chose to listen more than you cut. The ash still remembers your first haven choice: " + choice + "."
		elif eid == "harvest_dominion":
			base = "Memory closes on a closed fist. You harvested what the veins would give. The first haven choice (" + choice + ") named the shape of this dominion."
		elif eid == "collapse_ash":
			base = "Memory scatters. The ember failed, or the veins took everyone. The cycle does not keep score of nurture or harvest — only of ash."
		else:
			base = "An ending settles (" + eid + " / " + outcome + "). The ash keeps the pattern of " + choice + "."
	elif event_key.begins_with("faction_unlock_"):
		var fbid: String = str(extra.get("building", event_key.replace("faction_unlock_", "")))
		var fname: String = building_data.get(fbid, {}).get("name", fbid)
		if fbid == "echo_choir" or fbid == "resonance_spire" or fbid == "sanctuary_ward":
			if choice == "shelter":
				base = "The " + fname + " unlocks because you opened the havens and listened along the veins. The circle remembers that mercy as architecture."
			elif choice == "demand":
				base = "The " + fname + " almost does not fit the demand you first made — yet the pulse still answers when alignment softens enough to hear."
			else:
				base = "The " + fname + " stands ready. Nurture-leaning will shaped the ash enough to open this gate."
		elif fbid == "ash_binder" or fbid == "will_press" or fbid == "dread_foundry" or fbid == "spire_foundry":
			if choice == "demand":
				base = "The " + fname + " unlocks because you demanded work at the first haven and harvested the veins. The ash learned that shape of will."
			elif choice == "seal":
				base = "The " + fname + " unlocks from a circle that learned to close. Binding follows sealing."
			else:
				base = "The " + fname + " stands ready. Harvest-leaning will pressed the ash hard enough to open this gate."
		else:
			base = "A faction gate opens: the " + fname + ". Your early choice (" + choice + ") and the weight you set on the veins made this possible."
	elif event_key.begins_with("production_queued_"):
		var bid: String = str(extra.get("building", ""))
		var dname: String = building_data.get(bid, {}).get("name", bid)
		if choice == "shelter":
			base = "You set the " + dname + " in motion. The shelter you first chose now means ordering more labor and eyes from the circle."
		elif choice == "demand":
			base = "The demand you made at the first haven taught the ash that will can be imposed through work. The order for the " + dname + " follows that same will."
		elif choice == "seal":
			base = "Sealing taught the circle to close ranks. Queuing the " + dname + " raises another wall of intent and labor."
		else:
			base = "Work is queued at the " + dname + ". The pulse demands more from the ash, and from those bound to it."
	elif event_key.begins_with("labor_assigned_"):
		var role: String = str(extra.get("role", "work"))
		if choice == "shelter":
			base = "You direct the hands to " + role + ". The shelter you first chose now means ordering the circle's labor along the veins."
		elif choice == "demand":
			base = "The demand you made at the first haven taught that will moves hands. Assigning labor to " + role + " follows the same order."
		elif choice == "seal":
			base = "Sealing the havens taught the circle what is allowed inside. Labor assigned to " + role + " keeps the work within the lines you drew."
		else:
			base = "Labor is set to " + role + ". The pulse claims more of the ash, and of those bound to answer it."
	elif event_key.begins_with("echo_manifest"):
		base = "An echo manifests and is resolved. The ash answers the pattern you set at the first circle."
	elif event_key == "ng_plus_memory_shard":
		var prev_end: String = str(extra.get("ending_id", "a prior cycle"))
		var prev_out: String = str(extra.get("outcome", ""))
		var prev_choice: String = str(extra.get("early_choice", ""))
		var run_n: int = int(extra.get("ng_plus_run", 1))
		base = "A Memory shard survived the ash from cycle " + str(run_n) + ". Ending: " + prev_end
		if prev_out != "":
			base += " (" + prev_out + ")"
		if prev_choice != "":
			base += ". Your first haven choice then was " + prev_choice + "."
		else:
			base += ". The pulse remembers a shape you do not."
		base += " The shard warms a few starting embers."

	if base == "":
		return  # unknown key: do not spam empty entries

	# Dedup: skip if identical key already recorded (keeps panel readable over long sessions)
	for e in memory_entries:
		if str(e.get("key", "")) == event_key:
			return

	if NarrativeSystem:
		base = NarrativeSystem.get_flavored_text(base, get_current_narrative_context())
	memory_entries.append({
		"key": event_key,
		"text": base,
		"time": total_play_time,
		"context": extra.duplicate()
	})
	GameEvents.log_message.emit(base, "memory")

func meets_faction_requirements(req: Dictionary) -> bool:
	if req.is_empty():
		return true
	var a: float = alignment
	if req.has("align_lt") and a >= float(req["align_lt"]):
		return false
	if req.has("align_gt") and a <= float(req["align_gt"]):
		return false
	if req.has("early_choice") and early_choice != str(req["early_choice"]):
		return false
	if req.has("early_choice_is") and early_choice != str(req["early_choice_is"]):
		return false
	# R4: richer JSON faction gates (claims + path moral tallies + prerequisite building)
	if req.has("min_claims") and _claim_count() < int(req["min_claims"]):
		return false
	if req.has("path_moral_nurture_gte") and path_moral_nurture < int(req["path_moral_nurture_gte"]):
		return false
	if req.has("path_moral_harvest_gte") and path_moral_harvest < int(req["path_moral_harvest_gte"]):
		return false
	if req.has("building"):
		var need: String = str(req["building"])
		if int(buildings.get(need, 0)) < 1:
			return false
	return true

# Map support (for 2D OutlandsMap scene + UI)
func get_path_visual_data(path_id: String) -> Dictionary:
	if not path_data.has(path_id):
		return {}
	return path_data[path_id].get("visual", {})

func get_path_progress(path_id: String) -> float:
	# Returns 0-1 progress for active expeditions on this path (for moving entities on map)
	for exp in active_expeditions:
		if str(exp.get("path_id", "")) == path_id:
			var eta: float = float(exp.get("eta", 0.0))
			var departed: float = float(exp.get("departed_at", total_play_time))
			if eta <= departed:
				return 1.0
			var prog: float = (total_play_time - departed) / (eta - departed)
			return clamp(prog, 0.0, 1.0)
	return 0.0

func get_vein_defense_strength(path_id: String) -> float:
	# Simple distribution for schematic map; can be per-claim + local tower contrib later
	# Now includes production labor assigned to defense (when labor active, map shows stronger via callers)
	var base: float = defense_strength
	if path_claims.get(path_id, false):
		base += float(buildings.get("watch_spire", 0)) * 1.5
	var def_labor: float = float(labor_assigned.get("defense", 0.0))
	if def_labor > 0.0:
		base += def_labor * 0.12
	elif production_labor > 0.0:
		base += production_labor * 0.04  # base labor helps all veins
	return clamp(base, 0.0, 18.0)

# Simple status for UI/Memory/map to show C&C queue progress (etas live via time ticks)
func get_active_queues_text() -> String:
	if production_queue.is_empty():
		return "No active production."
	var parts: Array[String] = []
	for q in production_queue:
		var bid: String = str(q.get("id", ""))
		var nm: String = building_data.get(bid, {}).get("name", bid)
		var rem: float = max(0.0, float(q.get("eta", total_play_time)) - total_play_time)
		parts.append(nm + " ~" + str(int(rem)) + "s")
	return "Queues: " + "; ".join(parts)

func get_current_narrative_context() -> Dictionary:
	# Helper for Memory + flavored text (extends existing get_current_context in Narrative if present)
	var ctx: Dictionary = {}
	if NarrativeSystem and NarrativeSystem.has_method("get_current_context"):
		ctx = NarrativeSystem.get_current_context()
	else:
		ctx = {
			"alignment": alignment,
			"phase": phase,
			"havens": buildings.get("haven", 0),
			"population": population,
			"early_choice": early_choice,
			"paths_opened": phase == "outlands" or flags.get("outlands_reached", false),
			"claims": path_claims.keys().size() if typeof(path_claims) == TYPE_DICTIONARY else 0,
			"production_labor": production_labor
		}
	return ctx


# === R3 Ending reckoning (nurture vs harvest + collapse) ===

func _claim_count() -> int:
	var n: int = 0
	for k in path_claims.keys():
		if path_claims[k]:
			n += 1
	return n

func _tally_path_moral(option_id: String, align_delta: float) -> void:
	# Classify expedition moral: positive / listen/mend = nurture; negative / harvest/cut/claim = harvest
	var oid: String = option_id.to_lower()
	var nurture_keys: Array = ["listen", "mend", "offer", "shelter", "passage", "ward"]
	var harvest_keys: Array = ["harvest", "cut", "claim", "demand", "seal", "press", "force"]
	var is_nurture: bool = false
	var is_harvest: bool = false
	for k in nurture_keys:
		if oid.find(k) >= 0:
			is_nurture = true
			break
	for k in harvest_keys:
		if oid.find(k) >= 0:
			is_harvest = true
			break
	if is_nurture and not is_harvest:
		path_moral_nurture += 1
	elif is_harvest and not is_nurture:
		path_moral_harvest += 1
	elif align_delta > 0.01:
		path_moral_nurture += 1
	elif align_delta < -0.01:
		path_moral_harvest += 1
	else:
		# Neutral option: lean by current Weight
		if alignment >= 0.0:
			path_moral_nurture += 1
		else:
			path_moral_harvest += 1

func _check_ending_conditions(source: String = "") -> void:
	if game_ended:
		return
	# Lose first: circle collapses
	if phase == "outlands" or _claim_count() > 0:
		if population <= 0:
			trigger_ending("collapse_ash", "population wiped (%s)" % source)
			return
		if ember_pulse <= 0.0 and _claim_count() >= 1 and total_play_time > 30.0:
			trigger_ending("collapse_ash", "ember died (%s)" % source)
			return
	# Win reckoning: enough veins claimed + early moral choice recorded
	if early_choice == "" or _claim_count() < ENDING_CLAIM_THRESHOLD:
		return
	# Prefer firing on path_claim (session beat); allow tick only if somehow missed
	if source != "path_claim" and source != "force":
		return
	var nurture_score: int = path_moral_nurture
	var harvest_score: int = path_moral_harvest
	if early_choice == "shelter":
		nurture_score += 2
	elif early_choice == "demand" or early_choice == "seal":
		harvest_score += 2
	if flags.get("demand_more_policy", false):
		harvest_score += 1
	else:
		nurture_score += 1
	if alignment > 0.1:
		nurture_score += 1
	elif alignment < -0.1:
		harvest_score += 1
	# Buildings reinforce trajectory (faction production)
	if int(buildings.get("resonance_spire", 0)) > 0 or int(buildings.get("sanctuary_ward", 0)) > 0 or int(buildings.get("vein_ward", 0)) > 0 or int(buildings.get("echo_choir", 0)) > 0:
		nurture_score += 1
	if int(buildings.get("will_press", 0)) > 0 or int(buildings.get("dread_foundry", 0)) > 0 or int(buildings.get("spire_foundry", 0)) > 0 or int(buildings.get("ash_binder", 0)) > 0:
		harvest_score += 1
	if nurture_score > harvest_score:
		trigger_ending("nurture_circle", "score n=%d h=%d" % [nurture_score, harvest_score])
	else:
		trigger_ending("harvest_dominion", "score n=%d h=%d" % [nurture_score, harvest_score])

func trigger_ending(id: String, reason: String = "") -> void:
	if game_ended:
		return
	if ending_data.is_empty():
		_load_endings_data()
	var def: Dictionary = ending_data.get(id, {})
	if def.is_empty():
		# Fallback stubs so headless still works if JSON missing
		def = {"id": id, "outcome": "lose" if id == "collapse_ash" else "win", "title": id, "badge": id, "body": "The ash settles.", "legacy": ""}
	game_ended = true
	ending_id = id
	ending_outcome = str(def.get("outcome", "win"))
	is_paused = true
	time_scale = 0.0
	flags["ending_reason"] = reason
	add_memory("ending_" + id, {"outcome": ending_outcome, "reason": reason})
	var title: String = str(def.get("title", id))
	var body: String = str(def.get("body", ""))
	_log("--- " + title + " ---", "revelation")
	if body != "":
		_log(body, "story")
	var legacy: String = str(def.get("legacy", ""))
	if legacy != "":
		_log(legacy, "revelation")
	GameEvents.ending_reached.emit(ending_id, ending_outcome)
	GameEvents.sfx_cue.emit("reframe_sting", {"ending": ending_id, "outcome": ending_outcome, "strength": 1.0})
	GameEvents.available_actions_changed.emit()
	# R5: seal Memory shard for NG+ carry into the next run
	_seal_memory_shard()
	save_game()

func get_ending_info() -> Dictionary:
	if ending_id == "" or not ending_data.has(ending_id):
		return {}
	var info: Dictionary = ending_data[ending_id].duplicate(true)
	info["claims"] = _claim_count()
	info["nurture_tally"] = path_moral_nurture
	info["harvest_tally"] = path_moral_harvest
	info["early_choice"] = early_choice
	info["alignment"] = alignment
	info["population"] = population
	info["play_time"] = total_play_time
	return info

# End R3 ending reckoning

# End accelerated helpers

func save_game(slot: String = "auto") -> void:
	var save_data: Dictionary = {
		"version": 1,
		"resources": resources,
		"rates": rates,
		"buildings": buildings,
		"production_queue": production_queue,
		"memory_entries": memory_entries,
		"labor_boost": labor_boost,
		"production_labor": production_labor,
		"labor_assigned": labor_assigned,
		"build_speed_bonus": build_speed_bonus,
		"active_whispers": active_whispers,
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
		"game_ended": game_ended,
		"ending_id": ending_id,
		"ending_outcome": ending_outcome,
		"path_moral_nurture": path_moral_nurture,
		"path_moral_harvest": path_moral_harvest,
		"ng_plus_run": ng_plus_run,
		"memory_shard_active": memory_shard_active,
		"memory_shard_last": memory_shard_last,
		"pending_raid": pending_raid,
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
	var _pr = data.get("pending_raid", {})
	pending_raid = _pr if typeof(_pr) == TYPE_DICTIONARY else {}
	# Polish: restore choice memory so reframes survive reload/offline
	early_choice = data.get("early_choice", early_choice)
	choice_history.clear()
	var _ch: Array = data.get("choice_history", [])
	for item in _ch:
		choice_history.append(item)
	game_ended = bool(data.get("game_ended", false))
	ending_id = str(data.get("ending_id", ""))
	ending_outcome = str(data.get("ending_outcome", ""))
	path_moral_nurture = int(data.get("path_moral_nurture", 0))
	path_moral_harvest = int(data.get("path_moral_harvest", 0))
	ng_plus_run = int(data.get("ng_plus_run", ng_plus_run))
	memory_shard_active = bool(data.get("memory_shard_active", false))
	var _msl = data.get("memory_shard_last", {})
	if typeof(_msl) == TYPE_DICTIONARY:
		memory_shard_last = _msl

	# Accelerated: restore production and Memory
	production_queue.clear()
	var _pq: Array = data.get("production_queue", [])
	if _pq is Array:
		for item in _pq:
			production_queue.append(item)
	memory_entries.clear()
	var _me: Array = data.get("memory_entries", [])
	if _me is Array:
		for item in _me:
			memory_entries.append(item)
	labor_boost = float(data.get("labor_boost", 0.0))
	production_labor = float(data.get("production_labor", 0.0))
	var _la = data.get("labor_assigned", {})
	labor_assigned.clear()
	if typeof(_la) == TYPE_DICTIONARY:
		for k in _la:
			labor_assigned[str(k)] = float(_la[k])
	build_speed_bonus = float(data.get("build_speed_bonus", 0.0))

	# Restore active whispers (temp events persist across save/load/offline; expirations checked on time catchup)
	active_whispers.clear()
	var _aw = data.get("active_whispers", {})
	if typeof(_aw) == TYPE_DICTIONARY:
		for k in _aw:
			active_whispers[str(k)] = _aw[k]

	_recalculate_rates()
	GameEvents.available_actions_changed.emit()

	# Resolve expeditions that may have passed eta during offline (per plan)
	if not active_expeditions.is_empty():
		_resolve_expeditions()
	# Accelerated: catch up production queues on load/offline
	if not production_queue.is_empty():
		advance_production(0.0)
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
	pending_raid.clear()
	production_queue.clear()
	memory_entries.clear()
	labor_boost = 0.0
	production_labor = 0.0
	labor_assigned.clear()
	build_speed_bonus = 0.0
	active_whispers.clear()
	cooldowns = {}
	# Polish: clear choice memory on full reset
	early_choice = ""
	choice_history.clear()
	game_ended = false
	ending_id = ""
	ending_outcome = ""
	path_moral_nurture = 0
	path_moral_harvest = 0
	memory_shard_active = false
	memory_shard_last = {}
	# ng_plus_run / meta file survive; apply runs on fresh _load_or_init
	# Re-init (will call _load_paths_data + _load_or_init fresh)
	_ready()


# === R5 NG+ Memory shard (carry ending echo into next run) ===

func _load_ng_plus_meta() -> Dictionary:
	if not FileAccess.file_exists(NG_PLUS_META_PATH):
		return {}
	var file: FileAccess = FileAccess.open(NG_PLUS_META_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _save_ng_plus_meta(meta: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(NG_PLUS_META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta, "\t"))
		file.close()

func _seal_memory_shard() -> void:
	# Called from trigger_ending. Writes pending shard outside save_auto so reset/editor wipe keep it.
	if ending_id == "":
		return
	var meta: Dictionary = _load_ng_plus_meta()
	var runs: int = int(meta.get("ng_plus_run", 0)) + 1
	var shard: Dictionary = {
		"ending_id": ending_id,
		"outcome": ending_outcome,
		"early_choice": early_choice,
		"path_moral_nurture": path_moral_nurture,
		"path_moral_harvest": path_moral_harvest,
		"alignment": alignment,
		"ng_plus_run": runs,
		"sealed_at": total_play_time,
	}
	meta["ng_plus_run"] = runs
	meta["pending"] = true
	meta["shard"] = shard
	var hist = meta.get("history", [])
	if typeof(hist) != TYPE_ARRAY:
		hist = []
	hist = hist.duplicate()
	hist.append(shard.duplicate(true))
	while hist.size() > 12:
		hist.remove_at(0)
	meta["history"] = hist
	_save_ng_plus_meta(meta)
	memory_shard_last = shard.duplicate(true)
	_log("A Memory shard settles in the ash. The next awakening may remember this cycle.", "revelation")

func _apply_memory_shard_carry() -> void:
	# One-shot: if pending shard exists, seed this fresh run then clear pending.
	var meta: Dictionary = _load_ng_plus_meta()
	if not bool(meta.get("pending", false)):
		memory_shard_active = false
		ng_plus_run = int(meta.get("ng_plus_run", 0))
		return
	var shard: Dictionary = meta.get("shard", {})
	if typeof(shard) != TYPE_DICTIONARY or shard.is_empty():
		meta["pending"] = false
		_save_ng_plus_meta(meta)
		return
	ng_plus_run = int(meta.get("ng_plus_run", int(shard.get("ng_plus_run", 1))))
	memory_shard_active = true
	memory_shard_last = shard.duplicate(true)
	resources["shards"] = float(resources.get("shards", 0.0)) + MEMORY_SHARD_START_SHARDS
	var prior_end: String = str(shard.get("ending_id", ""))
	var prior_out: String = str(shard.get("outcome", ""))
	if prior_end == "nurture_circle":
		alignment = clamp(alignment + 0.05, -1.0, 1.0)
	elif prior_end == "harvest_dominion":
		alignment = clamp(alignment - 0.05, -1.0, 1.0)
	elif prior_end == "collapse_ash":
		ember_pulse = max(ember_pulse, 0.5)
	flags["ng_plus"] = true
	flags["ng_plus_from_ending"] = prior_end
	add_memory("ng_plus_memory_shard", {
		"ending_id": prior_end,
		"outcome": prior_out,
		"early_choice": str(shard.get("early_choice", "")),
		"ng_plus_run": ng_plus_run,
	})
	meta["pending"] = false
	meta["last_applied"] = shard.duplicate(true)
	_save_ng_plus_meta(meta)
	GameEvents.resource_changed.emit("shards", float(resources.get("shards", 0.0)), MEMORY_SHARD_START_SHARDS)
	_log("Something warm remains in your palm — a Memory shard from a cycle the ash will not fully forget.", "story")

func get_memory_shard_info() -> Dictionary:
	return {
		"active": memory_shard_active,
		"ng_plus_run": ng_plus_run,
		"last": memory_shard_last.duplicate(true),
	}

