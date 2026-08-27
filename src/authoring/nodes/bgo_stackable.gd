@tool
class_name BgoStackable
extends BgoFeature

@export_range(1, 10000, 1) var max_stack := 999
@export var visual_spacing := 0.035


func _init() -> void:
	feature_id = &"stackable"


func get_definition_schema() -> Dictionary:
	var schema := {
		"max_stack": {"type": "int", "min": 1, "default": max_stack},
		"stack_spacing": {"type": "float", "min": 0.0, "default": visual_spacing},
	}
	schema.merge(property_schema, true)
	return schema
