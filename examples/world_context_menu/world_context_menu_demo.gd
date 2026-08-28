extends Node3D

const CONTEXT_MENU_COMPONENT = preload("res://src/components/ui/context_menu/context_menu_component.gd")

const MENU_TEXTURE_SIZE := Vector2i(960, 720)
const MENU_WORLD_SIZE := Vector2(7.36, 5.52)
const MENU_MIN_HEIGHT := 3.2
const MENU_MAX_HEIGHT := 5.8
const MENU_REFERENCE_VIEWPORT_HEIGHT := 720.0
const MENU_REFERENCE_HEIGHT := 4.8
const MENU_OPEN_DURATION := 0.5
const MENU_CLOSE_DURATION := 0.5
const MENU_ACTIVATION_HOLD := 1.0
const MENU_CONTENT_FADE_DURATION := 0.16
const MENU_CONTENT_SLIDE_PIXELS := 24.0

var _camera: Camera3D
var _piece: MeshInstance3D
var _piece_area: Area3D
var _other_objects: Array[MeshInstance3D] = []
var _game_objects: Array[MeshInstance3D] = []
var _active_object: MeshInstance3D
var _menu_anchor: Node3D
var _menu_surface: MeshInstance3D
var _menu_viewport: SubViewport
var _menu_component
var _reactive_root: ReactiveRootNode
var _expanded := false
var _selected_id := ""
var _menu_open := false
var _menu_safe_margin := 28.0
var _activation_locked := false


func _ready() -> void:
	_build_environment()
	_build_table()
	_build_piece()
	_build_menu()
	_build_camera()
	set_process_input(true)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10161d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8d5e8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -28, 0)
	key.light_color = Color("d9efff")
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)


func _build_table() -> void:
	var table := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(15, 9)
	table.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("27333d")
	material.roughness = 0.82
	material.metallic = 0.06
	table.material_override = material
	add_child(table)


func _build_piece() -> void:
	_piece = MeshInstance3D.new()
	_piece.position = Vector3(3.15, 0.58, 0.3)
	_piece.rotation_degrees.y = -12.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.76
	mesh.bottom_radius = 0.82
	mesh.height = 1.16
	mesh.radial_segments = 64
	_piece.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("080b0f")
	material.metallic = 0.42
	material.roughness = 0.24
	_piece.material_override = material
	add_child(_piece)
	_game_objects.append(_piece)
	_piece_area = Area3D.new()
	_piece.add_child(_piece_area)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.86
	shape.height = 1.2
	collision.shape = shape
	_piece_area.add_child(collision)
	_piece_area.input_event.connect(_on_piece_input)
	_build_other_objects()


func _build_other_objects() -> void:
	for data in [
		[Vector3(-1.4, 0.52, -1.25), Color("6b8fa3")],
		[Vector3(0.2, 0.52, 1.65), Color("8b6b9e")],
		[Vector3(-3.15, 0.52, 0.85), Color("6d9a7d")],
	]:
		var object := MeshInstance3D.new()
		object.mesh = _piece.mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = data[1]
		material.roughness = 0.3
		object.material_override = material
		object.position = data[0]
		add_child(object)
		_other_objects.append(object)
		_game_objects.append(object)

	var edge_object := MeshInstance3D.new()
	edge_object.name = "EdgePiece"
	edge_object.mesh = _piece.mesh
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = Color("b47a4f")
	edge_material.roughness = 0.3
	edge_object.material_override = edge_material
	edge_object.position = Vector3(5.55, 0.52, -2.55)
	add_child(edge_object)
	_other_objects.append(edge_object)
	_game_objects.append(edge_object)
	var edge_area := Area3D.new()
	edge_object.add_child(edge_area)
	var edge_collision := CollisionShape3D.new()
	var edge_shape := CylinderShape3D.new()
	edge_shape.radius = 0.86
	edge_shape.height = 1.2
	edge_collision.shape = edge_shape
	edge_area.add_child(edge_collision)
	edge_area.input_event.connect(_on_edge_piece_input)


