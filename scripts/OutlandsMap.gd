@tool
extends Node2D
class_name OutlandsMap

# Dedicated 2D schematic map scene for accelerated RTS/TD redesign (per approved plan: "schematic visual map with moving elements", visual moral/alignment state, production queues, faction branching).
# Lightweight: manual progress on pre-defined lines from data visual metadata + hardcoded fallback.
# Polls GameState (get_path_visual_data, get_path_progress, get_vein_defense_strength, path_claims, active_expeditions, alignment, defense_strength, ember_pulse, buildings, early_choice, production_queue).
# Editor friendly: static Line2D veins in .tscn show even without run; @tool + mocks allow live preview.
# Self-contained for later MapPanel instancing + update_from_gamestate() / focus_vein / dispatch_on_vein calls.
# Enhanced: faction tower variants (dread spikes red vs ward glow green using buildings + align), production labor dots (bound_figure + anim on veins when queue labor/spire), click interaction offers moral dispatch (auto + signal + hint labels), raid thicker anim lines, binding fx with weight_accent, etc. API compat preserved.

signal vein_focused(path_id: String)
signal dispatch_requested(path_id: String, choice: String)
# For map interaction offering moral choices directly (Main can connect to trigger custom choice UI or auto; per task)
signal moral_choice_offered(path_id: String, options: Array)

const PATH_IDS: Array[String] = [
	"vein_of_fading_echoes",
	"shattered_crossing",
	"hollow_of_silent_bound",
	"vein_of_broken_circles"
]

const HARDCODED_VISUALS: Dictionary = {
	"vein_of_fading_echoes": {"angle_deg": 30, "radius": 120, "length": 95},
	"shattered_crossing": {"angle_deg": 120, "radius": 120, "length": 95},
	"hollow_of_silent_bound": {"angle_deg": 210, "radius": 120, "length": 95},
	"vein_of_broken_circles": {"angle_deg": 300, "radius": 120, "length": 95}
}

var path_visuals: Dictionary = {}
var vein_lines: Dictionary = {}      # path_id -> Line2D (pre-placed in tscn for editor preview)
var entity_nodes: Dictionary = {}    # "exp_xxx" / "raid_xxx" -> Polygon2D icons
var tower_nodes: Dictionary = {}     # path_id -> Polygon2D (watch_spire + faction variants)
var highlight: Line2D = null
var hearth: Sprite2D = null

var selected_path: String = ""
var raid_progress: Dictionary = {}   # path_id -> float (1.0 far/out -> 0.0 at hearth/in)
var prev_claims: Dictionary = {}
var _last_visual_update: float = 0.0
var _raid_spawn_timer: float = 0.0

# Art assets for polish (bound_figure for labor/builder icons per "use more of the art", weight_accent for binding/claim effects)
var bound_figure_tex: Texture2D = null
var weight_accent_tex: Texture2D = null

# Production indicators + labor dots (moving along veins when queue active; tied to production_queue labor/spire)
var labor_nodes: Dictionary = {}  # path_id -> Array[Node2D] small labor/builder sprites moving
var production_active: Dictionary = {}  # path_id -> {"labor": bool, "spire": bool, "boost": float} for this refresh
var raid_line_nodes: Dictionary = {}  # path_id -> Line2D for thicker/animated raid threat line (more visible movement)

# Ash Whispers icons on map: for area-tied events, show pulsing notification icon (warm/echo marker) on the affected vein. Creative visual for "whisper from the ash" on that area.
var whisper_nodes: Dictionary = {}  # path_id -> Node2D (simple pulsing marker for active whisper on that vein)

# Temp UI for offering moral choices on unclaimed vein click (self-contained in map; calls dispatch_on_vein with specific choice id from data)
var _choice_ui_nodes: Array = []  # temp controls/poly labels for options near vein
var _choice_for_path: String = ""
var _choice_option_hits: Array = []  # {rect: Rect2, id: String, path: String}

func _ready() -> void:
	_load_visual_data()
	_load_art_assets()
	_find_or_create_nodes()
	_setup_highlight()
	# Clear dynamic nodes for fresh (labor, raid lines, choice hints)
	labor_nodes.clear()
	raid_line_nodes.clear()
	production_active.clear()
	whisper_nodes.clear()
	_hide_choice_ui()
	if not Engine.is_editor_hint():
		_connect_signals()
	_update_from_state(true)

func _load_visual_data() -> void:
	path_visuals.clear()
	if GameState and GameState.has_method("get_path_visual_data"):
		for pid in PATH_IDS:
			var v: Dictionary = GameState.get_path_visual_data(pid)
			path_visuals[pid] = v if not v.is_empty() else HARDCODED_VISUALS.get(pid, {})
	else:
		path_visuals = HARDCODED_VISUALS.duplicate(true)

# Load art for labor icons (bound_figure), effects (weight_accent). Fallback safe for editor/@tool.
func _load_art_assets() -> void:
	bound_figure_tex = null
	weight_accent_tex = null
	var bf_path := "res://assets/art/bound_figure.jpg"
	var wa_path := "res://assets/art/weight_accent.jpg"
	if ResourceLoader.exists(bf_path):
		bound_figure_tex = load(bf_path) as Texture2D
	if ResourceLoader.exists(wa_path):
		weight_accent_tex = load(wa_path) as Texture2D

