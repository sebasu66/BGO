@tool
class_name BgoFeature
extends Node3D

@export var feature_id: StringName = &"feature"
@export var enabled := true
@export var property_schema: Dictionary = {}


func root_object() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("get_definition_value") and current.has_method("effective_definition"):
			return current
		current = current.get_parent()
	return null


func definition_value(key: StringName, fallback: Variant = null) -> Variant:
	var root := root_object()
	return fallback if root == null else root.call("get_definition_value", key, fallback)


func get_definition_schema() -> Dictionary:
	return property_schema.duplicate(true)


func refresh_from_definition() -> void:
	pass


func composition_descriptor() -> Dictionary:
	return {"type": "feature", "id": String(feature_id), "enabled": enabled}
