@tool
class_name BgoModelRepresentation
extends BgoRepresentation3D


func _init() -> void:
	representation_id = &"model_3d"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"model_path": {"type": "asset", "asset_kind": "scene_or_model", "default": ""},
		"model_scale": {"type": "float", "min": 0.001, "default": 1.0},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	for child in get_children():
		if child.has_meta("bgo_generated_model"):
			child.free()
	var path := String(definition_value(&"model_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return
	instance.name = "Model"
	instance.set_meta("bgo_generated_model", true)
	var model_scale := float(definition_value(&"model_scale", 1.0))
	instance.scale = Vector3.ONE * model_scale
	add_child(instance)
