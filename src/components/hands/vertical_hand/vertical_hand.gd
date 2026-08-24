class_name BgoVerticalHand
extends Control

signal item_selected(item_id: String)
signal mode_selected(mode: String)

# 3D hand presentation tuning. The hand itself has no visible container.
const ITEM_VIEW_SIZE := 156
const ITEM_SCREEN_SIZE := 112.0
const ITEM_CONTENT_SCALE := 0.85
const ITEM_PREVIEW_BASE_SCALE := 2.4
const STACK_STEP := 70.0
const STACK_TILT_DEGREES := 4.0
const SELECTED_SCALE := 1.14
const SELECTED_OFFSET_X := -18.0
const HAND_SIDE_MARGIN := 10.0
const SELECTION_COLOR := Color(0.96, 0.78, 0.30, 0.95)

var _items: Array = []
var _selected_item_id := ""
var _mode := "none"
var _preview_factory: Callable
var _stack: Control
var _preview_viewports: Array[SubViewport] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	get_viewport().size_changed.connect(_rebuild_items)
	_build_shell()


## The renderer supplies the real component representation; Hand owns only presentation.
func set_preview_factory(factory: Callable) -> void:
	_preview_factory = factory
	if is_node_ready():
		_rebuild_items()


## Updates FILO order. Index zero is rendered as the top/front object.
func set_items(items: Array, selected_id := "") -> void:
	_items = items.duplicate(true)
	if not selected_id.is_empty() and _contains_item(selected_id):
		_selected_item_id = selected_id
	elif not _contains_item(_selected_item_id):
		_selected_item_id = _first_item_id()
	if is_node_ready():
		_rebuild_items()


func set_selected(item_id: String) -> void:
	_selected_item_id = item_id if _contains_item(item_id) else _first_item_id()
	if is_node_ready():
		_rebuild_items()


func get_selected_item_id() -> String:
	return _selected_item_id


## Mode remains part of the hand contract, but its controls live in the global action rail.
func set_mode(mode: String) -> void:
	_mode = mode if mode in ["pickup", "none", "place"] else "none"


func get_mode() -> String:
	return _mode


func _build_shell() -> void:
	for child in get_children():
		child.queue_free()
	_preview_viewports.clear()
	_stack = Control.new()
	_stack.name = "FloatingObjectStack"
	_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stack)
	_rebuild_items()


func _rebuild_items() -> void:
	if _stack == null:
		return
	for child in _stack.get_children():
		child.queue_free()
	_preview_viewports.clear()
	if _items.is_empty():
		_selected_item_id = ""
		return
	if not _contains_item(_selected_item_id):
		_selected_item_id = _first_item_id()
	var visible_height := minf(size.y, get_viewport_rect().size.y * 0.72)
	var step := minf(
		STACK_STEP, maxf(34.0, (visible_height - ITEM_SCREEN_SIZE) / maxf(1.0, _items.size() - 1.0))
	)
	var stack_height := ITEM_SCREEN_SIZE + step * (_items.size() - 1)
	var start_y := maxf(0.0, (size.y - stack_height) * 0.5)
	# Reverse insertion keeps FILO index zero visually in front of overlapping siblings.
	for reverse_index in range(_items.size() - 1, -1, -1):
		var item_value: Variant = _items[reverse_index]
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue
		var selected := item_id == _selected_item_id
		var object_control := _build_object_control(item, selected)
		object_control.position = Vector2(
			HAND_SIDE_MARGIN + (SELECTED_OFFSET_X if selected else 0.0),
			start_y + reverse_index * step
		)
		object_control.rotation = deg_to_rad(
			STACK_TILT_DEGREES * (-1.0 if reverse_index % 2 == 0 else 1.0)
		)
		object_control.scale = Vector2.ONE * (SELECTED_SCALE if selected else 1.0)
		_stack.add_child(object_control)


func _build_object_control(item: Dictionary, selected: bool) -> Control:
	var root := Control.new()
	root.name = "HandObject_%s" % str(item.get("id", "item"))
	root.custom_minimum_size = Vector2.ONE * ITEM_SCREEN_SIZE
	root.size = Vector2.ONE * ITEM_SCREEN_SIZE
	root.pivot_offset = root.size * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var viewport := _make_preview_viewport(item)
	root.add_child(viewport)
	var button := TextureButton.new()
	button.name = "ObjectInput"
	button.texture_normal = viewport.get_texture()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.tooltip_text = str(item.get("label", item.get("id", "OBJECT")))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_item_pressed.bind(str(item.get("id", ""))))
	root.add_child(button)
	var focus := Panel.new()
	focus.name = "SelectionFrame"
	focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus.add_theme_stylebox_override(
		"panel", _outline(SELECTION_COLOR if selected else Color.TRANSPARENT, 3 if selected else 0)
	)
	root.add_child(focus)
	var quantity := int(item.get("quantity", 1))
	if quantity > 1:
		var badge := Label.new()
		badge.text = "×%d" % quantity
		badge.position = Vector2(74, 76)
		badge.size = Vector2(36, 28)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_shadow_color", Color.BLACK)
		badge.add_theme_constant_override("shadow_offset_x", 2)
		badge.add_theme_constant_override("shadow_offset_y", 2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(badge)
	return root


func _make_preview_viewport(item: Dictionary) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Preview_%s" % str(item.get("id", "item"))
	viewport.size = Vector2i(ITEM_VIEW_SIZE, ITEM_VIEW_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	_preview_viewports.append(viewport)
	var camera := Camera3D.new()
	camera.fov = 40.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 1.8, 2.5), Vector3(0.0, 0.08, 0.0), Vector3.UP)
	camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	key.light_energy = 1.25
	viewport.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, 1.2, 1.8)
	fill.light_energy = 0.7
	viewport.add_child(fill)
	if _preview_factory.is_valid():
		var preview_node: Node3D = _preview_factory.call(item)
		if preview_node != null:
			preview_node.position = Vector3.ZERO
			preview_node.scale = (Vector3.ONE * ITEM_PREVIEW_BASE_SCALE * ITEM_CONTENT_SCALE)
			viewport.add_child(preview_node)
	return viewport


func _contains_item(item_id: String) -> bool:
	for item_value in _items:
		if item_value is Dictionary and str(item_value.get("id", "")) == item_id:
			return true
	return false


func _first_item_id() -> String:
	for item_value in _items:
		if not item_value is Dictionary:
			continue
		var item_id := str(item_value.get("id", ""))
		if not item_id.is_empty():
			return item_id
	return ""


func _on_item_pressed(item_id: String) -> void:
	_selected_item_id = item_id
	item_selected.emit(item_id)
	_rebuild_items()


func _outline(color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(width)
	style.set_corner_radius_all(10)
	return style
