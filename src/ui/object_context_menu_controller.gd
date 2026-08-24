class_name BgoObjectContextMenuController
extends Node

signal action_requested(action_id: String, piece: Node3D)

const LONG_PRESS_MSEC := 600
const DRAG_THRESHOLD := 10.0
const MENU_SCALE := 0.38
const MENU_SIZE := Vector2i(370, 286)

var _camera: Camera3D
var _ui: CanvasLayer
var _fallback_picker: Callable
var _role_provider: Callable
var _viewer_id_provider: Callable
var _logger: BgoLogger
var _popup: PopupPanel
var _menu: BgoContextMenuComponent
var _piece: Node3D
var _expanded := false
var _pointer_start := Vector2.ZERO
var _pointer_candidate: Node3D
var _touch_index := -1
var _touch_started_msec := 0
var _touch_position := Vector2.ZERO
var _touch_candidate: Node3D


func configure(
	ui: CanvasLayer,
	camera: Camera3D,
	fallback_picker: Callable,
	role_provider: Callable,
	viewer_id_provider: Callable,
	logger: BgoLogger
) -> bool:
	_ui = ui
	_camera = camera
	_fallback_picker = fallback_picker
	_role_provider = role_provider
	_viewer_id_provider = viewer_id_provider
	_logger = logger
	var packed := BgoComponentRegistry.load_scene("bgo.ui.context_menu")
	if packed == null:
		return false
	_popup = PopupPanel.new()
	_popup.name = "ObjectContextPopup"
	_popup.size = MENU_SIZE
	_popup.transparent_bg = true
	_menu = packed.instantiate() as BgoContextMenuComponent
	_menu.name = "ObjectContextMenu"
	_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_menu.size = Vector2(960, 720)
	_menu.scale = Vector2.ONE * MENU_SCALE
	_popup.add_child(_menu)
	_ui.add_child(_popup)
	return true


func is_open() -> bool:
	return _popup != null and _popup.visible


func begin_pointer(position: Vector2) -> void:
	_pointer_start = position
	_pointer_candidate = _piece_at(position)


func drag_pointer(position: Vector2) -> void:
	if position.distance_to(_pointer_start) > DRAG_THRESHOLD:
		_pointer_candidate = null


func end_pointer(position: Vector2) -> bool:
	var candidate := _pointer_candidate
	var is_click := position.distance_to(_pointer_start) <= DRAG_THRESHOLD
	_pointer_candidate = null
	if not is_click or candidate == null:
		return false
	_open(candidate, position)
	return true


func track_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_index = event.index
		_touch_started_msec = Time.get_ticks_msec()
		_touch_position = event.position
		_touch_candidate = _piece_at(event.position)
	elif event.index == _touch_index:
		_cancel_touch()


func track_touch_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index and event.position.distance_to(_touch_position) > DRAG_THRESHOLD:
		_cancel_touch()


func update_long_press() -> bool:
	if (
		_touch_index < 0
		or _touch_candidate == null
		or Time.get_ticks_msec() - _touch_started_msec < LONG_PRESS_MSEC
	):
		return false
	var candidate := _touch_candidate
	var position := _touch_position
	_cancel_touch()
	_open(candidate, position)
	return true


func _cancel_touch() -> void:
	_touch_index = -1
	_touch_started_msec = 0
	_touch_candidate = null


func _piece_at(screen_position: Vector2) -> Node3D:
	if _camera == null:
		return null
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100.0)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node3D
	if collider != null and collider.has_meta("bgo_piece"):
		return collider
	if _fallback_picker.is_valid():
		return _fallback_picker.call(screen_position) as Node3D
	return null


func _open(target: Node3D, screen_position: Vector2) -> void:
	if _popup == null or _menu == null:
		return
	_piece = target
	_expanded = false
	if _menu.reactive_root == null:
		_menu.setup(_props())
	else:
		_menu.rerender(_props())
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	_popup.position = Vector2i(
		int(clampf(screen_position.x, 8.0, viewport_size.x - MENU_SIZE.x - 8.0)),
		int(clampf(screen_position.y, 8.0, viewport_size.y - MENU_SIZE.y - 8.0))
	)
	_popup.popup()
	_log("CONTEXT_MENU_OPENED", {"piece_id": target.name, "role": _viewer_role()})


func _props() -> Dictionary:
	return {
		"actions": _actions(),
		"expanded": _expanded,
		"selected_id": "",
		"on_toggle": Callable(self, "_toggle_move"),
		"on_action": Callable(self, "_on_action"),
	}


func _actions() -> Array[Dictionary]:
	if _piece == null or not _piece.has_method("menu_actions"):
		return []
	var actions: Array[Dictionary] = []
	for value in _piece.call("menu_actions", _viewer_role(), _viewer_id()):
		if value is Dictionary:
			actions.append((value as Dictionary).duplicate(true))
	if _expanded:
		actions.append({"id": "move_slot", "label": "A CASILLA", "depth": 1})
		actions.append({"id": "move_hand", "label": "A MANO", "depth": 1})
		actions.append({"id": "move_area", "label": "A ÁREA", "depth": 1})
	return actions


func _viewer_role() -> String:
	return str(_role_provider.call()) if _role_provider.is_valid() else "spectator"


func _viewer_id() -> String:
	return str(_viewer_id_provider.call()) if _viewer_id_provider.is_valid() else ""


func _toggle_move() -> void:
	_expanded = not _expanded
	_menu.rerender(_props())


func _on_action(action_id: String) -> void:
	if _piece == null:
		return
	var target := _piece
	action_requested.emit(action_id, target)
	_log("CONTEXT_MENU_ACTION", {"piece_id": target.name, "action_id": action_id})
	_popup.hide()


func _log(event_name: String, payload: Dictionary = {}) -> void:
	if _logger != null:
		_logger.info(event_name, payload)
