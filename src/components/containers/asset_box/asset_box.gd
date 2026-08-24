@tool
class_name BgoAssetBox
extends Node3D

const TABLE_GRID_SCENE = preload("res://src/components/grids/table_grid/table_grid.tscn")

## Editor/authoring representation of the Asset Placer catalog surface.
##
## This node is intentionally not the runtime source of truth: the runtime
## AssetBoxState is a logical catalog with no physical positions. The child
## BgoTableGrid is kept for editor previews and Asset Placer snapping, where a
## 5 cm point spacing can be styled without changing gameplay state.

@export_range(1, 64, 1) var point_columns: int = 6:
	set(value):
		point_columns = maxi(value, 1)
		_queue_rebuild()
@export_range(1, 64, 1) var point_rows: int = 4:
	set(value):
		point_rows = maxi(value, 1)
		_queue_rebuild()
@export var point_spacing_cm := Vector2(5.0, 5.0):
	set(value):
		point_spacing_cm = Vector2(maxf(value.x, 0.01), maxf(value.y, 0.01))
		_queue_rebuild()
@export_range(0.0001, 10.0, 0.0001) var world_units_per_cm: float = 0.24:
	set(value):
		world_units_per_cm = maxf(value, 0.0001)
		_queue_rebuild()
@export var box_color := Color(0.12, 0.14, 0.17, 0.96):
	set(value):
		box_color = value
		_queue_rebuild()
@export var grid_color := Color(0.62, 0.82, 0.96, 0.86):
	set(value):
		grid_color = value
		_queue_rebuild()
@export var open := false:
	set(value):
		open = value
		visible = value

var _rebuild_queued := false


func _ready() -> void:
	set_meta("bgo_asset_box", true)
	rebuild()
	visible = open


## Configures the visual box from a declarative asset-box definition.
func configure(
	new_point_columns: int,
	new_point_rows: int,
	new_point_spacing_cm: Vector2 = Vector2(5.0, 5.0),
	new_world_units_per_cm: float = 0.24
) -> void:
	point_columns = new_point_columns
	point_rows = new_point_rows
	point_spacing_cm = new_point_spacing_cm
	world_units_per_cm = new_world_units_per_cm
	rebuild()


## Opens or closes the box without changing logical contents.
func set_open(value: bool) -> void:
	open = value
	visible = value


## Returns the world position of a logical box point.
func point_world(point: Vector2i) -> Vector3:
	return global_transform * point_local(point)


## Returns the grid node used by Asset Placer and editor adapters.
func get_table_grid() -> Node:
	return get_node_or_null("TableGrid")


## Rebuilds the box floor and its shared point grid.
func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.free()

	var cell_size := Vector2(point_spacing_cm.x, point_spacing_cm.y) * world_units_per_cm
	var floor := MeshInstance3D.new()
	floor.name = "AssetBoxFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(
		maxf(cell_size.x * float(point_columns), cell_size.x),
		0.06,
		maxf(cell_size.y * float(point_rows), cell_size.y)
	)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = box_color
	floor_material.roughness = 0.72
	floor.material_override = floor_material
	floor.position = Vector3(0.0, -0.03, 0.0)
	add_child(floor)

	var grid := TABLE_GRID_SCENE.instantiate() as Node3D
	grid.name = "TableGrid"
	grid.position = Vector3(
		-cell_size.x * float(point_columns - 1) * 0.5,
		0.02,
		-cell_size.y * float(point_rows - 1) * 0.5
	)
	add_child(grid)
	grid.set("point_columns", point_columns)
	grid.set("point_rows", point_rows)
	grid.set("point_spacing_cm", point_spacing_cm)
	grid.set("world_units_per_cm", world_units_per_cm)
	grid.set("point_color", grid_color)
	grid.set("show_points", true)
	grid.call("rebuild")

	if Engine.is_editor_hint() and get_tree() != null:
		for child in get_children():
			child.owner = get_tree().edited_scene_root


func point_local(point: Vector2i) -> Vector3:
	var cell_size := Vector2(point_spacing_cm.x, point_spacing_cm.y) * world_units_per_cm
	return Vector3(
		(float(point.x) - float(point_columns - 1) * 0.5) * cell_size.x,
		0.08,
		(float(point.y) - float(point_rows - 1) * 0.5) * cell_size.y
	)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")
