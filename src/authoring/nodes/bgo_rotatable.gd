@tool
class_name BgoRotatable
extends "res://src/authoring/nodes/bgo_feature.gd"

@export var step_degrees := 15.0
@export var free_rotation := true


func _init() -> void:
	feature_id = &"rotatable"


func get_definition_schema() -> Dictionary:
	var schema := {
		"rotation_step_degrees": {"type": "float", "min": 0.1, "default": step_degrees},
		"free_rotation": {"type": "bool", "default": free_rotation},
	}
	schema.merge(property_schema, true)
	return schema
