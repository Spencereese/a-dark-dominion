# scripts/Main.gd
# Main controller for the prototype UI. Builds most of the early-game interface in code
# so it is easy to iterate rapidly with AI assistance.
# Later phases can introduce more instanced scenes and a visual map.

extends Control

@onready var log_label: RichTextLabel = %StoryLog
@onready var actions_container: VBoxContainer = %ActionsContainer
@onready var resources_container: HBoxContainer = %Resources
@onready var status_label: Label = %StatusLabel
@onready var alignment_bar: ProgressBar = %AlignmentBar
@onready var speed_buttons: HBoxContainer = %SpeedButtons
@onready var alignment_section: HBoxContainer = %AlignmentSection
@onready var actions_panel: PanelContainer = %ActionsPanel
@onready var log_panel: PanelContainer = null
@onready var main_area_node: HBoxContainer = null

var action_buttons: Dictionary = {}  # action_id -> Button

# Outlands / paths panel (Phase 2+5 / outlands UI, dynamic code-driven per plan)
var outlands_panel: PanelContainer = null
var outlands_content: VBoxContainer = null

# Polish: dedicated early choice prompt UI. Appears as a distinct, high-impact panel/section when incursion_pending.
# Styled differently (header in revelation gold, options as prominent buttons). Can pause time for the moment to land.
var choice_prompt_panel: PanelContainer = null
var choice_prompt_content: VBoxContainer = null
# R6 raid/defense encounter UI (mirrors choice prompt pattern)
var raid_encounter_panel: PanelContainer = null
var raid_encounter_content: VBoxContainer = null
var _raid_time_was_paused_by_prompt: bool = false
var _choice_time_was_paused_by_prompt: bool = false

# Accelerated visual RTS/TD map + Memory (per approved plan)
var map_panel: PanelContainer = null
var map_view: Node = null  # instance of scenes/OutlandsMap.tscn (Node2D)
var memory_panel: PanelContainer = null
var ending_panel: Control = null  # R3: full-screen WIN/LOSE overlay
var memory_content: VBoxContainer = null

# Simple events UI: notification popup/banner for Ash Whispers (or map icon). Transient, high-contrast, fits austere style.
var whisper_banner: PanelContainer = null
var whisper_banner_label: RichTextLabel = null
var _whisper_banner_timer: float = 0.0

# Placeholder art visuals (AI-generated minimalist austere dark + warm ember accents; placed via code like outlands/choice panels for rapid iteration)
var ember_visual: TextureRect = null
var ash_bg_visual: TextureRect = null
# Scattered embers: small secondary pulses that appear as central pulse grows / more of the world "wakes". Reinforces "scattered embers... brighten" + "as light grows we see more" purely visually (no text flood).
var scattered_embers: Array[TextureRect] = []
# Paths/veins art for integration into outlands panel (header + per-entry icons per UI subagent brief; austere modulation to fit dark high-contrast theme)
var paths_veins_tex: Texture2D = null

# Audio players (placeholder impl per SOUND_DIRECTION.md: sparse lo-fi ash/ember. Start with code-gen tones via AudioStreamGenerator for no-asset cues.
# Buses: Ash (wind/hiss), Ember (warm pulse hum), Dread (raids/negative), UI (dry actions). Dynamic volume/pitch on state.
var ember_player: AudioStreamPlayer = null
var ash_ambient: AudioStreamPlayer = null
var one_shot_player: AudioStreamPlayer = null
var one_shot_dry: AudioStreamPlayer = null  # second layer for gather clink etc (sparse UI bus)
var generator: AudioStreamGenerator = null  # for procedural tones
var outlands_drone: AudioStreamPlayer = null  # subtle new layer on phase unfurl
var _ash_prev: float = 0.0  # state for brown noise lowpass in ambient fill

func _ready() -> void:
	# Connect to global events
	GameEvents.log_message.connect(_on_log_message)
	GameEvents.resource_changed.connect(_on_resource_changed)
	GameEvents.rate_changed.connect(_on_rate_changed)
	GameEvents.alignment_changed.connect(_on_alignment_changed)
	GameEvents.population_changed.connect(_on_population_changed)
	GameEvents.available_actions_changed.connect(_refresh_actions)
	GameEvents.phase_advanced.connect(_on_phase_advanced)
	GameEvents.time_advanced.connect(_on_time_for_ui)
	GameEvents.action_performed.connect(_on_action_performed)
	GameEvents.choice_offered.connect(_on_choice_offered)
	GameEvents.choice_resolved.connect(_on_choice_resolved)
	GameEvents.raid_occurred.connect(_on_raid_occurred)
	if GameEvents.has_signal("raid_encounter_offered"):
		GameEvents.raid_encounter_offered.connect(_on_raid_encounter_offered)
	if GameEvents.has_signal("raid_encounter_resolved"):
		GameEvents.raid_encounter_resolved.connect(_on_raid_encounter_resolved)
	GameEvents.ending_reached.connect(_on_ending_reached)
	GameEvents.sfx_cue.connect(_on_sfx_cue)
	GameEvents.whisper_triggered.connect(_on_whisper_triggered)
	GameEvents.whisper_expired.connect(_on_whisper_expired)

	_setup_initial_ui()
	_refresh_resources_display()
	_update_status()
	_setup_placeholder_art()  # load ash bg + pulsing ember visual from assets/art (placeholders)
	_setup_audio()  # sparse placeholder tones + buses; hooks via signals for nurture/gather/raid/choice

	# Initial welcome if needed (GameState already logged some) Ã¢â‚¬â€ polished to ash/ember (no room/fire remnant)
	if log_label.get_parsed_text().strip_edges() == "":
		var txt: String = "The ash is vast and silent. Embers lie scattered like forgotten sparks."
		if NarrativeSystem:
			GameEvents.log_message.emit(NarrativeSystem.get_flavored_text(txt), "story")
		else:
			GameEvents.log_message.emit(txt, "story")

	# If loaded or starting directly in outlands, ensure the paths panel
	if GameState.phase == "outlands":
		_ensure_outlands_panel()
		_refresh_outlands()
	# Accelerated: ensure visual map (schematic 2D) and Memory panel
	_ensure_map_panel()
	_ensure_memory_panel()
	if GameState.phase == "outlands":
		_refresh_map()
	_refresh_memories()
	call_deferred("_refresh_actions")
	call_deferred("_refresh_choice_prompt")
	if GameState != null and GameState.game_ended:
		call_deferred("_ensure_ending_overlay")

func _setup_initial_ui() -> void:
	# Dark theme enforcement (can be improved with real Theme later)
	modulate = Color(0.95, 0.93, 0.9)  # slight warm tint on everything

	# Ensure the actions panel on the right has proper expand to take full height of the main area
	# (prevents it from being squished to small height like 49px early in layout)
	# Use traversal to be robust even if %ActionsPanel unique not resolved yet
	var actions_vbox = actions_container.get_parent() if actions_container else null
	var actions_margin = actions_vbox.get_parent() if actions_vbox else null
	var panel = actions_margin.get_parent() as PanelContainer if actions_margin else null
	if panel:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if panel.custom_minimum_size.x < 320:
			panel.custom_minimum_size = Vector2(320, panel.custom_minimum_size.y)
		if panel.custom_minimum_size.y < 200:
			panel.custom_minimum_size = Vector2(panel.custom_minimum_size.x, 200)

	# Also ensure the inner vbox and container expand vertically inside the panel
	if actions_vbox:
		actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if actions_container:
		actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# give the buttons area some min height so button is always visible even early layout
		if actions_container.custom_minimum_size.y < 100:
			actions_container.custom_minimum_size = Vector2(actions_container.custom_minimum_size.x, 100)

	# Alignment bar setup
	alignment_bar.min_value = -1.0
	alignment_bar.max_value = 1.0
	alignment_bar.value = GameState.alignment
	alignment_bar.show_percentage = false

	# Resolve unique panels defensively (some % lookups can be timing sensitive in _ready; use known paths)
	if log_panel == null:
		log_panel = get_node_or_null("Margin/VBox/MainArea/LogPanel") as PanelContainer
	if main_area_node == null:
		main_area_node = get_node_or_null("Margin/VBox/MainArea") as HBoxContainer

	# Speed controls
	for child in speed_buttons.get_children():
		if child is Button:
			child.pressed.connect(_on_speed_pressed.bind(child))

	# Make log scroll nicely
	log_label.scroll_following = true
	log_label.bbcode_enabled = true

func _setup_placeholder_art() -> void:
	# Load and place generated placeholder art (minimalist, austere, warm-ember accents only).
	# Ash bg adds subtle texture interest over the solid ColorRect without changing the dark feel.
	# Ember visual sits in TopBar as living indicator of the core "pulse" state; its brightness/alpha tracks GameState.ember_pulse.
	# Easy to swap later for final ink/pixel art or animated sprites.

	# Subtle ash field background (full screen, low opacity, tile if wanted)
	var ash_tex: Texture2D = load("res://assets/art/ash_field.jpg") as Texture2D
	if ash_tex:
		ash_bg_visual = TextureRect.new()
		ash_bg_visual.texture = ash_tex
		ash_bg_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ash_bg_visual.stretch_mode = TextureRect.STRETCH_TILE
		ash_bg_visual.modulate = Color(0.6, 0.55, 0.5, 0.08)  # very faint texture wash
		ash_bg_visual.layout_mode = 1
		ash_bg_visual.anchors_preset = 15
		ash_bg_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ash_bg_visual)
		move_child(ash_bg_visual, 1)  # just above the solid Background ColorRect

	# Ember pulse visual - central growing visual of the ember. Scales larger as pulse grows.
	# Positioned in upper center of the "world" area. Not in layout containers to allow free scaling without jitter.
	var ember_tex: Texture2D = load("res://assets/art/ember_pulse.jpg") as Texture2D
	if ember_tex:
		ember_visual = TextureRect.new()
		ember_visual.texture = ember_tex
		ember_visual.custom_minimum_size = Vector2(100, 100)
		ember_visual.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		ember_visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ember_visual.modulate = Color(1.0, 0.82, 0.55, 0.85)
		add_child(ember_visual)
		move_child(ember_visual, 2)  # after ash bg, before main Margin content

	# Load paths_veins art for outlands panel integration (small austere icons; other arts like bound_figure/haven_shelter/weight_accent remain available for pop/choice/status extensions)
	paths_veins_tex = load("res://assets/art/paths_veins.jpg")

	# Scattered smaller embers (reuse the pulse texture, tiny, positioned around central). They "wake" with light growth.
	var ember_tex2: Texture2D = load("res://assets/art/ember_pulse.jpg") as Texture2D
	if ember_tex2:
		scattered_embers.clear()
		for i in range(6):
			var se: TextureRect = TextureRect.new()
			se.texture = ember_tex2
			se.custom_minimum_size = Vector2(28, 28)
			se.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			se.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			se.modulate = Color(1.0, 0.75, 0.45, 0.0)  # start invisible
			se.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(se)
			move_child(se, 2)  # with the main ember layer
			scattered_embers.append(se)

	_update_ember_visual()

