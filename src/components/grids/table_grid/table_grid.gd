@tool
class_name BgoTableGrid
extends Node3D

const TABLE_GRID_STATE = preload("res://src/core/table_grid_state.gd")

@export_range(1, 512, 1) var point_columns: int = 16:
	set(value):
		point_columns = maxi(value, 1)
		_queue_rebuild()
@export_range(1, 512, 1) var point_rows: int = 10:
	set(value):
		point_rows = maxi(value, 1)
		_queue_rebuild()
@export var point_spacing_cm := Vector2(5.0, 5.0):
	set(value):
		point_spacing_cm = Vector2(maxf(value.x, 0.01), maxf(value.y, 0.01))
		_queue_rebuild()
@export_range(0.0001, 10.0, 0.0001) var world_units_per_cm: float = 0.01:
	set(value):
		world_units_per_cm = maxf(value, 0.0001)
		_queue_rebuild()
@export var surface_local_y: float = 0.0
@export var virtual_infinite := false:
	set(value):
		virtual_infinite = value
		_queue_rebuild()
@export var show_points := true:
	set(value):
		show_points = value
		_queue_rebuild()
@export_range(0.002, 0.2, 0.002) var point_radius: float = 0.012:
	set(value):
		point_radius = maxf(value, 0.002)
		_queue_rebuild()
@export var point_color := Color(0.45, 0.78, 0.95, 0.72):
	set(value):
		point_color = value
		_queue_rebuild()
@export_range(1, 12, 1) var sparse_radius_points := 5:
	set(value):
		sparse_radius_points = clampi(value, 1, 12)
		_queue_rebuild()

var _rebuild_queued := false
var _visual_anchor_points: Array[Vector2i] = []


func _ready() -> void:
	set_meta("bgo_table_grid", true)
	rebuild()


## Rebuilds the editor/runtime point markers from the logical grid contract.
func rebuild() -> void:
	_rebuild_queued = false
	var existing := get_node_or_null("GridPoints")
	if existing != null:
		existing.free()
	if not show_points:
		return

	var sphere := SphereMesh.new()
	sphere.radius = point_radius
	sphere.height = point_radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = point_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = material

	var rendered_points := _rendered_points()
	if rendered_points.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = rendered_points.size()
	for index in rendered_points.size():
		multimesh.set_instance_transform(
			index, Transform3D(Basis.IDENTITY, point_local(rendered_points[index]))
		)

	var visuals := MultiMeshInstance3D.new()
	visuals.name = "GridPoints"
	visuals.multimesh = multimesh
	visuals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visuals)
	if Engine.is_editor_hint() and get_tree() != null:
		visuals.owner = get_tree().edited_scene_root


## Returns the world-space position for a logical point on this table plane.
func point_world(point: Vector2i) -> Vector3:
	return global_transform * point_local(point)


## Converts a world-space position to the nearest logical point.
func world_to_point(world_position: Vector3) -> Vector2i:
	var local := global_transform.affine_inverse() * world_position
	return Vector2i(
		roundi(local.x / (point_spacing_cm.x * world_units_per_cm)),
		roundi(local.z / (point_spacing_cm.y * world_units_per_cm))
	)


## Converts a world position to the nearest point constrained to this grid.
func clamped_world_to_point(world_position: Vector3) -> Vector2i:
	var point := world_to_point(world_position)
	if virtual_infinite:
		return point
	return Vector2i(clampi(point.x, 0, point_columns - 1), clampi(point.y, 0, point_rows - 1))


## Grid-only surfaces expose the same placement shape as slotted boards.
func resolve_magnetic_placement(world_position: Vector3) -> Dictionary:
	return {"type": "grid", "grid_point": clamped_world_to_point(world_position)}


## Snaps an asset position to the nearest point without changing its height.
func snap_world_position(world_position: Vector3) -> Vector3:
	var local := global_transform.affine_inverse() * world_position
	var point := world_to_point(world_position)
	local.x = float(point.x) * point_spacing_cm.x * world_units_per_cm
	local.z = float(point.y) * point_spacing_cm.y * world_units_per_cm
	return global_transform * local


## Returns whether a grid coordinate lies inside this table's point bounds.
func is_valid_point(point: Vector2i) -> bool:
	return (
		virtual_infinite
		or (point.x >= 0 and point.x < point_columns and point.y >= 0 and point.y < point_rows)
	)


## Updates sparse visualization centres without constraining the logical grid.
func set_visual_anchors_world(world_positions: Array[Vector3]) -> void:
	var next_points: Array[Vector2i] = []
	for world_position in world_positions:
		var point := world_to_point(world_position)
		if not next_points.has(point):
			next_points.append(point)
	if next_points == _visual_anchor_points:
		return
	_visual_anchor_points = next_points
	if is_inside_tree():
		rebuild()


## Returns a metadata payload that an editor placement adapter can attach to an asset.
func placement_metadata(world_position: Vector3, footprint: Vector2i = Vector2i.ONE) -> Dictionary:
	var origin := world_to_point(world_position)
	return {
		"grid_path": str(get_path()),
		"origin": origin,
		"footprint": footprint,
		"point_spacing_cm": point_spacing_cm,
	}


func point_local(point: Vector2i) -> Vector3:
	return Vector3(
		float(point.x) * point_spacing_cm.x * world_units_per_cm,
		surface_local_y,
		float(point.y) * point_spacing_cm.y * world_units_per_cm
	)


func _rendered_points() -> Array[Vector2i]:
	if not virtual_infinite:
		var bounded: Array[Vector2i] = []
		for y in point_rows:
			for x in point_columns:
				bounded.append(Vector2i(x, y))
		return bounded
	var unique: Dictionary = {}
	for anchor in _visual_anchor_points:
		for y in range(anchor.y - sparse_radius_points, anchor.y + sparse_radius_points + 1):
			for x in range(anchor.x - sparse_radius_points, anchor.x + sparse_radius_points + 1):
				unique[Vector2i(x, y)] = true
	var sparse: Array[Vector2i] = []
	for point in unique:
		sparse.append(point as Vector2i)
	sparse.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	return sparse


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")
