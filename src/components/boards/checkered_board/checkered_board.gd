@tool
class_name BgoCheckeredBoard
extends Node3D

signal component_event(event_name: String, payload: Dictionary)

const TABLE_GRID_SCENE = preload("res://src/components/grids/table_grid/table_grid.tscn")

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
@export_range(0.1, 100.0, 0.1) var grid_cell_size_cm: float = 5.0:
	set(value):
		grid_cell_size_cm = maxf(value, 0.1)
		_queue_rebuild()
@export_range(1, 100, 1) var grid_points_per_unit: int = 5:
	set(value):
		grid_points_per_unit = maxi(value, 1)
		_queue_rebuild()
@export var grid_virtual_infinite := true:
	set(value):
		grid_virtual_infinite = value
		_queue_rebuild()
@export var slots_enabled := true:
	set(value):
		slots_enabled = value
		_queue_rebuild()
@export var light_color := Color(0.20, 0.22, 0.25):
	set(value):
		light_color = value
		_queue_rebuild()
@export var dark_color := Color(0.12, 0.14, 0.17):
	set(value):
		dark_color = value
		_queue_rebuild()
@export_category("PBR Material")
@export var light_texture: Texture2D:
	set(value):
		light_texture = value
		_queue_rebuild()
@export var dark_texture: Texture2D:
	set(value):
		dark_texture = value
		_queue_rebuild()
@export var show_grid_points := true:
	set(value):
		show_grid_points = value
		_queue_rebuild()
@export var grid_point_color := Color(0.45, 0.78, 0.95, 0.72):
	set(value):
		grid_point_color = value
		_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	set_meta("bgo_placeable", true)
	set_meta("bgo_placement_anchor", "base_center")
	rebuild()
	component_event.emit("ready", {"columns": columns, "rows": rows})


## Applies a project Texture2D to light cells and rebuilds the visual board.
func set_light_texture_path(resource_path: String) -> bool:
	var texture := _load_texture(resource_path)
	if texture == null:
		return false
	light_texture = texture
	rebuild()
	return true


## Applies a project Texture2D to dark cells and rebuilds the visual board.
func set_dark_texture_path(resource_path: String) -> bool:
	var texture := _load_texture(resource_path)
	if texture == null:
		return false
	dark_texture = texture
	rebuild()
	return true


## Updates the light-cell color from a CSS-style color string.
func set_light_color_string(value: String) -> bool:
	var color := Color.from_string(value, Color.TRANSPARENT)
	if color == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	light_color = color
	rebuild()
	return true


## Updates the dark-cell color from a CSS-style color string.
func set_dark_color_string(value: String) -> bool:
	var color := Color.from_string(value, Color.TRANSPARENT)
	if color == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	dark_color = color
	return true


## Updates the fine-grid marker color from a CSS-style color string.
func set_grid_point_color_string(value: String) -> bool:
	var color := Color.from_string(value, Color.TRANSPARENT)
	if color == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	grid_point_color = color
	return true


## Returns the stable console/MCP method surface for this component.
func console_api() -> Dictionary:
	var methods := _console_config_methods()
	methods.merge(_console_query_methods())
	methods["refresh"] = BgoComponentApiDescriptor.method("rebuild")
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.board.checkered",
			"BgoCheckeredBoard",
			"Configurable checkered board preview and runtime controls.",
			methods,
		)
	)


func _console_config_methods() -> Dictionary:
	return {
		"setColumns": BgoComponentApiDescriptor.bound_setter("_set_config_value", "columns", "int"),
		"setRows": BgoComponentApiDescriptor.bound_setter("_set_config_value", "rows", "int"),
		"setCellSize":
		BgoComponentApiDescriptor.bound_setter("_set_config_value", "cell_size", "float"),
		"setGridCellSizeCm":
		BgoComponentApiDescriptor.bound_setter("_set_config_value", "grid_cell_size_cm", "float"),
		"setGridPointsPerUnit":
		BgoComponentApiDescriptor.bound_setter("_set_config_value", "grid_points_per_unit", "int"),
		"setGridVirtualInfinite":
		BgoComponentApiDescriptor.bound_setter(
			"_set_config_value", "grid_virtual_infinite", "bool"
		),
		"setSlotsEnabled":
		BgoComponentApiDescriptor.bound_setter("_set_config_value", "slots_enabled", "bool"),
		"setLightTexture":
		BgoComponentApiDescriptor.setter(
			"set_light_texture_path", "light_texture", "string", "bool"
		),
		"setDarkTexture":
		BgoComponentApiDescriptor.setter("set_dark_texture_path", "dark_texture", "string", "bool"),
		"setLightColor":
		BgoComponentApiDescriptor.setter("set_light_color_string", "light_color", "string", "bool"),
		"setDarkColor":
		BgoComponentApiDescriptor.setter("set_dark_color_string", "dark_color", "string", "bool"),
		"setShowGridPoints":
		BgoComponentApiDescriptor.bound_setter("_set_config_value", "show_grid_points", "bool"),
		"setGridPointColor":
		BgoComponentApiDescriptor.setter(
			"set_grid_point_color_string", "grid_point_color", "string", "bool"
		),
	}