func _update_ember_visual(_delta: float = 0.0) -> void:
	if ember_visual == null or not GameState:
		return
	var pulse: float = GameState.ember_pulse
	# Stronger pulse = brighter + warmer + larger (grows as fed). 
	# Color/alpha + scale for clear growing visual. No text feed.
	var t: float = clamp(pulse / 7.5, 0.25, 1.5)
	var r: float = 1.0
	var g: float = 0.78 + t * 0.18
	var b: float = 0.48 + t * 0.35
	var a: float = 0.65 + t * 0.32
	ember_visual.modulate = Color(r, g, b, a)
	ember_visual.scale = Vector2(1.0 + t * 1.0, 1.0 + t * 1.0)
	# Position in upper center of view (absolute, not affected by margins)
	ember_visual.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 40 * ember_visual.scale.x, 80)

	if ash_bg_visual:
		var ash_a: float = 0.08 + clamp(pulse / 30.0, 0.0, 0.08)
		ash_bg_visual.modulate = Color(0.6, 0.55, 0.5, ash_a)

	# Dynamic margins on main content: larger margins when pulse high = more ash visible around shrunken content area = "camera backs out" to see more world.
	# Low pulse (not fed) = smaller margins = content fills more, world "shrinks" to focus.
	var main_margin: MarginContainer = get_node("Margin") as MarginContainer
	if main_margin:
		var base_m: int = 24
		var expand_m: int = int(clamp(pulse * 4.0, 0.0, 120.0))
		main_margin.add_theme_constant_override("margin_left", base_m + expand_m)
		main_margin.add_theme_constant_override("margin_top", base_m + expand_m)
		main_margin.add_theme_constant_override("margin_right", base_m + expand_m)
		main_margin.add_theme_constant_override("margin_bottom", base_m + expand_m)

	# Update scattered embers: more visible + positioned as pulse rises (and pop/havens grow). Pure visual storytelling for "scattered embers stir", "light grows we see more".
	if scattered_embers.size() > 0 and GameState:
		var spulse: float = GameState.ember_pulse
		var pop: int = GameState.population
		var havens: int = int(GameState.buildings.get("haven", 0)) + int(GameState.buildings.get("basic_sanctum", 0))
		var num_visible: int = 0
		if spulse > 1.5:
			num_visible = 1
		if spulse > 3.0:
			num_visible = 2
		if spulse > 4.5 or pop >= 3:
			num_visible = 3
		if spulse > 6.0 or havens >= 2:
			num_visible = 4
		if spulse > 7.5 or havens >= 3:
			num_visible = 5
		var vp: Rect2 = get_viewport().get_visible_rect()
		var cx: float = vp.size.x * 0.5
		var cy: float = 95.0  # near main ember y
		var offsets: Array[Vector2] = [
			Vector2(-165, -35), Vector2(155, -25),
			Vector2(-125, 48), Vector2(135, 55),
			Vector2(-195, 12), Vector2(180, 8)
		]
		for i in range(scattered_embers.size()):
			var se: TextureRect = scattered_embers[i]
			if not is_instance_valid(se):
				continue
			if i < num_visible:
				var st: float = clamp((spulse - 1.0) / 6.0, 0.15, 0.85)
				var sa: float = 0.18 + st * 0.55
				var ss: float = 0.35 + st * 0.25
				se.modulate = Color(0.95, 0.78, 0.52, sa)
				se.scale = Vector2(ss, ss)
				var off: Vector2 = offsets[i % offsets.size()]
				# slight spread based on pulse for "world opening"
				var spread: float = 1.0 + clamp(spulse / 9.0, 0.0, 0.3)
				se.position = Vector2(cx + off.x * spread - 14 * ss, cy + off.y * spread - 14 * ss)
				se.show()
			else:
				se.hide()

func _setup_audio() -> void:
	# Load custom bus layout (Ash/Ember/Dread/UI as directed). Apply once.
	var bus_layout: AudioBusLayout = load("res://resources/audio_buses.tres") as AudioBusLayout
	if bus_layout:
		AudioServer.set_bus_layout(bus_layout)
	# Create players (add as children so they process)
	ember_player = AudioStreamPlayer.new()
	ember_player.bus = "Ember"
	add_child(ember_player)

	ash_ambient = AudioStreamPlayer.new()
	ash_ambient.bus = "Ash"
	add_child(ash_ambient)

	one_shot_player = AudioStreamPlayer.new()
	one_shot_player.bus = "UI"
	add_child(one_shot_player)

	one_shot_dry = AudioStreamPlayer.new()
	one_shot_dry.bus = "UI"
	add_child(one_shot_dry)

	# Basic procedural generator for ambient hum/hiss (no asset). Looping low tone + noise.
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.5
	# Assign to ash for base wind/hiss layer (we'll fill manually)
	ash_ambient.stream = generator
	ash_ambient.play()
	_fill_ash_ambient(1200)  # seed initial hiss
	# Ember uses a second generator for pulse hum (set on play or separate)
	# For cues we will create temp streams or modulate existing.

	# Initial mix: very quiet ash, faint ember (will be driven by state in _on_time + action hooks)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ash"), -28.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ember"), -22.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Dread"), -18.0)

	# Hook some signals for cues (nurture swells, gather scrapes, raid threat, choice resolve stings)
	# Already connected raid; use action + time + choice for others.
	# Start a very faint continuous fill for ash hiss (simple brown-ish via generator in _process if needed).

func _play_ember_cue(strength: float = 1.0) -> void:
	# Soft warm swell for nurture/feed. Vary by pulse/align/strength: stronger nurture = lower warmer freq + longer tail.
	# Benevolent align warms pitch slightly; tyrant cooler. Sparse generator tone.
	if not ember_player:
		return
	var pulse: float = GameState.ember_pulse if GameState else 4.0
	var align: float = GameState.alignment if GameState else 0.0
	var freq: float = 74.0 - clamp(strength * 11.0 + (pulse - 2.0) * 0.8, 0.0, 32.0)
	freq = clamp(freq, 44.0, 92.0)
	var dur: float = 0.72 + clamp(strength * 0.48, 0.0, 0.85)
	var vdb: float = -13.0 + clamp(strength * 4.5, -3.0, 5.0)
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = max(0.85, dur + 0.15)
	ember_player.stream = g
	ember_player.volume_db = vdb
	ember_player.pitch_scale = 0.88 + clamp(align * 0.07 + strength * 0.03, -0.08, 0.22)
	ember_player.play()
	# Fill warm low sine (nurture stronger -> warmer/longer)
	_generate_tone_burst(ember_player, freq, dur, 0.36 + strength * 0.09, false, false)

func _play_gather_cue() -> void:
	if not one_shot_player or not one_shot_dry:
		return
	# Dry scrape+clink 2 layers (per task): low friction noise on main, high glassy sine clink on dry variant.
	# Vary slight by state if avail (e.g. first shards warmer but keep lo-fi sparse).
	var pulse: float = GameState.ember_pulse if GameState else 3.0
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 0.24
	one_shot_player.stream = g
	one_shot_player.volume_db = -15.0
	one_shot_player.pitch_scale = 0.96 + clamp(pulse / 40.0, 0.0, 0.06)
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, 185.0, 0.19, 0.48, true, false)  # low scrape noise (use freq loosely for rate feel)

	# layer 2: high clink/tap (sine, dry)
	var g2: AudioStreamGenerator = AudioStreamGenerator.new()
	g2.mix_rate = 44100
	g2.buffer_length = 0.13
	one_shot_dry.stream = g2
	one_shot_dry.volume_db = -21.0
	one_shot_dry.pitch_scale = 1.55 + clamp(pulse / 25.0, 0.0, 0.12)
	one_shot_dry.play()
	_generate_tone_burst(one_shot_dry, 1180.0, 0.09, 0.32, false, false)  # high tap clink

func _play_raid_cue(mitigated: bool) -> void:
	if not one_shot_player:
		return
	var align: float = GameState.alignment if GameState else 0.0
	# Different noise profiles: loss (not mitigated) = low dread rumble noise + longer; mitigated = higher shorter tone-ish on Ash.
	# Vary by align too (tyrant harsher).
	var freq: float = 46.0 if not mitigated else 76.0
	var dur: float = 0.62 if not mitigated else 0.32
	var vdb: float = -8.5 if not mitigated else -14.0
	if align < -0.3 and not mitigated:
		vdb -= 2.0; freq -= 6.0
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = dur + 0.1
	one_shot_player.stream = g
	one_shot_player.bus = "Dread" if not mitigated else "Ash"
	one_shot_player.volume_db = vdb
	one_shot_player.pitch_scale = 0.66 if not mitigated else 0.94
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, freq, dur, 0.68 if not mitigated else 0.38, not mitigated, false)

func _play_choice_cue(resolved: bool, align_delta: float) -> void:
	# Tension rise on offer, resolve sting per moral weight (warm for +, cold for -). Slight pulse/align color.
	if not one_shot_player:
		return
	var pulse: float = GameState.ember_pulse if GameState else 4.0
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 0.85 if resolved else 1.3
	one_shot_player.stream = g
	one_shot_player.bus = "Ember" if align_delta > 0.0 else "Dread"
	one_shot_player.volume_db = -7.0 + clamp(pulse * -0.2, -2.0, 1.0)
	one_shot_player.pitch_scale = 1.07 if align_delta > 0.0 else 0.61
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, 108.0 if align_delta > 0.0 else 51.0, 0.8 if resolved else 1.1, 0.58, align_delta <= 0.0, false)

func _play_revelation_swell(strength: float = 1.0) -> void:
	# Low bell-like resonance swell on gold revelation logs (key reframe/narrative moments).
	# Warmer on positive align, longer on strong. Uses bell mode in generator for austere partials.
	if not one_shot_player:
		return
	var align: float = GameState.alignment if GameState else 0.0
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 1.9
	one_shot_player.stream = g
	one_shot_player.bus = "Ember"
	one_shot_player.volume_db = -19.0 + clamp(strength * 3.5, -1.0, 3.0)
	one_shot_player.pitch_scale = 0.93 + clamp(align * 0.06, -0.04, 0.08)
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, 57.0 + align * 5.0, 1.55, 0.30 * strength, false, true)

func _play_first_bound_sting() -> void:
	# Special "first bound" path claim sting (on resolve if new claim). Resonance chord memory for reframe.
	# Ties to "vein is held" + early choice realization.
	if not one_shot_player:
		return
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 1.15
	one_shot_player.stream = g
	one_shot_player.bus = "Ember"
	one_shot_player.volume_db = -11.0
	one_shot_player.pitch_scale = 0.84
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, 79.0, 0.95, 0.42, false, true)

