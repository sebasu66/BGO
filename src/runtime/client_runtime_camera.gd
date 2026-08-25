extends "res://src/runtime/client_runtime_gameplay.gd"

const UI_THEME_PROFILES = preload("res://src/components/ui/theme_profiles/ui_theme_profiles.gd")

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
					"%s Â· owner %s Â· %s"
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
