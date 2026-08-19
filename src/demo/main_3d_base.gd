extends Node3D

const GRID_COLUMNS := 8
const GRID_ROWS := 6
const CELL_SIZE := 1.2
const GAME_ID_DEFAULT := "TEST001"
const ROLE_DISPLAY := "display"
const ROLE_PLAYER := "player"
const MODE_PICK_UP := "pick_up"
const MODE_PLACE := "place"
const MOVE_DURATION := 1.25
const PLAYER_AREA_X := 6.15
const PLAYER_AREA_DEPTH := 7.2

var repository: GameSessionRepository
var logger: BgoLogger
var client_role := ROLE_DISPLAY
var game_id := GAME_ID_DEFAULT
var player_id := "player_1"
var interaction_mode := MODE_PICK_UP
var client_id := ""

var selected_piece: Node3D
var pieces: Dictionary = {}
var _session_seed_requested := false
var _pointer_down := false
var _pointer_dragged := false
var _pointer_start := Vector2.ZERO

var _camera_yaw := 0.0
var _camera_pitch := deg_to_rad(52.0)
var _camera_distance := 12.8
var _camera_focus := Vector3.ZERO
var _desired_focus := Vector3.ZERO
var _focus_release_at := 0.0

var _mode_label: Label
var _status_label: Label
var _debug_label: Label
var _player_controls: Control
var _hand_strip: HBoxContainer
var _pickup_button: Button
var _place_button: Button

@onready var camera: Camera3D = $Camera3D
@onready var title_label: Label = $UI/Title
@onready var hint_label: Label = $UI/Hint


func _animate_piece(piece: Node3D, target: Vector3, reason: String) -> void:
	# A visible lift/travel/drop arc. Total duration is ~1.25 s.
	var start := piece.position
	var lift_start := start + Vector3(0, 0.75, 0)
	var lift_target := target + Vector3(0, 0.75, 0)
	logger.info(
		"PIECE_ANIMATION_STARTED",
		{
			"piece_id": piece.name,
			"reason": reason,
			"from": _vec3_payload(start),
			"to": _vec3_payload(target)
		}
	)
	var tween := piece.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(piece, "position", lift_start, 0.20)
	tween.tween_property(piece, "position", lift_target, 0.80)
	tween.tween_property(piece, "position", target, 0.25)


func _select_piece(piece: Node3D) -> void:
	selected_piece = piece
	for candidate in pieces.values():
		(candidate as Node3D).scale = Vector3.ONE * (1.12 if candidate == selected_piece else 1.0)
	logger.info("HAND_ACTIVE_CHANGED", {"piece_id": piece.name})
	_refresh_hand_strip()


func _create_hud() -> void:
	title_label.text = "BGO · %s · %s" % [game_id, client_role.to_upper()]

	_status_label = Label.new()
	_status_label.position = Vector2(30, 96)
	_status_label.size = Vector2(900, 30)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(_status_label)

	if client_role == ROLE_DISPLAY:
		hint_label.text = (
			"Shared display · Firebase TEST001 · " + "player hand areas live outside the board."
		)
		return

	hint_label.text = (
		"Drag to orbit · PICK UP moves a piece into your hand · "
		+ "PLACE moves the active hand piece to the board."
	)

	# Explicit bottom HUD geometry: no scroll/container compression in mobile Web.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = -142
	panel.offset_bottom = -10
	$UI.add_child(panel)
	_player_controls = panel

	var content := Control.new()
	content.custom_minimum_size = Vector2(0, 132)
	panel.add_child(content)

	var hand_title := Label.new()
	hand_title.text = "YOUR HAND"
	hand_title.position = Vector2(14, 8)
	hand_title.size = Vector2(180, 24)
	hand_title.add_theme_font_size_override("font_size", 16)
	content.add_child(hand_title)

	_hand_strip = HBoxContainer.new()
	_hand_strip.position = Vector2(14, 34)
	_hand_strip.size = Vector2(760, 46)
	_hand_strip.add_theme_constant_override("separation", 8)
	content.add_child(_hand_strip)

	_pickup_button = Button.new()
	_pickup_button.text = "PICK UP"
	_pickup_button.toggle_mode = true
	_pickup_button.position = Vector2(14, 86)
	_pickup_button.size = Vector2(150, 40)
	_pickup_button.pressed.connect(func(): _set_mode(MODE_PICK_UP))
	content.add_child(_pickup_button)

	_place_button = Button.new()
	_place_button.text = "PLACE"
	_place_button.toggle_mode = true
	_place_button.position = Vector2(174, 86)
	_place_button.size = Vector2(150, 40)
	_place_button.pressed.connect(func(): _set_mode(MODE_PLACE))
	content.add_child(_place_button)

	_mode_label = Label.new()
	_mode_label.text = "Mode: PICK UP"
	_mode_label.position = Vector2(338, 94)
	_mode_label.size = Vector2(240, 30)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_mode_label)

	_debug_label = Label.new()
	_debug_label.text = "Input debug: waiting for tap"
	_debug_label.position = Vector2(30, 154)
	_debug_label.size = Vector2(800, 28)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 13)
	$UI.add_child(_debug_label)

	_set_mode(MODE_PICK_UP)
	_refresh_hand_strip()