func _find_or_create_nodes() -> void:
	hearth = get_node_or_null("Hearth") as Sprite2D
	if hearth == null:
		hearth = Sprite2D.new()
		hearth.name = "Hearth"
		if ResourceLoader.exists("res://assets/art/ember_pulse.jpg"):
			hearth.texture = load("res://assets/art/ember_pulse.jpg")
		hearth.position = Vector2.ZERO
		hearth.scale = Vector2(0.55, 0.55)
		hearth.modulate = Color(1.0, 0.82, 0.6, 0.85)
		add_child(hearth)

	vein_lines.clear()
	for pid in PATH_IDS:
		var node_name: String = "Vein_" + pid
		var line: Line2D = get_node_or_null(node_name) as Line2D
		if line == null:
			# Runtime create (editor preview relies on tscn static nodes)
			line = Line2D.new()
			line.name = node_name
			var se: Array = _get_vein_start_end(pid)
			line.points = PackedVector2Array([se[0], se[1]])
			line.width = 3.0
			line.default_color = Color(0.4, 0.36, 0.32, 0.65)
			line.antialiased = true
			add_child(line)
		vein_lines[pid] = line

func _setup_highlight() -> void:
	highlight = get_node_or_null("Highlight") as Line2D
	if highlight == null:
		highlight = Line2D.new()
		highlight.name = "Highlight"
		highlight.width = 5.5
		highlight.default_color = Color(0.95, 0.9, 0.65, 0.38)
		highlight.antialiased = true
		highlight.z_index = 5
		add_child(highlight)
	highlight.visible = false

func _connect_signals() -> void:
	if GameEvents:
		if GameEvents.has_signal("raid_occurred"):
			GameEvents.raid_occurred.connect(_on_raid_occurred)
		if GameEvents.has_signal("time_advanced"):
			GameEvents.time_advanced.connect(_on_time_advanced)
		if GameEvents.has_signal("action_performed"):
			GameEvents.action_performed.connect(_on_action_performed)

func _on_time_advanced(_seconds: float) -> void:
	_update_from_state()

func _on_action_performed(_action_id: String, _success: bool) -> void:
	_update_from_state()

func _on_raid_occurred(_mitigated: bool, _pop_loss: int) -> void:
	# Visual raid approach on a claimed vein (or any for preview)
	if path_visuals.is_empty():
		return
	var cands: Array = []
	if GameState:
		for pid in GameState.path_claims:
			if GameState.path_claims.get(pid, false):
				cands.append(pid)
	if cands.is_empty():
		cands = path_visuals.keys()
	if cands.size() > 0:
		var pid: String = cands[randi() % cands.size()]
		raid_progress[pid] = 1.0

func _process(delta: float) -> void:
	_update_pulse(delta)
	_update_moving_entities(delta)
	_update_raid_simulation(delta)

	_last_visual_update += delta
	if _last_visual_update > 0.16 or Engine.is_editor_hint():
		_last_visual_update = 0.0
		_update_from_state(false)

func _update_pulse(_delta: float) -> void:
	if hearth == null or not is_instance_valid(hearth):
		return
	var t: float = Time.get_ticks_msec() / 380.0
	var breathe: float = 1.0 + 0.09 * sin(t)
	var base_scale: float = 0.52
	if GameState and GameState.get("ember_pulse") != null:
		var ep: float = float(GameState.ember_pulse)
		var e: float = clamp(ep / 6.5, 0.0, 1.3)
		hearth.modulate = Color(1.0, 0.83 + e * 0.11, 0.56 + e * 0.28, 0.72 + e * 0.22)
		base_scale = 0.48 + e * 0.18
	hearth.scale = Vector2(base_scale * breathe, base_scale * breathe)

func _update_raid_simulation(delta: float) -> void:
	if Engine.is_editor_hint() and raid_progress.is_empty():
		# Static-ish mock raid for editor preview without run
		raid_progress[PATH_IDS[1]] = 0.72
		raid_progress[PATH_IDS[3]] = 0.31

	_raid_spawn_timer += delta
	var spawn_interval: float = 6.8
	if Engine.is_editor_hint():
		spawn_interval = 1.8
	if _raid_spawn_timer > spawn_interval:
		_raid_spawn_timer = 0.0
		if raid_progress.size() < 2:
			var cands: Array = []
			if GameState:
				for pid in PATH_IDS:
					if GameState.path_claims.get(pid, false):
						cands.append(pid)
			if cands.is_empty():
				cands = PATH_IDS.duplicate()
			if cands.size() > 0:
				var pid: String = cands[randi() % cands.size()]
				if not raid_progress.has(pid):
					raid_progress[pid] = 1.0

	# Advance inward (toward hearth)
	var to_clear: Array = []
	for pid in raid_progress:
		var def: float = 1.0
		if GameState and GameState.has_method("get_vein_defense_strength"):
			def = GameState.get_vein_defense_strength(pid)
		elif Engine.is_editor_hint():
			def = 2.2 if pid == PATH_IDS[0] else 0.7
		var spd: float = 0.105 / max(0.55, 0.6 + def * 0.11)
		raid_progress[pid] = raid_progress[pid] - delta * spd
		if raid_progress[pid] <= 0.0:
			to_clear.append(pid)
			if hearth and is_instance_valid(hearth):
				hearth.modulate = Color(0.75, 0.35, 0.28, 0.9)
	for pid in to_clear:
		raid_progress.erase(pid)
		# Clean associated raid line
		if raid_line_nodes.has(pid):
			var rl: Line2D = raid_line_nodes[pid]
			if is_instance_valid(rl): rl.queue_free()
			raid_line_nodes.erase(pid)

