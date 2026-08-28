@tool
class_name BgoTabletopWorld
extends Node3D

const DEFAULT_PRESET := "Default"
const DEFAULT_COLLECTION_ROOT := "res://assets/table_pbr"

@export_group("Table Surface")
@export_dir var pbr_collection_root := DEFAULT_COLLECTION_ROOT:
	set(value):
		pbr_collection_root = value
		_rescan_presets()
@export_range(0.01, 100.0, 0.01) var surface_uv_scale := 1.0:
	set(value):
		surface_uv_scale = maxf(value, 0.01)
		_apply_selected_preset()
@export var surface_tint := Color.WHITE:
	set(value):
		surface_tint = value
		_apply_selected_preset()
@export var fallback_surface_color := Color(0.68, 0.66, 0.61, 1.0):
	set(value):
		fallback_surface_color = value
		_apply_selected_preset()
@export_range(0.0, 1.0, 0.01) var fallback_roughness := 0.86:
	set(value):
		fallback_roughness = clampf(value, 0.0, 1.0)
		_apply_selected_preset()

var _surface_preset := DEFAULT_PRESET
var _preset_paths: Dictionary = {}
var _scan_queued := false


func _ready() -> void:
	_rescan_presets()


func _get_property_list() -> Array[Dictionary]:
	var names := PackedStringArray([DEFAULT_PRESET])
	var discovered: Array[String] = []
	for key in _preset_paths.keys():
		var name := String(key)
		if name != DEFAULT_PRESET:
			discovered.append(name)
	discovered.sort()
	for name in discovered:
		names.append(name)
	return [{
		"name": "surface_pbr_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(names),
		"usage": PROPERTY_USAGE_DEFAULT,
	}]


func _get(property: StringName) -> Variant:
	if property == &"surface_pbr_preset":
		return _surface_preset
	return null


func _set(property: StringName, value: Variant) -> bool:
	if property != &"surface_pbr_preset":
		return false
	_surface_preset = String(value)
	_apply_selected_preset()
	return true


func available_surface_presets() -> PackedStringArray:
	var names := PackedStringArray([DEFAULT_PRESET])
	var discovered: Array[String] = []
	for key in _preset_paths.keys():
		var name := String(key)
		if name != DEFAULT_PRESET:
			discovered.append(name)
	discovered.sort()
	for name in discovered:
		names.append(name)
	return names


func selected_surface_preset() -> String:
	return _surface_preset


## Portable settings hook for Game Authoring / GameDefinition serialization.
func surface_configuration() -> Dictionary:
	return {
		"pbr_preset": _surface_preset,
		"uv_scale": surface_uv_scale,
		"tint": surface_tint.to_html(),
	}


## Applies a portable table surface configuration previously produced by surface_configuration().
func apply_surface_configuration(config: Dictionary) -> void:
	if config.has("uv_scale"):
		surface_uv_scale = float(config["uv_scale"])
	if config.has("tint"):
		surface_tint = Color.from_string(String(config["tint"]), Color.WHITE)
	if config.has("pbr_preset"):
		_surface_preset = String(config["pbr_preset"])
	_apply_selected_preset()


func refresh_pbr_collection() -> void:
	_rescan_presets()


func _rescan_presets() -> void:
	if _scan_queued:
		return
	_scan_queued = true
	call_deferred("_perform_rescan")


func _perform_rescan() -> void:
	_scan_queued = false
	_preset_paths.clear()
	if not pbr_collection_root.is_empty() and DirAccess.dir_exists_absolute(pbr_collection_root):
		_scan_directory(pbr_collection_root)
	if not _surface_preset.is_empty() and _surface_preset != DEFAULT_PRESET and not _preset_paths.has(_surface_preset):
		_surface_preset = DEFAULT_PRESET
	notify_property_list_changed()
	_apply_selected_preset()


func _scan_directory(path: String) -> void:
	var material_resource := _find_material_resource(path)
	var texture_maps := _find_texture_maps(path)
	if not material_resource.is_empty() or texture_maps.has("albedo"):
		var preset_name := path.get_file()
		if preset_name.is_empty():
			preset_name = "Surface"
		_preset_paths[preset_name] = path

	for child in DirAccess.get_directories_at(path):
		if child.begins_with("."):
			continue
		_scan_directory(path.path_join(child))


