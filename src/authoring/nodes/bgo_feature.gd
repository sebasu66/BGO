@tool
class_name BgoFeature
extends Node3D

@export var feature_id: StringName = &"feature"
@export var enabled := true
@export var property_schema: Dictionary = {}


func root_object() -> BgoGameObject3D:
	var current := get_parent()
	while current != null:
		if current is BgoGameObject3D:
			return current as BgoGameObject3D
		current = current.get_parent()
	return null


func definition_value(key: StringName, fallback: Variant = null) -> Variant:
	var root := root_object()
	return fallback if root == null else root.get_definition_value(key, fallback)


func get_definition_schema() -> Dictionary:
	return property_schema.duplicate(true)


func refresh_from_definition() -> void:
	pass


func composition_descriptor() -> Dictionary:
	return {"type": "feature", "id": String(feature_id), "enabled": enabled}