func _update_moving_entities(_delta: float) -> void:
	for key in entity_nodes.keys():
		var icon: Polygon2D = entity_nodes[key]
		if not is_instance_valid(icon):
			continue
		var pid: String = key.substr(4) if key.length() > 4 else ""
		if not path_visuals.has(pid):
			continue
		var frac: float = 0.0
		if key.begins_with("exp_"):
			if GameState:
				frac = GameState.get_path_progress(pid)
			else:
				frac = 0.38  # mock for editor
		elif key.begins_with("raid_"):
			frac = float(raid_progress.get(pid, 0.0))
		var se: Array = _get_vein_start_end(pid)
		var pos: Vector2 = se[0].lerp(se[1], clamp(frac, 0.0, 1.0))
		icon.position = pos
		var dirv: Vector2 = (se[1] - se[0]).normalized()
		var rot: float = dirv.angle()
		if key.begins_with("raid_"):
			icon.rotation = rot + PI
		else:
			icon.rotation = rot

	# Live update labor dots anim (independent of full refresh rate; uses production state)
	for pid in labor_nodes:
		var dots: Array = labor_nodes[pid]
		var pa: Dictionary = production_active.get(pid, {})
		_update_labor_positions(pid, dots, pa)

# === Raid lines for visibility polish (thicker, animated threat lines on raid movement; per task) ===
func _refresh_raid_lines() -> void:
	for pid in raid_progress.keys():
		var frac: float = clamp(float(raid_progress.get(pid, 0.0)), 0.0, 1.0)
		var se: Array = _get_vein_start_end(pid)
		var raid_pos: Vector2 = se[0].lerp(se[1], frac)
		var rl: Line2D = raid_line_nodes.get(pid)
		if rl == null or not is_instance_valid(rl):
			rl = Line2D.new()
			rl.name = "RaidLine_" + pid
			rl.width = 7.0
			rl.default_color = Color(0.65, 0.18, 0.12, 0.65)
			rl.antialiased = true
			rl.z_index = 1
			add_child(rl)
			raid_line_nodes[pid] = rl
		# Partial line from outer (far) to current raid head (makes movement "thicker animated line" visible)
		rl.points = PackedVector2Array([se[1], raid_pos])
		# Animate width + alpha for threat pulse (more visible than dot alone)
		var pulse: float = 0.6 + 0.35 * sin(Time.get_ticks_msec() / 180.0 + pid.hash() % 4)
		rl.width = 5.5 + 2.5 * pulse
		rl.modulate.a = 0.55 + 0.3 * pulse
		rl.default_color = Color(0.72, 0.22, 0.14, 0.72) if frac > 0.4 else Color(0.55, 0.15, 0.10, 0.6)

	# Prune lines for ended raids
	for pid in raid_line_nodes.keys().duplicate():
		if not raid_progress.has(pid):
			var rl: Line2D = raid_line_nodes[pid]
			if is_instance_valid(rl): rl.queue_free()
			raid_line_nodes.erase(pid)

# === Ash Whispers map icons (area-tied notification visual on schematic) ===
# Simple pulsing marker on the vein (mid/outer) when that area has active whisper. Warm color for "echo from ash".
# Creative: different shape tint for "echo_manifest" special mob vs boost types. Polls GS active_whispers.
func _refresh_whispers() -> void:
	var active_areas: Dictionary = {}  # pid -> w dict
	if GameState and GameState.has_method("get_active_whispers"):
		var aws: Dictionary = GameState.get_active_whispers()
		for wid in aws:
			var w: Dictionary = aws[wid]
			var wa: String = str(w.get("area", ""))
			if wa in PATH_IDS:
				active_areas[wa] = w
	# Create/update markers for active
	for pid in active_areas:
		var w: Dictionary = active_areas[pid]
		var key: String = "whisper_" + pid
		var marker: Node2D = whisper_nodes.get(key)
		if marker == null or not is_instance_valid(marker):
			# Pulsing "whisper" icon: use a small warm circle-ish poly (echo/ember feel) + optional accent
			marker = Polygon2D.new()
			marker.name = key
			marker.z_index = 5
			# Base shape: soft glow dot
			marker.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(3, -2), Vector2(4, 2), Vector2(-4, 2)])
			marker.color = Color(0.95, 0.82, 0.55, 0.75) if str(w.get("type","")) != "echo_manifest" else Color(0.85, 0.55, 0.35, 0.85)
			add_child(marker)
			whisper_nodes[key] = marker
		# Position on vein (slightly outer for "source in the ash")
		var se: Array = _get_vein_start_end(pid)
		var pos: Vector2 = se[0].lerp(se[1], 0.78)
		marker.position = pos
		# Gentle pulse + size by type (manifest "mob" bigger/threat)
		var t: float = Time.get_ticks_msec() / 420.0
		var pulse: float = 0.65 + 0.35 * sin(t + pid.hash() % 5)
		var is_manifest: bool = str(w.get("type", "")) == "echo_manifest"
		marker.scale = Vector2(1.0 + (0.4 if is_manifest else 0.15) * pulse, 1.0 + (0.4 if is_manifest else 0.15) * pulse)
		marker.modulate.a = 0.55 + 0.45 * pulse
		if is_manifest:
			marker.rotation = sin(t * 1.6) * 0.2  # slight "restless" for special mob echo
	# Prune ended whispers
	for k in whisper_nodes.keys().duplicate():
		var pid: String = k.substr(8)  # after "whisper_"
		if pid not in active_areas:
			var m: Node2D = whisper_nodes[k]
			if is_instance_valid(m): m.queue_free()
			whisper_nodes.erase(k)

func _update_from_state(_force_full: bool = false) -> void:
	if not is_instance_valid(self):
		return
	# Clear transient choice offer UI on state refresh (e.g. after claim/dispatch)
	if selected_path != _choice_for_path:
		_hide_choice_ui()
	_refresh_production_indicators()
	_refresh_veins()
	_refresh_towers()
	_refresh_entities()
	_refresh_raid_lines()
	_refresh_whispers()  # icons for area-tied Ash Whispers events (popup in Main + icon on map)
	_update_highlight()