func _play_expedition_cue(path_id: String = "", is_resolve: bool = false, align_delta: float = 0.0) -> void:
	# Dispatch: step into ash whoosh (noise layer). Resolve: return tone vary by outcome/align_delta (good vs loss).
	# Eta tick is separate sparse in time hook. Uses dispatch/resolve_expeditions hooks via sfx_cue.
	if not one_shot_player:
		return
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 0.85 if is_resolve else 0.55
	one_shot_player.stream = g
	if not is_resolve:
		# dispatch into ash
		one_shot_player.bus = "Ash"
		one_shot_player.volume_db = -17.0
		one_shot_player.pitch_scale = 0.72
		one_shot_player.play()
		_generate_tone_burst(one_shot_player, 195.0, 0.48, 0.29, true, false)
	else:
		# resolve: benevolent returns steadier/warmer tone; loss harsher noise
		var good: bool = align_delta >= -0.02
		one_shot_player.bus = "Ash" if good else "Dread"
		one_shot_player.volume_db = -13.5 if good else -10.0
		one_shot_player.pitch_scale = 1.02 if good else 0.71
		one_shot_player.play()
		_generate_tone_burst(one_shot_player, (92.0 if good else 47.0), 0.72 if good else 0.55, 0.36 if good else 0.52, not good, false)

func _play_eta_tick_cue() -> void:
	# Sparse dry eta tick for expeditions in progress (time passage feel during resolve wait).
	if not one_shot_player:
		return
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 0.12
	one_shot_player.stream = g
	one_shot_player.bus = "UI"
	one_shot_player.volume_db = -25.0
	one_shot_player.pitch_scale = 1.28
	one_shot_player.play()
	_generate_tone_burst(one_shot_player, 710.0, 0.08, 0.18, false, false)

func _generate_tone_burst(player: AudioStreamPlayer, freq: float, dur: float, vol: float, is_noise: bool, is_bell: bool = false) -> void:
	# Fills the generator playback with a simple sine or noise burst so cues are audible (lo-fi placeholder).
	# Extended for bell-like (low inharmonic partials for revelation swell / first bound resonance).
	if player == null or not is_instance_valid(player):
		return
	var pb: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var frames: int = int(dur * 44100.0)
	var phase: float = 0.0
	var step: float = freq / 44100.0
	for i in range(frames):
		var s: float = 0.0
		if is_noise:
			s = randf_range(-0.8, 0.8)
		elif is_bell:
			# Low bell/resonance: fund + inharmonic overtones (cold austere, not bright)
			var f1: float = sin(phase * TAU)
			var f2: float = 0.38 * sin(phase * TAU * 2.37)
			var f3: float = 0.18 * sin(phase * TAU * 4.05)
			s = f1 + f2 + f3
			phase += step
		else:
			s = sin(phase * TAU)
			phase += step
		# slight envelope
		var env: float = 1.0 - (float(i) / float(max(1, frames)))
		pb.push_frame(Vector2(s * vol * env, s * vol * env))

func _fill_ash_ambient(frames_cap: int = 600) -> void:
	# Better low brown noise fill (lowpassed integrated white for rumble/hiss feel, not harsh white).
	# Sparse, called smartly from time hook; stateful prev for continuity.
	if ash_ambient == null or not is_instance_valid(ash_ambient):
		return
	var pb: AudioStreamGeneratorPlayback = ash_ambient.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var avail: int = pb.get_frames_available()
	var to_push: int = min(avail, frames_cap)
	for i in range(to_push):
		var white: float = randf_range(-0.55, 0.55)
		_ash_prev = _ash_prev * 0.91 + white * 0.09  # brown-ish lowpass integration, slow drift
		var s: float = _ash_prev * 0.29  # quiet ash wind/scrape
		pb.push_frame(Vector2(s, s))

func _on_log_message(text: String, category: String) -> void:
	var color: String = "#c8c0b0"
	match category:
		"revelation":
			color = "#d4a017"  # gold/ominous
		"warning":
			color = "#aa5544"
		"system":
			color = "#888877"

	var line: String = "[color=%s]%s[/color]\n" % [color, text]
	log_label.append_text(line)

	# Auto-scroll is handled by the property

func _on_resource_changed(res: String, _new_amount: float, _delta: float) -> void:
	_refresh_resources_display()
	# Simple juice for resource changes (helps player feel the 'gather' worked)
	resources_container.modulate = Color(1.2, 1.15, 0.9)
	var tween := create_tween()
	tween.tween_property(resources_container, "modulate", Color(1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)

func _on_rate_changed(_res: String, _new_rate: float) -> void:
	_refresh_resources_display()

func _on_alignment_changed(new_val: float, _delta: float, _reason: String) -> void:
	alignment_bar.value = new_val
	_update_status()
	# Dynamic mix stub: tyrant path more dread grit (lower ash, boost dread), benevolent steadier ember.
	var ash_idx: int = AudioServer.get_bus_index("Ash")
	var dread_idx: int = AudioServer.get_bus_index("Dread")
	var ember_idx: int = AudioServer.get_bus_index("Ember")
	if ash_idx >= 0:
		AudioServer.set_bus_volume_db(ash_idx, -26.0 + clamp(new_val * -6.0, -8.0, 3.0))
	if dread_idx >= 0:
		AudioServer.set_bus_volume_db(dread_idx, -16.0 + clamp(new_val * 5.0, -6.0, 2.0))  # less dread on positive
	if ember_idx >= 0:
		AudioServer.set_bus_volume_db(ember_idx, -20.0 + clamp(new_val * 3.0, -2.0, 4.0))

func _on_population_changed(_total: int, _free: int, _delta: int) -> void:
	_refresh_resources_display()
	_update_status()
	_refresh_actions()
	_refresh_choice_prompt()

func _on_phase_advanced(new_phase: String) -> void:
	_update_status()
	_log_phase_flavor(new_phase)
	_refresh_actions()  # ensure new phase actions (e.g. defend/dispatch) appear immediately on outlands etc.
	_refresh_choice_prompt()
	if new_phase == "outlands":
		_ensure_outlands_panel()
		_refresh_outlands()
		_ensure_map_panel()
		_refresh_map()
		_ensure_memory_panel()
		_refresh_memories()
		_play_outlands_unfurl()  # wider ash + new subtle drone per SOUND_DIRECTION phase advance

func _log_phase_flavor(p: String) -> void:
	match p:
		"hearth":
			# Polished: ember/ash language, no "fire" remnant
			if NarrativeSystem:
				NarrativeSystem.trigger_revelation("The ember holds. Other embers stir. You are no longer entirely alone with the ash.")
			else:
				GameEvents.log_message.emit("The ember holds. Other embers stir. You are no longer entirely alone with the ash.", "revelation")
		"village":
			var vtxt: String = "What was a spark is now a small circle of light and people. The darkness has a shape."
			if NarrativeSystem:
				NarrativeSystem.trigger_revelation(vtxt)
			else:
				GameEvents.log_message.emit(vtxt, "revelation")
		"outlands":
			# Minimal addition for phase flavor (reframe log for outlands is in GameState per plan; this echoes the widening)
			if NarrativeSystem:
				NarrativeSystem.trigger_revelation("The ash thins along the lines. Embers stir farther out. What was foraging now reaches for dominion.")
			else:
				GameEvents.log_message.emit("The ash thins along the lines. Embers stir farther out. What was foraging now reaches for dominion.", "revelation")

func _refresh_resources_display() -> void:
	# Clear and rebuild simple labels for prototype
	for child in resources_container.get_children():
		child.queue_free()

	# At the absolute start (complete darkness, no awareness yet): hide all numbers, resources, pop counts.
	# This keeps the mystery Ã¢â‚¬â€ the player doesn't yet "know" there are shards, rates, or "the lost".
	# The first Nurture action will advance phase, after which the systems reveal gradually.
	if GameState.phase == "dark" and GameState.population == 0 and GameState.resources.get("shards", 0.0) < 0.5:
		var vague: Label = Label.new()
		vague.text = "Embers glow faintly in the ash. One pulses stronger near your hand."
		vague.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
		resources_container.add_child(vague)
		return

	var res_names: Array[String] = ["shards", "resonance", "vitalis"]
	for res in res_names:
		var amount: float = GameState.resources.get(res, 0.0)
		var rate: float = GameState.rates.get(res, 0.0) * GameState.get_prod_mult()

		var label: Label = Label.new()
		var rate_str: String = ""
		if rate > 0.001:
			rate_str = " (+%.0f/min)" % (rate * 60)
		label.text = "%s: %.0f%s" % [res.capitalize(), amount, rate_str]
		label.custom_minimum_size = Vector2(140, 0)
		label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
		resources_container.add_child(label)

	# Population line - flavored for mutations (e.g. The Bound when oppressive)
	var pop_label: Label = Label.new()
	var free: int = GameState._get_free_pop()
	var pop_text: String = "The Lost: %d" % [GameState.population]
	if NarrativeSystem:
		pop_text = NarrativeSystem.get_flavored_text(pop_text)
	pop_label.text = pop_text
	pop_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75))
	resources_container.add_child(pop_label)

	# Surface defense/vigil when it matters (outlands+): makes the Defend action's investment visible and ties to raid mitigation.
	if GameState.phase == "outlands":
		var def_val: float = GameState.defense_strength
		var watch: int = int(GameState.buildings.get("watch_spire", 0))
		if def_val > 0.1 or watch > 0:
			var def_label: Label = Label.new()
			var dstr: String = "Paths watched: %.1f" % def_val
			if watch > 0:
				dstr += " (+spire)"
			def_label.text = dstr
			def_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
			def_label.custom_minimum_size = Vector2(140, 0)
			resources_container.add_child(def_label)