func _console_query_methods() -> Dictionary:
	return {
		"getSlotId":
		BgoComponentApiDescriptor.method(
			"slot_id", [{"name": "cell", "type": "Vector2i"}], "string"
		),
		"parseSlotId":
		BgoComponentApiDescriptor.method(
			"parse_slot_id", [{"name": "slot_id", "type": "string"}], "Vector2i"
		),
		"isValidCell":
		BgoComponentApiDescriptor.method(
			"is_valid_cell", [{"name": "cell", "type": "Vector2i"}], "bool"
		),
		"isValidSlot":
		BgoComponentApiDescriptor.method(
			"is_valid_slot", [{"name": "slot_id", "type": "string"}], "bool"
		),
		"getSlotWorld":
		BgoComponentApiDescriptor.method(
			"slot_world", [{"name": "slot_id", "type": "string"}], "Vector3"
		),
		"getSurfaceHeight": BgoComponentApiDescriptor.method("surface_height", [], "float"),
		"getCellWorld":
		BgoComponentApiDescriptor.method(
			"cell_world", [{"name": "cell", "type": "Vector2i"}], "Vector3"
		),
		"getGridPointWorld":
		BgoComponentApiDescriptor.method(
			"grid_point_world", [{"name": "point", "type": "Vector2i"}], "Vector3"
		),
		"cellToGridPoint":
		BgoComponentApiDescriptor.method(
			"cell_to_grid_point", [{"name": "cell", "type": "Vector2i"}], "Vector2i"
		),
		"gridPointToCell":
		BgoComponentApiDescriptor.method(
			"grid_point_to_cell", [{"name": "point", "type": "Vector2i"}], "Vector2i"
		),
		"resolvePlacement":
		BgoComponentApiDescriptor.method(
			"resolve_magnetic_placement",
			[{"name": "world_position", "type": "Vector3"}],
			"Dictionary"
		),
	}


func _set_config_value(value: Variant, property_name: String) -> void:
	match property_name:
		"columns":
			columns = int(value)
		"rows":
			rows = int(value)
		"cell_size":
			cell_size = float(value)
		"grid_cell_size_cm":
			grid_cell_size_cm = float(value)
		"grid_points_per_unit":
			grid_points_per_unit = int(value)
		"grid_virtual_infinite":
			grid_virtual_infinite = bool(value)
		"slots_enabled":
			slots_enabled = bool(value)
		"show_grid_points":
			show_grid_points = bool(value)


func _load_texture(resource_path: String) -> Texture2D:
	if not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path):
		return null
	return ResourceLoader.load(resource_path, "Texture2D") as Texture2D


## Configures this object from the supplied project data.
func configure(
	new_columns: int,
	new_rows: int,
	new_cell_size: float,
	new_grid_cell_size_cm: float = 5.0,
	new_grid_points_per_unit: int = 5
) -> void:
	columns = new_columns
	rows = new_rows
	cell_size = new_cell_size
	grid_cell_size_cm = new_grid_cell_size_cm
	grid_points_per_unit = new_grid_points_per_unit
	rebuild()
	(
		component_event
		. emit(
			"configured",
			{
				"columns": columns,
				"rows": rows,
				"cell_size": cell_size,
				"grid_cell_size_cm": grid_cell_size_cm,
				"grid_points_per_unit": grid_points_per_unit,
			}
		)
	)


## Rebuilds the runtime representation from the current configuration.
func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child is BgoPbrMaterial:
			continue
		child.free()

	for y in rows:
		for x in columns:
			var cell := StaticBody3D.new()
			cell.name = "Cell_%d_%d" % [x, y]
			var cell_coord := Vector2i(x, y)
			cell.set_meta("board_cell", cell_coord)
			if slots_enabled:
				cell.set_meta("bgo_slot", true)
				cell.set_meta("slot_id", slot_id(cell_coord))
				cell.set_meta("capacity", 1)
			cell.position = cell_world(cell_coord)

			var mesh_instance := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(cell_size - 0.03, 0.08, cell_size - 0.03)
			mesh_instance.mesh = mesh
			var material := StandardMaterial3D.new()
			var is_light_cell := (x + y) % 2 == 0
			material.albedo_color = light_color if is_light_cell else dark_color
			material.albedo_texture = light_texture if is_light_cell else dark_texture
			material.roughness = 0.78
			var pbr_feature := get_node_or_null("PbrMaterial") as BgoPbrMaterial
			if pbr_feature != null:
				pbr_feature.configure_board_material(material, is_light_cell)
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

	_sync_grid_component()
	component_event.emit("rebuilt", {"slot_count": columns * rows})