func _find_material_resource(path: String) -> String:
	for file_name in DirAccess.get_files_at(path):
		var lower := file_name.to_lower()
		if lower.ends_with(".tres") or lower.ends_with(".res"):
			var resource_path := path.path_join(file_name)
			var resource := ResourceLoader.load(resource_path)
			if resource is Material:
				return resource_path
	return ""


func _find_texture_maps(path: String) -> Dictionary:
	var maps := {}
	for file_name in DirAccess.get_files_at(path):
		if not _is_texture_file(file_name):
			continue
		var lower := file_name.to_lower()
		var full_path := path.path_join(file_name)
		if not maps.has("normal") and _contains_any(lower, ["normalgl", "normal_gl", "_normal", "-normal", "_nor", "-nor"]):
			maps["normal"] = full_path
		elif not maps.has("roughness") and _contains_any(lower, ["roughness", "_rough", "-rough"]):
			maps["roughness"] = full_path
		elif not maps.has("metallic") and _contains_any(lower, ["metalness", "metallic", "_metal", "-metal"]):
			maps["metallic"] = full_path
		elif not maps.has("ao") and _contains_any(lower, ["ambientocclusion", "ambient_occlusion", "_ao.", "-ao.", "_ao_", "-ao-"]):
			maps["ao"] = full_path
		elif not maps.has("height") and _contains_any(lower, ["displacement", "heightmap", "_height", "-height", "_disp", "-disp"]):
			maps["height"] = full_path
		elif not maps.has("albedo") and _contains_any(lower, ["basecolor", "base_color", "albedo", "diffuse", "_color", "-color"]):
			maps["albedo"] = full_path
	return maps


func _apply_selected_preset() -> void:
	if not is_inside_tree():
		return
	var surface := get_node_or_null("InfiniteLightSurface") as MeshInstance3D
	if surface == null:
		return

	if _surface_preset == DEFAULT_PRESET or not _preset_paths.has(_surface_preset):
		surface.material_override = _fallback_material()
		return

	var preset_path := String(_preset_paths[_surface_preset])
	var material_path := _find_material_resource(preset_path)
	if not material_path.is_empty():
		var loaded := ResourceLoader.load(material_path) as Material
		if loaded != null:
			var material := loaded.duplicate() as Material
			_apply_common_material_settings(material)
			surface.material_override = material
			return

	var maps := _find_texture_maps(preset_path)
	var generated := StandardMaterial3D.new()
	generated.albedo_color = surface_tint
	generated.roughness = fallback_roughness
	generated.uv1_scale = Vector3(surface_uv_scale, surface_uv_scale, 1.0)
	_apply_texture_map(generated, maps, "albedo", "albedo_texture")
	_apply_texture_map(generated, maps, "normal", "normal_texture", "normal_enabled")
	_apply_texture_map(generated, maps, "roughness", "roughness_texture")
	_apply_texture_map(generated, maps, "metallic", "metallic_texture")
	_apply_texture_map(generated, maps, "ao", "ao_texture", "ao_enabled")
	_apply_texture_map(generated, maps, "height", "heightmap_texture", "heightmap_enabled")
	surface.material_override = generated


func _fallback_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback_surface_color * surface_tint
	material.roughness = fallback_roughness
	material.uv1_scale = Vector3(surface_uv_scale, surface_uv_scale, 1.0)
	return material


func _apply_common_material_settings(material: Material) -> void:
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		base.uv1_scale = Vector3(surface_uv_scale, surface_uv_scale, 1.0)
		base.albedo_color *= surface_tint


func _apply_texture_map(
	material: StandardMaterial3D,
	maps: Dictionary,
	map_key: String,
	material_property: String,
	enabled_property: String = ""
) -> void:
	if not maps.has(map_key):
		return
	var texture := ResourceLoader.load(String(maps[map_key])) as Texture2D
	if texture == null:
		return
	material.set(material_property, texture)
	if not enabled_property.is_empty():
		material.set(enabled_property, true)


func _is_texture_file(file_name: String) -> bool:
	var lower := file_name.to_lower()
	return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".tga") or lower.ends_with(".exr")


func _contains_any(text: String, tokens: Array[String]) -> bool:
	for token in tokens:
		if text.contains(token):
			return true
	return false
