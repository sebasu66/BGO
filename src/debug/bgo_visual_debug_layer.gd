class_name BgoVisualDebugLayer
extends Node3D

## Runtime-only presentation helper. It never mutates logical game state.
const PIVOT_MARKER_NAME := "BgoDebugPivot"
const REFRESH_SECONDS := 0.75
const AXIS_LENGTH := 0.42

var _target_root: Node3D
var _refresh_elapsed := 0.0


func configure(target_root: Node3D) -> void:
	_target_root = target_root


func set_debug_enabled(enabled: bool) -> void:
	visible = enabled
	set_process(enabled)
	if enabled:
		_refresh()
	else:
		_remove_markers()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_SECONDS:
		return
	_refresh_elapsed = 0.0
	_refresh()


func _refresh() -> void:
	if _target_root == null or not visible:
		return
	var descendants := _all_descendants(_target_root)
	var grid_anchors: Array[Vector3] = []
	for node in descendants:
		if (
			is_instance_valid(node)
			and node is Node3D
			and bool(node.get_meta("bgo_piece", false))
			and (node as Node3D).visible
		):
			grid_anchors.append((node as Node3D).global_position)
	for node in descendants:
		if is_instance_valid(node) and node is BgoTableGrid:
			(node as BgoTableGrid).set_visual_anchors_world(grid_anchors)
		if is_instance_valid(node) and node is Node3D and _is_debuggable_model(node as Node3D):
			_ensure_pivot_marker(node as Node3D)


func _is_debuggable_model(node: Node3D) -> bool:
	return (
		bool(node.get_meta("bgo_piece", false))
		or bool(node.get_meta("bgo_placeable", false))
		or bool(node.get_meta("bgo_component_instance", false))
	)


func _ensure_pivot_marker(target: Node3D) -> void:
	if target.get_node_or_null(PIVOT_MARKER_NAME) != null:
		return
	var marker := MeshInstance3D.new()
	marker.name = PIVOT_MARKER_NAME
	marker.mesh = _axis_mesh()
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.set_meta("bgo_visual_debug", true)
	target.add_child(marker)


func _axis_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _axis_material())
	_add_axis(mesh, Vector3.RIGHT, Color(1.0, 0.18, 0.14))
	_add_axis(mesh, Vector3.UP, Color(0.2, 1.0, 0.3))
	_add_axis(mesh, Vector3.BACK, Color(0.2, 0.55, 1.0))
	mesh.surface_end()
	return mesh


func _add_axis(mesh: ImmediateMesh, direction: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(direction * AXIS_LENGTH)


func _axis_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	return material


func _remove_markers() -> void:
	if _target_root == null:
		return
	for node in _all_descendants(_target_root):
		if (
			is_instance_valid(node)
			and node.name == PIVOT_MARKER_NAME
			and bool(node.get_meta("bgo_visual_debug", false))
		):
			node.queue_free()


func _all_descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result
