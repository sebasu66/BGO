@tool
class_name BgoFlippable
extends "res://src/authoring/nodes/bgo_feature.gd"

@export_category("BGO Flippable")
@export var flip_axis := Vector3.RIGHT
@export var default_face_up := true

func _init() -> void:
	feature_id = &"flippable"

func get_definition_schema() -> Dictionary:
	var schema := {
		"face_up": {"type": "bool", "default": default_face_up},
	}
	schema.merge(property_schema, true)
	return schema
