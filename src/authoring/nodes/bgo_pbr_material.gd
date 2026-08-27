@tool
class_name BgoPbrMaterial
extends BgoFeature

@export var default_roughness := 0.8
@export var default_metallic := 0.0


func _init() -> void:
	feature_id = &"pbr_material"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"pbr_albedo": {"type": "asset", "asset_kind": "texture", "default": ""},
		"pbr_normal": {"type": "asset", "asset_kind": "texture", "default": ""},
		"pbr_roughness": {"type": "asset", "asset_kind": "texture", "default": ""},
		"pbr_metallic": {"type": "asset", "asset_kind": "texture", "default": ""},
		"pbr_ao": {"type": "asset", "asset_kind": "texture", "default": ""},
		"pbr_height": {"type": "asset", "asset_kind": "texture", "default": ""},
		"roughness": {"type": "float", "min": 0.0, "max": 1.0, "default": default_roughness},
		"metallic": {"type": "float", "min": 0.0, "max": 1.0, "default": default_metallic},
		"uv_scale": {"type": "float", "min": 0.001, "default": 1.0},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	var root := root_object()
	if root == null:
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		material = material.duplicate() as StandardMaterial3D if material != null else StandardMaterial3D.new()
		material.roughness = float(definition_value(&"roughness", default_roughness))
		material.metallic = float(definition_value(&"metallic", default_metallic))
		var uv_scale := float(definition_value(&"uv_scale", 1.0))
		material.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
		_apply_texture(material, "albedo_texture", &"pbr_albedo")
		_apply_texture(material, "normal_texture", &"pbr_normal", "normal_enabled")
		_apply_texture(material, "roughness_texture", &"pbr_roughness")
		_apply_texture(material, "metallic_texture", &"pbr_metallic")
		_apply_texture(material, "ao_texture", &"pbr_ao", "ao_enabled")
		_apply_texture(material, "heightmap_texture", &"pbr_height", "heightmap_enabled")
		mesh_instance.material_override = material


func _apply_texture(
	material: StandardMaterial3D,
	property_name: String,
	definition_key: StringName,
	enabled_property: String = ""
) -> void:
	var path := String(definition_value(definition_key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return
	material.set(property_name, texture)
	if not enabled_property.is_empty():
		material.set(enabled_property, true)
