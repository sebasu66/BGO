extends RefCounted

const PRESENTER_SCRIPT := preload("res://src/debug/bgo_console_api_presenter.gd")

var _registered_commands: Dictionary
var _api_entities: Dictionary
var _builder_registry
var _fluent_parser
var _registry
var _invocation
var _presenter = PRESENTER_SCRIPT.new()


func _configure(
	registered_commands: Dictionary,
	api_entities: Dictionary,
	builder_registry,
	fluent_parser,
	registry,
	invocation,
) -> void:
	_registered_commands = registered_commands
	_api_entities = api_entities
	_builder_registry = builder_registry
	_fluent_parser = fluent_parser
	_registry = registry
	_invocation = invocation
	_presenter._configure(_api_entities, _builder_registry, _registry)


func _execute_fluent_expression(source: String) -> bool:
	if not _fluent_parser.recognizes(source):
		return false
	var result: Dictionary = _fluent_parser.execute(source)
	if not bool(result.get("ok", false)):
		Console.print_error(
			(
				"%s (column %d)"
				% [
					str(result.get("error", "Invalid expression.")),
					int(result.get("position", 0)) + 1
				]
			)
		)
		return true
	var value: Variant = result.get("value")
	if value is BgoDefinitionBuilder:
		Console.print_line(
			(
				"%s %s %s"
				% [
					BgoConsoleSyntax.type_name((value as BgoDefinitionBuilder).type_name),
					BgoConsoleSyntax.punctuation("=>"),
					BgoConsoleSyntax.literal_name("ready")
				]
			)
		)
	elif value is Dictionary or value is Array:
		Console.print_line(JSON.stringify(value, "  "))
	else:
		Console.print_line(str(value))
	return true


func _complete_fluent_expression(source: String) -> Array[String]:
	var result: Array[String] = _fluent_parser.complete(source)
	for suggestion in _complete_live_namespace(source):
		if suggestion not in result:
			result.append(suggestion)
	return result


func _complete_live_namespace(source: String) -> Array[String]:
	var result: Array[String] = []
	for root_name in ["Game", "Match"]:
		var root_prefix := "%s." % root_name
		if not source.to_lower().begins_with(root_prefix.to_lower()) or "(" in source:
			continue
		var remainder := source.substr(root_prefix.length())
		if "." not in remainder:
			for entity_path in _api_entities:
				if str(entity_path).to_lower().begins_with((root_prefix + remainder).to_lower()):
					result.append("%s." % entity_path)
			return result
		var entity_name := _case_insensitive_key(
			_api_entities, "%s.%s" % [root_name, remainder.get_slice(".", 0)]
		)
		if not _api_entities.has(entity_name):
			return result
		var method_prefix := remainder.get_slice(".", 1)
		var methods: Dictionary = _api_entities[entity_name].get("methods", {})
		for method_name in methods:
			if str(method_name).to_lower().begins_with(method_prefix.to_lower()):
				var arguments: Array = methods[method_name].get("args", [])
				var suffix := "()" if arguments.is_empty() else "("
				result.append("%s.%s%s" % [entity_name, method_name, suffix])
		return result
	return result


func _invoke_python_namespace(path: String, arguments: Array) -> Dictionary:
	if path.to_lower().begins_with("system."):
		return _invoke_python_system(path, arguments)
	var canonical_path := _case_insensitive_key(_registered_commands, path)
	if canonical_path.is_empty():
		return {"ok": false, "error": "Unknown public API method: %s" % path}
	var registration: Dictionary = _registered_commands[canonical_path]
	var required := int(registration.get("required", 0))
	var argument_specs: Array = registration.get("args", [])
	if arguments.size() < required or arguments.size() > argument_specs.size():
		return {
			"ok": false,
			"error":
			(
				"%s expects %d..%d arguments, received %d."
				% [path, required, argument_specs.size(), arguments.size()]
			),
		}
	var typed_arguments: Array = []
	for index in arguments.size():
		var converted: Dictionary = _invocation._convert_argument(
			str(arguments[index]), argument_specs[index]
		)
		if not bool(converted.get("ok", false)):
			return {
				"ok": false,
				"error":
				(
					"Invalid argument %d for %s: %s"
					% [index + 1, path, converted.get("error", "invalid value")]
				),
			}
		typed_arguments.append(converted.get("value"))
	typed_arguments.append_array(registration.get("bound_args", []))
	var target: Object = registration.get("target")
	if not is_instance_valid(target):
		return {"ok": false, "error": "Target for %s is no longer available." % path}
	return {
		"ok": true,
		"value": target.callv(StringName(registration.get("method", "")), typed_arguments),
	}


func _invoke_python_system(path: String, arguments: Array) -> Dictionary:
	match path.to_lower().get_slice(".", 1):
		"api":
			return _invoke_system_api(path, arguments)
		"builders":
			return _invoke_system_builders(path, arguments)
		"constants":
			return _invoke_system_constants(path, arguments)
	return {"ok": false, "error": "Unknown System API method: %s" % path}


