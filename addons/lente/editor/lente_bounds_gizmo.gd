@tool
extends EditorNode3DGizmoPlugin

const BoxBound := preload("res://addons/lente/runtime/bounds/lente_box_bound.gd")
const SphereBound := preload("res://addons/lente/runtime/bounds/lente_sphere_bound.gd")
const PathBound := preload("res://addons/lente/runtime/bounds/lente_path_bound.gd")


func _init() -> void:
	create_material("lente_bounds", Color("5dd9c1"), false, true, true)
	create_material("lente_center", Color("d8fff7"), false, true, true)


func _has_gizmo(node_3d: Node3D) -> bool:
	return node_3d is BoxBound or node_3d is SphereBound or node_3d is PathBound


func _get_gizmo_name() -> String:
	return "Lente Bounds"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var lines := PackedVector3Array()
	var center_lines := PackedVector3Array()
	if node is BoxBound:
		_add_box(lines, node.size)
	elif node is SphereBound:
		_add_sphere(lines, node.radius)
	elif node is PathBound:
		_add_path(lines, center_lines, node)
	if not lines.is_empty():
		gizmo.add_lines(lines, get_material("lente_bounds", gizmo))
		gizmo.add_collision_segments(lines)
	if not center_lines.is_empty():
		gizmo.add_lines(center_lines, get_material("lente_center", gizmo))


func _add_box(lines: PackedVector3Array, size: Vector3) -> void:
	var h := size * 0.5
	var points := PackedVector3Array([
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	])
	var edges := PackedInt32Array([0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7])
	for index in range(0, edges.size(), 2):
		lines.append(points[edges[index]])
		lines.append(points[edges[index + 1]])


func _add_sphere(lines: PackedVector3Array, radius: float) -> void:
	const SEGMENTS := 48
	for axis in 3:
		for index in SEGMENTS:
			var angle_a := TAU * float(index) / float(SEGMENTS)
			var angle_b := TAU * float(index + 1) / float(SEGMENTS)
			lines.append(_ring_point(axis, angle_a, radius))
			lines.append(_ring_point(axis, angle_b, radius))


func _ring_point(axis: int, angle: float, radius: float) -> Vector3:
	match axis:
		0:
			return Vector3(0.0, cos(angle), sin(angle)) * radius
		1:
			return Vector3(cos(angle), 0.0, sin(angle)) * radius
		_:
			return Vector3(cos(angle), sin(angle), 0.0) * radius


func _add_path(lines: PackedVector3Array, center_lines: PackedVector3Array, bound: Node3D) -> void:
	if not bound.curve or bound.curve.point_count == 0:
		_add_sphere(lines, bound.radius)
		return
	var points: PackedVector3Array = bound.curve.get_baked_points()
	if points.size() < 2:
		_add_sphere(lines, bound.radius)
		return
	for index in range(points.size() - 1):
		center_lines.append(points[index])
		center_lines.append(points[index + 1])
	var length: float = bound.curve.get_baked_length()
	var ring_count := maxi(2, ceili(length / maxf(bound.radius, 0.5)) + 1)
	for ring_index in ring_count:
		var offset := length * float(ring_index) / float(ring_count - 1)
		var path_transform: Transform3D = bound.curve.sample_baked_with_rotation(offset, true, false)
		const RING_SEGMENTS := 20
		for segment in RING_SEGMENTS:
			var a := TAU * float(segment) / float(RING_SEGMENTS)
			var b := TAU * float(segment + 1) / float(RING_SEGMENTS)
			lines.append(path_transform * (Vector3(cos(a), sin(a), 0.0) * bound.radius))
			lines.append(path_transform * (Vector3(cos(b), sin(b), 0.0) * bound.radius))