func _refresh_actions() -> void:
	# 100% data-driven action buttons (from action_data) + minimal special for dynamic path dispatches
	for child in actions_container.get_children():
		child.queue_free()
	action_buttons.clear()

	# Static actions from data (conditions or unlocked_buildings determine visibility)
	for aid in GameState.action_data.keys():
		var adef: Dictionary = GameState.action_data[aid]
		# Visibility: either meets conditions in data, or is a "build" action whose building is unlocked, or in the unlocked list
		var show: bool = false
		var by_unlock: bool = aid in GameState.unlocked_buildings
		var by_cond: bool = GameState.check_conditions(adef.get("conditions", {}))
		if aid == "nurture_ember" and by_cond:
			# Special case for the very first action in darkness: always show when conds met.
			# This ensures the starter button appears even with save timing or state edge cases.
			show = true
		elif by_unlock:
			show = true
		elif by_cond and not adef.has("unlocks_at"):
			# runtime conds (e.g. pop free for assign) only if no explicit unlock gate like for demand_more
			show = true
		elif adef.get("effects", {}).has("build"):
			var bld: String = str(adef["effects"]["build"])
			if bld in GameState.unlocked_buildings:
				show = true
		if show:
			var tip: String = str(adef.get("tooltip", adef.get("desc", "")))
			var cost: Dictionary = adef.get("cost", {}).duplicate()
			# For build actions (raise_haven, set_foraging etc): action cost in json is {}, real cost is on the target building.
			# Pull it in so tooltip shows e.g. "(costs 40 shards)" even though the "Raise a Haven" option appears as soon as
			# the haven building unlocks_at 15 shards (via _check_unlocks + available_actions_changed + cond logic).
			# This removes the "click and get not-enough surprise" friction for new options.
			if cost.is_empty() and adef.get("effects", {}).has("build"):
				var bld: String = str(adef["effects"]["build"])
				if GameState and bld in GameState.building_data:
					var bcost: Dictionary = GameState.building_data[bld].get("cost", {})
					if not bcost.is_empty():
						cost = bcost.duplicate()
			if not cost.is_empty():
				var cstr := " (costs "
				var first := true
				for k in cost:
					if not first:
						cstr += ", "
					cstr += str(cost[k]) + " " + k
					first = false
				cstr += ")"
				tip += cstr
			if adef.has("cooldown"):
				tip += " (cooldown " + str(adef["cooldown"]) + "s)"
			var nm: String = str(adef.get("name", aid))
			if NarrativeSystem:
				nm = NarrativeSystem.get_flavored_text(nm)
				tip = NarrativeSystem.get_flavored_text(tip)
			_add_action_button(aid, nm, tip)

	actions_container.queue_sort()

	# Outlands / paths actions (dynamic from paths data; keep loop as paths are runtime discovered)
	# defend_paths is added via the 100% data-driven loop above (its conditions include phase=="outlands")
	if GameState.phase == "outlands":
		for p_id in GameState.discovered_paths:
			if not GameState.path_claims.get(p_id, false):
				var has_active: bool = false
				for e in GameState.active_expeditions:
					if e.get("path_id", "") == p_id:
						has_active = true
						break
				if not has_active:
					var label: String = p_id.capitalize().replace("_", " ")
					var dispatch_id: String = "dispatch_" + p_id
					var button_text: String = "Send to " + label
					var tip_text: String = "The lost walk this path in the ash."
					if NarrativeSystem:
						button_text = NarrativeSystem.get_flavored_text(button_text)
						tip_text = NarrativeSystem.get_flavored_text(tip_text)
					_add_action_button(dispatch_id, button_text, tip_text)

	# Population assignments (assign_forager / unassign_forager) are now 100% data-driven via their conditions in action_data (free_pop_gte etc) -- added in the loop above when conditions met.

	# Early choice now has a dedicated prompt area (see _refresh_choice_prompt + _show_choice_prompt).
	# We still surface the action ids here for keyboard/flow, but the real UI is the prompt section for impact.
	if GameState.flags.get("incursion_pending", false) and not GameState.flags.get("incursion_handled", false):
		# Keep minimal action fallbacks (flavored)
		var ctx: Dictionary = {}
		if NarrativeSystem: ctx = NarrativeSystem.get_current_context()
		_add_action_button("choice_shelter_incursion", NarrativeSystem.get_flavored_text("Shelter them within the havens", ctx) if NarrativeSystem else "Shelter them within the havens", "Cost shards. They join the circle.")
		_add_action_button("choice_seal_havens", NarrativeSystem.get_flavored_text("Seal the havens. Let the ash claim them.", ctx) if NarrativeSystem else "Seal the havens. Let the ash claim them.", "No cost. The circle learns to close.")
		_add_action_button("choice_demand_work", NarrativeSystem.get_flavored_text("Demand they work for the shelter of the pulse.", ctx) if NarrativeSystem else "Demand they work for the shelter of the pulse.", "Shards now. Emptiness from the first step.")

	_update_action_cooldowns()

func _add_action_button(action_id: String, label_text: String, tooltip: String) -> void:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.tooltip_text = tooltip
	btn.set_meta("original_tooltip", tooltip)
	btn.custom_minimum_size = Vector2(300, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_action_pressed.bind(action_id))
	# Style hook for later
	btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))

	actions_container.add_child(btn)
	action_buttons[action_id] = btn

func _update_action_cooldowns() -> void:
	for aid in action_buttons:
		var btn: Button = action_buttons[aid]
		if not is_instance_valid(btn):
			continue
		var adef: Dictionary = GameState.action_data.get(aid, {})
		var has_cd: bool = adef.has("cooldown")
		var orig_tip: String = btn.get_meta("original_tooltip", btn.tooltip_text) if btn.has_meta("original_tooltip") else btn.tooltip_text
		if not has_cd:
			btn.disabled = false
			btn.tooltip_text = orig_tip
			var pb = btn.get_node_or_null("CooldownBar")
			if pb:
				pb.queue_free()
			continue
		var cd: float = float(adef["cooldown"])
		var is_ready: bool = GameState._check_cooldown(aid, cd)
		btn.disabled = not is_ready
		var last: float = float(GameState.cooldowns.get(aid, 0.0))
		var now: float = GameState.total_play_time
		var progress: float = 1.0
		var rem: float = 0.0
		if not is_ready and cd > 0:
			var elapsed: float = now - last
			progress = clamp(elapsed / cd, 0.0, 1.0)
			rem = cd - elapsed
		btn.tooltip_text = orig_tip + (" (%.1fs)" % rem if not is_ready else "")
		if is_ready:
			btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
		var pb: ProgressBar = btn.get_node_or_null("CooldownBar") as ProgressBar
		if is_ready:
			if pb:
				pb.queue_free()
		else:
			if not pb:
				pb = ProgressBar.new()
				pb.name = "CooldownBar"
				pb.custom_minimum_size = Vector2(0, 4)
				pb.show_percentage = false
				pb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				btn.add_child(pb)
			pb.value = progress * 100.0
			pb.modulate = Color(0.85, 0.55, 0.2, 0.75)

func _on_action_pressed(action_id: String) -> void:
	var ok: bool = GameState.perform_action(action_id)
	if not ok:
		# GameState already logged the reason
		pass
	_refresh_actions()
	if ok:
		# Simple juice: flash the actions area on successful action (helps feel responsive for friend)
		actions_container.modulate = Color(1.3, 1.2, 0.9)
		var tween := create_tween()
		tween.tween_property(actions_container, "modulate", Color(1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)

# === Outlands / Paths UI (Phase 2+5 implementation per approved plan wireframe) ===
# Dynamic panel inserted as sibling in MainArea HBox (appears on outlands phase advance).
# Compact: title + dynamic entries (name/desc/status + moral choice buttons from path_data).
# Refreshes on phase outlands, dispatch success, time ticks (for etas), relevant signals.
# All text uses strict differentiation (the lost, ash, veins, paths, ember; Weight in status).
# Uses _add_action_button styling patterns for buttons. No duplicates on refresh.
# Eta computed live from time ticks / total_play_time.

func _on_time_for_ui(_seconds: float) -> void:
	_update_action_cooldowns()
	# Thin per spec: only refresh outlands UI if in that phase (etas, resolved expeditions update live)
	if GameState.phase == "outlands":
		_refresh_outlands()
		_refresh_map()  # live movement of expeditions/raids on schematic veins + visual state (moral/align "binding")
	_refresh_choice_prompt()  # so prompt can appear/disappear live when threshold crossed during ticks
	_update_ember_visual(_seconds)  # keep the placeholder ember visual breathing with the sim pulse state
	_refresh_memories()  # progressive Memory context surfaces as time/events advance (tied to early_choice)
	_update_whisper_banner(_seconds)  # transient notification popup for Ash Whispers events
	_refresh_map()  # ensure map icons for active area whispers update live

	# Ash ambient: more reliable continuous fill (smart: only when buffer has room, small caps to avoid lag/CPU; occasional larger body)
	# No _process; driven by time_advanced ticks.
	if ash_ambient and is_instance_valid(ash_ambient):
		if not ash_ambient.playing:
			ash_ambient.play()
		var pb: AudioStreamGeneratorPlayback = ash_ambient.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb != null:
			var avail: int = pb.get_frames_available()
			if avail > 280:
				_fill_ash_ambient(min(280, avail))
	# Occasional fuller fill for body (still sparse, ~every 3s)
	if GameState and int(GameState.total_play_time * 1.5) % 5 == 0:
		_fill_ash_ambient(220)

	# Slight LFO on ash for living wind/cutoff feel (volume micro + pitch for "muffle" without heavy loops or fx)
	# Slow patient wander; respects austere sparse.
	if ash_ambient and is_instance_valid(ash_ambient) and GameState:
		var t: float = GameState.total_play_time
		var lfo_p: float = 0.89 + sin(t * 0.12) * 0.065  # slow pitch drift ~ feels like cutoff shift
		ash_ambient.pitch_scale = clamp(lfo_p, 0.82, 1.02)
		var lfo_v: float = -2.5 + sin(t * 0.07) * 1.8
		ash_ambient.volume_db = clamp(lfo_v, -6.0, 0.5)

	# Sparse eta tick for expeditions (only when active, very quiet, in time hook)
	_maybe_play_eta_tick()

func _on_action_performed(action_id: String, success: bool) -> void:
	# _on_dispatch handlers: on defend or any dispatch_*, refresh outlands+resources+actions+status (covers action-list and panel calls)
	if not success:
		return
	if action_id == "defend_paths" or action_id.begins_with("dispatch_") or action_id.begins_with("queue_") or action_id.begins_with("assign_labor"):
		if GameState.phase == "outlands":
			_refresh_outlands()
			_refresh_map()  # update visual state, moving elements, defense towers on specific veins + labor indicators
		_refresh_resources_display()
		_refresh_actions()
		_update_status()
		_refresh_memories()  # production/claim/defend/labor-assign actions surface new Memory context (and assign may not add mem but refresh ok)
	if action_id.begins_with("choice_"):
		_refresh_choice_prompt()
		_refresh_actions()
		_refresh_memories()  # early choice resolution adds the core memory entry
		_refresh_resources_display()
		_update_status()
	_update_ember_visual()  # immediate visual response for nurture/feed actions that change ember_pulse
	# Audio cues (sparse, stateful)
	if action_id == "nurture_ember" or action_id == "feed_ember":
		_play_ember_cue( clamp(GameState.ember_pulse / 5.0, 0.4, 1.6) if GameState else 1.0 )
	elif action_id == "gather_shards":
		_play_gather_cue()
	elif action_id == "defend_paths":
		_play_ember_cue(0.6)  # quiet "watch set" tone


func _on_raid_encounter_offered(_raid_id: String) -> void:
	_show_raid_encounter()
	_play_raid_cue(false)
	_refresh_map()

func _on_raid_encounter_resolved(_raid_id: String, _choice_id: String) -> void:
	_hide_raid_encounter()
	_refresh_actions()
	_refresh_resources_display()
	_update_status()
	_refresh_memories()
	_refresh_map()

func _show_raid_encounter() -> void:
	if not GameState or not GameState.has_method("has_pending_raid"):
		return
	if not GameState.has_pending_raid():
		_hide_raid_encounter()
		return
	_ensure_raid_encounter()
	if raid_encounter_content == null or not is_instance_valid(raid_encounter_content):
		return
	for c in raid_encounter_content.get_children():
		c.queue_free()
	var pending: Dictionary = GameState.get_pending_raid()
	var header: Label = Label.new()
	header.text = str(pending.get("title", "Ash Along the Veins"))
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.85, 0.45, 0.35))
	raid_encounter_content.add_child(header)
	var prompt: Label = Label.new()
	prompt.text = str(pending.get("prompt", "The ash moves along the old veins."))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(280, 0)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.82, 0.72))
	prompt.add_theme_font_size_override("font_size", 11)
	raid_encounter_content.add_child(prompt)
	var def_lbl: Label = Label.new()
	def_lbl.text = "Defense at the veins: %.1f" % float(pending.get("def_val", 0.0))
	def_lbl.add_theme_font_size_override("font_size", 10)
	def_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	raid_encounter_content.add_child(def_lbl)
	var opts = pending.get("options", [])
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	if typeof(opts) == TYPE_ARRAY:
		for o in opts:
			var b: Button = Button.new()
			b.text = str(o.get("label", "Respond"))
			b.tooltip_text = str(o.get("tip", ""))
			b.custom_minimum_size = Vector2(0, 28)
			b.add_theme_color_override("font_color", Color(0.95, 0.88, 0.78))
			b.add_theme_font_size_override("font_size", 10)
			var oid: String = str(o.get("id", ""))
			b.pressed.connect(_on_raid_response_selected.bind(oid))
			vbox.add_child(b)
	raid_encounter_content.add_child(vbox)
	var note: Label = Label.new()
	note.text = "Your order will be remembered by the ash."
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	raid_encounter_content.add_child(note)
	raid_encounter_panel.show()
	if GameState and not GameState.is_paused and GameState.time_scale > 0:
		_raid_time_was_paused_by_prompt = true
		GameState.set_time_scale(0.0)

