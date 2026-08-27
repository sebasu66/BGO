@tool
class_name BgoRollable
extends "res://src/authoring/nodes/bgo_feature.gd"

@export_category("BGO Rollable")
@export_range(2, 100, 1) var sides := 6
@export var face_values: Array[String] = []

func _init() -> void:
	feature_id = &"rollable"

func get_definition_schema() -> Dictionary:
	var schema := {
		"sides": {"type": "int", "min": 2, "default": sides},
	}
	schema.merge(property_schema, true)
	return schema
