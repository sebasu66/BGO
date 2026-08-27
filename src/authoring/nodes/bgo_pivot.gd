@tool
class_name BgoPivot
extends Marker3D

@export var anchor_id := "placement"
@export var definition_key: StringName = &"pivot_offset"
@export var default_offset := Vector3.ZERO


func _ready() -> void:
	refresh_from_definition()


func root_object() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("get_definition_value") and current.has_method("effective_definition"):
			return current
		current = current.get_parent()
	return null


func get_definition_schema() -> Dictionary:
	return {
		String(definition_key): {
			"type": "vector3",
			"default": {"x": default_offset.x, "y": default_offset.y, "z": default_offset.z},
		}
	}


func refresh_from_definition() -> void:
	var root := root_object()
	if root == null:
		position = default_offset
		return
	var value: Variant = root.call("get_definition_value", definition_key, default_offset)
	if value is Vector3:
		position = value
	elif value is Dictionary:
		position = Vector3(
			float(value.get("x", default_offset.x)),
			float(value.get("y", default_offset.y)),
			float(value.get("z", default_offset.z))
		)


func composition_descriptor() -> Dictionary:
	return {"type": "pivot", "id": anchor_id, "position": position}