func _on_raid_response_selected(choice_id: String) -> void:
	if choice_id == "" or not GameState:
		return
	var res: Dictionary = {}
	if GameState.has_method("resolve_raid_encounter"):
		res = GameState.resolve_raid_encounter(choice_id)
	_hide_raid_encounter()
	if bool(res.get("ok", false)):
		_refresh_actions()
		_refresh_resources_display()
		_update_status()
		_refresh_memories()
		_refresh_map()
		_play_raid_cue(bool(res.get("mitigated", false)))

func _hide_raid_encounter() -> void:
	if raid_encounter_panel and is_instance_valid(raid_encounter_panel):
		raid_encounter_panel.hide()
	if _raid_time_was_paused_by_prompt and GameState and GameState.is_paused:
		GameState.set_time_scale(1.0)
		_raid_time_was_paused_by_prompt = false

func _ensure_raid_encounter() -> void:
	if raid_encounter_panel != null and is_instance_valid(raid_encounter_panel):
		return
	var main_area: HBoxContainer = main_area_node if main_area_node else get_node_or_null("Margin/VBox/MainArea") as HBoxContainer
	raid_encounter_panel = PanelContainer.new()
	raid_encounter_panel.name = "RaidEncounterPanel"
	raid_encounter_panel.custom_minimum_size = Vector2(300, 0)
	raid_encounter_panel.size_flags_horizontal = 0
	var dark_style: StyleBoxFlat = StyleBoxFlat.new()
	dark_style.bg_color = Color(0.05, 0.02, 0.02, 0.97)
	dark_style.border_width_left = 1
	dark_style.border_width_top = 1
	dark_style.border_width_right = 1
	dark_style.border_width_bottom = 1
	dark_style.border_color = Color(0.55, 0.28, 0.22, 1)
	dark_style.corner_radius_top_left = 4
	dark_style.corner_radius_top_right = 4
	dark_style.corner_radius_bottom_right = 4
	dark_style.corner_radius_bottom_left = 4
	raid_encounter_panel.add_theme_stylebox_override("panel", dark_style)
	var marg: MarginContainer = MarginContainer.new()
	marg.add_theme_constant_override("margin_left", 6)
	marg.add_theme_constant_override("margin_top", 4)
	marg.add_theme_constant_override("margin_right", 6)
	marg.add_theme_constant_override("margin_bottom", 4)
	raid_encounter_panel.add_child(marg)
	raid_encounter_content = VBoxContainer.new()
	raid_encounter_content.add_theme_constant_override("separation", 4)
	marg.add_child(raid_encounter_content)
	if main_area:
		main_area.add_child(raid_encounter_panel)
		main_area.move_child(raid_encounter_panel, 0)
	raid_encounter_panel.hide()


func _on_raid_occurred(mitigated: bool, pop_loss: int) -> void:
	# Visual payoff for defense system: ash "reacts" briefly on raid (even mitigated). Ties the world feeling to the mechanic.
	# Stronger reaction on loss. Also forces refresh so defense value (if surfaced) would update.
	if ash_bg_visual and is_instance_valid(ash_bg_visual):
		var orig: Color = ash_bg_visual.modulate
		var flash: Color = Color(0.7, 0.45, 0.4, orig.a + 0.12) if not mitigated else Color(0.55, 0.5, 0.48, orig.a + 0.06)
		ash_bg_visual.modulate = flash
		# Tween back
		var tw: Tween = create_tween()
		tw.tween_property(ash_bg_visual, "modulate", orig, 1.2 if not mitigated else 0.7)
	if ember_visual and is_instance_valid(ember_visual) and not mitigated:
		var eorig: Color = ember_visual.modulate
		ember_visual.modulate = Color(0.9, 0.6, 0.4, eorig.a)
		var tw2: Tween = create_tween()
		tw2.tween_property(ember_visual, "modulate", eorig, 1.8)
	_refresh_actions()
	_update_status()
	_update_ember_visual()
	_refresh_map()  # raid visual reaction on the schematic (threat movement, vein flash, defense hold)
	_play_raid_cue(mitigated)

func _on_speed_pressed(btn: Button) -> void:
	var txt: String = btn.text
	if txt == "Pause":
		GameState.set_time_scale(0.0)
	elif txt == "1x":
		GameState.set_time_scale(1.0)
	elif txt == "5x":
		GameState.set_time_scale(5.0)
	elif txt == "20x":
		GameState.set_time_scale(20.0)
	elif txt == "Reset":
		GameState.reset_to_new_game()
		log_label.clear()
		# Clean dynamic outlands panel on reset (no leak/dupe)
		if outlands_panel and is_instance_valid(outlands_panel):
			outlands_panel.queue_free()
			outlands_panel = null
			outlands_content = null
		if choice_prompt_panel and is_instance_valid(choice_prompt_panel):
			choice_prompt_panel.queue_free()
			choice_prompt_panel = null
			choice_prompt_content = null
		if raid_encounter_panel and is_instance_valid(raid_encounter_panel):
			raid_encounter_panel.queue_free()
			raid_encounter_panel = null
			raid_encounter_content = null
			_raid_time_was_paused_by_prompt = false
		if map_panel and is_instance_valid(map_panel):
			map_panel.queue_free()
			map_panel = null
			map_view = null
		if memory_panel and is_instance_valid(memory_panel):
			memory_panel.queue_free()
			memory_panel = null
			memory_content = null
		if ending_panel and is_instance_valid(ending_panel):
			ending_panel.queue_free()
			ending_panel = null
		_refresh_resources_display()
		_refresh_actions()
		_refresh_choice_prompt()

	_update_status()

func _ensure_outlands_panel() -> void:
	# Exact pattern match to resources rebuild (clear/re-add) + actions (dynamic children) + _add_action_button (158-style button creation).
	# Create once, insert into MainArea HBox as sibling (UI grows on phase). Compact vertical.
	if outlands_panel != null and is_instance_valid(outlands_panel):
		outlands_panel.show()
		return
	var main_area: HBoxContainer = main_area_node if main_area_node else get_node_or_null("Margin/VBox/MainArea") as HBoxContainer
	outlands_panel = PanelContainer.new()
	outlands_panel.custom_minimum_size = Vector2(240, 0)
	outlands_panel.size_flags_horizontal = 0  # shrink to min, don't steal log flex
	# Set dark panel style since current theme is color-only
	var dark_style: StyleBoxFlat = StyleBoxFlat.new()
	dark_style.bg_color = Color(0.03, 0.025, 0.035, 1)
	dark_style.border_width_left = 1
	dark_style.border_width_top = 1
	dark_style.border_width_right = 1
	dark_style.border_width_bottom = 1
	dark_style.border_color = Color(0.18, 0.15, 0.14, 1)
	dark_style.corner_radius_top_left = 4
	dark_style.corner_radius_top_right = 4
	dark_style.corner_radius_bottom_right = 4
	dark_style.corner_radius_bottom_left = 4
	outlands_panel.add_theme_stylebox_override("panel", dark_style)
	# Compact margins like actions but tighter
	var marg: MarginContainer = MarginContainer.new()
	marg.add_theme_constant_override("margin_left", 8)
	marg.add_theme_constant_override("margin_top", 6)
	marg.add_theme_constant_override("margin_right", 8)
	marg.add_theme_constant_override("margin_bottom", 6)
	outlands_panel.add_child(marg)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	marg.add_child(vbox)
	# Title per spec: "Paths in the Ash" (alt "Veins in the Ash" ok; chosen for "paths"/"veins" language)
	var title: Label = Label.new()
	title.text = "Paths in the Ash"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 1))
	vbox.add_child(title)
	# Header graphic decoration (paths_veins art placeholder integrated into unfurl panel per plan/UI brief; faint to preserve austere dark high-contrast)
	if paths_veins_tex:
		var header_icon: TextureRect = TextureRect.new()
		header_icon.texture = paths_veins_tex
		header_icon.custom_minimum_size = Vector2(200, 18)
		header_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_icon.modulate = Color(0.55, 0.5, 0.45, 0.55)  # subtle veins texture wash, not competing with text
		vbox.add_child(header_icon)
	# Content container for dynamic loc entries (cleared on each refresh)
	outlands_content = VBoxContainer.new()
	outlands_content.add_theme_constant_override("separation", 6)
	vbox.add_child(outlands_content)
	main_area.add_child(outlands_panel)

