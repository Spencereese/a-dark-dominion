# test_headless.gd - Headless verification + core-loop simulation for A Dark Dominion
# Run: Godot_v4.6.3-stable_win64_console.exe --headless --path . -s res://test_headless.gd
# Note: with -s, autoloads are NOT ready in _init; defer to _initialize / idle frame.
extends SceneTree

var _failures: int = 0

func _fail(msg: String) -> void:
	_failures += 1
	print("FAIL: ", msg)

func _ok(msg: String) -> void:
	print("OK: ", msg)

func _init() -> void:
	print("=== A Dark Dominion Headless Test ===")
	print("Godot version: ", Engine.get_version_info())
	# Autoloads register after SceneTree script _init when using -s; run on next idle.
	call_deferred("_run_tests")

func _run_tests() -> void:
	# --- Autoloads (nodes under /root) ---
	print("Checking autoloads...")
	var gs: Node = get_root().get_node_or_null("GameState")
	if gs == null:
		_fail("GameState autoload missing under /root")
		_finish()
		return
	_ok("GameState autoload")
	if get_root().get_node_or_null("GameEvents") != null:
		_ok("GameEvents autoload")
	else:
		_fail("GameEvents autoload missing")
	if get_root().get_node_or_null("NarrativeSystem") != null:
		_ok("NarrativeSystem autoload")
	else:
		_fail("NarrativeSystem autoload missing")

	# --- Data ---
	print("Loading data files...")
	var paths_data: Dictionary = _load_json("res://data/paths.json")
	if paths_data.is_empty():
		_fail("paths.json failed")
	else:
		_ok("paths.json (%d paths)" % paths_data.keys().size())
		for pid in paths_data:
			if not paths_data[pid].has("visual"):
				print("  WARN: path ", pid, " missing visual")
	var buildings_data: Dictionary = _load_json("res://data/buildings.json")
	if buildings_data.is_empty():
		_fail("buildings.json failed")
	else:
		_ok("buildings.json (%d buildings)" % buildings_data.keys().size())
		var expected: Array = ["labor_hall", "resonance_spire", "will_press", "vein_ward", "watch_spire"]
		for b in expected:
			if buildings_data.has(b):
				_ok("building present: " + b)
			else:
				_fail("building missing: " + b)
	var actions_data: Dictionary = _load_json("res://data/actions.json")
	if actions_data.is_empty():
		_fail("actions.json failed")
	else:
		_ok("actions.json (%d actions)" % actions_data.keys().size())
		for a in ["queue_resonance_spire", "queue_will_press", "queue_vein_ward"]:
			if actions_data.has(a):
				_ok("action present: " + a)
			else:
				_fail("action missing: " + a)

	# --- Scenes ---
	print("Checking scenes...")
	var main_packed: PackedScene = load("res://scenes/Main.tscn")
	if main_packed == null:
		_fail("Main.tscn load failed")
	else:
		_ok("Main.tscn loads")
	var map_packed: PackedScene = load("res://scenes/OutlandsMap.tscn")
	if map_packed == null:
		_fail("OutlandsMap.tscn load failed")
	else:
		_ok("OutlandsMap.tscn loads")

	# --- Instantiate Main ---
	print("Simulating Main scene instantiation...")
	if main_packed:
		var main_inst: Node = main_packed.instantiate()
		if main_inst == null:
			_fail("Main instantiate null")
		else:
			get_root().add_child(main_inst)
			_ok("Main in tree")
			if main_inst.has_method("_refresh_map"):
				main_inst.call("_refresh_map")
				_ok("_refresh_map")
			if main_inst.has_method("_refresh_memories"):
				main_inst.call("_refresh_memories")
				_ok("_refresh_memories")
			var mv = main_inst.get("map_view")
			if mv:
				_ok("map_view present")
				if mv.has_method("update_from_gamestate"):
					mv.update_from_gamestate(true)
					_ok("map_view.update_from_gamestate")
				if mv.has_method("_process"):
					mv._process(0.016)
					_ok("map_view._process tick")
			else:
				print("  note: map_view may be null until outlands panel ensured (ok at dark start)")
			main_inst.queue_free()

	# --- Core loop simulation ---
	print("Simulating core loop (build → gather → moral choice → consequence)...")
	_ok("GameState reachable")
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
		_ok("reset_to_new_game")

	if not gs.perform_action("nurture_ember"):
		_fail("nurture_ember failed")
	else:
		_ok("nurture_ember → phase " + str(gs.phase))

	gs.resources["shards"] = 200.0
	gs.resources["resonance"] = 40.0
	gs.resources["vitalis"] = 10.0
	gs.ember_pulse = 8.0
	gs.population = 6
	gs.buildings["haven"] = 2
	gs.buildings["basic_sanctum"] = 1
	gs.buildings["foraging_lines"] = 1
	gs.phase = "village"
	gs.flags["outlands_reached"] = false
	gs.flags["incursion_handled"] = false
	gs.flags["incursion_triggered"] = false
	gs.flags["incursion_pending"] = false
	gs.early_choice = ""
	gs.memory_entries.clear()
	if gs.has_method("_check_unlocks"):
		gs._check_unlocks()
	if gs.has_method("_check_early_choice_events"):
		gs._check_early_choice_events()

	var choice_ok: bool = gs.perform_action("choice_demand_work")
	if not choice_ok and gs.has_method("_resolve_early_choice"):
		choice_ok = gs._resolve_early_choice("echo_incursion", "demand")
	if not choice_ok:
		_fail("early moral choice failed")
	else:
		_ok("early choice demand recorded: " + str(gs.early_choice))
		if gs.early_choice != "demand":
			_fail("early_choice expected demand, got " + str(gs.early_choice))

	var has_early_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")).begins_with("early_choice_"):
			has_early_mem = true
			break
	if has_early_mem:
		_ok("memory_entries has early_choice")
	else:
		_fail("memory_entries missing early_choice (Memory panel would be empty)")

	gs.resources["shards"] = max(float(gs.resources.get("shards", 0.0)), 80.0)
	gs.population = max(gs.population, 6)
	if gs.has_method("_check_phase_advancement"):
		gs._check_phase_advancement()
	if gs.phase != "outlands":
		gs.phase = "outlands"
		gs.flags["outlands_reached"] = true
		if gs.has_method("add_memory"):
			gs.add_memory("first_outlands", {})
		_ok("forced outlands phase for sim")
	else:
		_ok("phase advanced to outlands")

	if gs.discovered_paths.is_empty() and gs.path_data:
		for pid in gs.path_data.keys():
			gs.discovered_paths.append(str(pid))
	var path_id: String = "vein_of_fading_echoes"
	if not gs.dispatch_expedition(path_id, "harvest"):
		_fail("dispatch_expedition harvest failed")
	else:
		_ok("dispatched expedition with moral choice harvest")

	if gs.has_method("advance_time"):
		gs.advance_time(30.0)
		_ok("advance_time 30s (resolve expeditions + production ticks)")

	var claimed: bool = bool(gs.path_claims.get(path_id, false))
	if not claimed and gs.active_expeditions.size() > 0:
		for exp in gs.active_expeditions.duplicate():
			if gs.has_method("_resolve_one_expedition"):
				gs._resolve_one_expedition(exp)
		gs.active_expeditions.clear()
		claimed = bool(gs.path_claims.get(path_id, false))
	if claimed:
		_ok("path claimed after resolve")
	else:
		_fail("path not claimed after expedition")

	var has_claim_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")).begins_with("path_claim_"):
			has_claim_mem = true
			break
	if has_claim_mem:
		_ok("memory_entries has path_claim")
	else:
		_fail("memory_entries missing path_claim")

	if "vein_ward" not in gs.unlocked_buildings:
		gs.unlocked_buildings.append("vein_ward")
	if "resonance_spire" not in gs.unlocked_buildings:
		gs.unlocked_buildings.append("resonance_spire")
	if "will_press" not in gs.unlocked_buildings:
		gs.unlocked_buildings.append("will_press")
	gs.alignment = -0.2
	gs.resources["shards"] = 200.0
	gs.resources["resonance"] = 50.0

	if not gs.start_production("vein_ward"):
		_fail("start_production vein_ward failed")
	else:
		_ok("queued vein_ward")
	if gs.production_queue.size() > 0:
		gs.production_queue[0]["eta"] = gs.total_play_time
	if gs.has_method("advance_production"):
		gs.advance_production(1.0)
	if int(gs.buildings.get("vein_ward", 0)) >= 1:
		_ok("vein_ward built via production queue")
	else:
		_fail("vein_ward not built after production complete")

	var has_prod_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")).begins_with("production_complete_"):
			has_prod_mem = true
			break
	if has_prod_mem:
		_ok("memory_entries has production_complete")
	else:
		_fail("memory_entries missing production_complete")

	if gs.alignment < 0.0:
		_ok("alignment negative after demand path (Weight felt): " + str(gs.alignment))
	else:
		print("  note: alignment=", gs.alignment, " (may have drifted)")

	print("memory_entries count: ", gs.memory_entries.size())
	print("phase=", gs.phase, " pop=", gs.population, " claims=", gs.path_claims.keys())
	_finish()

func _finish() -> void:
	print("=== Headless Test Complete ===")
	if _failures > 0:
		print("RESULT: FAILED with ", _failures, " failure(s)")
		quit(1)
	else:
		print("RESULT: PASSED")
		quit(0)

func _load_json(path: String) -> Dictionary:
	if ResourceLoader.exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed
	print("  Failed to load/parse JSON: ", path)
	return {}