func _build_menu() -> void:
	_menu_anchor = Node3D.new()
	_menu_anchor.name = "ContextMenuAnchor"
	_menu_anchor.visible = false
	_piece.add_child(_menu_anchor)
	_menu_anchor.position = Vector3(0.0, 1.28, 0.0)
	_menu_viewport = SubViewport.new()
	_menu_viewport.name = "MenuViewport"
	_menu_viewport.size = MENU_TEXTURE_SIZE
	_menu_viewport.transparent_bg = true
	_menu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_menu_viewport.gui_embed_subwindows = false
	_menu_anchor.add_child(_menu_viewport)
	_menu_component = CONTEXT_MENU_COMPONENT.new()
	_menu_component.name = "ContextMenuComponent"
	_menu_component.size = Vector2(MENU_TEXTURE_SIZE)
	_menu_component.setup(
		{"expanded": _expanded, "selected_id": _selected_id, "on_toggle": _toggle_nested, "on_action": _on_action},
	)
	_menu_viewport.add_child(_menu_component)
	_reactive_root = _menu_component.reactive_root
	_menu_surface = MeshInstance3D.new()
	_menu_surface.name = "ContextMenuBillboard"
	var quad := QuadMesh.new()
	quad.size = MENU_WORLD_SIZE
	_menu_surface.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_texture = _menu_viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_menu_surface.material_override = material
	_menu_anchor.add_child(_menu_surface)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 39.0
	_camera.current = true
	_camera.position = Vector3(8.4, 7.4, 9.2)
	add_child(_camera)
	_camera.look_at(Vector3(0.4, 0.0, 0.0), Vector3.UP)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_menu()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _menu_open:
			var delivered_to_menu := _forward_pointer_to_menu(event)
			if event.pressed and not delivered_to_menu:
				_close_menu()


func _process(_delta: float) -> void:
	if _menu_open:
		_update_menu_size()
		_fit_menu_to_viewport()


func _on_piece_input(_camera_node: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_menu_for(_piece)
		get_viewport().set_input_as_handled()


func _on_edge_piece_input(_camera_node: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_menu_for(_other_objects.back())
		get_viewport().set_input_as_handled()


func _open_menu_for(object: MeshInstance3D) -> void:
	if _menu_open:
		return
	_menu_open = true
	_activation_locked = false
	_active_object = object
	_menu_anchor.visible = true
	_menu_anchor.global_position = _active_object.global_position + Vector3(0.0, 1.28, 0.0)
	_set_background_filter(true)
	_update_menu_size()
	_fit_menu_to_viewport()
	_menu_anchor.scale = Vector3(5.0, 5.0, 5.0)
	_reactive_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_reactive_root.position = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_anchor, "scale", Vector3.ONE, MENU_OPEN_DURATION)
	tween.parallel().tween_property(_reactive_root, "modulate:a", 1.0, MENU_OPEN_DURATION)


func _close_menu() -> void:
	if not _menu_open:
		return
	_menu_open = false
	_activation_locked = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_menu_anchor, "scale", Vector3(5.0, 5.0, 5.0), MENU_CLOSE_DURATION)
	tween.parallel().tween_property(_reactive_root, "modulate:a", 0.0, MENU_CLOSE_DURATION)
	tween.tween_callback(func() -> void:
		_menu_anchor.visible = false
		_set_background_filter(false)
		_expanded = false
		_selected_id = ""
		_active_object = null
		_activation_locked = false
		_rerender_menu()
	)


func _set_background_filter(active: bool) -> void:
	for object in _game_objects:
		if object == _active_object:
			continue
		var material := object.material_override as StandardMaterial3D
		if material == null:
			continue
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if active else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = 0.14 if active else 1.0


func _update_menu_size() -> void:
	if _menu_surface == null:
		return
	var viewport_height := get_viewport().get_visible_rect().size.y
	var desired_height := clampf(
		MENU_REFERENCE_VIEWPORT_HEIGHT / maxf(viewport_height, 1.0) * MENU_REFERENCE_HEIGHT,
		MENU_MIN_HEIGHT,
		MENU_MAX_HEIGHT,
	)
	_menu_surface.scale = Vector3.ONE * (desired_height / MENU_WORLD_SIZE.y)


