@tool
class_name BgoCheckeredBoard
extends Node3D

@export_range(2, 30, 1) var columns: int = 8:
	set(value):
		columns = clampi(value, 2, 30)
		_queue_rebuild()
@export_range(2, 30, 1) var rows: int = 6:
	set(value):
		rows = clampi(value, 2, 30)
		_queue_rebuild()
@export_range(0.5, 3.0, 0.05) var cell_size: float = 1.2:
	set(value):
		cell_size = clampf(value, 0.5, 3.0)
		_queue_rebuild()
@export var light_color := Color(0.20, 0.22, 0.25):
	set(value):
		light_color = value
		_queue_rebuild()
@export var dark_color := Color(0.12, 0.14, 0.17):
	set(value):
		dark_color = value
		_queue_rebuild()

var _rebuild_queued := false

func _ready() -> void:
	rebuild()

func configure(new_columns: int, new_rows: int, new_cell_size: float) -> void:
	columns = new_columns
	rows = new_rows
	cell_size = new_cell_size
	rebuild()

func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.free()

	for y in rows:
		for x in columns:
			var cell := StaticBody3D.new()
			cell.name = "Cell_%d_%d" % [x, y]
			var cell_coord := Vector2i(x, y)
			cell.set_meta("board_cell", cell_coord)
			cell.set_meta("bgo_slot", true)
			cell.set_meta("slot_id", slot_id(cell_coord))
			cell.set_meta("capacity", 1)
			cell.position = cell_world(cell_coord)

			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(cell_size - 0.03, 0.08, cell_size - 0.03)
			mesh_instance.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = light_color if (x + y) % 2 == 0 else dark_color
			material.roughness = 0.78
			mesh_instance.material_override = material
			cell.add_child(mesh_instance)

			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(cell_size, 0.12, cell_size)
			shape.shape = box
			cell.add_child(shape)
			add_child(cell)
			if Engine.is_editor_hint():
				cell.owner = get_tree().edited_scene_root
				mesh_instance.owner = get_tree().edited_scene_root
				shape.owner = get_tree().edited_scene_root

func slot_id(cell: Vector2i) -> String:
	return "board:%d:%d" % [cell.x, cell.y]

func parse_slot_id(value: String) -> Vector2i:
	var parts := value.split(":")
	if parts.size() != 3 or parts[0] != "board":
		return Vector2i(-1, -1)
	var cell := Vector2i(int(parts[1]), int(parts[2]))
	return cell if is_valid_cell(cell) else Vector2i(-1, -1)

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func is_valid_slot(value: String) -> bool:
	return parse_slot_id(value).x >= 0

func slot_world(value: String) -> Vector3:
	var cell := parse_slot_id(value)
	if cell.x < 0:
		return Vector3.ZERO
	return cell_world(cell)

func cell_world(cell: Vector2i) -> Vector3:
	var width := float(columns - 1) * cell_size
	var depth := float(rows - 1) * cell_size
	return Vector3(float(cell.x) * cell_size - width * 0.5, 0.0, float(cell.y) * cell_size - depth * 0.5)

func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")