func _invoke_system_api(path: String, arguments: Array) -> Dictionary:
	match path.to_lower():
		"system.api.getentities":
			return (
				_python_arity_error(path, 0, arguments.size())
				if not arguments.is_empty()
				else {"ok": true, "value": _public_api_entities()}
			)
		"system.api.getmethods":
			return (
				_python_arity_error(path, 1, arguments.size())
				if arguments.size() != 1
				else _python_get_methods(str(arguments[0]))
			)
		"system.api.describe":
			if arguments.size() not in [1, 2]:
				return {"ok": false, "error": "%s expects one or two arguments." % path}
			return _python_describe(
				str(arguments[0]), str(arguments[1]) if arguments.size() == 2 else ""
			)
		"system.api.audit":
			return (
				_python_arity_error(path, 0, arguments.size())
				if not arguments.is_empty()
				else {"ok": true, "value": _api_audit_records()}
			)
	return {"ok": false, "error": "Unknown System API method: %s" % path}


func _invoke_system_builders(path: String, arguments: Array) -> Dictionary:
	if path.to_lower() == "system.builders.gettypes":
		return (
			_python_arity_error(path, 0, arguments.size())
			if not arguments.is_empty()
			else {"ok": true, "value": Array(_builder_registry.get_public_types())}
		)
	if path.to_lower() != "system.builders.describe":
		return {"ok": false, "error": "Unknown System API method: %s" % path}
	if arguments.size() != 1:
		return _python_arity_error(path, 1, arguments.size())
	var type_name := _internal_builder_type(str(arguments[0]))
	return (
		{"ok": false, "error": "Unknown Game builder: %s" % arguments[0]}
		if type_name.is_empty()
		else {"ok": true, "value": _builder_registry.describe(type_name)}
	)


func _invoke_system_constants(path: String, arguments: Array) -> Dictionary:
	if path.to_lower() == "system.constants.getall":
		return (
			_python_arity_error(path, 0, arguments.size())
			if not arguments.is_empty()
			else {"ok": true, "value": _system_constants()}
		)
	if path.to_lower() == "system.constants.get":
		return (
			_python_arity_error(path, 1, arguments.size())
			if arguments.size() != 1
			else _resolve_system_constant(str(arguments[0]))
		)
	return {"ok": false, "error": "Unknown System API method: %s" % path}


func _public_api_entities() -> Array[String]:
	var result: Array[String] = ["Game"]
	for type_name in _builder_registry.get_public_types():
		if type_name != "Game":
			result.append(type_name)
	for system_entity in ["System.api", "System.builders", "System.constants"]:
		result.append(system_entity)
	for entity_name in _api_entities:
		if str(entity_name) not in result:
			result.append(str(entity_name))
	result.sort()
	return result


func _python_get_methods(entity_name: String) -> Dictionary:
	var builder_type := _internal_builder_type(entity_name)
	if not builder_type.is_empty():
		return {"ok": true, "value": _builder_public_methods(builder_type)}
	var system_methods := _system_methods(entity_name)
	if not system_methods.is_empty():
		return {"ok": true, "value": system_methods}
	var normalized: String = _registry._canonical_api_entity(entity_name)
	normalized = _case_insensitive_key(_api_entities, normalized)
	if normalized.is_empty():
		return {"ok": false, "error": "Unknown public API entity: %s" % entity_name}
	return {
		"ok": true, "value": (_api_entities[normalized].get("methods", {}) as Dictionary).keys()
	}


