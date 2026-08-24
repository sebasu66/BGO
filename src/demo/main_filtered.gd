extends "res://src/demo/main_componentized.gd"

const UiThemeProfiles = preload("res://src/components/ui/theme_profiles/ui_theme_profiles.gd")

const PLAYER_CAMERA_MIN_DISTANCE := 4.8
const PLAYER_CAMERA_MAX_DISTANCE := 18.0
const PLAYER_CAMERA_PAN_LIMIT := 9.0
const PLAYER_CAMERA_PAN_SPEED := 0.0028
const PLAYER_CAMERA_ROTATE_SPEED := 0.006
const PLAYER_CAMERA_KEYBOARD_PAN_SPEED := 0.48
const PLAYER_CAMERA_KEYBOARD_ROTATE_SPEED := 1.35
const PLAYER_CAMERA_KEYBOARD_ZOOM_SPEED := 1.25
const PLAYER_CAMERA_FAST_MULTIPLIER := 2.4

static var _hotseat_profile := ""

var _active_touches: Dictionary = {}
var _multi_last_distance := 0.0
var _multi_last_centroid := Vector2.ZERO
var _suppress_single_tap := false
var _camera_drag_button := MOUSE_BUTTON_NONE

var _camera_home_focus := Vector3.ZERO
var _camera_home_yaw := 0.0
var _camera_home_pitch := 0.0
var _camera_home_distance := 0.0

var _utility_panel: PanelContainer
var _utility_content: VBoxContainer
var _utility_collapse_button: Button
var _utility_collapsed := false
var _settings_controller: BgoClientSettingsController
var _settings_panel: BgoSettingsPanel
var _settings_button: Button
var _session_header: BgoSessionHeader
var _game_strip: BgoActionStrip
var _profile_popup: PopupPanel
var _context_controller: BgoObjectContextMenuController


func _read_launch_options() -> void:
	super._read_launch_options()
	match _hotseat_profile:
		"spectator":
			client_role = ROLE_DISPLAY
		"host", "player_1", "player_2":
			client_role = ROLE_PLAYER
			player_id = "player_1" if _hotseat_profile == "host" else _hotseat_profile


func _is_host_viewer() -> bool:
	return _hotseat_profile == "host"


func _set_mode(mode: String) -> void:
	super._set_mode(mode)
	if _game_strip != null:
		_game_strip.set_action_active("pickup", mode == MODE_PICK_UP)
		_game_strip.set_action_active("place", mode == MODE_PLACE)


func _create_hud() -> void:
	super._create_hud()
	_setup_client_settings()
	_setup_modular_shell()
	_setup_context_menu()


func _configure_camera() -> void:
	super._configure_camera()
	if client_role != ROLE_PLAYER:
		return
	_camera_home_focus = _camera_focus
	_camera_home_yaw = _camera_yaw
	_camera_home_pitch = _camera_pitch
	_camera_home_distance = _camera_distance


func _process(delta: float) -> void:
	super._process(delta)
	if _context_controller != null and _context_controller.update_long_press():
		_suppress_single_tap = true
		_pointer_down = false
	if client_role == ROLE_PLAYER and not _camera_keyboard_input_blocked():
		_apply_keyboard_camera(delta)