# Public API expected by Main.gd integration and approved plan
func update_from_gamestate(force_full: bool = false) -> void:
	_update_from_state(force_full)

func focus_vein(path_id: String) -> void:
	_hide_choice_ui()
	selected_path = path_id
	_update_highlight()
	emit_signal("vein_focused", path_id)

func dispatch_on_vein(path_id: String, choice: String = "auto") -> void:
	_hide_choice_ui()
	if GameState and GameState.has_method("dispatch_expedition"):
		var ok = GameState.dispatch_expedition(path_id, choice)
		if ok:
			_update_from_state()
	emit_signal("dispatch_requested", path_id, choice)

func _refresh_veins() -> void:
	for pid in PATH_IDS:
		var line: Line2D = vein_lines.get(pid)
		if line == null or not is_instance_valid(line):
			continue
		var claimed: bool = false
		var al: float = 0.0
		if GameState:
			claimed = bool(GameState.path_claims.get(pid, false))
			al = float(GameState.alignment)
		else:
			# Editor / no GS mock: two claimed (one harsh for visual contrast)
			claimed = (pid == PATH_IDS[0] or pid == PATH_IDS[2])
			al = -0.28 if pid == PATH_IDS[2] else 0.18

		var was: bool = bool(prev_claims.get(pid, false))
		if claimed and not was:
			_start_binding_effect(pid)
		prev_claims[pid] = claimed

		# Production boost: labor active -> thicker + slight glow tint on claimed veins (visual boost to "defense glow" too)
		var pa: Dictionary = production_active.get(pid, {"labor":false, "boost":0.0})
		var labor_active: bool = bool(pa.get("labor", false))
		var boost: float = float(pa.get("boost", 0.0))

		if not claimed:
			line.default_color = Color(0.33, 0.30, 0.27, 0.52)
			line.width = 2.0
		else:
			if al < -0.2:
				# Harsh/tyrant claim: darker, "thornier" (wider + later overlays)
				line.default_color = Color(0.20, 0.15, 0.12, 0.85)
				line.width = 4.5 + boost * 1.2
			elif al > 0.15:
				# Positive: steadier, warmer tint
				line.default_color = Color(0.47, 0.51, 0.36, 0.78)
				line.width = 3.6 + boost * 0.8
			else:
				line.default_color = Color(0.37, 0.33, 0.27, 0.76)
				line.width = 3.4 + boost * 0.7

			if labor_active:
				# Visual boost: warmer/lighter when labor moving (ties production to map life)
				line.default_color = line.default_color.lightened(0.12)
				line.modulate = Color(1.05, 1.03, 0.95, 1.0)
			else:
				line.modulate = Color(1,1,1,1)

		# Always set points from current visual data (ensures runtime entities + lines match even if data/visuals in paths.json updated; tscn bakes for pure-editor preview)
		var se: Array = _get_vein_start_end(pid)
		line.points = PackedVector2Array([se[0], se[1]])

func _start_binding_effect(pid: String) -> void:
	# "Binding" on recently claimed: subtle anim icon + vein flash (per plan visual moral state).
	# Use weight_accent art asset for effect (instead of pure poly) + modulate for "binding" resonance.
	var se: Array = _get_vein_start_end(pid)
	var pos: Vector2 = se[1] * 0.88

	if weight_accent_tex:
		var fx: Sprite2D = Sprite2D.new()
		fx.name = "BindFX_" + pid
		fx.texture = weight_accent_tex
		fx.scale = Vector2(0.28, 0.28)
		fx.position = pos
		fx.z_index = 4
		fx.modulate = Color(0.85, 0.78, 0.6, 0.75)
		add_child(fx)
		var tw := create_tween()
		tw.tween_property(fx, "modulate:a", 0.0, 2.8).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(fx, "scale", Vector2(0.42, 0.42), 2.8)
		tw.tween_callback(func(): if is_instance_valid(fx): fx.queue_free())
	else:
		# Fallback poly
		var marker: Polygon2D = Polygon2D.new()
		marker.name = "BindFX_" + pid
		marker.color = Color(0.65, 0.58, 0.42, 0.65)
		marker.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
		marker.position = pos
		marker.z_index = 4
		add_child(marker)
		var tw := create_tween()
		tw.tween_property(marker, "modulate:a", 0.0, 3.2).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(): if is_instance_valid(marker): marker.queue_free())

	# Vein flash + extra "binding" pulse
	var ln: Line2D = vein_lines.get(pid)
	if ln and is_instance_valid(ln):
		var orig_c: Color = ln.default_color
		var orig_w: float = ln.width
		ln.default_color = Color(0.82, 0.78, 0.62, 0.98)
		ln.width = orig_w * 1.35
		var tw2 := create_tween()
		tw2.tween_property(ln, "default_color", orig_c, 1.4)
		tw2.parallel().tween_property(ln, "width", orig_w, 1.4)
		# Subtle particles-like: small fading accents along vein (use weight if avail, else polys)
		_spawn_binding_accent_particles(pid, se)

# Fake simple "particles" for binding claim (small sprites or polys that tween out along the vein; called from _start_binding)
func _spawn_binding_accent_particles(pid: String, se: Array) -> void:
	var num: int = 3
	for i in range(num):
		var ppos: Vector2 = se[0].lerp(se[1], 0.6 + (i-1)*0.12)
		var n: Node2D
		if weight_accent_tex:
			n = Sprite2D.new()
			(n as Sprite2D).texture = weight_accent_tex
			(n as Sprite2D).scale = Vector2(0.12, 0.12)
			(n as Sprite2D).modulate = Color(0.9, 0.85, 0.6, 0.7)
		else:
			n = Polygon2D.new()
			(n as Polygon2D).color = Color(0.7, 0.65, 0.5, 0.6)
			(n as Polygon2D).polygon = PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
		n.position = ppos
		n.z_index = 3
		add_child(n)
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 1.1 + i*0.4).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(n, "position", ppos + (se[1]-se[0]).normalized()*8, 1.3)
		tw.tween_callback(func(): if is_instance_valid(n): n.queue_free())

