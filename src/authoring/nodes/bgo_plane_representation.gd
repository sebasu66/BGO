@tool
class_name BgoPlaneRepresentation
extends BgoRepresentation3D

@export var default_width := 1.0
@export var default_height := 1.4
@export var default_color := Color.WHITE


func _init() -> void:
	representation_id = &"plane"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"width": {"type": "float", "min": 0.01, "default": default_width},
		"height": {"type": "float", "min": 0.01, "default": default_height},
		"color": {"type": "color", "default": default_color.to_html()},
		"texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	var visual := visual_mesh()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(
		float(definition_value(&"width", default_width)),
		float(definition_value(&"height", default_height))
	)
	visual.mesh = mesh
	visual.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = definition_color(&"color", default_color)
	material.roughness = 0.72
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var texture := definition_texture(&"texture_path")
	if texture != null:
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material