func _refresh_hand_strip() -> void:
	if _hand_strip == null:
		return
	for child in _hand_strip.get_children():
		child.queue_free()

	var hand_ids: Array[String] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "board")) == "hand"
			and str(piece.get_meta("holder_id", "")) == player_id
		):
			hand_ids.append(str(key))
	hand_ids.sort()

	if hand_ids.is_empty():
		var empty := Label.new()
		empty.text = "Hand is empty"
		empty.custom_minimum_size = Vector2(180, 42)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hand_strip.add_child(empty)
		return

	for piece_id in hand_ids:
		var piece := pieces[piece_id] as Node3D
		var button := Button.new()
		var quantity := int(piece.get_meta("quantity", 1))
		button.text = "%s%s" % [piece_id, " ×%d" % quantity if quantity > 1 else ""]
		button.custom_minimum_size = Vector2(150, 42)
		button.toggle_mode = true
		button.button_pressed = piece == selected_piece
		button.pressed.connect(_on_hand_item_pressed.bind(piece_id))
		_apply_hand_button_style(button, piece == selected_piece)
		_hand_strip.add_child(button)


func _on_hand_item_pressed(piece_id: String) -> void:
	if not pieces.has(piece_id):
		return
	_select_piece(pieces[piece_id])
	_set_status("Active hand object: %s" % piece_id)


func _set_mode(mode: String) -> void:
	interaction_mode = mode
	if _mode_label != null:
		_mode_label.text = "Mode: %s" % mode.replace("_", " ").to_upper()
	if _pickup_button != null:
		_pickup_button.button_pressed = mode == MODE_PICK_UP
		_apply_mode_button_style(_pickup_button, mode == MODE_PICK_UP, Color(0.90, 0.58, 0.10))
	if _place_button != null:
		_place_button.button_pressed = mode == MODE_PLACE
		_apply_mode_button_style(_place_button, mode == MODE_PLACE, Color(0.18, 0.68, 0.94))
	if logger != null:
		logger.info("INTERACTION_MODE_CHANGED", {"mode": mode})
	_set_debug("mode: %s" % mode)


func _apply_mode_button_style(button: Button, active: bool, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if active else Color(0.10, 0.11, 0.14, 0.96)
	style.border_width_left = 3 if active else 1
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.border_color = accent.lightened(0.22) if active else Color(0.28, 0.30, 0.34)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.text = ("● " if active else "") + ("PICK UP" if button == _pickup_button else "PLACE")


func _apply_hand_button_style(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.42, 0.62, 1.0) if active else Color(0.12, 0.13, 0.16, 0.98)
	style.border_width_left = 3 if active else 1
	style.border_width_top = 3 if active else 1
	style.border_width_right = 3 if active else 1
	style.border_width_bottom = 3 if active else 1
	style.border_color = Color(0.62, 0.82, 1.0) if active else Color(0.30, 0.32, 0.36)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover", style)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _set_debug(text: String) -> void:
	if _debug_label != null:
		_debug_label.text = "Input debug: %s" % text


func _configure_camera() -> void:
	_camera_yaw = 0.0
	_camera_pitch = deg_to_rad(52.0 if client_role == ROLE_DISPLAY else 45.0)
	_camera_distance = 12.8 if client_role == ROLE_DISPLAY else 10.2
	_update_camera_transform()


func _update_camera_transform() -> void:
	var horizontal := cos(_camera_pitch) * _camera_distance
	camera.position = (
		_camera_focus
		+ Vector3(
			sin(_camera_yaw) * horizontal,
			sin(_camera_pitch) * _camera_distance,
			cos(_camera_yaw) * horizontal
		)
	)
	camera.look_at(_camera_focus, Vector3.UP)


func _setup_logger() -> void:
	client_id = (
		"%s-%s-%d-%d" % [client_role, player_id, Time.get_ticks_msec(), randi_range(1000, 9999)]
	)
	logger = BgoLogger.new()
	add_child(logger)
	logger.configure(game_id, client_id)


func _read_launch_options() -> void:
	if OS.has_feature("web"):
		var role_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('role') || 'display'", true
		)
		var game_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('game') || 'TEST001'", true
		)
		var player_value = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('player') || 'player_1'", true
		)
		client_role = str(role_value).to_lower()
		game_id = str(game_value)
		player_id = str(player_value)
	else:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--role="):
				client_role = arg.trim_prefix("--role=").to_lower()
			elif arg.begins_with("--game="):
				game_id = arg.trim_prefix("--game=")
			elif arg.begins_with("--player="):
				player_id = arg.trim_prefix("--player=")
	if client_role != ROLE_PLAYER:
		client_role = ROLE_DISPLAY


func _cell_world(cell: Vector2i) -> Vector3:
	var width := float(GRID_COLUMNS - 1) * CELL_SIZE
	var depth := float(GRID_ROWS - 1) * CELL_SIZE
	return Vector3(
		float(cell.x) * CELL_SIZE - width * 0.5, 0.0, float(cell.y) * CELL_SIZE - depth * 0.5
	)


func _vec3_payload(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _cell_payload(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _pointer_is_over_controls(position: Vector2) -> bool:
	return _player_controls != null and _player_controls.get_global_rect().has_point(position)


func _orbit_camera(relative: Vector2) -> void:
	_camera_yaw -= relative.x * 0.008
	_camera_pitch = clampf(_camera_pitch + relative.y * 0.006, deg_to_rad(28.0), deg_to_rad(72.0))
	_update_camera_transform()
