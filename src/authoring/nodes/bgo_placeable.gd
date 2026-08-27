@tool
class_name BgoPlaceable
extends BgoFeature

@export var snap_to_slots := true
@export var allow_free_placement := false


func _init() -> void:
	feature_id = &"placeable"


func get_definition_schema() -> Dictionary:
	var schema := {
		"snap_to_slots": {"type": "bool", "default": snap_to_slots},
		"allow_free_placement": {"type": "bool", "default": allow_free_placement},
	}
	schema.merge(property_schema, true)
	return schema