func _refresh_outlands() -> void:
	# Dynamic entries from GameState.path_data + discovered_paths + active_expeditions + path_claims (exact per plan).
	# Each: name/desc/status + moral choice buttons (use dispatch_expedition(choice) not auto).
	# Status shows eta (via time ticks) or claimed/bound. No dups. Compact.
	if outlands_content == null or not is_instance_valid(outlands_content):
		return
	for child in outlands_content.get_children():
		child.queue_free()
	if GameState.phase != "outlands":
		if outlands_panel and is_instance_valid(outlands_panel):
			outlands_panel.hide()
		return
	for p_id in GameState.discovered_paths:
		var pdef: Dictionary = GameState.path_data.get(p_id, {})
		if pdef.is_empty():
			continue
		var pname: String = pdef.get("name", p_id)
		var pdesc: String = pdef.get("desc", "")
		# Apply Narrative flavor/mutations (e.g. "foragers" -> "claiming" once paths opened or tyrant; ensures panel text evolves with prior actions)
		if NarrativeSystem:
			pname = NarrativeSystem.get_flavored_text(pname)
			pdesc = NarrativeSystem.get_flavored_text(pdesc)
		var is_claimed: bool = GameState.path_claims.get(p_id, false)
		var is_active: bool = false
		var eta_rem: float = 0.0
		for exp in GameState.active_expeditions:
			if exp.get("path_id", "") == p_id:
				is_active = true
				eta_rem = max(0.0, float(exp.get("eta", 0.0)) - GameState.total_play_time)
				break
		# Entry vbox (compact)
		var entry: VBoxContainer = VBoxContainer.new()
		entry.add_theme_constant_override("separation", 1)
		# Small paths_veins art icon per entry (integrates placeholder into dynamic list entries per UI brief/plan wireframe; keeps austere by low modulate)
		if paths_veins_tex:
			var eicon: TextureRect = TextureRect.new()
			eicon.texture = paths_veins_tex
			eicon.custom_minimum_size = Vector2(16, 16)
			eicon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			eicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			eicon.modulate = Color(0.65, 0.6, 0.52, 0.65)
			entry.add_child(eicon)
		# Name
		var nlab: Label = Label.new()
		nlab.text = pname
		nlab.add_theme_font_size_override("font_size", 11)
		nlab.add_theme_color_override("font_color", Color(0.88, 0.84, 0.78))
		entry.add_child(nlab)
		# Desc (small, allows some wrap for compact info)
		if pdesc != "":
			var dlab: Label = Label.new()
			dlab.text = pdesc
			dlab.add_theme_font_size_override("font_size", 9)
			dlab.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
			dlab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dlab.custom_minimum_size = Vector2(220, 0)
			entry.add_child(dlab)
		# Status (eta via ticks, claimed uses reframe language) + live eta polish: show chosen moral intent label + flavored text
		var slab: Label = Label.new()
		slab.add_theme_font_size_override("font_size", 9)
		# Live eta polish: lookup active choice label for display (makes intent visible alongside countdown; accurate from stored exp data)
		var active_intent: String = ""
		if is_active:
			var ch: String = ""
			for exp in GameState.active_expeditions:
				if exp.get("path_id", "") == p_id:
					ch = str(exp.get("choice", ""))
					break
			if ch != "":
				for opt in pdef.get("moral_options", []):
					if str(opt.get("id", "")) == ch:
						active_intent = str(opt.get("label", ""))
						break
		var status_base: String = ""
		if is_claimed:
			status_base = "Bound. The vein is held."
			slab.add_theme_color_override("font_color", Color(0.55, 0.65, 0.5))
		elif is_active:
			status_base = "The lost walk the vein"
			if active_intent != "":
				status_base += " (" + active_intent + ")"
			status_base += "... ~%.0f s" % eta_rem
			slab.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
		else:
			status_base = "Unclaimed in the ash."
			slab.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
		if NarrativeSystem:
			status_base = NarrativeSystem.get_flavored_text(status_base)
		slab.text = status_base
		entry.add_child(slab)
		# Moral choice buttons if ready to dispatch (from path_data.moral_options); styled after _add_action_button
		if not is_claimed and not is_active:
			var hbox: HBoxContainer = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 3)
			var opts: Array = pdef.get("moral_options", [])
			for opt in opts:
				var oid: String = str(opt.get("id", ""))
				var olbl: String = opt.get("label", oid)
				if NarrativeSystem:
					olbl = NarrativeSystem.get_flavored_text(olbl)
				var cbtn: Button = Button.new()
				cbtn.text = olbl
				cbtn.tooltip_text = "Dispatch the lost along this path with the chosen intent."
				cbtn.custom_minimum_size = Vector2(0, 24)
				cbtn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
				# compact font if supported
				cbtn.add_theme_font_size_override("font_size", 9)
				cbtn.pressed.connect(_on_dispatch_choice.bind(p_id, oid))
				hbox.add_child(cbtn)
			if not hbox.get_children().is_empty():
				entry.add_child(hbox)
		outlands_content.add_child(entry)

func _on_dispatch_choice(path_id: String, choice: String) -> void:
	# Direct call (bypasses generic action for specific moral); on success per spec: refresh outlands + res + actions + status
	var ok: bool = GameState.dispatch_expedition(path_id, choice)
	if ok:
		_refresh_outlands()
		_refresh_resources_display()
		_refresh_actions()
		_update_status()
		_refresh_map()  # live update moving elements / state on dispatch
	# On fail GS already emitted warning log

# === Accelerated Visual Map Panel + Memory (RTS/TD + faction + layman story per approved plan) ===
# Mirrors the exact _ensure/_refresh unfurl + dynamic code-driven pattern used for outlands and choice.
# MapPanel contains/instances the dedicated 2D OutlandsMap scene (schematic veins + moving exp/raid + towers with moral/align state).
# Memory panel surfaces GameState.memory_entries (tied to early_choice) for context while preserving mystery.

func _ensure_map_panel() -> void:
	if map_panel != null:
		return
	# Create panel (dark austere style, min width for map + controls, inserted as sibling in MainArea HBox like outlands)
	map_panel = PanelContainer.new()
	map_panel.name = "MapPanel"
	map_panel.custom_minimum_size = Vector2(280, 0)
	# Use the @onready log_panel (unique name resolved at ready) to clone its style.
	var style: StyleBoxFlat = null
	if log_panel:
		style = log_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		# Fallback (should not normally hit)
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.025, 0.035, 1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.18, 0.15, 0.14, 1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	if style:
		map_panel.add_theme_stylebox_override("panel", style.duplicate())
	# Header + content
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "The Veins (The Ash Remembers)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 1))
	vbox.add_child(title)
	# Instance the 2D map scene (lightweight Node2D with schematic + movement)
	# Embed via SubViewport + SubViewportContainer so the Node2D (with its Camera2D, Line2D, sprites) actually renders inside the UI panel.
	# Direct add of Node2D under Control/VBox does not produce visible canvas items.
	var map_scene: PackedScene = load("res://scenes/OutlandsMap.tscn")
	if map_scene:
		map_view = map_scene.instantiate()
		var svc := SubViewportContainer.new()
		svc.name = "MapViewportContainer"
		svc.custom_minimum_size = Vector2(260, 220)
		svc.stretch = true
		svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sv := SubViewport.new()
		sv.name = "MapViewport"
		sv.size = Vector2i(520, 440)  # 2x for crisp schematic
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.handle_input_locally = true
		sv.add_child(map_view)
		svc.add_child(sv)
		vbox.add_child(svc)
		if map_view.has_method("update_from_gamestate"):
			map_view.update_from_gamestate(true)  # initial sync
	# Optional compact status / dispatch buttons area (hybrid with existing list style)
	var status_hb: HBoxContainer = HBoxContainer.new()
	var status_lbl: Label = Label.new()
	status_lbl.name = "MapStatus"
	status_lbl.text = "Veins claimed: 0"
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_hb.add_child(status_lbl)
	vbox.add_child(status_hb)
	map_panel.add_child(vbox)
	# Insert into MainArea (grows UI surface on outlands, like the historical unfurl)
	if main_area_node:
		main_area_node.add_child(map_panel)
	map_panel.visible = (GameState != null and GameState.phase == "outlands")
	# Wire basic signals for the map instance if it exposes them
	if map_view and map_view.has_signal("vein_focused"):
		map_view.vein_focused.connect(_on_map_vein_focused)
	if map_view and map_view.has_signal("dispatch_requested"):
		map_view.dispatch_requested.connect(_on_map_dispatch_requested)
	if map_view and map_view.has_signal("moral_choice_offered"):
		map_view.moral_choice_offered.connect(_on_map_moral_choice_offered)

func _refresh_map() -> void:
	if map_panel == null or not is_instance_valid(map_panel):
		return
	if GameState.phase != "outlands":
		map_panel.visible = false
		return
	map_panel.visible = true
	if map_view and map_view.has_method("update_from_gamestate"):
		map_view.update_from_gamestate()
	# Compact status (number claimed, defense hint) - search by name since dynamic vbox
	var status: Label = null
	for child in map_panel.get_children():
		if child is VBoxContainer:
			for c2 in child.get_children():
				if c2 is HBoxContainer:
					status = c2.get_node_or_null("MapStatus") as Label
					break
			if status: break
	if status and GameState:
		var claimed: int = 0
		if typeof(GameState.path_claims) == TYPE_DICTIONARY:
			claimed = GameState.path_claims.keys().filter(func(k): return GameState.path_claims[k]).size()
		var qtxt: String = ""
		if GameState.has_method("get_active_queues_text"):
			qtxt = "  |  " + GameState.get_active_queues_text()
		elif GameState.production_queue.size() > 0:
			qtxt = "  | Queues: %d" % GameState.production_queue.size()
		var pl = 0.0
		if "production_labor" in GameState: pl = GameState.production_labor
		var lb = 0.0
		if "labor_boost" in GameState: lb = GameState.labor_boost
		if pl > 0.1 or lb > 0.1:
			qtxt += "  | Labor active"
		status.text = "Veins claimed: %d  |  Paths watched: %.1f%s" % [claimed, GameState.defense_strength, qtxt]
	# Live refresh of moving elements is handled inside the map_view _process / update

func _on_map_vein_focused(path_id: String) -> void:
	# Stub for future: highlight in list or auto-dispatch UI
	if GameState and GameState.has_method("get_path_visual_data"):
		var v: Dictionary = GameState.get_path_visual_data(path_id)
		# Could open moral buttons for this vein or just log
		GameEvents.log_message.emit("Vein focused: " + path_id + " (visual angle " + str(v.get("angle_deg", "?")) + ")", "system")

func _on_map_dispatch_requested(path_id: String, choice: String) -> void:
	# Map requested dispatch (from click/interaction in 2D view); Main can enhance with choice UI later.
	# For now, the map script already tried GameState.dispatch if possible; log for visibility.
	GameEvents.log_message.emit("Map dispatch requested for " + path_id + " (choice: " + choice + ")", "system")
	# Refresh to show any new exp on map
	_refresh_map()

func _on_map_moral_choice_offered(path_id: String, options: Array) -> void:
	# Map click offered moral choices Ã¢â‚¬â€ do NOT auto-pick. Show clickable buttons in the map panel.
	GameEvents.log_message.emit("The ash waits on the " + path_id.replace("_", " ") + ". Choose how they walk it.", "story")
	_show_map_path_choices(path_id, options)
	_refresh_outlands()
	_refresh_actions()

func _show_map_path_choices(path_id: String, options: Array) -> void:
	# Temporary moral buttons under the map status row (player agency for Listen vs Harvest etc.)
	if map_panel == null or not is_instance_valid(map_panel):
		return
	var host: VBoxContainer = null
	for child in map_panel.get_children():
		if child is VBoxContainer:
			host = child
			break
	if host == null:
		return
	# Remove prior map choice bar if any
	var old: Node = host.get_node_or_null("MapMoralChoices")
	if old:
		old.queue_free()
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "MapMoralChoices"
	var title: Label = Label.new()
	var pname: String = path_id
	if GameState and GameState.path_data.has(path_id):
		pname = str(GameState.path_data[path_id].get("name", path_id))
	title.text = "Dispatch: " + pname
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45, 1))
	box.add_child(title)
	for opt in options:
		var b: Button = Button.new()
		b.text = str(opt.get("label", opt.get("id", "Choose")))
		b.tooltip_text = "align " + str(opt.get("alignment", 0))
		b.add_theme_font_size_override("font_size", 10)
		var cid: String = str(opt.get("id", ""))
		b.pressed.connect(_on_map_path_choice_pressed.bind(path_id, cid))
		box.add_child(b)
	host.add_child(box)

