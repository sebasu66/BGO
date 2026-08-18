@tool
class_name BgoPlayerArea
extends Node3D

@export var player_id := "player_1"
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
	_apply_visuals()


func area_slot_world(slot: int) -> Vector3:
	return global_position + Vector3(0.0, 0.38, -2.3 + float(slot) * 0.85)


# Compatibility alias for early PoC code. A PlayerArea is deliberately not a Hand.
func hand_slot_world(slot: int) -> Vector3:
	return area_slot_world(slot)


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
