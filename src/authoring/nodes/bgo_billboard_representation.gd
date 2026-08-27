@tool
class_name BgoBillboardRepresentation
extends BgoRepresentation3D

@export var default_width := 0.9
@export var default_height := 1.8
@export var default_color := Color.WHITE
@export_enum("y_axis", "full") var default_billboard_mode := "y_axis"


func _init() -> void:
	representation_id = &"billboard"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"width": {"type": "float", "min": 0.01, "default": default_width},
		"height": {"type": "float", "min": 0.01, "default": default_height},
		"color": {"type": "color", "default": default_color.to_html()},
		"texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
		"billboard_mode": {"type": "enum", "values": ["y_axis", "full"], "default": default_billboard_mode},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	var visual := visual_mesh()
	var mesh := QuadMesh.new()
	var width := float(definition_value(&"width", default_width))
	var height := float(definition_value(&"height", default_height))
	mesh.size = Vector2(width, height)
	visual.mesh = mesh
	visual.position.y = height * 0.5
	visual.rotation_degrees = Vector3.ZERO
	var material := StandardMaterial3D.new()
	material.albedo_color = definition_color(&"color", default_color)
	material.roughness = 0.75
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = (
		BaseMaterial3D.BILLBOARD_ENABLED
		if String(definition_value(&"billboard_mode", default_billboard_mode)) == "full"
		else BaseMaterial3D.BILLBOARD_FIXED_Y
	)
	var texture := definition_texture(&"texture_path")
	if texture != null:
		material.albedo_texture = texture
	visual.material_override = material
