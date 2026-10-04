@tool
class_name BgoMiniature
extends BgoBasicCylinderPiece

var _glb_path := ""
var _glb_url := ""
var _last_asset_error := ""


func _model_representation() -> BgoModelRepresentation:
	return get_node_or_null("ModelPivot/ModelRepresentation") as BgoModelRepresentation


func _model_pivot() -> Marker3D:
	return get_node_or_null("ModelPivot") as Marker3D


func _asset_resolver() -> BgoAssetResolver:
	return get_node_or_null("AssetResolver") as BgoAssetResolver


func _adaptive_representation() -> BgoAdaptiveRepresentation:
	return get_node_or_null("ModelPivot/AdaptiveRepresentation") as BgoAdaptiveRepresentation


## A single, non-stackable character/miniature representation.
func is_stackable() -> bool:
	return false


## Sets a project-local GLB/GLTF scene under the base-anchored model pivot.
func set_glb(path: String) -> bool:
	var resolved_path := path
	if not resolved_path.begins_with("res://"):
		resolved_path = "res://" + resolved_path.trim_prefix("/")
	var file_exists := not path.is_empty() and FileAccess.file_exists(resolved_path)
	var resource_exists := not path.is_empty() and ResourceLoader.exists(resolved_path)
	if not file_exists:
		_last_asset_error = (
			"file_missing original=%s resolved=%s file_exists=%s resource_exists=%s"
			% [path, resolved_path, file_exists, resource_exists]
		)
		push_error("BgoMiniature asset load failed: %s" % _last_asset_error)
		return false
	var packed := ResourceLoader.load(resolved_path) as PackedScene
	if packed == null:
		_last_asset_error = (
			"resource_load_null original=%s resolved=%s file_exists=%s resource_exists=%s"
			% [path, resolved_path, file_exists, resource_exists]
		)
		push_error("BgoMiniature asset load failed: %s" % _last_asset_error)
		return false
	_last_asset_error = ""
	_glb_path = resolved_path
	var representation := _model_representation()
	if representation == null:
		return false
	representation.model_scene = packed
	representation.refresh_from_definition()
	return true


## Returns the project-local GLB/GLTF path currently assigned to this miniature.
func get_glb() -> String:
	return _glb_path


## Requests one externally hosted GLB through the shared validated resolver.
func set_glb_url(url: String) -> bool:
	_glb_url = url
	var resolver := _asset_resolver()
	if resolver == null:
		return false
	return resolver.load_model(url, str(_configuration.get("model_sha256", "")))


## Returns the currently requested external GLB URL.
func get_glb_url() -> String:
	return _glb_url


## Routes a local model path or external URL through the appropriate loader.
func set_model_path(path: String) -> bool:
	if path.begins_with("http://") or path.begins_with("https://"):
		return set_glb_url(path)
	return set_glb(path)


## Sets the authored model scale while preserving a positive runtime value.
func set_model_scale(value: float) -> bool:
	var representation := _model_representation()
	if representation == null:
		return false
	representation.model_scale = maxf(value, 0.001)
	_configuration["model_scale"] = representation.model_scale
	return true


## Sets the optional normalized SHA-256 expected for a remote model.
func set_model_sha256(value: String) -> bool:
	_configuration["model_sha256"] = value.strip_edges().to_lower()
	return true


## Configures the miniature's model, LOD, billboard, and tactical representations.
func set_representation_manifest(path: String) -> bool:
	var resolved_path := path if path.begins_with("res://") else "res://" + path.trim_prefix("/")
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		_last_asset_error = "representation_manifest_missing path=%s" % resolved_path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_last_asset_error = "representation_manifest_invalid_json path=%s" % resolved_path
		return false
	var representations := (parsed as Dictionary).get("representations", {}) as Dictionary
	var desktop := representations.get("desktop_model", {}) as Dictionary
	var desktop_path := str(desktop.get("path", ""))
	if not desktop_path.is_empty() and not set_glb(desktop_path):
		return false
	var adaptive := _adaptive_representation()
	var representation := _model_representation()
	if (
		adaptive != null
		and not adaptive.representation_sized.is_connected(_on_representation_sized)
	):
		adaptive.representation_sized.connect(_on_representation_sized)
	if (
		adaptive == null
		or representation == null
		or not adaptive.configure(resolved_path, representation)
	):
		_last_asset_error = "representation_manifest_setup_failed path=%s" % resolved_path
		return false
	# The inherited cylinder is a placeholder for asset-less miniatures only.
	var fallback_mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if fallback_mesh != null:
		fallback_mesh.visible = false
	_configuration["representation_manifest"] = resolved_path
	return true


