@tool
class_name BgoBoxRepresentation
extends BgoRepresentation3D

@export var default_size := Vector3(1.0, 0.2, 1.0)
@export var default_color := Color(0.5, 0.5, 0.5)


func _init() -> void:
	representation_id = &"box"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"size_x": {"type": "float", "min": 0.01, "default": default_size.x},
		"size_y": {"type": "float", "min": 0.01, "default": default_size.y},
		"size_z": {"type": "float", "min": 0.01, "default": default_size.z},
		"color": {"type": "color", "default": default_color.to_html()},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	var visual := visual_mesh()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		float(definition_value(&"size_x", default_size.x)),
		float(definition_value(&"size_y", default_size.y)),
		float(definition_value(&"size_z", default_size.z))
	)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = definition_color(&"color", default_color)
	material.roughness = 0.8
	visual.material_override = material
