class_name BgoComponentRegistry
extends RefCounted

const COMPONENT_ROOT := "res://src/components"
const CONTRACT_FILE := "component.jsonh"

static var _contracts: Dictionary = {}
static var _loaded := false


static func load_components() -> Array[String]:
	_contracts.clear()
	_loaded = true
	var errors: Array[String] = []
	_scan_directory(COMPONENT_ROOT, errors)
	return errors


static func has_component(component_id: String) -> bool:
	_ensure_loaded()
	return _contracts.has(component_id)


static func get_contract(component_id: String) -> Dictionary:
	_ensure_loaded()
	if not _contracts.has(component_id):
		return {}
	return (_contracts[component_id] as Dictionary).duplicate(true)


## Returns every registered stable component id in deterministic order.
static func component_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for component_id in _contracts:
		result.append(str(component_id))
	result.sort()
	return result


static func get_kind(component_id: String) -> String:
	return str(get_contract(component_id).get("kind", ""))


static func capabilities(component_id: String) -> Array:
	return get_contract(component_id).get("capabilities", []).duplicate()


static func verbs(component_id: String) -> Dictionary:
	return (get_contract(component_id).get("verbs", {}) as Dictionary).duplicate(true)


static func load_scene(component_id: String) -> PackedScene:
	var scene_path := str(get_contract(component_id).get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	return load(scene_path) as PackedScene


static func validate_config(component_id: String, config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var contract := get_contract(component_id)
	if contract.is_empty():
		errors.append("Unknown component id '%s'." % component_id)
		return errors
	var schema: Dictionary = contract.get("config", {})
	for key_variant in schema:
		var key := str(key_variant)
		var descriptor: Dictionary = schema[key_variant]
		var required := bool(descriptor.get("required", not descriptor.has("default")))
		if not config.has(key):
			if required:
				errors.append("Missing required property '%s'." % key)
			continue
		_validate_value(key, config[key], descriptor, errors)
	for key_variant in config:
		var key := str(key_variant)
		if not schema.has(key):
			errors.append("Unknown configuration property '%s'." % key)
	return errors


static func _ensure_loaded() -> void:
	if not _loaded:
		load_components()


static func _scan_directory(path: String, errors: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(path):
		errors.append("Cannot open component directory '%s'." % path)
		return
	for directory_name in DirAccess.get_directories_at(path):
		_scan_directory(path.path_join(directory_name), errors)
	for file_name in DirAccess.get_files_at(path):
		if file_name == CONTRACT_FILE:
			_load_contract(path.path_join(file_name), errors)


static func _load_contract(path: String, errors: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open component contract '%s'." % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		errors.append("Invalid component contract '%s': %s" % [path, json.get_error_message()])
		return
	var contract: Dictionary = json.data
	if str(contract.get("schema", "")) != "bgo.component":
		errors.append("Component contract '%s' must declare schema 'bgo.component'." % path)
		return
	var component_id := str(contract.get("id", ""))
	if component_id.is_empty():
		errors.append("Component contract '%s' has no id." % path)
		return
	if _contracts.has(component_id):
		errors.append("Duplicate component id '%s'." % component_id)
		return
	if str(contract.get("kind", "")).is_empty():
		errors.append("Component '%s' has no kind." % component_id)
		return
	if str(contract.get("description", "")).strip_edges().is_empty():
		errors.append("Component '%s' requires a description." % component_id)
		return
	var capabilities_value: Variant = contract.get("capabilities", [])
	if not (capabilities_value is Array):
		errors.append("Component '%s'.capabilities must be an array." % component_id)
		return
	var verbs_value: Variant = contract.get("verbs", {})
	if not (verbs_value is Dictionary):
		errors.append("Component '%s'.verbs must be an object." % component_id)
		return
	var state_value: Variant = contract.get("state", {})
	if not (state_value is Dictionary):
		errors.append("Component '%s'.state must be an object." % component_id)
		return
	contract["contract_path"] = path
	_contracts[component_id] = contract


static func _validate_value(
	key: String, value: Variant, descriptor: Dictionary, errors: Array[String]
) -> void:
	var type_name := str(descriptor.get("type", "variant"))
	var valid_type := true
	match type_name:
		"int":
			valid_type = (
				typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(int(value)) == float(value)
			)
		"float":
			valid_type = typeof(value) in [TYPE_INT, TYPE_FLOAT]
		"bool":
			valid_type = typeof(value) == TYPE_BOOL
		"string", "enum":
			valid_type = typeof(value) == TYPE_STRING
	if not valid_type:
		errors.append("'%s' must be of type %s." % [key, type_name])
		return
	if type_name in ["int", "float"]:
		var number := float(value)
		if descriptor.has("min") and number < float(descriptor["min"]):
			errors.append("'%s' must be >= %s." % [key, descriptor["min"]])
		if descriptor.has("max") and number > float(descriptor["max"]):
			errors.append("'%s' must be <= %s." % [key, descriptor["max"]])
	if type_name == "enum" and not (descriptor.get("values", []) as Array).has(value):
		errors.append("'%s' must be one of %s." % [key, descriptor.get("values", [])])