func _on_map_path_choice_pressed(path_id: String, choice_id: String) -> void:
	if GameState and GameState.has_method("dispatch_expedition"):
		GameState.dispatch_expedition(path_id, choice_id)
	# Clear the temporary bar
	if map_panel and is_instance_valid(map_panel):
		for child in map_panel.get_children():
			if child is VBoxContainer:
				var old: Node = child.get_node_or_null("MapMoralChoices")
				if old:
					old.queue_free()
				break
	_refresh_map()
	_refresh_outlands()
	_refresh_actions()
	_refresh_memories()

func _ensure_memory_panel() -> void:
	if memory_panel != null:
		return
	memory_panel = PanelContainer.new()
	memory_panel.name = "MemoryPanel"
	memory_panel.custom_minimum_size = Vector2(0, 120)
	# Use the @onready log_panel (unique name resolved at ready) to clone its style.
	var style: StyleBoxFlat = null
	if log_panel:
		style = log_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		# Fallback (should not normally hit)
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.025, 0.035, 1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.18, 0.15, 0.14, 1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	if style:
		memory_panel.add_theme_stylebox_override("panel", style.duplicate())
	var vbox: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.text = "Memory / Reflections (The Ash Remembers What You Chose)"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 1))
	vbox.add_child(title)
	memory_content = VBoxContainer.new()
	memory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(memory_content)
	memory_panel.add_child(vbox)
	if main_area_node:
		main_area_node.add_child(memory_panel)
	memory_panel.visible = (GameState != null and GameState.phase == "outlands")

func _refresh_memories() -> void:
	if memory_panel and is_instance_valid(memory_panel):
		var show_mem: bool = false
		if GameState:
			show_mem = (GameState.phase == "outlands") or (GameState.memory_entries.size() > 0) or (GameState.early_choice != "")
		memory_panel.visible = show_mem
	if memory_content == null or not is_instance_valid(memory_content):
		return
	# Clear and repopulate from GameState (curated, progressive, tied to early_choice per plan)
	for c in memory_content.get_children():
		c.queue_free()
	if not GameState or not ("memory_entries" in GameState):
		return
	for entry in GameState.memory_entries:
		var lbl: RichTextLabel = RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		var txt: String = str(entry.get("text", ""))
		# Subtle gold for key memory/reframe moments
		lbl.text = "[color=#c8a070]" + txt + "[/color]"
		lbl.add_theme_font_size_override("normal_font_size", 11)
		memory_content.add_child(lbl)

# === Proper Early Choice Prompt UI (polish for gut-punch landing) ===
# Distinct visual weight: gold-tinted header, full prompt, prominent option buttons.
# Appears when incursion_pending flag is set by GS _check_early... 
# On selection: perform the choice action (which routes to Narrative.apply + records early_choice + fires immediate + delayed reframes), then hide.
# Optionally pauses time on show so the moment registers.

func _refresh_choice_prompt() -> void:
	if not GameState:
		return
	var pending: bool = GameState.flags.get("incursion_pending", false) and not GameState.flags.get("incursion_handled", false)
	if pending:
		_show_choice_prompt("echo_incursion")
	else:
		_hide_choice_prompt()

func _show_choice_prompt(event_key: String) -> void:
	_ensure_choice_prompt()
	if choice_prompt_content == null or not is_instance_valid(choice_prompt_content):
		return
	# Clear previous option children
	for c in choice_prompt_content.get_children():
		c.queue_free()

	var ctx: Dictionary = {}
	if NarrativeSystem:
		ctx = NarrativeSystem.get_current_context()

	# Header
	var header: Label = Label.new()
	header.text = "A Choice in the Havens"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3))  # ominous gold
	choice_prompt_content.add_child(header)

	# Prompt (use Narrative to flavor with current context / prior actions)
	var prompt_text: String = "Broken figures approach from the ash. They seek the pulse, like the ones who came before."
	if NarrativeSystem:
		var ev: Dictionary = NarrativeSystem.trigger_choice_event(event_key, ctx)
		prompt_text = ev.get("prompt", prompt_text)
	var prompt: Label = Label.new()
	prompt.text = prompt_text
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(260, 0)
	prompt.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	prompt.add_theme_font_size_override("font_size", 11)
	choice_prompt_content.add_child(prompt)

	# Options (3 for echo_incursion; use Narrative flavored labels + descs as tooltips)
	var opts: Array = [
		{"id": "choice_shelter_incursion", "label": "Shelter them", "tip": "Cost shards. They join... and change what the circle already holds."},
		{"id": "choice_seal_havens", "label": "Seal the havens", "tip": "Let the ash take them. The pulse steadies."},
		{"id": "choice_demand_work", "label": "Demand work for shelter", "tip": "Shards now. Their eyes go quiet from the first step."}
	]
	if NarrativeSystem:
		var ev: Dictionary = NarrativeSystem.trigger_choice_event(event_key, ctx)
		var evopts: Array = ev.get("options", [])
		if not evopts.is_empty():
			opts = []
			for o in evopts:
				var cid: String = ""
				if o.get("id") == "shelter": cid = "choice_shelter_incursion"
				elif o.get("id") == "seal": cid = "choice_seal_havens"
				elif o.get("id") == "demand": cid = "choice_demand_work"
				opts.append({"id": cid, "label": o.get("label", ""), "tip": o.get("desc", "")})

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	for opt in opts:
		var b: Button = Button.new()
		b.text = opt.get("label", "Choose")
		b.tooltip_text = opt.get("tip", "")
		b.custom_minimum_size = Vector2(0, 28)
		b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(_on_choice_selected.bind(opt.get("id", "")))
		hbox.add_child(b)
	choice_prompt_content.add_child(hbox)

	# Subtle instruction
	var note: Label = Label.new()
	note.text = "This decision will be remembered by the ash."
	note.add_theme_font_size_override("font_size", 9)
	note.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5))
	choice_prompt_content.add_child(note)

	choice_prompt_panel.show()

	# Pause time on choice for emotional weight (the gut-punch needs a moment)
	if not GameState.is_paused and GameState.time_scale > 0:
		_choice_time_was_paused_by_prompt = true
		GameState.set_time_scale(0.0)

func _on_choice_selected(action_id: String) -> void:
	if action_id == "": return
	var ok: bool = GameState.perform_action(action_id)
	_hide_choice_prompt()
	if ok:
		# Special post-choice revelation already handled in GS via Narrative, but ensure UI catches any new logs
		_refresh_actions()
		_refresh_resources_display()
		_update_status()
		_play_choice_cue(true, 0.0)  # resolve sting (placeholder; could pass real delta from GS choice if exposed)

func _hide_choice_prompt() -> void:
	if choice_prompt_panel and is_instance_valid(choice_prompt_panel):
		choice_prompt_panel.hide()
	# Resume time only if we were the ones who paused it
	if _choice_time_was_paused_by_prompt and GameState and GameState.is_paused:
		GameState.set_time_scale(1.0)
		_choice_time_was_paused_by_prompt = false

func _ensure_choice_prompt() -> void:
	if choice_prompt_panel != null and is_instance_valid(choice_prompt_panel):
		return
	var main_area: HBoxContainer = main_area_node if main_area_node else get_node_or_null("Margin/VBox/MainArea") as HBoxContainer
	choice_prompt_panel = PanelContainer.new()
	choice_prompt_panel.custom_minimum_size = Vector2(280, 0)
	choice_prompt_panel.size_flags_horizontal = 0
	# Set dark panel style since current theme is color-only
	var dark_style: StyleBoxFlat = StyleBoxFlat.new()
	dark_style.bg_color = Color(0.03, 0.025, 0.035, 1)
	dark_style.border_width_left = 1
	dark_style.border_width_top = 1
	dark_style.border_width_right = 1
	dark_style.border_width_bottom = 1
	dark_style.border_color = Color(0.18, 0.15, 0.14, 1)
	dark_style.corner_radius_top_left = 4
	dark_style.corner_radius_top_right = 4
	dark_style.corner_radius_bottom_right = 4
	dark_style.corner_radius_bottom_left = 4
	choice_prompt_panel.add_theme_stylebox_override("panel", dark_style)
	var marg: MarginContainer = MarginContainer.new()
	marg.add_theme_constant_override("margin_left", 6)
	marg.add_theme_constant_override("margin_top", 4)
	marg.add_theme_constant_override("margin_right", 6)
	marg.add_theme_constant_override("margin_bottom", 4)
	choice_prompt_panel.add_child(marg)
	choice_prompt_content = VBoxContainer.new()
	choice_prompt_content.add_theme_constant_override("separation", 4)
	marg.add_child(choice_prompt_content)
	# Insert before actions or at start of main area for visibility (choice is early-game critical)
	main_area.add_child(choice_prompt_panel)
	# Move to front-ish
	main_area.move_child(choice_prompt_panel, 0)
	choice_prompt_panel.hide()

func _update_status() -> void:
	var phase_name: String = GameState.phase.capitalize()
	var align_desc: String = ""
	if GameState.alignment < -0.6:
		align_desc = " (oppressive)"
	elif GameState.alignment < -0.2:
		align_desc = " (harsh)"
	elif GameState.alignment > 0.5:
		align_desc = " (measured)"
	elif GameState.alignment > 0.2:
		align_desc = " (careful)"

	if GameState.phase == "dark":
		status_label.text = "The ash is silent."
	else:
		status_label.text = "Phase: %s%s   |   Time: %.0fs" % [phase_name, align_desc, GameState.total_play_time]

	if GameState.phase == "dark":
		if alignment_section:
			alignment_section.hide()
	else:
		if alignment_section:
			alignment_section.show()

	# Color the alignment bar based on value
	if GameState.alignment < -0.3:
		alignment_bar.modulate = Color(0.9, 0.4, 0.35)
	elif GameState.alignment > 0.3:
		alignment_bar.modulate = Color(0.6, 0.85, 0.6)
	else:
		alignment_bar.modulate = Color(0.7, 0.7, 0.65)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.set_time_scale(0.0 if GameState.time_scale > 0 else 1.0)

func _on_choice_offered(event_key: String) -> void:
	# Dedicated signal for future richer choice UI (dialogs etc). For now the flag-driven prompt catches it via refresh.
	_refresh_choice_prompt()
	_play_choice_cue(false, -0.05)  # rising tension on offer (dread-leaning)

func _on_choice_resolved(event_key: String, choice_id: String) -> void:
	_refresh_choice_prompt()
	# The real gut-punch text (delayed reframe) will appear via the log from GS/Narrative when conditions met later.