func _refresh_towers() -> void:
	for pid in PATH_IDS:
		var claimed: bool = false
		var def_str: float = 0.0
		var tyrant: bool = false
		var benevolent: bool = false
		var has_dread: bool = false
		var has_sanct: bool = false
		if GameState:
			claimed = bool(GameState.path_claims.get(pid, false))
			if GameState.has_method("get_vein_defense_strength"):
				def_str = GameState.get_vein_defense_strength(pid)
			has_dread = GameState.buildings.get("dread_foundry", 0) > 0
			has_sanct = GameState.buildings.get("sanctuary_ward", 0) > 0
			tyrant = (GameState.alignment < -0.2) or has_dread
			benevolent = (GameState.alignment > 0.15) or has_sanct
			# If both somehow, dread (tyrant) takes precedence as aggressive override
			if has_dread:
				benevolent = false
				tyrant = true
		else:
			claimed = (pid == PATH_IDS[0] or pid == PATH_IDS[2])
			def_str = 3.8 if claimed else 0.0
			tyrant = (pid == PATH_IDS[2])
			benevolent = not tyrant

		var want: bool = claimed and def_str > 0.25
		var tnode: Polygon2D = tower_nodes.get(pid) as Polygon2D
		if want:
			if tnode == null or not is_instance_valid(tnode):
				tnode = _create_tower(pid, tyrant, benevolent, has_dread, has_sanct)
				tower_nodes[pid] = tnode
				add_child(tnode)
			_update_tower_visual(tnode, pid, def_str, tyrant, benevolent, has_dread, has_sanct)
		elif tnode and is_instance_valid(tnode):
			tnode.queue_free()
			tower_nodes.erase(pid)

func _create_tower(pid: String, is_tyrant: bool, is_benevolent: bool, has_dread: bool, has_sanct: bool) -> Polygon2D:
	# Enhanced faction visuals per task: different icons/shapes/colors.
	# Tyrant/dread (aggressive spikes, redder/black ash): uses dread_foundry require (align_lt)
	# Benevolent/ward (protective, greener/glow): uses sanctuary_ward require (align_gt)
	# Falls back to align or basic watch_spire.
	var p := Polygon2D.new()
	p.name = "Tower_" + pid
	p.z_index = 2
	if has_dread or (is_tyrant and not is_benevolent):
		# Dread / aggressive: more spikes, jagged, redder tones (tyrant playstyle)
		p.polygon = PackedVector2Array([
			Vector2(-6, 9), Vector2(6, 9), Vector2(3.5, 1),
			Vector2(1.5, -6), Vector2(0, -16), Vector2(-1.5, -6),
			Vector2(-3.5, 1)
		])
		p.color = Color(0.38, 0.12, 0.09, 0.97)
	elif has_sanct or is_benevolent:
		# Sanctuary Ward / protective: smoother, broader base + point, greener with room for glow overlay
		p.polygon = PackedVector2Array([
			Vector2(-5.5, 8), Vector2(5.5, 8), Vector2(2, -2),
			Vector2(0, -14), Vector2(-2, -2)
		])
		p.color = Color(0.32, 0.48, 0.28, 0.92)
	elif is_tyrant:
		# Basic tyrant lean (align driven, no specific building yet)
		p.polygon = PackedVector2Array([
			Vector2(-5.5, 8), Vector2(5.5, 8), Vector2(2.5, -1),
			Vector2(0, -13), Vector2(-2.5, -1)
		])
		p.color = Color(0.32, 0.15, 0.11, 0.96)
	else:
		# Warded / basic benevolent or neutral watch
		p.polygon = PackedVector2Array([
			Vector2(-4.5, 7.5), Vector2(4.5, 7.5), Vector2(0, -12)
		])
		p.color = Color(0.50, 0.47, 0.36, 0.9)
	return p

func _update_tower_visual(tnode: Polygon2D, pid: String, def_str: float, is_tyr: bool, is_ben: bool, has_dread: bool, has_sanct: bool) -> void:
	var se: Array = _get_vein_start_end(pid)
	var pos: Vector2 = se[0].lerp(se[1], 0.67)
	tnode.position = pos
	var dir: Vector2 = (se[1] - se[0]).normalized()
	tnode.rotation = dir.angle() + (PI * 0.5)
	var sz: float = 0.82 + clamp(def_str / 4.8, 0.0, 1.7)
	tnode.scale = Vector2(sz, sz)

	# Production labor boost: extra defense glow / pulse when labor active on vein (visual boost)
	var pa: Dictionary = production_active.get(pid, {})
	var labor_glow: float = float(pa.get("boost", 0.0)) * 0.4
	var base_pulse: float = 0.72 + 0.28 * sin(Time.get_ticks_msec() / 260.0 + (pid.hash() % 7))
	var pulse_a: float = clamp(base_pulse + labor_glow * 0.35, 0.5, 1.0)
	tnode.modulate.a = pulse_a

	# Faction tints + glows (use production boost for intensity on ward)
	var glow_extra: float = 0.15 * labor_glow
	if has_dread or (is_tyr and not is_ben):
		tnode.color = Color(0.42, 0.11, 0.08, 0.96)
		tnode.modulate = Color(1.0 + glow_extra*0.1, 0.92, 0.88, 1.0)  # slight red pulse
	elif has_sanct or is_ben:
		tnode.color = Color(0.28, 0.52, 0.26, 0.93)
		# Greener protective glow (brighter when labor boosting)
		var g: float = 0.12 + glow_extra
		tnode.modulate = Color(0.92, 1.0 + g, 0.9, 1.0)
	elif is_tyr:
		tnode.color = Color(0.36, 0.14, 0.10, 0.94)
	else:
		tnode.color = Color(0.48, 0.52, 0.40, 0.88)
	# Add a subtle glow child for ward if benevolent (simple extra modulate or small accent poly if not present)
	_ensure_tower_glow(tnode, pid, is_ben or has_sanct, glow_extra)

