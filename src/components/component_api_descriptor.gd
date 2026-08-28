class_name BgoComponentApiDescriptor
extends RefCounted


## Builds one stable curated API descriptor for console, GUI, and MCP adapters.
static func create(
	host: Node,
	component_id: String,
	class_name_value: String,
	description: String,
	methods: Dictionary,
) -> Dictionary:
	return {
		"scope": "Match",
		"entity": _entity_name(host, component_id),
		"component_id": component_id,
		"class": class_name_value,
		"description": description,
		"methods": methods,
	}


## Describes a curated method with typed arguments and a stable return type.
static func method(
	call_name: String,
	arguments: Array = [],
	returns := "void",
	description := "",
	required := -1,
) -> Dictionary:
	var normalized_arguments := _normalize_arguments(arguments)
	var result := {
		"call": call_name,
		"args": normalized_arguments,
		"returns": returns,
		"description": description,
	}
	if required >= 0:
		result["required"] = required
	return result


## Describes a configuration setter and links it to its manifest property.
static func setter(
	call_name: String,
	property_name: String,
	value_type: String,
	returns := "void",
	description := "",
) -> Dictionary:
	var result := method(
		call_name,
		[{"name": "value", "type": value_type}],
		returns,
		description,
	)
	result["property"] = property_name
	return result


## Describes a setter whose stable property name is bound by the adapter.
static func bound_setter(
	call_name: String,
	property_name: String,
	value_type: String,
	returns := "void",
	description := "",
) -> Dictionary:
	var result := setter(call_name, property_name, value_type, returns, description)
	result["bound_args"] = [property_name]
	return result


static func _entity_name(host: Node, component_id: String) -> String:
	var entity_id := str(host.get_meta("entity_id", ""))
	if not entity_id.is_empty():
		return entity_id
	if not host.name.is_empty():
		return str(host.name)
	return component_id.trim_prefix("bgo.").replace(".", "_")


static func _normalize_arguments(arguments: Array) -> Array:
	var result: Array = []
	for value in arguments:
		if not value is Dictionary:
			continue
		var argument: Dictionary = (value as Dictionary).duplicate(true)
		argument["type"] = _type_id(argument.get("type", TYPE_STRING))
		result.append(argument)
	return result


static func _type_id(value: Variant) -> int:
	if value is int:
		return value
	match str(value).to_lower():
		"bool":
			return TYPE_BOOL
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"array", "packedstringarray":
			return TYPE_ARRAY
		"dictionary":
			return TYPE_DICTIONARY
		"vector2":
			return TYPE_VECTOR2
		"vector2i":
			return TYPE_VECTOR2I
		"vector3":
			return TYPE_VECTOR3
		"vector3i":
			return TYPE_VECTOR3I
		"color":
			return TYPE_COLOR
		_:
			return TYPE_STRING