func _fit_menu_to_viewport() -> void:
	if _camera == null or _menu_surface == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var center := _camera.unproject_position(_menu_anchor.global_position)
	var half_width := MENU_WORLD_SIZE.x * _menu_surface.scale.x * 0.5
	var half_height := MENU_WORLD_SIZE.y * _menu_surface.scale.y * 0.5
	var camera_basis := _camera.global_transform.basis
	var right_screen := _camera.unproject_position(_menu_anchor.global_position + camera_basis.x * half_width)
	var up_screen := _camera.unproject_position(_menu_anchor.global_position + camera_basis.y * half_height)
	var pixels_per_world_x := maxf(absf(right_screen.x - center.x) / half_width, 0.001)
	var pixels_per_world_y := maxf(absf(center.y - up_screen.y) / half_height, 0.001)
	var shift := Vector2.ZERO
	if center.x - absf(right_screen.x - center.x) < _menu_safe_margin:
		shift.x = _menu_safe_margin - (center.x - absf(right_screen.x - center.x))
	elif center.x + absf(right_screen.x - center.x) > viewport_size.x - _menu_safe_margin:
		shift.x = viewport_size.x - _menu_safe_margin - (center.x + absf(right_screen.x - center.x))
	if center.y - absf(up_screen.y - center.y) < _menu_safe_margin:
		shift.y = _menu_safe_margin - (center.y - absf(up_screen.y - center.y))
	elif center.y + absf(up_screen.y - center.y) > viewport_size.y - _menu_safe_margin:
		shift.y = viewport_size.y - _menu_safe_margin - (center.y + absf(up_screen.y - center.y))
	_menu_anchor.global_position += camera_basis.x * (shift.x / pixels_per_world_x)
	_menu_anchor.global_position -= camera_basis.y * (shift.y / pixels_per_world_y)


func _toggle_nested() -> void:
	if _activation_locked:
		return
	_activation_locked = true
	_selected_id = "move"
	_rerender_menu()
	var next_expanded := not _expanded
	get_tree().create_timer(MENU_ACTIVATION_HOLD).timeout.connect(func() -> void:
		if not _menu_open:
			return
		_selected_id = ""
		_animate_nested_state(next_expanded)
	)


func _animate_nested_state(next_expanded: bool) -> void:
	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(_reactive_root, "modulate:a", 0.0, MENU_CONTENT_FADE_DURATION)
	fade_out.parallel().tween_property(_reactive_root, "position", Vector2(0.0, -MENU_CONTENT_SLIDE_PIXELS), MENU_CONTENT_FADE_DURATION)
	fade_out.tween_callback(func() -> void:
		_expanded = next_expanded
		_rerender_menu()
		_reactive_root.position = Vector2(0.0, MENU_CONTENT_SLIDE_PIXELS)
		var fade_in := create_tween()
		fade_in.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_in.tween_property(_reactive_root, "modulate:a", 1.0, MENU_CONTENT_FADE_DURATION)
		fade_in.parallel().tween_property(_reactive_root, "position", Vector2.ZERO, MENU_CONTENT_FADE_DURATION)
		fade_in.tween_callback(func() -> void: _activation_locked = false)
	)


func _on_action(action_id: String) -> void:
	if _activation_locked:
		return
	_activation_locked = true
	print("WORLD_MENU_ACTION: ", action_id)
	_selected_id = action_id
	_rerender_menu()
	get_tree().create_timer(MENU_ACTIVATION_HOLD).timeout.connect(_close_menu)


func _rerender_menu() -> void:
	_menu_component.rerender(
		{"expanded": _expanded, "selected_id": _selected_id, "on_toggle": _toggle_nested, "on_action": _on_action},
	)


func _forward_pointer_to_menu(event: InputEventMouseButton) -> bool:
	var ray_origin := _camera.project_ray_origin(event.position)
	var ray_direction := _camera.project_ray_normal(event.position)
	var camera_basis := _camera.global_transform.basis
	var plane := Plane(camera_basis.z.normalized(), _menu_anchor.global_position)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return false
	var delta: Vector3 = hit - _menu_anchor.global_position
	var local_x: float = delta.dot(camera_basis.x)
	var local_y: float = delta.dot(camera_basis.y)
	var menu_width := MENU_WORLD_SIZE.x * _menu_surface.scale.x
	var menu_height := MENU_WORLD_SIZE.y * _menu_surface.scale.y
	if absf(local_x) > menu_width * 0.5 or absf(local_y) > menu_height * 0.5:
		return false
	var viewport_event := event.duplicate() as InputEventMouseButton
	viewport_event.position = Vector2(
		(local_x / menu_width + 0.5) * MENU_TEXTURE_SIZE.x,
		(0.5 - local_y / menu_height) * MENU_TEXTURE_SIZE.y,
	)
	viewport_event.global_position = viewport_event.position
	_menu_viewport.push_input(viewport_event, true)
	return true