# Ensure (or update) a faint protective glow overlay on benevolent towers (uses modulate; can be enhanced with weight_accent later)
func _ensure_tower_glow(tnode: Polygon2D, pid: String, is_protective: bool, glow_amt: float) -> void:
	if not is_instance_valid(tnode): return
	var glow_name := "Glow_" + pid
	var glow: Node = tnode.get_node_or_null(glow_name)
	if is_protective:
		if glow == null or not is_instance_valid(glow):
			# Simple duplicate-ish poly or sprite accent for glow (schematic)
			glow = Polygon2D.new()
			glow.name = glow_name
			(glow as Polygon2D).polygon = tnode.polygon  # similar shape, larger soft
			(glow as Polygon2D).color = Color(0.4, 0.65, 0.35, 0.18)
			(glow as Polygon2D).z_index = -1
			(glow as Polygon2D).scale = Vector2(1.25, 1.25)
			tnode.add_child(glow)
		# Pulse the glow
		var gmod: float = 0.18 + 0.1 * sin(Time.get_ticks_msec() / 380.0 + pid.hash() % 5) + glow_amt * 0.5
		(glow as Polygon2D).modulate.a = clamp(gmod, 0.08, 0.45)
		(glow as Polygon2D).scale = Vector2(1.22 + glow_amt*0.3, 1.22 + glow_amt*0.3)
	elif glow and is_instance_valid(glow):
		glow.queue_free()

func _refresh_entities() -> void:
	# Expeditions (real from GS)
	var live_exp: Array[String] = []
	if GameState:
		for e in GameState.active_expeditions:
			var pid: String = str(e.get("path_id", ""))
			if pid in PATH_IDS:
				live_exp.append(pid)
				var key: String = "exp_" + pid
				var ic: Polygon2D = entity_nodes.get(key) as Polygon2D
				if ic == null or not is_instance_valid(ic):
					ic = _create_entity(true)
					entity_nodes[key] = ic
					add_child(ic)

	# Raids (simulated or triggered)
	for pid in raid_progress:
		var key: String = "raid_" + pid
		var ic: Polygon2D = entity_nodes.get(key) as Polygon2D
		if ic == null or not is_instance_valid(ic):
			ic = _create_entity(false)
			entity_nodes[key] = ic
			add_child(ic)

	# Prune stale expeditions
	for k in entity_nodes.keys().duplicate():
		if k.begins_with("exp_"):
			var pid: String = k.substr(4)
			if pid not in live_exp:
				var ic: Polygon2D = entity_nodes[k]
				if is_instance_valid(ic):
					ic.queue_free()
				entity_nodes.erase(k)

func _create_entity(is_exp: bool) -> Polygon2D:
	var p := Polygon2D.new()
	p.z_index = 3
	if is_exp:
		# Expedition / lost mover (neutral ash tone)
		p.color = Color(0.72, 0.68, 0.52, 0.88)
		p.polygon = PackedVector2Array([Vector2(0, -5), Vector2(3.2, 4), Vector2(-3.2, 4)])
	else:
		# Raid threat (darker, spikier)
		p.color = Color(0.52, 0.10, 0.07, 0.94)
		p.polygon = PackedVector2Array([Vector2(0, -4.5), Vector2(4.2, 0), Vector2(0, 4.5), Vector2(-4.2, 0)])
	return p

func _get_vein_start_end(pid: String) -> Array:
	var v: Dictionary = path_visuals.get(pid, HARDCODED_VISUALS.get(pid, {"angle_deg": 30, "radius": 120, "length": 95}))
	var ang: float = deg_to_rad(float(v.get("angle_deg", 30)))
	var r: float = float(v.get("radius", 120))
	var l: float = float(v.get("length", 95))
	var d: Vector2 = Vector2(cos(ang), sin(ang))
	return [d * r, d * (r + l)]

func _update_highlight() -> void:
	if highlight == null or not is_instance_valid(highlight):
		return
	if selected_path == "" or not path_visuals.has(selected_path):
		highlight.visible = false
		return
	var se: Array = _get_vein_start_end(selected_path)
	highlight.points = PackedVector2Array([se[0], se[1]])
	highlight.visible = true