func _input(event: InputEvent) -> void:
	if (
		event is InputEventScreenTouch
		and _context_controller != null
		and not (event.pressed and _pointer_is_over_controls(event.position))
	):
		_context_controller.track_touch(event)
	if event is InputEventScreenDrag and _context_controller != null:
		_context_controller.track_touch_drag(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_context_mouse_button(event)
		return
	if client_role != ROLE_PLAYER:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event is InputEventMouseButton:
		_handle_player_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_player_mouse_motion(event)
		return
	if event is InputEventKey:
		_handle_player_camera_key(event)


func _handle_player_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_player_camera(0.88, event.position)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_player_camera(1.12, event.position)
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed and _pointer_is_over_controls(event.position):
			return
		_camera_drag_button = event.button_index if event.pressed else MOUSE_BUTTON_NONE
		return
	if event.button_index != MOUSE_BUTTON_LEFT or _pointer_is_over_controls(event.position):
		return
	if event.pressed:
		_begin_pointer(event.position, "mouse")
	else:
		_end_pointer(event.position, "mouse")


func _handle_player_mouse_motion(event: InputEventMouseMotion) -> void:
	if _camera_drag_button == MOUSE_BUTTON_RIGHT:
		_context_controller.drag_pointer(event.position)
		_orbit_player_camera(event.relative)
		return
	if _camera_drag_button == MOUSE_BUTTON_MIDDLE:
		_pan_player_camera(event.relative)
		return
	if not _pointer_down or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if _pointer_is_over_controls(event.position):
		return
	if event.position.distance_to(_pointer_start) <= 8.0:
		return
	_pointer_dragged = true
	_pan_player_camera(event.relative)


func _handle_player_camera_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo or _camera_keyboard_input_blocked():
		return
	match event.physical_keycode:
		KEY_R, KEY_HOME:
			reset_player_camera()
		KEY_EQUAL, KEY_KP_ADD:
			_zoom_player_camera(0.88)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_player_camera(1.12)


func _apply_keyboard_camera(delta: float) -> void:
	var horizontal := (
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	)
	var forward := (
		float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		- float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	)
	var fast := PLAYER_CAMERA_FAST_MULTIPLIER if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if not is_zero_approx(horizontal) or not is_zero_approx(forward):
		_move_player_camera(horizontal, forward, delta * fast)

	var rotation_direction := (
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	)
	if not is_zero_approx(rotation_direction):
		_camera_yaw += rotation_direction * PLAYER_CAMERA_KEYBOARD_ROTATE_SPEED * delta * fast
		_update_camera_transform()

	var zoom_direction := (
		float(Input.is_physical_key_pressed(KEY_PAGEUP))
		- float(Input.is_physical_key_pressed(KEY_PAGEDOWN))
	)
	if not is_zero_approx(zoom_direction):
		var multiplier := exp(-zoom_direction * PLAYER_CAMERA_KEYBOARD_ZOOM_SPEED * delta * fast)
		_zoom_player_camera(multiplier)


func _move_player_camera(horizontal: float, forward_amount: float, delta_scale: float) -> void:
	var right := _camera_flat_right()
	var forward := _camera_flat_forward()
	var speed := _camera_distance * PLAYER_CAMERA_KEYBOARD_PAN_SPEED
	_camera_focus += (right * horizontal + forward * forward_amount) * speed * delta_scale
	_clamp_player_camera_focus()
	_desired_focus = _camera_focus
	_update_camera_transform()


func _orbit_player_camera(relative: Vector2) -> void:
	_camera_yaw -= relative.x * PLAYER_CAMERA_ROTATE_SPEED
	_camera_pitch = clampf(
		_camera_pitch + relative.y * PLAYER_CAMERA_ROTATE_SPEED, deg_to_rad(28.0), deg_to_rad(72.0)
	)
	_update_camera_transform()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _pointer_is_over_controls(event.position):
			return
		_active_touches[event.index] = event.position
		if _active_touches.size() == 1:
			_suppress_single_tap = false
			_begin_pointer(event.position, "touch")
		elif _active_touches.size() == 2:
			_suppress_single_tap = true
			_pointer_dragged = true
			_pointer_down = false
			_reset_multi_touch_reference()
		return

	var had_touch := _active_touches.has(event.index)
	var touch_count_before := _active_touches.size()
	if had_touch:
		_active_touches.erase(event.index)

	if touch_count_before >= 2:
		_suppress_single_tap = true
		_pointer_down = false
		_reset_multi_touch_reference()
		if _active_touches.is_empty():
			_suppress_single_tap = false
		return

	if had_touch and not _suppress_single_tap:
		_end_pointer(event.position, "touch")
	else:
		_pointer_down = false
	if _active_touches.is_empty():
		_suppress_single_tap = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _active_touches.has(event.index):
		return
	_active_touches[event.index] = event.position

	if _active_touches.size() >= 2:
		_pointer_dragged = true
		_pointer_down = false
		_apply_multi_touch_gesture()
		return

	if _suppress_single_tap:
		return
	if event.position.distance_to(_pointer_start) > 8.0:
		_pointer_dragged = true
	_pan_player_camera(event.relative)


func _reset_multi_touch_reference() -> void:
	if _active_touches.size() < 2:
		_multi_last_distance = 0.0
		_multi_last_centroid = Vector2.ZERO
		return
	var points := _first_two_touch_points()
	_multi_last_distance = points[0].distance_to(points[1])
	_multi_last_centroid = (points[0] + points[1]) * 0.5


func _apply_multi_touch_gesture() -> void:
	if _active_touches.size() < 2:
		return
	var points := _first_two_touch_points()
	var current_distance := points[0].distance_to(points[1])
	var current_centroid := (points[0] + points[1]) * 0.5

	if _multi_last_distance > 1.0 and current_distance > 1.0:
		var zoom_ratio := _multi_last_distance / current_distance
		_zoom_player_camera(zoom_ratio)

	if _multi_last_centroid != Vector2.ZERO:
		var centroid_delta := current_centroid - _multi_last_centroid
		_camera_yaw -= centroid_delta.x * PLAYER_CAMERA_ROTATE_SPEED
		_update_camera_transform()

	_multi_last_distance = current_distance
	_multi_last_centroid = current_centroid


func _first_two_touch_points() -> Array[Vector2]:
	var indexes: Array[int] = []
	for key in _active_touches.keys():
		indexes.append(int(key))
	indexes.sort()
	return [
		_active_touches[indexes[0]] as Vector2,
		_active_touches[indexes[1]] as Vector2,
	]


func _pan_player_camera(relative: Vector2) -> void:
	var right := _camera_flat_right()
	var forward := _camera_flat_forward()
	var scale := _camera_distance * PLAYER_CAMERA_PAN_SPEED
	_camera_focus += (-right * relative.x + forward * relative.y) * scale
	_clamp_player_camera_focus()
	_desired_focus = _camera_focus
	_update_camera_transform()


func _zoom_player_camera(multiplier: float, anchor := Vector2(-1.0, -1.0)) -> void:
	var before: Variant = _table_point_under_cursor(anchor)
	_camera_distance = clampf(
		_camera_distance * multiplier, PLAYER_CAMERA_MIN_DISTANCE, PLAYER_CAMERA_MAX_DISTANCE
	)
	_update_camera_transform()
	if before != null:
		var after: Variant = _table_point_under_cursor(anchor)
		if after != null:
			_camera_focus += (before as Vector3) - (after as Vector3)
			_clamp_player_camera_focus()
			_desired_focus = _camera_focus
			_update_camera_transform()


func _camera_flat_right() -> Vector3:
	var right := camera.global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT


func _camera_flat_forward() -> Vector3:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _clamp_player_camera_focus() -> void:
	_camera_focus.x = clampf(_camera_focus.x, -PLAYER_CAMERA_PAN_LIMIT, PLAYER_CAMERA_PAN_LIMIT)
	_camera_focus.z = clampf(_camera_focus.z, -PLAYER_CAMERA_PAN_LIMIT, PLAYER_CAMERA_PAN_LIMIT)


func _table_point_under_cursor(position: Vector2) -> Variant:
	if position.x < 0.0 or position.y < 0.0:
		return null
	var origin := camera.project_ray_origin(position)
	var direction := camera.project_ray_normal(position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func _camera_keyboard_input_blocked() -> bool:
	if _settings_panel != null and _settings_panel.visible:
		return true
	if _profile_popup != null and _profile_popup.visible:
		return true
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


## Resets the player camera to the configured default view.
func reset_player_camera() -> void:
	if client_role != ROLE_PLAYER:
		return
	_camera_focus = _camera_home_focus
	_desired_focus = _camera_home_focus
	_camera_yaw = _camera_home_yaw
	_camera_pitch = _camera_home_pitch
	_camera_distance = _camera_home_distance
	_update_camera_transform()
	if logger != null:
		(
			logger
			. info(
				"PLAYER_CAMERA_RESET",
				{
					"player_id": player_id,
					"distance": _camera_distance,
					"yaw": _camera_yaw,
					"pitch": _camera_pitch,
				}
			)
		)
	_set_status("Camera reset")


func _pointer_is_over_controls(position: Vector2) -> bool:
	if _settings_panel != null and _settings_panel.visible:
		return true
	if _profile_popup != null and _profile_popup.visible:
		return true
	if _context_controller != null and _context_controller.is_open():
		return true
	for strip in [_game_strip]:
		if strip != null and strip.visible and strip.get_global_rect().has_point(position):
			return true
	if (
		_utility_panel != null
		and _utility_panel.visible
		and _utility_panel.get_global_rect().has_point(position)
	):
		return true
	return super._pointer_is_over_controls(position)


func _setup_context_menu() -> void:
	_context_controller = BgoObjectContextMenuController.new()
	_context_controller.name = "ObjectContextMenuController"
	add_child(_context_controller)
	var ready := _context_controller.configure(
		$UI,
		camera,
		Callable(self, "_projected_piece_at"),
		Callable(self, "_context_viewer_role"),
		Callable(self, "_context_viewer_id"),
		logger
	)
	if not ready:
		logger.error("CONTEXT_MENU_COMPONENT_MISSING")
		return
	_context_controller.action_requested.connect(_on_context_action)
	logger.info("CONTEXT_MENU_READY")


func _handle_context_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		if _pointer_is_over_controls(event.position):
			return
		_context_controller.begin_pointer(event.position)
		_camera_drag_button = (
			MOUSE_BUTTON_RIGHT if client_role == ROLE_PLAYER else MOUSE_BUTTON_NONE
		)
		return
	_camera_drag_button = MOUSE_BUTTON_NONE
	_context_controller.end_pointer(event.position)


func _context_viewer_role() -> String:
	if _is_host_viewer():
		return "host"
	return "player" if client_role == ROLE_PLAYER else "spectator"


func _context_viewer_id() -> String:
	return player_id


func _on_context_action(action_id: String, piece: Node3D) -> void:
	if piece == null:
		return
	match action_id:
		"details":
			_set_status(
				(
					"%s · owner %s · %s"
					% [
						piece.name,
						str(piece.get_meta("owner_id", "neutral")),
						str(piece.get_meta("location_type", "table")),
					]
				)
			)
		"details-2":
			_set_status("Component: %s" % str(piece.get_meta("component_id", "unknown")))
		"take", "move_hand":
			_set_mode(MODE_PICK_UP)
			_on_piece_tapped(piece)
		"move", "move_slot":
			_select_piece(piece)
			_set_mode(MODE_PLACE)
		"move_area":
			_select_piece(piece)
			_move_selected_to_area()
		_:
			_set_status("Action %s requires its validated domain command" % action_id)


func _setup_modular_shell() -> void:
	title_label.visible = false
	hint_label.visible = false
	if _status_label != null:
		_status_label.visible = false
	if _settings_button != null:
		_settings_button.visible = false
	var filters := get_node_or_null("CameraFilters")
	if filters != null:
		var filter_button: Variant = filters.get("_button")
		if filter_button is Button:
			(filter_button as Button).visible = false

	var header_scene := BgoComponentRegistry.load_scene("bgo.ui.session_header")
	var strip_scene := BgoComponentRegistry.load_scene("bgo.ui.action_strip")
	if header_scene == null or strip_scene == null:
		logger.error("MODULAR_SHELL_COMPONENT_MISSING")
		return

	_session_header = header_scene.instantiate() as BgoSessionHeader
	_session_header.name = "SessionHeader"
	_session_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_session_header.offset_left = 92
	_session_header.offset_top = 12
	_session_header.offset_right = -12
	_session_header.offset_bottom = 70
	_session_header.profile_pressed.connect(_open_profile_selector)
	_session_header.action_requested.connect(_on_shell_action)
	(
		_session_header
		. configure_actions(
			[
				{"id": "settings", "icon": "settings", "tooltip": "Settings"},
				{"id": "lobby", "icon": "house", "tooltip": "Return to lobby"},
				{"id": "fullscreen", "icon": "maximize", "tooltip": "Full screen"},
			]
		)
	)
	$UI.add_child(_session_header)

	_game_strip = strip_scene.instantiate() as BgoActionStrip
	_game_strip.name = "GameActions"
	_game_strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_game_strip.offset_left = 12
	_game_strip.offset_top = 82
	_game_strip.offset_right = 76
	_game_strip.offset_bottom = 525
	(
		_game_strip
		. configure(
			"GAME",
			[
				{
					"id": "pickup",
					"label": "PICK UP",
					"icon": "hand",
					"toggle": true,
					"group": "hand_mode"
				},
				{
					"id": "place",
					"label": "PLACE",
					"icon": "map-pin",
					"toggle": true,
					"group": "hand_mode"
				},
				{"id": "asset_box", "label": "GAME BOX", "icon": "box"},
				{"id": "filters", "label": "FILTERS", "icon": "filter"},
				{"id": "camera", "label": "RESET CAMERA", "icon": "rotate-ccw"},
				{"id": "help", "label": "GAME MANUAL", "icon": "info"},
			],
			"left"
		)
	)
	_game_strip.action_requested.connect(_on_shell_action)
	$UI.add_child(_game_strip)

	_build_profile_selector()
	_apply_ui_theme_from_settings()
	_refresh_session_header()
	logger.info("MODULAR_UI_SHELL_READY", {"profile": _current_profile_key()})


func _refresh_session_header() -> void:
	if _session_header == null:
		return
	var game: Dictionary = game_definition.get("game", {})
	var profile_key := _current_profile_key()
	var profile_label := "SPECTATOR"
	var profile_icon := "eye"
	var profile_color := Color(0.72, 0.75, 0.78)
	if profile_key == "host":
		profile_label = "HOST"
		profile_icon = "crown"
		profile_color = Color(0.95, 0.78, 0.30)
	elif profile_key.begins_with("player_"):
		profile_color = _player_color(profile_key)
		profile_label = "YELLOW" if profile_key == "player_1" else "BLUE"
		profile_icon = "user"
	(
		_session_header
		. set_state(
			{
				"game_name": str(game.get("name", game_id)),
				"game_type": "BOARD GAME",
				"mode": "GAME",
				"profile_label": profile_label,
				"profile_icon": profile_icon,
				"profile_color": profile_color,
				"turn_number": 0,
			}
		)
	)


func _current_profile_key() -> String:
	if not _hotseat_profile.is_empty():
		return _hotseat_profile
	return player_id if client_role == ROLE_PLAYER else "spectator"


func _build_profile_selector() -> void:
	_profile_popup = PopupPanel.new()
	_profile_popup.name = "ProfileSelector"
	_profile_popup.size = Vector2i(320, 270)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	_profile_popup.add_child(list)
	var title := Label.new()
	title.text = "VIEW AS"
	title.add_theme_font_size_override("font_size", 18)
	list.add_child(title)
	_add_profile_option(list, "spectator", "SPECTATOR", "eye", Color(0.72, 0.75, 0.78))
	_add_profile_option(list, "host", "HOST", "crown", Color(0.95, 0.78, 0.30))
	_add_profile_option(list, "player_1", "YELLOW PLAYER", "user", _player_color("player_1"))
	_add_profile_option(list, "player_2", "BLUE PLAYER", "user", _player_color("player_2"))
	$UI.add_child(_profile_popup)


func _add_profile_option(
	container: VBoxContainer, profile_key: String, label: String, icon_name: String, color: Color
) -> void:
	var button := Button.new()
	button.text = label
	button.icon = LucideTexture.new(icon_name, 24.0, color, 2.0)
	button.custom_minimum_size = Vector2(286, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_switch_hotseat_profile.bind(profile_key))
	container.add_child(button)


func _open_profile_selector() -> void:
	if _profile_popup == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_profile_popup.position = Vector2i(int(viewport_size.x * 0.5 - 160), 78)
	_profile_popup.popup()


func _switch_hotseat_profile(profile_key: String) -> void:
	if profile_key == _current_profile_key():
		_profile_popup.hide()
		return
	_hotseat_profile = profile_key
	logger.info("LOCAL_VIEW_PROFILE_CHANGED", {"profile": profile_key})
	get_tree().reload_current_scene()


func _on_shell_action(action_id: String) -> void:
	match action_id:
		"pickup":
			_set_mode(MODE_PICK_UP if interaction_mode != MODE_PICK_UP else MODE_NONE)
		"place":
			_set_mode(MODE_PLACE if interaction_mode != MODE_PLACE else MODE_NONE)
		"asset_box":
			_set_status("Game Box drawer is available from the hand component")
		"settings":
			_open_settings()
		"filters":
			_open_camera_filters()
		"camera":
			reset_player_camera()
		"fullscreen":
			_enter_web_fullscreen()
		"help":
			_open_help_manual()
		"lobby":
			_return_to_lobby()


func _apply_landscape_player_layout() -> void:
	super._apply_landscape_player_layout()
	if client_role != ROLE_PLAYER:
		return
	_hide_button_by_text(_player_controls, "FULL SCREEN")
	# The modular shell owns utility actions; keep the legacy builder only for old scenes.


func _build_utility_strip() -> void:
	if _utility_panel != null:
		_utility_panel.queue_free()

	_utility_panel = PanelContainer.new()
	_utility_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_utility_panel.offset_left = 12.0
	_utility_panel.offset_right = 166.0
	_utility_panel.offset_top = 14.0
	_utility_panel.offset_bottom = -14.0
	$UI.add_child(_utility_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_utility_panel.add_child(root)

	var top_actions := HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 8)
	root.add_child(top_actions)

	_utility_collapse_button = Button.new()
	_utility_collapse_button.text = "‹"
	_utility_collapse_button.custom_minimum_size = Vector2(44, 42)
	_utility_collapse_button.tooltip_text = "Collapse utility controls"
	_utility_collapse_button.pressed.connect(_toggle_utility_strip)
	top_actions.add_child(_utility_collapse_button)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_actions.add_child(top_spacer)

	var help_button := Button.new()
	help_button.text = "?"
	help_button.custom_minimum_size = Vector2(44, 42)
	help_button.tooltip_text = "Open the BGO help manual in a new tab"
	help_button.pressed.connect(_open_help_manual)
	top_actions.add_child(help_button)

	_utility_content = VBoxContainer.new()
	_utility_content.add_theme_constant_override("separation", 8)
	root.add_child(_utility_content)

	_add_utility_button(
		"RESET CAM", reset_player_camera, "Return the camera to the player default view"
	)
	_add_utility_button(
		"FILTER", _open_camera_filters, "Choose which owners and component types are interactive"
	)
	_add_utility_button("SETTINGS", _open_settings, "Open client graphics and lighting settings")
	_add_utility_button("FULL SCREEN", _enter_web_fullscreen, "Enter fullscreen landscape mode")
	_add_utility_button("LOBBY", _return_to_lobby, "Return to the test lobby")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_utility_content.add_child(spacer)

	var camera_help := Label.new()
	camera_help.text = (
		"Mouse: L/M drag pan · R drag orbit · wheel zoom\n"
		+ "Keys: WASD/arrows pan · Q/E orbit · +/- zoom · R reset"
	)
	camera_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_help.add_theme_font_size_override("font_size", 12)
	_utility_content.add_child(camera_help)


func _add_utility_button(label_text: String, callback: Callable, tooltip: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(130, 48)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	_utility_content.add_child(button)


func _toggle_utility_strip() -> void:
	_utility_collapsed = not _utility_collapsed
	if _utility_content != null:
		_utility_content.visible = not _utility_collapsed
	if _utility_panel != null:
		_utility_panel.offset_right = 116.0 if _utility_collapsed else 166.0
	if _utility_collapse_button != null:
		_utility_collapse_button.text = "›" if _utility_collapsed else "‹"


func _open_help_manual() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('/help/', '_blank', 'noopener,noreferrer');", true)
		logger.info("HELP_MANUAL_OPENED", {"target": "/help/"})
		return
	var manual_path := ProjectSettings.globalize_path("res://web/help/index.html")
	var open_error := OS.shell_open(manual_path)
	if open_error == OK:
		logger.info("HELP_MANUAL_OPENED", {"target": manual_path})
		return
	logger.error("HELP_MANUAL_OPEN_FAILED", {"target": manual_path, "error": open_error})
	_set_status("Could not open the help manual")


func _open_camera_filters() -> void:
	var filters := get_node_or_null("CameraFilters")
	if filters == null:
		return
	var standalone_button: Variant = filters.get("_button")
	if standalone_button is Button:
		(standalone_button as Button).visible = false
	filters.call("_toggle_popup")


func _setup_client_settings() -> void:
	_settings_controller = BgoClientSettingsController.new()
	_settings_controller.name = "ClientSettings"
	add_child(_settings_controller)
	_settings_controller.initialize(self)
	_apply_visual_debug_ui()

	var packed := BgoComponentRegistry.load_scene("bgo.ui.settings_panel")
	if packed == null:
		logger.error("SETTINGS_COMPONENT_MISSING", {"component_id": "bgo.ui.settings_panel"})
		return
	_settings_panel = packed.instantiate() as BgoSettingsPanel
	_settings_panel.name = "SettingsPanel"
	$UI.add_child(_settings_panel)
	_settings_panel.setting_changed.connect(_on_client_setting_changed)
	_settings_panel.close_requested.connect(_close_settings)
	_settings_panel.reset_requested.connect(_reset_settings)

	_settings_button = Button.new()
	_settings_button.text = "⚙"
	_settings_button.tooltip_text = "Settings"
	_settings_button.custom_minimum_size = Vector2(48, 44)
	_settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Keep clear of the existing FILTER control at the far-right edge.
	_settings_button.offset_left = -174
	_settings_button.offset_top = 12
	_settings_button.offset_right = -126
	_settings_button.offset_bottom = 56
	_settings_button.pressed.connect(_open_settings)
	$UI.add_child(_settings_button)
	$UI.move_child(_settings_panel, $UI.get_child_count() - 1)
	logger.info("CLIENT_SETTINGS_READY", _settings_controller.values)


func _open_settings() -> void:
	if _settings_panel == null or _settings_controller == null:
		return
	_settings_panel.open(_settings_controller.values)
	logger.info("SETTINGS_OPENED", {"role": client_role, "player_id": player_id})


func _close_settings() -> void:
	if _settings_panel != null:
		_settings_panel.close()


func _reset_settings() -> void:
	if _settings_controller == null:
		return
	_settings_controller.reset_defaults()
	_apply_visual_debug_ui()
	_settings_panel.open(_settings_controller.values)
	logger.info("SETTINGS_RESET", _settings_controller.values)


func _on_client_setting_changed(key: String, value: Variant) -> void:
	if _settings_controller == null or not _settings_controller.set_value(key, value):
		return
	if key.begins_with("ui_"):
		_apply_ui_theme_from_settings()
	if key == "visual_debug":
		_apply_visual_debug_ui()
	logger.info("CLIENT_SETTING_CHANGED", {"key": key, "value": value})


func _apply_visual_debug_ui() -> void:
	if _debug_label != null and _settings_controller != null:
		_debug_label.visible = bool(_settings_controller.values.get("visual_debug", false))


func _apply_ui_theme_from_settings() -> void:
	if _settings_controller == null:
		return
	var profile_id := (
		"high_contrast"
		if int(_settings_controller.values.get("ui_theme_profile", 0)) == 1
		else "boardroom"
	)
	(
		UiThemeProfiles
		. apply_to(
			$UI,
			profile_id,
			{
				"font_scale": float(_settings_controller.values.get("ui_font_scale", 1.0)),
				"accent": _settings_controller.values.get("ui_accent_color", Color("#d7aa4c")),
			}
		)
	)


func _return_to_lobby() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href='/test-launcher/';", true)
		return
	_set_status("Lobby navigation is available in the Web client")


func _hide_button_by_text(node: Node, target_text: String) -> bool:
	if node == null:
		return false
	if node is Button and (node as Button).text == target_text:
		(node as Button).visible = false
		return true
	for child in node.get_children():
		if _hide_button_by_text(child, target_text):
			return true
	return false


func _on_piece_tapped(piece: Node3D) -> void:
	if bool(piece.get_meta("bgo_filtered_out", false)):
		if logger != null:
			logger.info("FILTERED_COMPONENT_IGNORED", {"piece_id": piece.name})
		return
	super._on_piece_tapped(piece)


func _projected_piece_at(screen_position: Vector2) -> Node3D:
	var closest: Node3D = null
	var closest_distance := INF
	var viewport_size := get_viewport().get_visible_rect().size
	var threshold := maxf(54.0, minf(viewport_size.x, viewport_size.y) * 0.055)
	for value in pieces.values():
		var piece := value as Node3D
		if piece == null or bool(piece.get_meta("bgo_filtered_out", false)):
			continue
		if camera.is_position_behind(piece.global_position):
			continue
		var projected := camera.unproject_position(piece.global_position)
		var distance := projected.distance_to(screen_position)
		if distance < threshold and distance < closest_distance:
			closest = piece
			closest_distance = distance
	return closest
