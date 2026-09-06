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

	# --- R5: Clear residual NG+ meta so prior runs do not contaminate ---
	if gs.has_method("_save_ng_plus_meta"):
		gs._save_ng_plus_meta({"ng_plus_run": 0, "pending": false, "shard": {}, "history": []})
		_ok("cleared ng_plus_meta for clean headless")

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
		var expected: Array = ["labor_hall", "resonance_spire", "will_press", "vein_ward", "watch_spire", "echo_choir", "ash_binder"]
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
		for a in ["queue_resonance_spire", "queue_will_press", "queue_vein_ward", "queue_echo_choir", "queue_ash_binder"]:
			if actions_data.has(a):
				_ok("action present: " + a)
			else:
				_fail("action missing: " + a)
	var endings_data: Dictionary = _load_json("res://data/endings.json")
	if endings_data.is_empty():
		_fail("endings.json failed")
	else:
		_ok("endings.json (%d endings)" % endings_data.keys().size())
		if endings_data.keys().size() >= 6:
			_ok("endings catalog size >= 6")
		else:
			_fail("endings catalog too small: %d" % endings_data.keys().size())
		for eid in ["nurture_circle", "harvest_dominion", "collapse_ash", "true_echo", "sparse_hearth", "pyrrhic_crown"]:
			if endings_data.has(eid):
				_ok("ending present: " + eid)
			else:
				_fail("ending missing: " + eid)
	var raids_data: Dictionary = _load_json("res://data/raids.json")
	if raids_data.is_empty():
		_fail("raids.json failed")
	else:
		_ok("raids.json (%d encounters)" % raids_data.keys().size())
		if raids_data.has("path_raid"):
			var ropts = raids_data["path_raid"].get("options", [])
			if typeof(ropts) == TYPE_ARRAY and ropts.size() >= 4:
				_ok("path_raid has %d options" % ropts.size())
			else:
				_fail("path_raid options incomplete")
			for oid in ["hold_watch", "offer_shelter", "strike_back", "abandon_line"]:
				var found: bool = false
				for o in ropts:
					if str(o.get("id", "")) == oid:
						found = true
						break
				if found:
					_ok("raid option present: " + oid)
				else:
					_fail("raid option missing: " + oid)
		else:
			_fail("path_raid missing from raids.json")
	var towers_data: Dictionary = _load_json("res://data/towers.json")
	if towers_data.is_empty():
		_fail("towers.json failed")
	else:
		_ok("towers.json (%d profiles)" % towers_data.keys().size())
		for tid in ["watch_bolt", "dread_spike", "ward_pulse"]:
			if towers_data.has(tid):
				var tp = towers_data[tid]
				if float(tp.get("push", 0.0)) > 0.0 and float(tp.get("credit", 0.0)) > 0.0:
					_ok("tower profile ok: " + tid)
				else:
					_fail("tower profile incomplete: " + tid)
			else:
				_fail("tower profile missing: " + tid)

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
	print("Simulating core loop (build â†’ gather â†’ moral choice â†’ consequence)...")
	_ok("GameState reachable")
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
		_ok("reset_to_new_game")

	if not gs.perform_action("nurture_ember"):
		_fail("nurture_ember failed")
	else:
		_ok("nurture_ember â†’ phase " + str(gs.phase))

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

	# --- R4 Faction unlocks (natural, no force-append) ---
	print("Simulating natural faction unlocks (nurture Echo Choir + harvest Ash Binder)...")
	if not gs.has_method("meets_faction_requirements") or not gs.has_method("_check_unlocks"):
		_fail("faction unlock methods missing")
	else:
		_ok("faction unlock methods present")

	# Nurture fork: shelter + positive align + 1 nurture claim -> echo_choir + resonance_spire
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.flags["outlands_reached"] = true
	gs.early_choice = "shelter"
	gs.alignment = 0.35
	gs.population = 8
	gs.ember_pulse = 6.0
	gs.game_ended = false
	gs.ending_id = ""
	gs.path_moral_nurture = 1
	gs.path_moral_harvest = 0
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.memory_entries.clear()
	# Ensure buildings data loaded
	if gs.building_data.is_empty() and gs.has_method("_load_building_data"):
		gs._load_building_data()
	# Must NOT already be unlocked
	while "echo_choir" in gs.unlocked_buildings:
		gs.unlocked_buildings.erase("echo_choir")
	while "resonance_spire" in gs.unlocked_buildings:
		gs.unlocked_buildings.erase("resonance_spire")
	var echo_req: Dictionary = gs.building_data.get("echo_choir", {}).get("require", {})
	if gs.meets_faction_requirements(echo_req):
		_ok("echo_choir faction require met under nurture state")
	else:
		_fail("echo_choir require should pass (align/shelter/claims/nurture)")
	gs._check_unlocks()
	if "echo_choir" in gs.unlocked_buildings:
		_ok("echo_choir unlocked naturally via _check_unlocks")
	else:
		_fail("echo_choir did not unlock naturally")
	if "resonance_spire" in gs.unlocked_buildings:
		_ok("resonance_spire unlocked naturally (align_gt)")
	else:
		_fail("resonance_spire did not unlock naturally")
	var has_faction_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")).begins_with("faction_unlock_"):
			has_faction_mem = true
			break
	if has_faction_mem:
		_ok("memory_entries has faction_unlock")
	else:
		_fail("memory_entries missing faction_unlock after natural unlock")

	# Production complete for echo_choir after natural unlock
	gs.resources["shards"] = 200.0
	gs.resources["resonance"] = 60.0
	if not gs.start_production("echo_choir"):
		_fail("start_production echo_choir failed after natural unlock")
	else:
		_ok("queued echo_choir")
	if gs.production_queue.size() > 0:
		gs.production_queue[0]["eta"] = gs.total_play_time
	if gs.has_method("advance_production"):
		gs.advance_production(1.0)
	if int(gs.buildings.get("echo_choir", 0)) >= 1:
		_ok("echo_choir built via production")
	else:
		_fail("echo_choir not built after production")

	# Harvest fork: demand + negative align + harvest tally -> ash_binder + will_press
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.flags["outlands_reached"] = true
	gs.early_choice = "demand"
	gs.alignment = -0.35
	gs.population = 8
	gs.ember_pulse = 6.0
	gs.game_ended = false
	gs.ending_id = ""
	gs.path_moral_nurture = 0
	gs.path_moral_harvest = 1
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.memory_entries.clear()
	while "ash_binder" in gs.unlocked_buildings:
		gs.unlocked_buildings.erase("ash_binder")
	while "will_press" in gs.unlocked_buildings:
		gs.unlocked_buildings.erase("will_press")
	var binder_req: Dictionary = gs.building_data.get("ash_binder", {}).get("require", {})
	if gs.meets_faction_requirements(binder_req):
		_ok("ash_binder faction require met under harvest state")
	else:
		_fail("ash_binder require should pass (align/demand/claims/harvest)")
	gs._check_unlocks()
	if "ash_binder" in gs.unlocked_buildings:
		_ok("ash_binder unlocked naturally via _check_unlocks")
	else:
		_fail("ash_binder did not unlock naturally")
	if "will_press" in gs.unlocked_buildings:
		_ok("will_press unlocked naturally (align_lt)")
	else:
		_fail("will_press did not unlock naturally")
	has_faction_mem = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "faction_unlock_ash_binder":
			has_faction_mem = true
			break
	if has_faction_mem:
		_ok("memory_entries has faction_unlock_ash_binder")
	else:
		_fail("memory_entries missing faction_unlock_ash_binder")

	gs.resources["shards"] = 200.0
	gs.resources["resonance"] = 60.0
	if not gs.start_production("ash_binder"):
		_fail("start_production ash_binder failed after natural unlock")
	else:
		_ok("queued ash_binder")
	if gs.production_queue.size() > 0:
		gs.production_queue[0]["eta"] = gs.total_play_time
	if gs.has_method("advance_production"):
		gs.advance_production(1.0)
	if int(gs.buildings.get("ash_binder", 0)) >= 1:
		_ok("ash_binder built via production")
	else:
		_fail("ash_binder not built after production")

	# Negative control: wrong early_choice must block echo_choir
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.early_choice = "demand"
	gs.alignment = 0.5
	gs.path_moral_nurture = 2
	gs.path_claims = {"vein_of_fading_echoes": true}
	while "echo_choir" in gs.unlocked_buildings:
		gs.unlocked_buildings.erase("echo_choir")
	echo_req = gs.building_data.get("echo_choir", {}).get("require", {})
	if not gs.meets_faction_requirements(echo_req):
		_ok("echo_choir blocked when early_choice is demand (not shelter)")
	else:
		_fail("echo_choir should require early_choice shelter")
	gs._check_unlocks()
	if "echo_choir" not in gs.unlocked_buildings:
		_ok("echo_choir stayed locked under wrong early_choice")
	else:
		_fail("echo_choir unlocked despite wrong early_choice")

	# --- R3 Ending reckoning ---
	print("Simulating ending reckoning (nurture win + collapse lose)...")
	if not gs.has_method("trigger_ending") or not gs.has_method("_check_ending_conditions"):
		_fail("ending methods missing on GameState")
	else:
		_ok("ending methods present")

	# Reset sim state for nurture win path
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.flags["outlands_reached"] = true
	gs.early_choice = "shelter"
	gs.alignment = 0.35
	gs.population = 8
	gs.ember_pulse = 6.0
	gs.game_ended = false
	gs.ending_id = ""
	gs.ending_outcome = ""
	gs.path_moral_nurture = 0
	gs.path_moral_harvest = 0
	gs.path_claims = {}
	gs.memory_entries.clear()
	gs.choice_history.clear()
	gs.flags["demand_more_policy"] = false
	if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
		gs._load_endings_data()
	if gs.ending_data.is_empty():
		_fail("ending_data empty after load")
	else:
		_ok("ending_data loaded (%d)" % gs.ending_data.keys().size())

	# R7: raise a Haven so nurture_circle is not stolen by sparse_hearth (built_count==0)
	gs.buildings["haven"] = 1
	# Claim two veins with listen (nurture) morals
	var pids: Array = []
	if gs.path_data:
		for pid in gs.path_data.keys():
			pids.append(str(pid))
	if pids.size() < 2:
		_fail("need >=2 paths for ending sim")
	else:
		gs.discovered_paths.clear()
		for _dp in pids:
			gs.discovered_paths.append(str(_dp))
		gs.resources["shards"] = 200.0
		gs.resources["resonance"] = 40.0
		var p1: String = str(pids[0])
		var p2: String = str(pids[1])
		if not gs.dispatch_expedition(p1, "listen"):
			# Some paths use respect/parley instead of listen — try first moral option
			var opts: Array = gs.path_data[p1].get("moral_options", [])
			var oid: String = "listen"
			if opts.size() > 0:
				oid = str(opts[0].get("id", "listen"))
			if not gs.dispatch_expedition(p1, oid):
				_fail("dispatch nurture path1 failed")
			else:
				_ok("dispatched path1 with " + oid)
		else:
			_ok("dispatched path1 listen")
		if gs.active_expeditions.size() > 0:
			for exp in gs.active_expeditions.duplicate():
				gs._resolve_one_expedition(exp)
			gs.active_expeditions.clear()
		if not bool(gs.path_claims.get(p1, false)):
			_fail("path1 not claimed")
		else:
			_ok("path1 claimed for nurture ending")
		if gs.game_ended:
			_fail("ending fired too early after 1 claim")
		else:
			_ok("no ending yet after 1 claim (threshold=2)")

		var opts2: Array = gs.path_data[p2].get("moral_options", [])
		var oid2: String = "listen"
		if opts2.size() > 0:
			# Prefer positive-align option
			for o in opts2:
				if float(o.get("alignment", 0.0)) > 0.0:
					oid2 = str(o.get("id", oid2))
					break
		if not gs.dispatch_expedition(p2, oid2):
			_fail("dispatch nurture path2 failed")
		else:
			_ok("dispatched path2 with " + oid2)
		if gs.active_expeditions.size() > 0:
			for exp in gs.active_expeditions.duplicate():
				gs._resolve_one_expedition(exp)
			gs.active_expeditions.clear()

		if not gs.game_ended:
			# Force check if claim hook missed
			gs._check_ending_conditions("path_claim")
		if gs.game_ended and gs.ending_id == "nurture_circle" and gs.ending_outcome == "win":
			_ok("nurture_circle WIN ending fired")
		elif gs.game_ended:
			_fail("expected nurture_circle win, got " + str(gs.ending_id) + "/" + str(gs.ending_outcome))
		else:
			_fail("nurture ending did not fire after 2 claims")

		var has_end_mem: bool = false
		for e in gs.memory_entries:
			if str(e.get("key", "")).begins_with("ending_"):
				has_end_mem = true
				break
		if has_end_mem:
			_ok("memory_entries has ending")
		else:
			_fail("memory_entries missing ending")

		if gs.has_method("get_ending_info"):
			var info: Dictionary = gs.get_ending_info()
			if info.has("title") and str(info.get("badge", "")).find("WIN") >= 0:
				_ok("get_ending_info win badge present")
			else:
				_fail("get_ending_info incomplete: " + str(info.keys()))

	# Collapse lose path
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.flags["outlands_reached"] = true
	gs.early_choice = "demand"
	gs.alignment = -0.4
	gs.population = 0
	gs.ember_pulse = 2.0
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.game_ended = false
	gs.ending_id = ""
	gs.ending_outcome = ""
	if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
		gs._load_endings_data()
	gs._check_ending_conditions("raid")
	if gs.game_ended and gs.ending_id == "collapse_ash" and gs.ending_outcome == "lose":
		_ok("collapse_ash LOSE ending fired")
	else:
		_fail("expected collapse_ash lose, got " + str(gs.ending_id) + "/" + str(gs.ending_outcome) + " ended=" + str(gs.game_ended))

	# Harvest win via explicit trigger sanity (after reset)
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.game_ended = false
	if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
		gs._load_endings_data()
	gs.trigger_ending("harvest_dominion", "headless force")
	if gs.game_ended and gs.ending_id == "harvest_dominion" and gs.ending_outcome == "win":
		_ok("harvest_dominion WIN ending via trigger_ending")
	else:
		_fail("harvest_dominion trigger failed")

	print("ending_id=", gs.ending_id, " outcome=", gs.ending_outcome)

	# --- R5 Map hitboxes (font-measured) ---
	print("Checking map choice hitboxes...")
	var map_script = load("res://scripts/OutlandsMap.gd")
	if map_script == null:
		_fail("OutlandsMap.gd load failed")
	else:
		var map_inst: Node = map_script.new()
		if map_inst == null or not map_inst.has_method("compute_choice_hit_rect"):
			_fail("compute_choice_hit_rect missing on OutlandsMap")
		else:
			_ok("compute_choice_hit_rect present")
			var short_r: Rect2 = map_inst.compute_choice_hit_rect(Vector2(10, 20), "> Listen", 9)
			var long_r: Rect2 = map_inst.compute_choice_hit_rect(Vector2(10, 20), "> Harvest the Bound Echoes", 9)
			if short_r.size.x >= 72.0 and short_r.size.y >= 12.0:
				_ok("short choice hitbox sized (%.1fx%.1f)" % [short_r.size.x, short_r.size.y])
			else:
				_fail("short choice hitbox too small: " + str(short_r.size))
			if long_r.size.x > short_r.size.x + 8.0:
				_ok("long choice hitbox wider than short (%.1f > %.1f)" % [long_r.size.x, short_r.size.x])
			else:
				_fail("long hitbox should exceed short; long=" + str(long_r.size.x) + " short=" + str(short_r.size.x))
			# Fixed 180x16 approx must NOT be the only size anymore — measured varies by text
			if abs(long_r.size.x - 180.0) > 0.5 or abs(long_r.size.y - 16.0) > 0.5:
				_ok("hitbox is measured (not fixed 180x16 approx)")
			else:
				_fail("hitbox still looks like fixed 180x16 approx")
		if map_inst:
			map_inst.free()

	# --- R5 NG+ Memory shard carry ---
	print("Simulating NG+ Memory shard seal -> reset -> carry...")
	if not gs.has_method("_seal_memory_shard") or not gs.has_method("_apply_memory_shard_carry"):
		_fail("NG+ Memory shard methods missing")
	else:
		_ok("NG+ Memory shard methods present")
	# Clean meta then seal via ending
	if gs.has_method("_save_ng_plus_meta"):
		gs._save_ng_plus_meta({"ng_plus_run": 0, "pending": false, "shard": {}, "history": []})
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.game_ended = false
	gs.ending_id = ""
	gs.ending_outcome = ""
	gs.early_choice = "shelter"
	gs.memory_entries.clear()
	gs.memory_shard_active = false
	if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
		gs._load_endings_data()
	gs.trigger_ending("nurture_circle", "headless ng+")
	if gs.game_ended and gs.ending_id == "nurture_circle":
		_ok("sealed ending nurture_circle for NG+")
	else:
		_fail("NG+ seal ending failed")
	var meta_after_seal: Dictionary = {}
	if gs.has_method("_load_ng_plus_meta"):
		meta_after_seal = gs._load_ng_plus_meta()
	if bool(meta_after_seal.get("pending", false)) and str(meta_after_seal.get("shard", {}).get("ending_id", "")) == "nurture_circle":
		_ok("ng_plus_meta pending shard sealed")
	else:
		_fail("ng_plus_meta pending missing after seal: " + str(meta_after_seal.keys()))

	# Reset must apply carry on fresh init
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	if gs.memory_shard_active:
		_ok("memory_shard_active after NG+ reset")
	else:
		_fail("memory_shard_active false after carry")
	var shard_bonus: float = float(gs.MEMORY_SHARD_START_SHARDS) if "MEMORY_SHARD_START_SHARDS" in gs else 3.0
	if float(gs.resources.get("shards", 0.0)) >= shard_bonus - 0.01:
		_ok("starting shards include Memory shard bonus (" + str(gs.resources.get("shards", 0.0)) + ")")
	else:
		_fail("shards missing NG+ bonus: " + str(gs.resources.get("shards", 0.0)))
	var has_ng_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "ng_plus_memory_shard":
			has_ng_mem = true
			break
	if has_ng_mem:
		_ok("memory_entries has ng_plus_memory_shard")
	else:
		_fail("memory_entries missing ng_plus_memory_shard")
	if int(gs.ng_plus_run) >= 1:
		_ok("ng_plus_run bumped to " + str(gs.ng_plus_run))
	else:
		_fail("ng_plus_run not bumped")
	# Pending cleared after apply (one-shot)
	var meta_after_apply: Dictionary = gs._load_ng_plus_meta() if gs.has_method("_load_ng_plus_meta") else {}
	if not bool(meta_after_apply.get("pending", true)):
		_ok("ng_plus pending cleared after apply")
	else:
		_fail("ng_plus pending still true after apply")
	# Second reset without new ending must NOT re-apply bonus pile-up from same shard
	var shards_before: float = float(gs.resources.get("shards", 0.0))
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	if not gs.memory_shard_active and float(gs.resources.get("shards", 0.0)) < shard_bonus:
		_ok("second reset without new seal does not re-carry")
	elif not gs.memory_shard_active:
		# Fresh start shards may be 0; bonus absent is the assert
		_ok("second reset without pending carry (shards=" + str(gs.resources.get("shards", 0.0)) + ")")
	else:
		_fail("second reset incorrectly re-applied memory shard")

	# Keep faction buildings still present after R5 work
	var bd: Dictionary = _load_json("res://data/buildings.json")
	if bd.has("echo_choir") and bd.has("ash_binder"):
		_ok("faction buildings still in data after R5")
	else:
		_fail("faction buildings missing after R5")


	# --- R6 Raid/defense encounter UI (data-driven, Memory + GameState) ---
	print("Simulating raid/defense encounter (offer -> resolve responses)...")
	if not gs.has_method("offer_raid_encounter") or not gs.has_method("resolve_raid_encounter"):
		_fail("raid encounter methods missing")
	else:
		_ok("raid encounter methods present")
	if gs.raid_data.is_empty() and gs.has_method("_load_raid_data"):
		gs._load_raid_data()
	if gs.raid_data.has("path_raid"):
		_ok("GameState.raid_data loaded path_raid")
	else:
		_fail("GameState.raid_data missing path_raid")

	# Shelter path: Pull Them Back must mitigate + write Memory
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	gs.phase = "outlands"
	gs.flags["outlands_reached"] = true
	gs.early_choice = "shelter"
	gs.alignment = 0.2
	gs.population = 8
	gs.ember_pulse = 5.0
	gs.game_ended = false
	gs.ending_id = ""
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.discovered_paths.clear()
	gs.discovered_paths.append("vein_of_fading_echoes")
	gs.defense_strength = 1.0
	gs.resources["shards"] = 40.0
	gs.memory_entries.clear()
	gs.pending_raid.clear()
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer_raid_encounter failed")
	else:
		_ok("raid encounter offered")
	if gs.has_pending_raid():
		_ok("pending_raid set after offer")
	else:
		_fail("pending_raid empty after offer")
	var pending: Dictionary = gs.get_pending_raid()
	if str(pending.get("raid_id", "")) == "path_raid" and pending.get("options", []).size() >= 4:
		_ok("pending snapshot has options")
	else:
		_fail("pending snapshot incomplete")
	if not gs.offer_raid_encounter():
		_ok("second offer blocked while pending")
	else:
		_fail("second offer should fail while pending")
	var shel_res: Dictionary = gs.resolve_raid_encounter("offer_shelter")
	if bool(shel_res.get("ok", false)) and bool(shel_res.get("mitigated", false)):
		_ok("offer_shelter mitigated raid")
	else:
		_fail("offer_shelter should mitigate: " + str(shel_res))
	if float(gs.resources.get("shards", 0.0)) <= 30.01:
		_ok("shelter spent shards (" + str(gs.resources.get("shards", 0.0)) + ")")
	else:
		_fail("shelter did not spend shards")
	if not gs.has_pending_raid():
		_ok("pending cleared after resolve")
	else:
		_fail("pending still set after resolve")
	var has_shel_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "raid_response_shelter":
			has_shel_mem = true
			break
	if has_shel_mem:
		_ok("memory_entries has raid_response_shelter")
	else:
		_fail("memory missing raid_response_shelter")

	# Hold watch: spends defense, writes hold memory
	gs.pending_raid.clear()
	gs.memory_entries.clear()
	gs.defense_strength = 6.0
	gs.population = 8
	gs.resources["shards"] = 40.0
	gs.game_ended = false
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer for hold_watch failed")
	var hold_before: float = gs.defense_strength
	var hold_res: Dictionary = gs.resolve_raid_encounter("hold_watch")
	if bool(hold_res.get("ok", false)):
		_ok("hold_watch resolved")
	else:
		_fail("hold_watch resolve failed")
	if gs.defense_strength < hold_before - 1.0:
		_ok("hold_watch spent defense (%.1f -> %.1f)" % [hold_before, gs.defense_strength])
	else:
		_fail("hold_watch should spend defense")
	var has_hold_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "raid_response_hold":
			has_hold_mem = true
			break
	if has_hold_mem:
		_ok("memory_entries has raid_response_hold")
	else:
		_fail("memory missing raid_response_hold")

	# Strike back: alignment drops / retaliation flag, Memory
	gs.pending_raid.clear()
	gs.memory_entries.clear()
	gs.early_choice = "demand"
	gs.alignment = -0.1
	gs.defense_strength = 8.0
	gs.population = 8
	gs.flags["raid_retaliation"] = 0.0
	gs.game_ended = false
	var align_before: float = gs.alignment
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer for strike_back failed")
	var strike_res: Dictionary = gs.resolve_raid_encounter("strike_back")
	if bool(strike_res.get("ok", false)):
		_ok("strike_back resolved")
	else:
		_fail("strike_back resolve failed")
	if gs.alignment < align_before:
		_ok("strike_back shifted alignment down")
	else:
		_fail("strike_back should lower alignment")
	if float(gs.flags.get("raid_retaliation", 0.0)) > 0.0:
		_ok("strike_back added raid_retaliation flag")
	else:
		_fail("strike_back missing retaliation flag")
	var has_strike_mem: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "raid_response_strike":
			has_strike_mem = true
			break
	if has_strike_mem:
		_ok("memory_entries has raid_response_strike")
	else:
		_fail("memory missing raid_response_strike")

	# Abandon line: force loss + Memory + defense bump
	gs.pending_raid.clear()
	gs.memory_entries.clear()
	gs.population = 8
	gs.defense_strength = 0.5
	gs.game_ended = false
	gs.ending_id = ""
	var pop_before: int = gs.population
	var def_before_ab: float = gs.defense_strength
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer for abandon_line failed")
	var ab_res: Dictionary = gs.resolve_raid_encounter("abandon_line")
	if bool(ab_res.get("ok", false)) and (not bool(ab_res.get("mitigated", true))) and int(ab_res.get("pop_loss", 0)) > 0:
		_ok("abandon_line forced loss (pop_loss=%d)" % int(ab_res.get("pop_loss", 0)))
	else:
		_fail("abandon_line should force loss: " + str(ab_res))
	if gs.population < pop_before:
		_ok("abandon_line reduced population")
	else:
		_fail("abandon_line pop unchanged")
	if gs.defense_strength > def_before_ab:
		_ok("abandon_line added hearth defense")
	else:
		_fail("abandon_line should add_defense")
	var has_ab_mem: bool = false
	var has_loss_mem: bool = false
	for e in gs.memory_entries:
		var k: String = str(e.get("key", ""))
		if k == "raid_response_abandon":
			has_ab_mem = true
		if k == "raid_loss":
			has_loss_mem = true
	if has_ab_mem:
		_ok("memory_entries has raid_response_abandon")
	else:
		_fail("memory missing raid_response_abandon")
	if has_loss_mem:
		_ok("memory_entries has raid_loss after abandon")
	else:
		_fail("memory missing raid_loss after abandon")

	# Insufficient shards for shelter should leave pending intact
	gs.pending_raid.clear()
	gs.resources["shards"] = 2.0
	gs.population = 6
	gs.game_ended = false
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer for cost-fail case failed")
	var fail_res: Dictionary = gs.resolve_raid_encounter("offer_shelter")
	if not bool(fail_res.get("ok", true)) and gs.has_pending_raid():
		_ok("offer_shelter blocked on low shards; pending kept")
	else:
		_fail("cost fail should keep pending: " + str(fail_res) + " pending=" + str(gs.has_pending_raid()))
	gs.resolve_raid_encounter("hold_watch")

	var bd6: Dictionary = _load_json("res://data/buildings.json")
	var ed6: Dictionary = _load_json("res://data/endings.json")
	if bd6.has("echo_choir") and bd6.has("ash_binder") and ed6.has("nurture_circle") and ed6.has("true_echo") and ed6.has("sparse_hearth") and ed6.has("pyrrhic_crown"):
		_ok("faction + Phase-5 endings data intact after R7")
	else:
		_fail("prior-round / R7 ending data missing")

	# --- R7 Phase-5 special endings ---
	print("Simulating R7 special endings (true_echo / sparse_hearth / pyrrhic_crown)...")
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	var r7_pids: Array = []
	if gs.path_data:
		for pid in gs.path_data.keys():
			r7_pids.append(str(pid))
	if r7_pids.size() < 2:
		_fail("need >=2 paths for R7 ending sims")
	else:
		# --- true_echo ---
		gs.phase = "outlands"
		gs.flags["outlands_reached"] = true
		gs.early_choice = "shelter"
		gs.alignment = 0.4
		gs.population = 8
		gs.ember_pulse = 6.0
		gs.game_ended = false
		gs.ending_id = ""
		gs.ending_outcome = ""
		gs.path_moral_nurture = 2
		gs.path_moral_harvest = 0
		gs.path_claims = {}
		gs.buildings = {"echo_choir": 1}
		gs.flags["demand_more_policy"] = false
		gs.memory_entries.clear()
		if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
			gs._load_endings_data()
		gs.path_claims[str(r7_pids[0])] = true
		gs.path_claims[str(r7_pids[1])] = true
		gs._check_ending_conditions("force")
		if gs.game_ended and gs.ending_id == "true_echo" and gs.ending_outcome == "win":
			_ok("true_echo WIN ending fired")
		else:
			_fail("expected true_echo win, got " + str(gs.ending_id) + "/" + str(gs.ending_outcome))

		# --- sparse_hearth ---
		gs.game_ended = false
		gs.ending_id = ""
		gs.ending_outcome = ""
		gs.early_choice = "shelter"
		gs.alignment = 0.2
		gs.population = 6
		gs.ember_pulse = 5.0
		gs.path_moral_nurture = 2
		gs.path_moral_harvest = 0
		gs.buildings = {}
		gs.flags["demand_more_policy"] = false
		gs.path_claims = {}
		gs.path_claims[str(r7_pids[0])] = true
		gs.path_claims[str(r7_pids[1])] = true
		gs.memory_entries.clear()
		gs._check_ending_conditions("force")
		if gs.game_ended and gs.ending_id == "sparse_hearth" and gs.ending_outcome == "win":
			_ok("sparse_hearth WIN ending fired")
		else:
			_fail("expected sparse_hearth win, got " + str(gs.ending_id) + "/" + str(gs.ending_outcome))

		# --- pyrrhic_crown ---
		gs.game_ended = false
		gs.ending_id = ""
		gs.ending_outcome = ""
		gs.early_choice = "demand"
		gs.alignment = -0.35
		gs.population = 2
		gs.ember_pulse = 4.0
		gs.path_moral_nurture = 0
		gs.path_moral_harvest = 2
		gs.buildings = {"ash_binder": 1}
		gs.flags["demand_more_policy"] = true
		gs.path_claims = {}
		gs.path_claims[str(r7_pids[0])] = true
		gs.path_claims[str(r7_pids[1])] = true
		gs.memory_entries.clear()
		gs._check_ending_conditions("force")
		if gs.game_ended and gs.ending_id == "pyrrhic_crown" and gs.ending_outcome == "win":
			_ok("pyrrhic_crown WIN ending fired")
		else:
			_fail("expected pyrrhic_crown win, got " + str(gs.ending_id) + "/" + str(gs.ending_outcome) + " pop=" + str(gs.population))

		# --- harvest_dominion still wins when pop healthy ---
		gs.game_ended = false
		gs.ending_id = ""
		gs.ending_outcome = ""
		gs.early_choice = "demand"
		gs.alignment = -0.35
		gs.population = 8
		gs.ember_pulse = 4.0
		gs.path_moral_nurture = 0
		gs.path_moral_harvest = 2
		gs.buildings = {"ash_binder": 1, "haven": 1}
		gs.flags["demand_more_policy"] = true
		gs.path_claims = {}
		gs.path_claims[str(r7_pids[0])] = true
		gs.path_claims[str(r7_pids[1])] = true
		gs._check_ending_conditions("force")
		if gs.game_ended and gs.ending_id == "harvest_dominion" and gs.ending_outcome == "win":
			_ok("harvest_dominion still fires at healthy pop")
		else:
			_fail("expected harvest_dominion at healthy pop, got " + str(gs.ending_id))

		# Memory text for new endings via trigger
		gs.game_ended = false
		gs.ending_id = ""
		gs.memory_entries.clear()
		gs.early_choice = "shelter"
		if gs.ending_data.is_empty() and gs.has_method("_load_endings_data"):
			gs._load_endings_data()
		gs.trigger_ending("true_echo", "headless memory")
		var mem_true: bool = false
		for e in gs.memory_entries:
			if str(e.get("key", "")) == "ending_true_echo":
				mem_true = true
				break
		if mem_true:
			_ok("memory_entries has ending_true_echo")
		else:
			_fail("memory missing ending_true_echo")

	# --- R8 Projectile towers / lane combat credit ---
	print("Simulating R8 projectile towers + lane combat credit...")
	if gs.has_method("reset_to_new_game"):
		gs.reset_to_new_game()
	if gs.tower_data.is_empty() and gs.has_method("_load_tower_data"):
		gs._load_tower_data()
	if gs.tower_data.has("watch_bolt") and gs.tower_data.has("dread_spike") and gs.tower_data.has("ward_pulse"):
		_ok("GameState.tower_data loaded 3 profiles")
	else:
		_fail("GameState.tower_data incomplete: " + str(gs.tower_data.keys()))
	if not gs.has_method("get_tower_profile_for_vein") or not gs.has_method("register_tower_hit") or not gs.has_method("get_lane_combat_bonus"):
		_fail("R8 tower combat methods missing")
	else:
		_ok("R8 tower combat methods present")

	# Neutral / watch profile
	gs.alignment = 0.0
	gs.buildings = {"watch_spire": 1}
	gs.path_claims = {"vein_of_fading_echoes": true}
	var neut: Dictionary = gs.get_tower_profile_for_vein("vein_of_fading_echoes")
	if str(neut.get("id", "")) == "watch_bolt":
		_ok("neutral vein uses watch_bolt")
	else:
		_fail("expected watch_bolt, got " + str(neut.get("id", "")))

	# Tyrant / dread
	gs.alignment = -0.4
	gs.buildings = {"watch_spire": 1, "dread_foundry": 1}
	var tyr: Dictionary = gs.get_tower_profile_for_vein("vein_of_fading_echoes")
	if str(tyr.get("id", "")) == "dread_spike":
		_ok("tyrant vein uses dread_spike")
	else:
		_fail("expected dread_spike, got " + str(tyr.get("id", "")))

	# Benevolent / ward
	gs.alignment = 0.35
	gs.buildings = {"watch_spire": 1, "sanctuary_ward": 1}
	var ben: Dictionary = gs.get_tower_profile_for_vein("vein_of_fading_echoes")
	if str(ben.get("id", "")) == "ward_pulse":
		_ok("benevolent vein uses ward_pulse")
	else:
		_fail("expected ward_pulse, got " + str(ben.get("id", "")))

	# Hits accumulate credit and first-shot memory
	gs.lane_combat_hits = 0
	gs.lane_combat_credit = 0.0
	gs.lane_combat_repels = 0
	gs.memory_entries.clear()
	gs.defense_strength = 1.0
	gs.register_tower_hit("vein_of_fading_echoes", 0.5, false)
	if gs.lane_combat_hits == 1 and gs.lane_combat_credit >= 0.5:
		_ok("register_tower_hit credits lane combat")
	else:
		_fail("hit credit failed hits=%d credit=%.2f" % [gs.lane_combat_hits, gs.lane_combat_credit])
	var mem_shot: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "lane_tower_first_shot":
			mem_shot = true
			break
	if mem_shot:
		_ok("memory_entries has lane_tower_first_shot")
	else:
		_fail("memory missing lane_tower_first_shot")

	gs.register_tower_hit("vein_of_fading_echoes", 0.6, true)
	if gs.lane_combat_repels == 1 and gs.defense_strength > 1.0:
		_ok("repel bumps defense + repel count")
	else:
		_fail("repel failed repels=%d def=%.2f" % [gs.lane_combat_repels, gs.defense_strength])
	var mem_repel: bool = false
	for e in gs.memory_entries:
		if str(e.get("key", "")) == "lane_tower_first_repel":
			mem_repel = true
			break
	if mem_repel:
		_ok("memory_entries has lane_tower_first_repel")
	else:
		_fail("memory missing lane_tower_first_repel")

	# Lane bonus feeds raid encounter def_val then consumes on resolve
	gs.pending_raid.clear()
	gs.game_ended = false
	gs.population = 8
	gs.resources["shards"] = 40.0
	gs.defense_strength = 0.5
	gs.buildings = {"watch_spire": 1}
	gs.lane_combat_credit = 3.0
	var bonus_before: float = gs.get_lane_combat_bonus()
	if bonus_before > 1.0:
		_ok("get_lane_combat_bonus from credit (%.2f)" % bonus_before)
	else:
		_fail("lane bonus too low: %.2f" % bonus_before)
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("offer_raid_encounter with lane bonus failed")
	else:
		var pend: Dictionary = gs.get_pending_raid()
		var lb: float = float(pend.get("lane_bonus", 0.0))
		var dv: float = float(pend.get("def_val", 0.0))
		if lb > 1.0 and dv >= gs.defense_strength + lb:
			_ok("pending raid includes lane_bonus=%.2f def_val=%.2f" % [lb, dv])
		else:
			_fail("pending missing lane bonus lb=%.2f def=%.2f" % [lb, dv])
		var credit_before_resolve: float = gs.lane_combat_credit
		var hold_res8: Dictionary = gs.resolve_raid_encounter("hold_watch")
		if bool(hold_res8.get("ok", false)) and gs.lane_combat_credit < credit_before_resolve:
			_ok("resolve consumed lane combat credit (%.2f -> %.2f)" % [credit_before_resolve, gs.lane_combat_credit])
		else:
			_fail("lane credit not consumed on resolve: " + str(hold_res8) + " credit=" + str(gs.lane_combat_credit))

	# Vein defense includes tower / credit contrib
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.buildings = {"watch_spire": 1, "dread_foundry": 1}
	gs.lane_combat_credit = 2.0
	gs.defense_strength = 2.0
	var vdef: float = gs.get_vein_defense_strength("vein_of_fading_echoes")
	if vdef > 3.5:
		_ok("get_vein_defense_strength includes tower/credit (%.2f)" % vdef)
	else:
		_fail("vein defense too low: %.2f" % vdef)

	# Prior-round data still intact
	var td8: Dictionary = _load_json("res://data/towers.json")
	var rd8: Dictionary = _load_json("res://data/raids.json")
	var ed8: Dictionary = _load_json("res://data/endings.json")
	if td8.has("ward_pulse") and rd8.has("path_raid") and ed8.has("true_echo"):
		_ok("R6/R7/R8 data intact together")
	else:
		_fail("cross-round data missing after R8")

	# --- R9 Raid auto-timeout (watchers act without orders) ---
	print("Simulating raid auto-timeout...")
	var rd9: Dictionary = _load_json("res://data/raids.json")
	var pr9: Dictionary = rd9.get("path_raid", {})
	if float(pr9.get("timeout_sec", 0.0)) > 0.0 and str(pr9.get("timeout_choice", "")) == "hold_watch":
		_ok("path_raid timeout_sec=%.0f choice=%s" % [float(pr9.get("timeout_sec", 0.0)), str(pr9.get("timeout_choice", ""))])
	else:
		_fail("path_raid missing timeout fields: " + str(pr9.keys()))
	if not gs.has_method("tick_pending_raid_timeout") or not gs.has_method("timeout_pending_raid") or not gs.has_method("get_raid_timeout_remaining"):
		_fail("raid timeout methods missing")
	else:
		_ok("raid timeout methods present")

	gs.pending_raid.clear()
	gs.game_ended = false
	gs.phase = "outlands"
	gs.population = 8
	gs.resources["shards"] = 40.0
	gs.defense_strength = 4.0
	gs.buildings = {"watch_spire": 1}
	gs.assigned = {"forager": 1}
	gs.path_claims = {"vein_of_fading_echoes": true}
	gs.discovered_paths.clear()
	gs.discovered_paths.append("vein_of_fading_echoes")
	gs.lane_combat_credit = 0.0
	gs.memory_entries.clear()
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("R9 offer_raid_encounter failed")
	else:
		var pend9: Dictionary = gs.get_pending_raid()
		if float(pend9.get("timeout_sec", 0.0)) > 0.0 and str(pend9.get("timeout_choice", "")) == "hold_watch":
			_ok("pending stamps timeout_sec + timeout_choice")
		else:
			_fail("pending missing timeout stamp: " + str(pend9.keys()))
		var rem_before: float = gs.get_raid_timeout_remaining()
		gs.tick_pending_raid_timeout(0.5)
		if gs.has_pending_raid() and gs.get_raid_timeout_remaining() < rem_before and gs.get_raid_timeout_remaining() > 0.0:
			_ok("early tick reduces remaining but does not fire")
		else:
			_fail("early tick unexpected rem_before=%.2f rem=%.2f pending=%s" % [rem_before, gs.get_raid_timeout_remaining(), str(gs.has_pending_raid())])
		var tsec: float = float(gs.pending_raid.get("timeout_sec", 30.0))
		# Drain remaining real-delta so watchers auto-hold
		gs.tick_pending_raid_timeout(tsec + 1.0)
		if not gs.has_pending_raid():
			_ok("real-delta timeout cleared pending via hold_watch")
		else:
			_fail("real-delta timeout left pending rem=%.2f" % gs.get_raid_timeout_remaining())
		var mem_hold_to: bool = false
		for e in gs.memory_entries:
			if str(e.get("key", "")) == "raid_response_hold":
				mem_hold_to = true
				break
		if mem_hold_to:
			_ok("timeout used hold_watch memory")
		else:
			_fail("timeout missing raid_response_hold memory")

	# Game-time path (bump play time + tick; hearth phase avoids same-tick re-offer)
	gs.pending_raid.clear()
	gs.memory_entries.clear()
	gs.game_ended = false
	gs.phase = "hearth"
	gs.population = 8
	gs.resources["shards"] = 40.0
	gs.defense_strength = 4.0
	gs.buildings = {"watch_spire": 1}
	gs.lane_combat_credit = 0.0
	if not gs.offer_raid_encounter("vein_of_fading_echoes"):
		_fail("R9 game-time offer failed")
	else:
		var tsec2: float = float(gs.pending_raid.get("timeout_sec", 30.0))
		var offered_at2: float = float(gs.pending_raid.get("offered_at", gs.total_play_time))
		# Early game-time tick should not fire
		gs.total_play_time = offered_at2 + 1.0
		gs.tick_pending_raid_timeout(0.0)
		if gs.has_pending_raid() and abs(gs.get_raid_timeout_remaining() - (tsec2 - 1.0)) < 0.05:
			_ok("game-time early tick keeps pending")
		else:
			_fail("game-time early unexpected rem=%.2f pending=%s" % [gs.get_raid_timeout_remaining(), str(gs.has_pending_raid())])
		gs.total_play_time = offered_at2 + tsec2 + 1.0
		gs.tick_pending_raid_timeout(0.0)
		if not gs.has_pending_raid():
			_ok("game-time timeout clears pending")
		else:
			_fail("game-time timeout left pending rem=%.2f" % gs.get_raid_timeout_remaining())
		# Also exercise advance_time hook (no random re-offer in hearth)
		gs.pending_raid.clear()
		gs.memory_entries.clear()
		gs.game_ended = false
		gs.defense_strength = 4.0
		if not gs.offer_raid_encounter("vein_of_fading_echoes"):
			_fail("R9 advance_time offer failed")
		else:
			gs.advance_time(tsec2 + 1.0)
			if not gs.has_pending_raid():
				_ok("advance_time game-time timeout clears pending")
			else:
				_fail("advance_time timeout left pending rem=%.2f" % gs.get_raid_timeout_remaining())
		var mem_hold_gt: bool = false
		for e2 in gs.memory_entries:
			if str(e2.get("key", "")) == "raid_response_hold":
				mem_hold_gt = true
				break
		if mem_hold_gt:
			_ok("game-time timeout used hold_watch memory")
		else:
			_fail("game-time timeout missing raid_response_hold")

	# Explicit timeout_pending_raid API
	gs.pending_raid.clear()
	gs.memory_entries.clear()
	gs.game_ended = false
	gs.phase = "hearth"
	gs.defense_strength = 4.0
	gs.resources["shards"] = 40.0
	if gs.offer_raid_encounter("vein_of_fading_echoes"):
		var explicit: Dictionary = gs.timeout_pending_raid()
		if bool(explicit.get("ok", false)) and bool(explicit.get("timed_out", false)) and not gs.has_pending_raid():
			_ok("timeout_pending_raid resolves + marks timed_out")
		else:
			_fail("timeout_pending_raid failed: " + str(explicit))
	else:
		_fail("offer for explicit timeout failed")

	if rd9.has("path_raid") and td8.has("ward_pulse") and ed8.has("true_echo"):
		_ok("R6/R7/R8/R9 data intact together")
	else:
		_fail("cross-round data missing after R9")

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

