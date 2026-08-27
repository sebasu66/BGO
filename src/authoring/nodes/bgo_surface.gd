@tool
class_name BgoSurface
extends BgoFeature

@export var default_size := Vector2(4.0, 4.0)
@export var show_debug_surface := true
@export var debug_color := Color(0.15, 0.55, 0.9, 0.12)


func _init() -> void:
	feature_id = &"surface"


func _ready() -> void:
	set_meta("bgo_placeable_surface", true)
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"surface_width": {"type": "float", "min": 0.01, "default": default_size.x},
		"surface_depth": {"type": "float", "min": 0.01, "default": default_size.y},
	}
	schema.merge(property_schema, true)
	return schema


func surface_size() -> Vector2:
	return Vector2(
		float(definition_value(&"surface_width", default_size.x)),
		float(definition_value(&"surface_depth", default_size.y))
	)


func refresh_from_definition() -> void:
	var marker := get_node_or_null("SurfaceMarker") as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = "SurfaceMarker"
		add_child(marker)
	marker.visible = show_debug_surface
	var mesh := QuadMesh.new()
	mesh.size = surface_size()
	marker.mesh = mesh
	marker.position.y = 0.015
	marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = debug_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