func _on_representation_sized(metrics: Dictionary) -> void:
	component_event.emit("representation_sized", metrics)


func _on_remote_model_loaded(url: String, model: Node3D) -> void:
	if url != _glb_url:
		model.queue_free()
		return
	model.name = "RemoteModel"
	var pivot := _model_pivot()
	if pivot == null:
		model.queue_free()
		return
	pivot.add_child(model)


func _on_remote_model_failed(url: String, reason: String) -> void:
	component_event.emit("model_load_failed", {"url": url, "reason": reason})


## Applies the miniature appearance and optional model configuration.
func apply_configuration(config: Dictionary) -> void:
	super.apply_configuration(config)
	if config.has("model_scale"):
		if not set_model_scale(float(config["model_scale"])):
			_emit_configuration_error("model_scale", "model_representation_missing")
	if config.has("model_path") and not str(config["model_path"]).is_empty():
		var model_path := str(config["model_path"])
		if not set_model_path(model_path):
			_emit_configuration_error("model_path", _last_asset_error)
	if (
		config.has("representation_manifest")
		and not str(config["representation_manifest"]).is_empty()
	):
		if not set_representation_manifest(str(config["representation_manifest"])):
			_emit_configuration_error("representation_manifest", _last_asset_error)


func _emit_configuration_error(property_name: String, reason: String) -> void:
	component_event.emit(
		"configuration_error",
		{
			"property": property_name,
			"reason": reason,
			"value": _configuration.get(property_name, "")
		}
	)


## Miniatures always represent exactly one logical instance.
func configure(
	entity_id: String,
	owner_id: String,
	holder_id: String,
	_new_quantity: int,
	color: Color,
	configuration: Dictionary = {}
) -> void:
	super.configure(entity_id, owner_id, holder_id, 1, color, configuration)


## Returns the curated developer-console API for a unique miniature.
func console_api() -> Dictionary:
	var descriptor := super.console_api()
	descriptor["component_id"] = "bgo.piece.miniature"
	descriptor["class_name"] = "BgoMiniature"
	descriptor["description"] = (
		"Unique non-stackable character miniature " + "with configurable primitive appearance."
	)
	var methods: Dictionary = descriptor.get("methods", {})
	methods["setGlb"] = BgoComponentApiDescriptor.method(
		"set_glb", [{"name": "path", "type": "string"}], "bool"
	)
	methods["getGlb"] = BgoComponentApiDescriptor.method("get_glb", [], "string")
	methods["setGlbUrl"] = BgoComponentApiDescriptor.method(
		"set_glb_url", [{"name": "url", "type": "string"}], "bool"
	)
	methods["getGlbUrl"] = BgoComponentApiDescriptor.method("get_glb_url", [], "string")
	methods["setModelPath"] = BgoComponentApiDescriptor.setter(
		"set_model_path", "model_path", "string", "bool"
	)
	methods["setModelScale"] = BgoComponentApiDescriptor.setter(
		"set_model_scale", "model_scale", "float", "bool"
	)
	methods["setModelSha256"] = BgoComponentApiDescriptor.setter(
		"set_model_sha256", "model_sha256", "string", "bool"
	)
	methods["setRepresentationManifest"] = BgoComponentApiDescriptor.setter(
		"set_representation_manifest", "representation_manifest", "string", "bool"
	)
	descriptor["methods"] = methods
	return descriptor
