@tool
class_name BgoBasicSlot
extends Area3D

@export var slot_id := "slot"
@export_range(1, 1000, 1) var capacity := 1
@export var accepted_kinds: PackedStringArray = []
@export var visible_marker := true:
	set(value):
		visible_marker = value
		_update_marker()
@export var marker_size := Vector2(0.9, 0.9):
	set(value):
		marker_size = value
		_update_marker()
@export var marker_color := Color(0.35, 0.8, 0.55, 0.22):
	set(value):
		marker_color = value
		_update_marker()

@onready var marker: MeshInstance3D = $Marker


func _ready() -> void:
	set_meta("bgo_slot", true)
	set_meta("slot_id", slot_id)
	set_meta("capacity", capacity)
	_update_marker()


## Updates the stable slot identifier exposed through metadata.
func set_slot_id(value: String) -> bool:
	if value.is_empty():
		return false
	slot_id = value
	set_meta("slot_id", value)
	return true


## Updates deterministic logical occupancy capacity.
func set_capacity(value: int) -> void:
	capacity = clampi(value, 1, 1000)
	set_meta("capacity", capacity)


## Updates the accepted component-kind allowlist.
func set_accepted_kinds(value: Array) -> void:
	accepted_kinds = PackedStringArray(value)


## Shows or hides the slot marker.
func set_visible_marker(value: bool) -> void:
	visible_marker = value


## Updates marker dimensions when both axes are positive.
func set_marker_size(value: Vector2) -> bool:
	if value.x <= 0.0 or value.y <= 0.0:
		return false
	marker_size = value
	return true


## Updates marker color from a CSS-style color string.
func set_marker_color_string(value: String) -> bool:
	var parsed := Color.from_string(value, Color.TRANSPARENT)
	if parsed == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	marker_color = parsed
	return true


## Returns the stable console, GUI, and MCP method surface for this component.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.slot.basic",
			"BgoBasicSlot",
			"Deterministic placement-target configuration and marker controls.",
			{
				"setCapacity": BgoComponentApiDescriptor.setter("set_capacity", "capacity", "int"),
				"setSlotId":
				BgoComponentApiDescriptor.method(
					"set_slot_id", [{"name": "value", "type": "string"}], "bool"
				),
				"setAcceptedKinds":
				BgoComponentApiDescriptor.method(
					"set_accepted_kinds", [{"name": "value", "type": "PackedStringArray"}]
				),
				"setVisibleMarker":
				BgoComponentApiDescriptor.method(
					"set_visible_marker", [{"name": "value", "type": "bool"}]
				),
				"setMarkerSize":
				BgoComponentApiDescriptor.method(
					"set_marker_size", [{"name": "value", "type": "Vector2"}], "bool"
				),
				"setMarkerColor":
				BgoComponentApiDescriptor.method(
					"set_marker_color_string", [{"name": "value", "type": "string"}], "bool"
				),
				"accepts":
				BgoComponentApiDescriptor.method(
					"accepts", [{"name": "component_kind", "type": "string"}], "bool"
				),
			},
		)
	)


## Describes the developer-facing methods exposed by this component.
func console_help() -> Dictionary:
	return {
		"_summary": "Controls slot identity, capacity, acceptance, and marker presentation.",
		"set_capacity": "Updates logical capacity and published metadata.",
		"set_accepted_kinds": "Updates the component-kind allowlist.",
		"accepts": "Queries whether a component kind is accepted.",
	}


## Returns whether this slot accepts the supplied logical object.
func accepts(component_kind: String) -> bool:
	return accepted_kinds.is_empty() or accepted_kinds.has(component_kind)


func _update_marker() -> void:
	if marker == null:
		return
	marker.visible = visible_marker
	var mesh := marker.mesh as QuadMesh
	if mesh != null:
		mesh.size = marker_size
	var material := marker.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = marker_color