# === Production indicators (labor/spire from GameState.production_queue) ===
# Per task: check queue for labor/spire types, show small moving "labor"/"builder" icons along veins (esp claimed) or near towers.
# Use bound_figure tex for labor icons (small sprites), simple anim (phase offset progress along vein).
# Visual boost to defense glow (extra modulate on towers/veins) when labor active.
# Not per-path in GS (global queues), so active labor/spire shows on all claimed veins (as "work strengthening the veins").
# Ties to _update_from_state / _refresh .
func _refresh_production_indicators() -> void:
	production_active.clear()
	var has_labor: bool = false
	var has_spire: bool = false
	var has_resonance: bool = false
	var has_extract: bool = false
	var has_ward: bool = false
	var labor_boost: float = 0.0
	if GameState and ("production_queue" in GameState):
		for q in GameState.production_queue:
			var qtype: String = str(q.get("type", ""))
			if qtype == "labor":
				has_labor = true
				labor_boost = max(labor_boost, 1.0)
			elif qtype == "resonance":
				has_resonance = true
				has_labor = true
				labor_boost = max(labor_boost, 1.0)
			elif qtype in ["spire", "aggressive_defense", "protective"]:
				has_spire = true
				labor_boost = max(labor_boost, 0.6)
			elif qtype == "extract":
				has_extract = true
				has_spire = true
				labor_boost = max(labor_boost, 0.7)
			elif qtype == "ward":
				has_ward = true
				has_spire = true
				labor_boost = max(labor_boost, 0.5)
	# Also show labor indicators when completed (production_labor or built hall) even if no active queue (per task "when labor active")
	if not has_labor and GameState:
		var pl = 0.0
		if "production_labor" in GameState: pl = float(GameState.production_labor)
		var lh = 0
		if "buildings" in GameState and typeof(GameState.buildings) == TYPE_DICTIONARY: lh = int(GameState.buildings.get("labor_hall", 0))
		var rs = 0
		if "buildings" in GameState and typeof(GameState.buildings) == TYPE_DICTIONARY: rs = int(GameState.buildings.get("resonance_spire", 0))
		var lb = 0.0
		if "labor_boost" in GameState: lb = float(GameState.labor_boost)
		if pl > 0.5 or lh > 0 or rs > 0 or lb > 0.1:
			has_labor = true
			labor_boost = max(labor_boost, 0.8)
	elif Engine.is_editor_hint():
		# Mock for editor preview of production indicators (labor on one claimed vein)
		has_labor = true
		has_spire = false
		labor_boost = 1.2
	# For simplicity, apply "active labor" state to all claimed veins (production strengthens the held veins)
	for pid in PATH_IDS:
		var claimed: bool = false
		if GameState:
			claimed = bool(GameState.path_claims.get(pid, false))
		else:
			claimed = (pid == PATH_IDS[0] or pid == PATH_IDS[2])
		production_active[pid] = {
			"labor": has_labor and claimed,
			"spire": has_spire and claimed,
			"resonance": has_resonance and claimed,
			"extract": has_extract and claimed,
			"ward": has_ward and claimed,
			"boost": labor_boost if (has_labor or has_spire) and claimed else 0.0
		}

	# Manage labor_nodes: create/update small moving icons for active labor on claimed
	var active_pids: Array = []
	for pid in production_active:
		var pa: Dictionary = production_active[pid]
		if pa.get("labor", false) or pa.get("spire", false):
			active_pids.append(pid)
			var dots: Array = labor_nodes.get(pid, [])
			if dots.is_empty():
				# Create 1-2 labor icons per active vein (use bound_figure for labor, tinted for builder/spire/resonance/extract/ward)
				var is_builder: bool = pa.get("spire", false) or pa.get("extract", false)
				for i in range(1 if is_builder else 2):
					var icon: Node2D = _create_labor_icon(is_builder, pa)
					icon.name = "LaborDot_" + pid + "_" + str(i)
					add_child(icon)
					dots.append(icon)
				labor_nodes[pid] = dots
			# Position will be updated in _process / _update_moving_entities extension or here with phase
			_update_labor_positions(pid, dots, pa)
	# Prune unused
	for pid in labor_nodes.keys().duplicate():
		if pid not in active_pids:
			for n in labor_nodes[pid]:
				if is_instance_valid(n): n.queue_free()
			labor_nodes.erase(pid)

func _create_labor_icon(is_builder: bool, pa: Dictionary = {}) -> Node2D:
	# Use Sprite2D + bound_figure tex for authentic art use (small "bound labor" moving on veins)
	var spr: Sprite2D = Sprite2D.new()
	spr.z_index = 4
	if bound_figure_tex:
		spr.texture = bound_figure_tex
		spr.scale = Vector2(0.18, 0.18) if not is_builder else Vector2(0.22, 0.22)
	else:
		# Fallback schematic poly (rare)
		var p := Polygon2D.new()
		p.color = Color(0.55, 0.5, 0.38, 0.9) if not is_builder else Color(0.65, 0.6, 0.35, 0.85)
		p.polygon = PackedVector2Array([Vector2(-2,-3), Vector2(2,-3), Vector2(2,3), Vector2(-2,3)])
		return p
	# Tint: labor (hands from hall) warmer ash, builder/spire more metallic/ward or dread tint
	# Expand for new: resonance = warm gold, extract = darker/thorn, ward = soft green
	if pa.get("resonance", false):
		spr.modulate = Color(0.92, 0.82, 0.55, 0.9)
	elif pa.get("extract", false):
		spr.modulate = Color(0.55, 0.35, 0.28, 0.95)
	elif pa.get("ward", false):
		spr.modulate = Color(0.58, 0.72, 0.55, 0.9)
	elif is_builder:
		spr.modulate = Color(0.75, 0.72, 0.55, 0.95)
	else:
		spr.modulate = Color(0.62, 0.58, 0.48, 0.92)
	return spr