func _on_sfx_cue(cue: String, params: Dictionary) -> void:
	# Triggered from GameState (or Narrative) via GameEvents for key moments (dispatch/resolve, first bound claim, reframes).
	# Keeps audio decoupled from direct Main refs; sparse calls only.
	match cue:
		"revelation_swell":
			_play_revelation_swell(params.get("strength", 1.0))
		"first_bound":
			_play_first_bound_sting()
		"expedition_dispatched":
			_play_expedition_cue(params.get("path_id", ""), false)
		"expedition_resolved":
			_play_expedition_cue(params.get("path_id", ""), true, params.get("align_delta", 0.0))
		"reframe_sting":
			# Key reframe moment (delayed choice memory on path/phase etc): use revelation swell + slight choice resolve color
			_play_revelation_swell(params.get("strength", 0.85))
			var ec: String = str(params.get("early_choice", ""))
			if ec != "":
				_play_choice_cue(true, -0.08 if ec in ["demand", "seal"] else 0.04)
		_:
			pass

# Optional sparse eta tick hook in time (called from _on_time_for_ui when outlands + active)
func _maybe_play_eta_tick() -> void:
	if GameState and GameState.phase == "outlands" and not GameState.active_expeditions.is_empty():
		if int(GameState.total_play_time * 2.8) % 13 == 0:
			_play_eta_tick_cue()

func _play_outlands_unfurl() -> void:
	# Hook into phase_advanced for outlands unfurl (wider ash layer, new subtle drone).
	# Per SOUND_DIRECTION: outlands entry "feels like the ash 'opening'" -- pitch down ash, extra fill, low drone.
	if ash_ambient and is_instance_valid(ash_ambient):
		ash_ambient.pitch_scale = max(0.78, ash_ambient.pitch_scale * 0.9)  # wider/open feel
		var ash_idx: int = AudioServer.get_bus_index("Ash")
		if ash_idx >= 0:
			AudioServer.set_bus_volume_db(ash_idx, AudioServer.get_bus_volume_db(ash_idx) - 1.5)
		_fill_ash_ambient(650)

	if not outlands_drone:
		outlands_drone = AudioStreamPlayer.new()
		outlands_drone.bus = "Ash"
		add_child(outlands_drone)
	var g: AudioStreamGenerator = AudioStreamGenerator.new()
	g.mix_rate = 44100
	g.buffer_length = 1.6
	outlands_drone.stream = g
	outlands_drone.volume_db = -23.0
	outlands_drone.pitch_scale = 0.62
	outlands_drone.play()
	# Subtle low drone sine (not noise) for new layer
	_generate_tone_burst(outlands_drone, 37.0, 1.35, 0.20, false, false)


# === Ash Whispers UI (notification popup/banner + map icon support) ===
# Simple transient banner (popup style, gold-tinted like choice/revelation for weight). Auto fades or manual close.
# Icon on map handled in OutlandsMap via active_whispers areas. Ties notification to state.

func _on_whisper_triggered(whisper_id: String, text: String) -> void:
	_show_whisper_banner(text)
	# Also ensure map gets fresh icons/state
	_refresh_map()

func _on_whisper_expired(whisper_id: String, resolved_text: String) -> void:
	if resolved_text != "":
		# Brief secondary notice on resolve (or just log which already happened in GS)
		_show_whisper_banner(resolved_text, 4.5)  # shorter for resolve
	_refresh_map()

func _ensure_whisper_banner() -> void:
	if whisper_banner != null and is_instance_valid(whisper_banner):
		return
	whisper_banner = PanelContainer.new()
	whisper_banner.name = "WhisperBanner"
	whisper_banner.custom_minimum_size = Vector2(300, 0)
	whisper_banner.size_flags_horizontal = 0
	var dark: StyleBoxFlat = StyleBoxFlat.new()
	dark.bg_color = Color(0.04, 0.03, 0.02, 0.95)
	dark.border_width_left = 1
	dark.border_width_top = 1
	dark.border_width_right = 1
	dark.border_width_bottom = 1
	dark.border_color = Color(0.6, 0.52, 0.35, 0.7)  # warm ember-ish border for whisper
	dark.corner_radius_top_left = 3
	dark.corner_radius_top_right = 3
	dark.corner_radius_bottom_right = 3
	dark.corner_radius_bottom_left = 3
	whisper_banner.add_theme_stylebox_override("panel", dark)

	var marg: MarginContainer = MarginContainer.new()
	marg.add_theme_constant_override("margin_left", 8)
	marg.add_theme_constant_override("margin_top", 4)
	marg.add_theme_constant_override("margin_right", 8)
	marg.add_theme_constant_override("margin_bottom", 4)
	whisper_banner.add_child(marg)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	marg.add_child(vb)

	whisper_banner_label = RichTextLabel.new()
	whisper_banner_label.bbcode_enabled = true
	whisper_banner_label.fit_content = true
	whisper_banner_label.scroll_active = false
	whisper_banner_label.add_theme_font_size_override("normal_font_size", 11)
	whisper_banner_label.add_theme_color_override("default_color", Color(0.92, 0.85, 0.7))
	vb.add_child(whisper_banner_label)

	# Close button for popup control (right aligned simple)
	var close: Button = Button.new()
	close.text = "Ãƒâ€”"
	close.custom_minimum_size = Vector2(22, 18)
	close.add_theme_font_size_override("font_size", 11)
	close.pressed.connect(_hide_whisper_banner)
	vb.add_child(close)

	# Insert near top of main area or actions for visibility (like choice)
	var main_area: HBoxContainer = main_area_node if main_area_node else get_node_or_null("Margin/VBox/MainArea") as HBoxContainer
	if main_area:
		main_area.add_child(whisper_banner)
		main_area.move_child(whisper_banner, 0)
	whisper_banner.hide()

func _show_whisper_banner(text: String, duration: float = 12.0) -> void:
	_ensure_whisper_banner()
	if whisper_banner_label:
		whisper_banner_label.text = "[color=#c8a070]Ash Whispers:[/color] " + text
	if whisper_banner:
		whisper_banner.show()
	_whisper_banner_timer = duration

func _hide_whisper_banner() -> void:
	if whisper_banner and is_instance_valid(whisper_banner):
		whisper_banner.hide()
	_whisper_banner_timer = 0.0

func _update_whisper_banner(delta: float) -> void:
	if _whisper_banner_timer > 0.0:
		_whisper_banner_timer -= delta
		if _whisper_banner_timer <= 0.0 and whisper_banner and is_instance_valid(whisper_banner) and whisper_banner.visible:
			# Auto fade simple (instant hide for prototype; could tween alpha)
			_hide_whisper_banner()
	# (No auto re-show to avoid spam; player sees via map icon + log + initial banner popup. State query available via get_active_whispers for future.)




# === R3 Ending overlay (nurture vs harvest WIN / collapse LOSE) ===

func _on_ending_reached(ending_id: String, outcome: String) -> void:
	_ensure_ending_overlay()
	_play_choice_cue(true, (0.2 if outcome == "win" else -0.2))
	_refresh_actions()
	_update_status()

func _ensure_ending_overlay() -> void:
	if GameState == null or not GameState.game_ended:
		return
	if ending_panel != null and is_instance_valid(ending_panel):
		ending_panel.show()
		_refresh_ending_overlay()
		return
	ending_panel = Control.new()
	ending_panel.name = "EndingOverlay"
	ending_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ending_panel.z_index = 80
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.025, 0.82)
	ending_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_panel.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.045, 0.055, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.32, 0.22, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	var badge := Label.new()
	badge.name = "EndingBadge"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 18)
	vbox.add_child(badge)
	var title := Label.new()
	title.name = "EndingTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	var body := RichTextLabel.new()
	body.name = "EndingBody"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(460, 120)
	vbox.add_child(body)
	var stats := Label.new()
	stats.name = "EndingStats"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 13)
	stats.modulate = Color(0.75, 0.7, 0.65)
	vbox.add_child(stats)
	var legacy := RichTextLabel.new()
	legacy.name = "EndingLegacy"
	legacy.bbcode_enabled = true
	legacy.fit_content = true
	legacy.scroll_active = false
	legacy.custom_minimum_size = Vector2(460, 40)
	vbox.add_child(legacy)
	var btn := Button.new()
	btn.name = "EndingRestart"
	btn.text = "Begin Again (Reset)"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(_on_ending_restart_pressed)
	vbox.add_child(btn)
	add_child(ending_panel)
	_refresh_ending_overlay()

func _refresh_ending_overlay() -> void:
	if ending_panel == null or not is_instance_valid(ending_panel) or GameState == null:
		return
	var info: Dictionary = {}
	if GameState.has_method("get_ending_info"):
		info = GameState.get_ending_info()
	var outcome: String = str(info.get("outcome", GameState.ending_outcome))
	var badge_l: Label = ending_panel.find_child("EndingBadge", true, false) as Label
	var title_l: Label = ending_panel.find_child("EndingTitle", true, false) as Label
	var body_l: RichTextLabel = ending_panel.find_child("EndingBody", true, false) as RichTextLabel
	var stats_l: Label = ending_panel.find_child("EndingStats", true, false) as Label
	var legacy_l: RichTextLabel = ending_panel.find_child("EndingLegacy", true, false) as RichTextLabel
	var badge_txt: String = str(info.get("badge", outcome.to_upper()))
	if badge_l:
		badge_l.text = badge_txt
		if outcome == "win":
			badge_l.modulate = Color(0.85, 0.75, 0.35)
		else:
			badge_l.modulate = Color(0.85, 0.35, 0.3)
	if title_l:
		title_l.text = str(info.get("title", GameState.ending_id))
	if body_l:
		body_l.text = "[center]" + str(info.get("body", "")) + "[/center]"
	if stats_l:
		stats_l.text = "Weight: %.2f  |  Early choice: %s  |  Claims: %s  |  Path morals N/H: %s/%s  |  Pop: %s" % [
			float(info.get("alignment", GameState.alignment)),
			str(info.get("early_choice", GameState.early_choice)),
			str(info.get("claims", 0)),
			str(info.get("nurture_tally", 0)),
			str(info.get("harvest_tally", 0)),
			str(info.get("population", GameState.population))
		]
	if legacy_l:
		var leg: String = str(info.get("legacy", ""))
		if leg != "":
			legacy_l.text = "[center][i]" + leg + "[/i][/center]"
		else:
			legacy_l.text = ""

func _on_ending_restart_pressed() -> void:
	# Reuse Reset path so panels rebuild cleanly
	GameState.reset_to_new_game()
	log_label.clear()
	if outlands_panel and is_instance_valid(outlands_panel):
		outlands_panel.queue_free()
		outlands_panel = null
		outlands_content = null
	if choice_prompt_panel and is_instance_valid(choice_prompt_panel):
		choice_prompt_panel.queue_free()
		choice_prompt_panel = null
		choice_prompt_content = null
	if raid_encounter_panel and is_instance_valid(raid_encounter_panel):
		raid_encounter_panel.queue_free()
		raid_encounter_panel = null
		raid_encounter_content = null
	if map_panel and is_instance_valid(map_panel):
		map_panel.queue_free()
		map_panel = null
		map_view = null
	if memory_panel and is_instance_valid(memory_panel):
		memory_panel.queue_free()
		memory_panel = null
		memory_content = null
	if ending_panel and is_instance_valid(ending_panel):
		ending_panel.queue_free()
		ending_panel = null
	_refresh_resources_display()
	_refresh_actions()
	_refresh_choice_prompt()
	_update_status()
	_update_ember_visual()
