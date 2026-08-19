extends "res://src/demo/main_componentized.gd"

const PLAYER_CAMERA_MIN_DISTANCE := 4.8
const PLAYER_CAMERA_MAX_DISTANCE := 18.0
const PLAYER_CAMERA_PAN_LIMIT := 9.0
const PLAYER_CAMERA_PAN_SPEED := 0.0028
const PLAYER_CAMERA_ROTATE_SPEED := 0.006

var _active_touches: Dictionary = {}
var _multi_last_distance := 0.0
var _multi_last_centroid := Vector2.ZERO
var _suppress_single_tap := false

var _camera_home_focus := Vector3.ZERO
var _camera_home_yaw := 0.0
var _camera_home_pitch := 0.0
var _camera_home_distance := 0.0

var _utility_panel: PanelContainer
var _utility_content: VBoxContainer
var _utility_collapsed := false


func _configure_camera() -> void:
	super._configure_camera()
	if client_role != ROLE_PLAYER:
		return
	_camera_home_focus = _camera_focus
	_camera_home_yaw = _camera_yaw
	_camera_home_pitch = _camera_pitch
	_camera_home_distance = _camera_distance


func _input(event: InputEvent) -> void:
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


func _handle_player_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_player_camera(0.90)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_player_camera(1.10)
		return
	if event.button_index != MOUSE_BUTTON_LEFT or _pointer_is_over_controls(event.position):
		return
	if event.pressed:
		_begin_pointer(event.position, "mouse")
	else:
		_end_pointer(event.position, "mouse")


func _handle_player_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pointer_down or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	if _pointer_is_over_controls(event.position):
		return
	if event.position.distance_to(_pointer_start) <= 8.0:
		return
	_pointer_dragged = true
	_pan_player_camera(event.relative)


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
	var right := camera.global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()

	var scale := _camera_distance * PLAYER_CAMERA_PAN_SPEED
	_camera_focus += (-right * relative.x + forward * relative.y) * scale
	_camera_focus.x = clampf(_camera_focus.x, -PLAYER_CAMERA_PAN_LIMIT, PLAYER_CAMERA_PAN_LIMIT)
	_camera_focus.z = clampf(_camera_focus.z, -PLAYER_CAMERA_PAN_LIMIT, PLAYER_CAMERA_PAN_LIMIT)
	_desired_focus = _camera_focus
	_update_camera_transform()


func _zoom_player_camera(multiplier: float) -> void:
	_camera_distance = clampf(
		_camera_distance * multiplier, PLAYER_CAMERA_MIN_DISTANCE, PLAYER_CAMERA_MAX_DISTANCE
	)
	_update_camera_transform()


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
	if (
		_utility_panel != null
		and _utility_panel.visible
		and _utility_panel.get_global_rect().has_point(position)
	):
		return true
	return super._pointer_is_over_controls(position)


func _apply_landscape_player_layout() -> void:
	super._apply_landscape_player_layout()
	if client_role != ROLE_PLAYER:
		return
	_hide_button_by_text(_player_controls, "FULL SCREEN")
	_build_utility_strip()


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

	var collapse_button := Button.new()
	collapse_button.text = "‹"
	collapse_button.custom_minimum_size = Vector2(44, 42)
	collapse_button.tooltip_text = "Collapse utility controls"
	collapse_button.pressed.connect(_toggle_utility_strip)
	root.add_child(collapse_button)

	_utility_content = VBoxContainer.new()
	_utility_content.add_theme_constant_override("separation", 8)
	root.add_child(_utility_content)

	_add_utility_button(
		"RESET CAM", reset_player_camera, "Return the camera to the player default view"
	)
	_add_utility_button(
		"FILTER", _open_camera_filters, "Choose which owners and component types are interactive"
	)
	_add_utility_button("FULL SCREEN", _enter_web_fullscreen, "Enter fullscreen landscape mode")
	_add_utility_button("LOBBY", _return_to_lobby, "Return to the test lobby")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_utility_content.add_child(spacer)

	var camera_help := Label.new()
	camera_help.text = "1 finger: pan\nPinch: zoom\n2 fingers: rotate"
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
		_utility_panel.offset_right = 64.0 if _utility_collapsed else 166.0
	var collapse_button := _utility_panel.get_child(0).get_child(0) as Button
	if collapse_button != null:
		collapse_button.text = "›" if _utility_collapsed else "‹"


func _open_camera_filters() -> void:
	var filters := get_node_or_null("CameraFilters")
	if filters == null:
		return
	var standalone_button: Variant = filters.get("_button")
	if standalone_button is Button:
		(standalone_button as Button).visible = false
	filters.call("_toggle_popup")


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