func _update_labor_positions(pid: String, dots: Array, pa: Dictionary) -> void:
	if not path_visuals.has(pid) or dots.is_empty():
		return
	var se: Array = _get_vein_start_end(pid)
	var t: float = Time.get_ticks_msec() / 1200.0
	for i in range(dots.size()):
		var icon: Node2D = dots[i]
		if not is_instance_valid(icon): continue
		# Simple anim progress along vein (offset per dot); use "get_path_progress" style but for labor cycle
		var prog: float = fmod(t + (i * 0.37), 1.0)
		# Bias toward outer half for "working the vein"
		prog = 0.35 + prog * 0.6
		var pos: Vector2 = se[0].lerp(se[1], clamp(prog, 0.0, 1.0))
		icon.position = pos
		# Gentle bob/lean with vein dir
		var dirv: Vector2 = (se[1] - se[0]).normalized()
		icon.rotation = dirv.angle() + sin(t*3.0 + i) * 0.2
		# Boost visibility when labor
		if pa.get("labor", false):
			icon.modulate.a = 0.75 + 0.2 * sin(t*4.0 + i*1.5)

# Basic mouse interaction stubs (focus on click; double-click dispatches default choice).
# Enhanced per task for better interaction: click near vein calls focus_vein + highlight.
# If unclaimed, "offer dispatch with moral choices": we emit moral_choice_offered (Main can use to trigger choice UI),
# and for direct map offer we auto-dispatch using "" (GS picks moral bias), plus spawn temp hint labels near vein
# showing options from path_data (player can use side list or re-click for auto). Keeps full API compat.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local: Vector2 = get_local_mouse_position()
	# First: if moral choice hints are up, a click on a hint dispatches THAT choice (player agency).
	for hit in _choice_option_hits:
		var r: Rect2 = hit.get("rect", Rect2())
		if r.has_point(local):
			var cid: String = str(hit.get("id", ""))
			var pid_hit: String = str(hit.get("path", _choice_for_path))
			get_viewport().set_input_as_handled()
			_hide_choice_ui()
			if cid != "" and pid_hit != "":
				dispatch_on_vein(pid_hit, cid)
				dispatch_requested.emit(pid_hit, cid)
			return
	for pid in PATH_IDS:
		var se: Array = _get_vein_start_end(pid)
		if _dist_to_line(local, se[0], se[1]) < 13.0:
			focus_vein(pid)
			get_viewport().set_input_as_handled()
			_hide_choice_ui()  # clear prior
			var claimed: bool = false
			if GameState:
				claimed = bool(GameState.path_claims.get(pid, false))
			else:
				claimed = (pid == PATH_IDS[0] or pid == PATH_IDS[2])
			if not claimed:
				# Offer moral choices only — do NOT auto-dispatch (preserves Listen vs Harvest agency)
				_offer_moral_dispatch(pid, local)
			elif mb.double_click:
				# Explicit double-click on claimed/defended vein: auto-bias dispatch only if already claimed
				dispatch_on_vein(pid, "")
			break

func compute_choice_hit_rect(pos: Vector2, text: String, font_size: int = 9, pad: Vector2 = Vector2(10, 6)) -> Rect2:
	# R5: font-measured hitbox (replaces approximate fixed Label rects). Public for headless asserts.
	var font: Font = ThemeDB.fallback_font
	var sz: Vector2 = Vector2(float(max(48, text.length() * 6)), float(font_size + 4))
	if font:
		sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	# Minimum comfortable click target (accessibility); pad beyond glyph bounds
	sz.x = max(sz.x, 72.0) + pad.x * 2.0
	sz.y = max(sz.y, float(font_size + 2)) + pad.y * 2.0
	return Rect2(pos - Vector2(pad.x, pad.y), sz)

func _offer_moral_dispatch(path_id: String, click_pos: Vector2) -> void:
	_hide_choice_ui()
	_choice_for_path = path_id
	var options: Array = []
	if GameState and GameState.has("path_data") and GameState.path_data.has(path_id):
		options = GameState.path_data[path_id].get("moral_options", [])
	# Emit so Main can show matching sidebar / map-panel buttons
	moral_choice_offered.emit(path_id, options)
	# R5: clickable Button hints with font-measured hitrects (no more fixed 180x16 approx)
	var se: Array = _get_vein_start_end(path_id)
	var base_pos: Vector2 = se[1] * 0.92 + Vector2(12, -8)
	_choice_option_hits.clear()
	var row_gap: float = 22.0
	for i in range(min(2, options.size())):
		var opt: Dictionary = options[i]
		var label_txt: String = str(opt.get("label", opt.get("id", "?")))
		var display: String = "> " + label_txt
		var btn := Button.new()
		btn.name = "ChoiceHint_" + str(i)
		btn.text = display
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", Color(0.92, 0.86, 0.55, 0.98))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
		btn.position = base_pos + Vector2(0, float(i) * row_gap)
		btn.z_index = 10
		var hit_rect: Rect2 = compute_choice_hit_rect(btn.position, display, 9)
		btn.size = hit_rect.size
		btn.custom_minimum_size = hit_rect.size
		var cid: String = str(opt.get("id", ""))
		var pid_cap: String = path_id
		btn.pressed.connect(func():
			_hide_choice_ui()
			if cid != "" and pid_cap != "":
				dispatch_on_vein(pid_cap, cid)
				dispatch_requested.emit(pid_cap, cid)
		)
		add_child(btn)
		_choice_ui_nodes.append(btn)
		_choice_option_hits.append({"rect": hit_rect, "id": cid, "path": path_id})
	var hint := Label.new()
	hint.name = "ChoiceHint_Prompt"
	hint.text = "Choose (click a path)"
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5, 0.9))
	hint.position = base_pos + Vector2(0, -14)
	hint.z_index = 10
	add_child(hint)
	_choice_ui_nodes.append(hint)
	var tw := create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(_hide_choice_ui)

func _hide_choice_ui() -> void:
	for n in _choice_ui_nodes:
		if is_instance_valid(n): n.queue_free()
	_choice_ui_nodes.clear()
	_choice_option_hits.clear()
	_choice_for_path = ""

func _dist_to_line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_to(proj)