func _python_describe(entity_name: String, method_name: String) -> Dictionary:
	var result: Dictionary = {}
	var builder_type := _internal_builder_type(entity_name)
	if not builder_type.is_empty():
		var descriptor: Dictionary = _builder_registry.describe(builder_type)
		if method_name.is_empty():
			result = {"ok": true, "value": descriptor}
		elif (
			_case_insensitive_array_value(_builder_public_methods(builder_type), method_name)
			. is_empty()
		):
			result = {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
		else:
			result = {"ok": true, "value": {"entity": entity_name, "method": method_name}}
	else:
		var system_methods := _system_methods(entity_name)
		if not system_methods.is_empty():
			if (
				not method_name.is_empty()
				and _case_insensitive_array_value(system_methods, method_name).is_empty()
			):
				result = {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
			else:
				result = {"ok": true, "value": {"entity": entity_name, "methods": system_methods}}
		else:
			result = _describe_live_entity(entity_name, method_name)
	return result


func _describe_live_entity(entity_name: String, method_name: String) -> Dictionary:
	var normalized: String = _registry._canonical_api_entity(entity_name)
	normalized = _case_insensitive_key(_api_entities, normalized)
	if normalized.is_empty():
		return {"ok": false, "error": "Unknown public API entity: %s" % entity_name}
	var entity: Dictionary = _api_entities[normalized]
	if method_name.is_empty():
		return {
			"ok": true,
			"value":
			{
				"entity": normalized,
				"class": entity.get("class", ""),
				"description": entity.get("description", ""),
				"methods": (entity.get("methods", {}) as Dictionary).keys()
			}
		}
	var methods: Dictionary = entity.get("methods", {})
	var canonical_method := _case_insensitive_key(methods, method_name)
	if canonical_method.is_empty():
		return {"ok": false, "error": "Unknown method %s.%s" % [normalized, method_name]}
	var method: Dictionary = methods[canonical_method]
	return {
		"ok": true,
		"value":
		{
			"entity": normalized,
			"method": canonical_method,
			"arguments": method.get("args", []),
			"returns": method.get("returns", "Variant"),
			"description": method.get("description", "")
		}
	}


func _system_methods(entity_name: String) -> Array[String]:
	match entity_name.to_lower():
		"system.api":
			return ["getEntities", "getMethods", "describe", "audit"]
		"system.builders":
			return ["getTypes", "describe"]
		"system.constants":
			return ["getAll", "get"]
	return []


func _builder_public_methods(type_name: String) -> Array:
	var result: Array = ["create"]
	if type_name == "Game":
		result.append_array(["current", "load"])
	result.append_array(_builder_registry.describe(type_name).get("methods", []))
	return result


func _internal_builder_type(public_name: String) -> String:
	if public_name.to_lower() == "game":
		return "Game"
	if not public_name.to_lower().begins_with("game."):
		return ""
	var type_name := public_name.substr("Game.".length())
	return _case_insensitive_array_value(Array(_builder_registry.get_types()), type_name)


func _system_constants() -> Dictionary:
	var result: Dictionary = {}
	for constant_name in BgoApiConstants.names():
		var short_name := str(constant_name).trim_prefix("G.")
		if "." not in short_name:
			result["System.constants.%s" % short_name] = (
				BgoApiConstants.get_value(constant_name).get("value")
			)
	return result


func _resolve_system_constant(name: String) -> Dictionary:
	var normalized := name
	if normalized.to_lower().begins_with("system.constants."):
		normalized = normalized.substr("System.constants.".length())
	if normalized.to_lower().begins_with("g."):
		normalized = normalized.substr(2)
	var resolved: Dictionary = BgoApiConstants.get_value("G.%s" % normalized)
	return (
		{"ok": true, "value": resolved.get("value")}
		if bool(resolved.get("ok", false))
		else {"ok": false, "error": "Unknown constant: %s" % name}
	)


func _python_arity_error(path: String, expected: int, received: int) -> Dictionary:
	return {
		"ok": false, "error": "%s expects %d arguments, received %d." % [path, expected, received]
	}


func _list_builder_types() -> void:
	_presenter._list_builder_types()


func _describe_builder(type_name: String) -> void:
	_presenter._describe_builder(type_name)


func _list_api_entities() -> void:
	_presenter._list_api_entities()


func _audit_api() -> void:
	Console.print_line(JSON.stringify(_api_audit_records(), "  "))


func _api_audit_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entity_names := _api_entities.keys()
	entity_names.sort()
	for entity_name in entity_names:
		var entity: Dictionary = _api_entities[entity_name]
		var exposed := (entity.get("methods", {}) as Dictionary).keys()
		exposed.sort()
		(
			result
			. append(
				{
					"entity": entity_name,
					"component_id": entity.get("component_id", ""),
					"exposed": exposed,
					"call_targets": _audit_call_targets(entity.get("methods", {})),
				}
			)
		)
	return result


func _audit_call_targets(methods_value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not methods_value is Dictionary:
		return result
	for api_name in methods_value:
		var registration: Dictionary = methods_value[api_name]
		result[api_name] = registration.get("method", "")
	return result


func _list_api_methods(entity_name: String) -> void:
	_presenter._list_api_methods(entity_name)


func _describe_api(entity_name: String, method_name: String = "") -> void:
	_presenter._describe_api(entity_name, method_name)


func _case_insensitive_key(values: Dictionary, requested: String) -> String:
	if values.has(requested):
		return requested
	var normalized := requested.to_lower()
	for candidate in values:
		if str(candidate).to_lower() == normalized:
			return str(candidate)
	return ""


func _case_insensitive_array_value(values: Array, requested: String) -> String:
	var normalized := requested.to_lower()
	for candidate in values:
		if str(candidate).to_lower() == normalized:
			return str(candidate)
	return ""


func _print_api_method(registration: Dictionary) -> void:
	_presenter._print_api_method(registration)


func _format_value(value: Variant) -> String:
	return _presenter._format_value(value)


func _list_constants() -> void:
	_presenter._list_constants()


func _get_constant(constant_name: String) -> void:
	_presenter._get_constant(constant_name)
