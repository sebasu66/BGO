@tool
class_name BgoBoxRepresentation
extends "res://src/authoring/nodes/bgo_representation_3d.gd"

@export_category("BGO Box Representation")
@export var size := Vector3(1.0, 0.2, 1.0):
	set(value):
		size = Vector3(maxf(value.x, 0.01), maxf(value.y, 0.01), maxf(value.z, 0.01))
		_queue_refresh()
@export var color := Color(0.5, 0.5, 0.5):
	set(value):
		color = value
		_queue_refresh()
@export var texture: Texture2D:
	set(value):
		texture = value
		_queue_refresh()
## Optional complete material override; ShaderMaterial is supported.
@export var material: Material:
	set(value):
		material = value
		_queue_refresh()
@export_range(0.0, 1.0, 0.01) var roughness := 0.8:
	set(value):
		roughness = clampf(value, 0.0, 1.0)
		_queue_refresh()

var _refresh_queued := false

func _init() -> void:
	representation_id = &"box"

func _ready() -> void:
	refresh_from_definition()

func get_definition_schema() -> Dictionary:
	var schema := {
		"size_x": {"type": "float", "min": 0.01, "default": size.x},
		"size_y": {"type": "float", "min": 0.01, "default": size.y},
		"size_z": {"type": "float", "min": 0.01, "default": size.z},
		"color": {"type": "color", "default": color.to_html()},
		"texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
	}
	schema.merge(property_schema, true)
	return schema

func refresh_from_definition() -> void:
	_refresh_queued = false
	var visual := visual_mesh()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		float(definition_value(&"size_x", size.x)),
		float(definition_value(&"size_y", size.y)),
		float(definition_value(&"size_z", size.z))
	)
	visual.mesh = mesh
	if material != null:
		visual.material_override = material
		return
	var standard := StandardMaterial3D.new()
	standard.albedo_color = definition_color(&"color", color)
	standard.roughness = roughness
	var resolved_texture := definition_texture(&"texture_path")
	standard.albedo_texture = texture if resolved_texture == null else resolved_texture
	visual.material_override = standard

func _queue_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("refresh_from_definition")
