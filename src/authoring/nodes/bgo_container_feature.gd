@tool
class_name BgoContainerFeature
extends "res://src/authoring/nodes/bgo_feature.gd"

@export_category("BGO Container")
@export_range(1, 10000, 1) var capacity := 100
@export var accepted_component_ids: PackedStringArray = []
@export var ordered := true
@export var hidden_contents := true

func _init() -> void:
	feature_id = &"container"

func get_definition_schema() -> Dictionary:
	var schema := {
		"container_capacity": {"type": "int", "min": 1, "default": capacity},
		"container_ordered": {"type": "bool", "default": ordered},
		"container_hidden_contents": {"type": "bool", "default": hidden_contents},
	}
	schema.merge(property_schema, true)
	return schema
