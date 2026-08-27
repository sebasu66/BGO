@tool
class_name BgoRepresentation3D
extends Node3D

@export var representation_id: StringName = &"representation"
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


func definition_color(key: StringName, fallback: Color) -> Color:
	var value := definition_value(key, fallback)
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, fallback)
	return fallback


func definition_texture(key: StringName) -> Texture2D:
	var path := String(definition_value(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


func get_definition_schema() -> Dictionary:
	return property_schema.duplicate(true)


func refresh_from_definition() -> void:
	pass


func composition_descriptor() -> Dictionary:
	return {"type": "representation", "id": String(representation_id)}


func visual_mesh() -> MeshInstance3D:
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		visual = MeshInstance3D.new()
		visual.name = "Visual"
		add_child(visual)
	return visual
