@tool
class_name BgoPlayerArea
extends Node3D

signal component_event(event_name: String, payload: Dictionary)

const SLOT_SPACING := 0.85

@export var player_id := "player_1"
@export var public_objects := true
## Side (local X) the grid grows toward, where the player is seated: -1 or 1.
## 0 means automatic: away from the table center.
@export var seat_side := 0.0
@export var label_text := "PLAYER 1":
	set(value):
		label_text = value
		_apply_visuals()
@export var area_color := Color(0.45, 0.31, 0.06):
	set(value):
		area_color = value
		_apply_visuals()
@export var area_size := Vector3(1.55, 0.06, 7.2):
	set(value):
		area_size = value
		_apply_visuals()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D


func _ready() -> void:
	set_meta("bgo_placeable_surface", true)
	_apply_visuals()
	component_event.emit(
		"ready", {"player_id": player_id, "label": label_text, "area_size": _size_payload()}
	)


## Updates the player identity associated with this presentation.
func set_player_id(value: String) -> void:
	player_id = value
	set_meta("player_id", value)


## Updates the public label rendered above the area.
func set_label_text(value: String) -> void:
	label_text = value


## Updates the area color from a CSS-style string.
func set_area_color_string(value: String) -> bool:
	var parsed := Color.from_string(value, Color.TRANSPARENT)
	if parsed == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	area_color = parsed
	return true


## Updates the rendered area dimensions when every axis is positive.
func set_area_size(value: Vector3) -> bool:
	if value.x <= 0.0 or value.y <= 0.0 or value.z <= 0.0:
		return false
	area_size = value
	return true


## Shows or hides this presentation without changing logical contents.
func set_area_visible(value: bool) -> void:
	visible = value


## Declares whether objects in the area belong to the public projection.
func set_public_objects(value: bool) -> void:
	public_objects = value
	set_meta("bgo_public_objects", value)


## Chooses which side the object grid grows toward (-1, 0 automatic, or 1).
func set_seat_side(value: float) -> bool:
	if (
		not is_equal_approx(value, -1.0)
		and not is_zero_approx(value)
		and not is_equal_approx(value, 1.0)
	):
		return false
	seat_side = value
	return true


## Returns the stable console, GUI, and MCP method surface for this component.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.player_area.basic",
			"BgoPlayerArea",
			"Player-associated tabletop area presentation controls.",
			{
				"setPlayerId":
				BgoComponentApiDescriptor.setter("set_player_id", "player_id", "string"),
				"setLabelText":
				BgoComponentApiDescriptor.setter("set_label_text", "label_text", "string"),
				"setAreaColor":
				BgoComponentApiDescriptor.setter(
					"set_area_color_string", "area_color", "string", "bool"
				),
				"setAreaSize":
				BgoComponentApiDescriptor.setter("set_area_size", "area_size", "Vector3", "bool"),
				"setVisible":
				BgoComponentApiDescriptor.setter("set_area_visible", "visible", "bool"),
				"setPublicObjects":
				BgoComponentApiDescriptor.setter("set_public_objects", "public_objects", "bool"),
				"setSeatSide":
				BgoComponentApiDescriptor.setter("set_seat_side", "seat_side", "float", "bool"),
				"getSlotWorld":
				BgoComponentApiDescriptor.method(
					"area_slot_world", [{"name": "slot", "type": "int"}], "Vector3"
				),
			},
		)
	)


## Objects in an area sit side by side in a grid: they fill a row along the
## length of the area, then new rows grow toward the seated player.
static func slot_columns(area_length: float) -> int:
	return maxi(1, int(area_length / SLOT_SPACING))


## Grid cell (column, row) of the Nth object kept in an area.
static func slot_cell(slot: int, area_length: float) -> Vector2i:
	var columns := slot_columns(area_length)
	var index := maxi(0, slot)
	return Vector2i(index % columns, floori(float(index) / float(columns)))


## Offset of the Nth object from the area center: X grows toward the seat, Z runs along the area.
static func slot_offset(slot: int, area_length: float, seat_sign: float) -> Vector3:
	var cell := slot_cell(slot, area_length)
	var columns := slot_columns(area_length)
	return Vector3(
		seat_sign * float(cell.y) * SLOT_SPACING,
		0.0,
		(float(cell.x) - float(columns - 1) * 0.5) * SLOT_SPACING
	)


## Returns the world-space position of a player-area slot.
func area_slot_world(slot: int) -> Vector3:
	var offset := slot_offset(slot, area_size.z, _seat_sign())
	return global_position + Vector3(offset.x, area_size.y * 0.5, offset.z)


func _seat_sign() -> float:
	if not is_zero_approx(seat_side):
		return signf(seat_side)
	return -1.0 if global_position.x < 0.0 else 1.0


func _apply_visuals() -> void:
	if not is_inside_tree():
		return
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if label == null:
		label = get_node_or_null("Label3D")
	if mesh_instance != null:
		var mesh := BoxMesh.new()
		mesh.size = area_size
		mesh_instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = area_color
		material.roughness = 0.82
		mesh_instance.material_override = material
	if label != null:
		label.text = label_text
		label.position = Vector3(0, 0.12, -area_size.z * 0.42)


func _size_payload() -> Dictionary:
	return {"x": area_size.x, "y": area_size.y, "z": area_size.z}