## Returns the stable slot identifier for the requested board cell.
func slot_id(cell: Vector2i) -> String:
	return "board:%d:%d" % [cell.x, cell.y]


## Parses a stable slot identifier back into board coordinates.
func parse_slot_id(value: String) -> Vector2i:
	var parts := value.split(":")
	if parts.size() != 3 or parts[0] != "board":
		return Vector2i(-1, -1)
	var cell := Vector2i(int(parts[1]), int(parts[2]))
	return cell if is_valid_cell(cell) else Vector2i(-1, -1)


## Returns whether the supplied board coordinates identify a valid cell.
func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


## Returns whether the supplied slot identifier belongs to this board.
func is_valid_slot(value: String) -> bool:
	return parse_slot_id(value).x >= 0


## Returns the world-space position represented by a logical slot identifier.
func slot_world(value: String) -> Vector3:
	var cell := parse_slot_id(value)
	if cell.x < 0:
		return Vector3.ZERO
	return global_position + cell_world(cell) + Vector3(0.0, surface_height(), 0.0)


## Height of the physical support surface above this component's origin.
func surface_height() -> float:
	return 0.04


## Returns the world-space position represented by board coordinates.
func cell_world(cell: Vector2i) -> Vector3:
	var width := float(columns - 1) * cell_size
	var depth := float(rows - 1) * cell_size
	return Vector3(
		float(cell.x) * cell_size - width * 0.5, 0.0, float(cell.y) * cell_size - depth * 0.5
	)


## Maps a board unit to the nearest fine-grid point at the centre of its cell.
func cell_to_grid_point(cell: Vector2i) -> Vector2i:
	var centre_offset := grid_points_per_unit / 2
	return cell * grid_points_per_unit + Vector2i(centre_offset, centre_offset)


## Returns the nearest board unit represented by a fine-grid point.
func grid_point_to_cell(point: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(point.x) / float(grid_points_per_unit)),
		floori(float(point.y) / float(grid_points_per_unit))
	)


## Resolves magnetic placement. Named slots always win; slotless boards use the fine grid.
func resolve_magnetic_placement(world_position: Vector3) -> Dictionary:
	var grid := get_node_or_null("TableGrid") as BgoTableGrid
	if grid == null:
		return {}
	var point := grid.clamped_world_to_point(world_position)
	if slots_enabled:
		var cell := grid_point_to_cell(point)
		if is_valid_cell(cell):
			return {
				"type": "slot",
				"slot_id": slot_id(cell),
				"cell": cell,
				"grid_point": cell_to_grid_point(cell),
			}
	return {"type": "grid", "grid_point": point}


## Returns the support position for a fine-grid point.
func grid_point_world(point: Vector2i) -> Vector3:
	var grid := get_node_or_null("TableGrid") as BgoTableGrid
	if grid == null or not grid.is_valid_point(point):
		return global_position
	var result := grid.point_world(point)
	result.y = global_position.y + surface_height()
	return result


func _sync_grid_component() -> void:
	var grid: Node3D = get_node_or_null("TableGrid")
	if grid == null:
		grid = TABLE_GRID_SCENE.instantiate() as Node3D
		grid.name = "TableGrid"
		add_child(grid)
		if Engine.is_editor_hint():
			grid.owner = get_tree().edited_scene_root
	var point_step_world := cell_size / float(grid_points_per_unit)
	# Cover the complete board, not only the span between outer cell centres.
	# Markers sit at the centre of each centimetre subdivision.
	grid.position = (
		cell_world(Vector2i.ZERO)
		+ Vector3(
			-cell_size * 0.5 + point_step_world * 0.5,
			0.08,
			-cell_size * 0.5 + point_step_world * 0.5
		)
	)
	grid.set("point_columns", columns * grid_points_per_unit)
	grid.set("point_rows", rows * grid_points_per_unit)
	grid.set("virtual_infinite", grid_virtual_infinite)
	# Each marker is one physical centimetre. A game-defined number of markers
	# spans one logical board unit while the renderer preserves cell_size.
	var point_spacing_cm := grid_cell_size_cm / float(grid_points_per_unit)
	grid.set("point_spacing_cm", Vector2(point_spacing_cm, point_spacing_cm))
	grid.set("world_units_per_cm", cell_size / grid_cell_size_cm)
	grid.set("show_points", show_grid_points)
	grid.set("point_color", grid_point_color)
	grid.call("rebuild")


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")
