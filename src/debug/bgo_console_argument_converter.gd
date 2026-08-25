extends RefCounted


static func _convert(raw: String, argument: Dictionary) -> Dictionary:
	var type := int(argument.get("type", TYPE_STRING))
	var constant_result := _convert_public_constant(raw, type)
	if bool(constant_result.get("handled", false)):
		constant_result.erase("handled")
		return constant_result
	return _convert_by_type(raw, type)


static func _convert_public_constant(raw: String, type: int) -> Dictionary:
	if not raw.begins_with("G."):
		return {"handled": false}
	var resolved := BgoApiConstants.get_value(raw)
	if not bool(resolved.get("ok", false)):
		return {"handled": false}
	var value: Variant = resolved.get("value")
	if type == TYPE_STRING:
		return {"handled": true, "ok": true, "value": str(value)}
	if typeof(value) == type:
		return {"handled": true, "ok": true, "value": value}
	return {"handled": false}


static func _convert_by_type(raw: String, type: int) -> Dictionary:
	match type:
		TYPE_STRING:
			return {"ok": true, "value": raw}
		TYPE_STRING_NAME:
			return {"ok": true, "value": StringName(raw)}
		TYPE_NODE_PATH:
			return {"ok": true, "value": NodePath(raw)}
		TYPE_BOOL:
			return _convert_bool(raw)
		TYPE_INT, TYPE_FLOAT:
			return _convert_number(raw, type)
		TYPE_ARRAY, TYPE_DICTIONARY:
			return _convert_collection(raw, type)
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I:
			return _convert_variant_literal(raw, type)
		_:
			return {"ok": false, "error": "unsupported argument type %s" % type_string(type)}


static func _convert_bool(raw: String) -> Dictionary:
	var lower := raw.to_lower()
	if lower in ["1", "true", "yes", "on"]:
		return {"ok": true, "value": true}
	if lower in ["0", "false", "no", "off"]:
		return {"ok": true, "value": false}
	return {"ok": false, "error": "expected true/false or on/off"}


static func _convert_number(raw: String, type: int) -> Dictionary:
	if type == TYPE_INT:
		if raw.is_valid_int():
			return {"ok": true, "value": raw.to_int()}
		return {"ok": false, "error": "expected integer"}
	if raw.is_valid_float():
		return {"ok": true, "value": raw.to_float()}
	return {"ok": false, "error": "expected number"}


static func _convert_collection(raw: String, type: int) -> Dictionary:
	var parsed_json: Variant = JSON.parse_string(raw)
	if type == TYPE_ARRAY and parsed_json is Array:
		return {"ok": true, "value": parsed_json}
	if type == TYPE_DICTIONARY and parsed_json is Dictionary:
		return {"ok": true, "value": parsed_json}
	var parsed_literal: Variant = str_to_var(raw)
	if typeof(parsed_literal) == type:
		return {"ok": true, "value": parsed_literal}
	return {"ok": false, "error": "expected %s literal" % type_string(type)}


static func _convert_variant_literal(raw: String, type: int) -> Dictionary:
	var parsed: Variant = str_to_var(raw)
	if typeof(parsed) == type:
		return {"ok": true, "value": parsed}
	return {"ok": false, "error": "expected %s(...) literal" % type_string(type)}
