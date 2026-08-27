@tool
class_name BgoModelRepresentation
extends "res://src/authoring/nodes/bgo_representation_3d.gd"

@export_category("BGO Model Representation")
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		_queue_refresh()
@export_range(0.001, 1000.0, 0.001) var model_scale := 1.0:
	set(value):
		model_scale = maxf(value, 0.001)
		_queue_refresh()
@export var material_override: Material:
	set(value):
		material_override = value
		_queue_refresh()

var _refresh_queued := false

func _init() -> void:
	representation_id = &"model_3d"

func _ready() -> void:
	refresh_from_definition()

func get_definition_schema() -> Dictionary:
	var schema := {
		"model_path": {"type": "asset", "asset_kind": "scene_or_model", "default": ""},
		"model_scale": {"type": "float", "min": 0.001, "default": model_scale},
	}
	schema.merge(property_schema, true)
	return schema

func refresh_from_definition() -> void:
	_refresh_queued = false
	for child in get_children():
		if child.has_meta("bgo_generated_model"):
			child.free()
	var packed := _resolved_model_scene()
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return
	instance.name = "Model"
	instance.set_meta("bgo_generated_model", true)
	var resolved_scale := float(definition_value(&"model_scale", model_scale))
	instance.scale = Vector3.ONE * resolved_scale
	add_child(instance)
	if material_override != null:
		for node in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance != null:
				mesh_instance.material_override = material_override

func _resolved_model_scene() -> PackedScene:
	var path := String(definition_value(&"model_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return ResourceLoader.load(path) as PackedScene
	return model_scene

func _queue_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("refresh_from_definition")
