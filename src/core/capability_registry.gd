class_name BgoCapabilityRegistry
extends RefCounted

const CATALOG_PATH := "res://src/capabilities/capabilities.jsonh"
const CORE_STATE_FIELDS := [
	"object_id",
	"component_id",
	"owner_id",
	"holder_id",
	"location_type",
	"location_id",
	"visibility",
	"quantity",
	"state_id",
	"properties",
]

static var _capabilities: Dictionary = {}
static var _loaded := false


static func load_catalog() -> Array[String]:
	_capabilities.clear()
	_loaded = true
	var errors: Array[String] = []
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return ["Cannot open capability catalog '%s'." % CATALOG_PATH]
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return ["Invalid capability catalog: %s" % json.get_error_message()]
	var catalog: Dictionary = json.data
	if str(catalog.get("schema", "")) != "bgo.capability_catalog":
		return ["Capability catalog schema must be 'bgo.capability_catalog'."]
	_capabilities = (catalog.get("capabilities", {}) as Dictionary).duplicate(true)
	for capability_id_variant in _capabilities:
		var capability_id := str(capability_id_variant)
		if not _valid_id(capability_id):
			errors.append("Invalid capability id '%s'." % capability_id)
	return errors


static func has(capability_id: String) -> bool:
	_ensure_loaded()
	return _capabilities.has(capability_id)


static func get_contract(capability_id: String) -> Dictionary:
	_ensure_loaded()
	if not _capabilities.has(capability_id):
		return {}
	return (_capabilities[capability_id] as Dictionary).duplicate(true)


static func validate_component(contract: Dictionary) -> Array[String]:
	_ensure_loaded()
	var errors: Array[String] = []
	var declared_verbs: Dictionary = contract.get("verbs", {})
	var declared_state: Dictionary = contract.get("state", {})
	for capability_value in contract.get("capabilities", []):
		var capability_id := str(capability_value)
		if not has(capability_id):
			errors.append("Unknown capability '%s'." % capability_id)
			continue
		var capability := get_contract(capability_id)
		for field_value in capability.get("required_state", []):
			var field := str(field_value)
			if not CORE_STATE_FIELDS.has(field) and not declared_state.has(field):
				errors.append("Capability '%s' requires state field '%s'." % [capability_id, field])
		for verb_value in capability.get("required_verbs", []):
			var verb := str(verb_value)
			if not declared_verbs.has(verb):
				errors.append("Capability '%s' requires verb '%s'." % [capability_id, verb])
	return errors


static func _ensure_loaded() -> void:
	if not _loaded:
		load_catalog()


static func _valid_id(value: String) -> bool:
	if value.is_empty() or value != value.to_lower():
		return false
	for character in value:
		if (
			not (character >= "a" and character <= "z")
			and not (character >= "0" and character <= "9")
			and character != "_"
		):
			return false
	return true
