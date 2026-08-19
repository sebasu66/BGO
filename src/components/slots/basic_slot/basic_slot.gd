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
