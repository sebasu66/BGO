class_name BgoTableStateController
extends RefCounted

## Makes the world look like the table state says: the lights of the table and
## the tint of the floor. It runs every time a new state arrives, so a change
## made by the host, the console or an AI shows up at once.

const TABLE_SCENE = preload("res://src/components/table/table.tscn")

var _table: Node3D
var _floor: MeshInstance3D


func _init(world: Node3D, floor_mesh: MeshInstance3D) -> void:
	_floor = floor_mesh
	_table = TABLE_SCENE.instantiate() as Node3D
	_table.surface_should_change.connect(_paint_the_floor)
	world.add_child(_table)


## Shows the table part of a full gameplay snapshot. Unknown shapes are ignored.
func show_snapshot(snapshot: Dictionary) -> void:
	var tabletop: Variant = snapshot.get("tabletop", {})
	if not tabletop is Dictionary:
		return
	var table_state: Variant = (tabletop as Dictionary).get("config", {})
	if table_state is Dictionary:
		_table.show_table_state(table_state)


## Returns the table node, so tests and tools can inspect what is shown.
func table_node() -> Node3D:
	return _table


func _paint_the_floor(surface: Dictionary) -> void:
	if _floor == null:
		return
	var material := _floor.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		_floor.material_override = material
	var tint := Color.from_string(str(surface.get("tint", "#ffffff")), Color.WHITE)
	material.albedo_color = tint
