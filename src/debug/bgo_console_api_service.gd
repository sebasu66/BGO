extends RefCounted

var _registered_commands: Dictionary
var _api_entities: Dictionary
var _builder_registry
var _fluent_parser
var _registry
var _invocation


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
		if not source.begins_with(root_prefix) or "(" in source:
			continue
		var remainder := source.trim_prefix(root_prefix)
		if "." not in remainder:
			for entity_path in _api_entities:
				if str(entity_path).begins_with(root_prefix + remainder):
					result.append("%s." % entity_path)
			return result
		var entity_name := "%s.%s" % [root_name, remainder.get_slice(".", 0)]
		if not _api_entities.has(entity_name):
			return result
		var method_prefix := remainder.get_slice(".", 1)
		var methods: Dictionary = _api_entities[entity_name].get("methods", {})
		for method_name in methods:
			if str(method_name).begins_with(method_prefix):
				var arguments: Array = methods[method_name].get("args", [])
				var suffix := "()" if arguments.is_empty() else "("
				result.append("%s.%s%s" % [entity_name, method_name, suffix])
		return result
	return result


func _invoke_python_namespace(path: String, arguments: Array) -> Dictionary:
	if path.begins_with("System."):
		return _invoke_python_system(path, arguments)
	if not _registered_commands.has(path):
		return {"ok": false, "error": "Unknown public API method: %s" % path}
	var registration: Dictionary = _registered_commands[path]
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
	var target: Object = registration.get("target")
	if not is_instance_valid(target):
		return {"ok": false, "error": "Target for %s is no longer available." % path}
	return {
		"ok": true,
		"value": target.callv(StringName(registration.get("method", "")), typed_arguments),
	}


func _invoke_python_system(path: String, arguments: Array) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "Unknown System API method: %s" % path}
	match path:
		"System.api.getEntities":
			if not arguments.is_empty():
				result = _python_arity_error(path, 0, arguments.size())
			else:
				result = {"ok": true, "value": _public_api_entities()}
		"System.api.getMethods":
			if arguments.size() != 1:
				result = _python_arity_error(path, 1, arguments.size())
			else:
				result = _python_get_methods(str(arguments[0]))
		"System.api.describe":
			if arguments.size() not in [1, 2]:
				result = {"ok": false, "error": "%s expects one or two arguments." % path}
			else:
				result = _python_describe(
					str(arguments[0]), str(arguments[1]) if arguments.size() == 2 else ""
				)
		"System.builders.getTypes":
			if not arguments.is_empty():
				result = _python_arity_error(path, 0, arguments.size())
			else:
				result = {"ok": true, "value": Array(_builder_registry.get_public_types())}
		"System.builders.describe":
			if arguments.size() != 1:
				result = _python_arity_error(path, 1, arguments.size())
			else:
				var type_name := _internal_builder_type(str(arguments[0]))
				if type_name.is_empty():
					result = {"ok": false, "error": "Unknown Game builder: %s" % arguments[0]}
				else:
					result = {"ok": true, "value": _builder_registry.describe(type_name)}
		"System.constants.getAll":
			if not arguments.is_empty():
				result = _python_arity_error(path, 0, arguments.size())
			else:
				result = {"ok": true, "value": _system_constants()}
		"System.constants.get":
			if arguments.size() != 1:
				result = _python_arity_error(path, 1, arguments.size())
			else:
				result = _resolve_system_constant(str(arguments[0]))
	return result


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
	if not _api_entities.has(normalized):
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
		elif method_name not in _builder_public_methods(builder_type):
			result = {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
		else:
			result = {"ok": true, "value": {"entity": entity_name, "method": method_name}}
	else:
		var system_methods := _system_methods(entity_name)
		if not system_methods.is_empty():
			if not method_name.is_empty() and method_name not in system_methods:
				result = {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
			else:
				result = {"ok": true, "value": {"entity": entity_name, "methods": system_methods}}
		else:
			result = _describe_live_entity(entity_name, method_name)
	return result


func _describe_live_entity(entity_name: String, method_name: String) -> Dictionary:
	var normalized: String = _registry._canonical_api_entity(entity_name)
	if not _api_entities.has(normalized):
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
	if not methods.has(method_name):
		return {"ok": false, "error": "Unknown method %s.%s" % [normalized, method_name]}
	var method: Dictionary = methods[method_name]
	return {
		"ok": true,
		"value":
		{
			"entity": normalized,
			"method": method_name,
			"arguments": method.get("args", []),
			"returns": method.get("returns", "Variant"),
			"description": method.get("description", "")
		}
	}


func _system_methods(entity_name: String) -> Array[String]:
	match entity_name:
		"System.api":
			return ["getEntities", "getMethods", "describe"]
		"System.builders":
			return ["getTypes", "describe"]
		"System.constants":
			return ["getAll", "get"]
	return []


func _builder_public_methods(type_name: String) -> Array:
	var result: Array = ["create"]
	if type_name == "Game":
		result.append_array(["current", "load"])
	result.append_array(_builder_registry.describe(type_name).get("methods", []))
	return result


func _internal_builder_type(public_name: String) -> String:
	if public_name == "Game":
		return "Game"
	if not public_name.begins_with("Game."):
		return ""
	var type_name := public_name.trim_prefix("Game.")
	return type_name if type_name in _builder_registry.get_types() else ""


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
	var normalized: String = name.trim_prefix("System.constants.").trim_prefix("G.")
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
	Console.print_line("Definition builders: %s" % ", ".join(_builder_registry.get_public_types()))


func _describe_builder(type_name: String) -> void:
	var internal_type := _internal_builder_type(type_name)
	if internal_type.is_empty() and type_name in _builder_registry.get_types():
		internal_type = type_name
	if internal_type.is_empty():
		Console.print_error("Unknown builder type: %s" % type_name)
		return
	var descriptor: Dictionary = _builder_registry.describe(internal_type)
	for factory in descriptor.get("factories", []):
		Console.print_line(str(factory))
	for method_name in descriptor.get("methods", []):
		Console.print_line("  .%s" % BgoConsoleSyntax.method(str(method_name)))


func _list_api_entities() -> void:
	var names := _api_entities.keys()
	names.sort()
	Console.print_line("Curated API entities (%d):" % names.size())
	for entity_name_variant in names:
		var entity_name := str(entity_name_variant)
		var entity: Dictionary = _api_entities[entity_name_variant]
		(
			Console
			. print_line(
				(
					"  %s %s %s"
					% [
						BgoConsoleSyntax.entity(entity_name),
						BgoConsoleSyntax.type_name(str(entity.get("class", "Entity"))),
						BgoConsoleSyntax.muted(str(entity.get("description", ""))),
					]
				)
			)
		)


func _list_api_methods(entity_name: String) -> void:
	var normalized: String = _registry._canonical_api_entity(entity_name)
	if not _api_entities.has(normalized):
		Console.print_error("Unknown curated API entity: %s" % entity_name)
		return
	var entity: Dictionary = _api_entities[normalized]
	var methods: Dictionary = entity.get("methods", {})
	var names := methods.keys()
	names.sort()
	(
		Console
		. print_line(
			(
				"%s %s"
				% [
					BgoConsoleSyntax.type_name(str(entity.get("class", "Entity"))),
					BgoConsoleSyntax.entity(normalized),
				]
			)
		)
	)
	for method_name_variant in names:
		_print_api_method(methods[method_name_variant])


func _describe_api(entity_name: String, method_name: String = "") -> void:
	var normalized: String = _registry._canonical_api_entity(entity_name)
	if not _api_entities.has(normalized):
		Console.print_error("Unknown curated API entity: %s" % entity_name)
		return
	var entity: Dictionary = _api_entities[normalized]
	if method_name.is_empty():
		(
			Console
			. print_line(
				(
					"%s %s"
					% [
						BgoConsoleSyntax.type_name(str(entity.get("class", "Entity"))),
						BgoConsoleSyntax.entity(normalized),
					]
				)
			)
		)
		var description := str(entity.get("description", ""))
		if not description.is_empty():
			Console.print_line("  %s" % BgoConsoleSyntax.muted(description))
		_list_api_methods(normalized)
		return
	var methods: Dictionary = entity.get("methods", {})
	if not methods.has(method_name):
		Console.print_error("Unknown curated API method: %s.%s" % [normalized, method_name])
		return
	_print_api_method(methods[method_name])


func _print_api_method(registration: Dictionary) -> void:
	Console.print_line(
		(
			"  %s"
			% BgoConsoleSyntax.signature(
				str(registration.get("object_name", "entity")),
				str(registration.get("api_name", "method")),
				registration.get("args", []),
				str(registration.get("returns", "Variant"))
			)
		)
	)
	var description := str(registration.get("description", ""))
	if not description.is_empty():
		Console.print_line("      %s" % BgoConsoleSyntax.muted(description))


func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return BgoConsoleSyntax.literal_name('"%s"' % str(value))
		TYPE_INT, TYPE_FLOAT:
			return "[color=#d19a66]%s[/color]" % str(value)
		TYPE_BOOL, TYPE_NIL:
			return "[color=#56b6c2]%s[/color]" % str(value)
		_:
			return BgoConsoleSyntax.literal_name(str(value))


func _list_constants() -> void:
	Console.print_line("Public constants:")
	for constant_name in BgoApiConstants.names():
		var resolved := BgoApiConstants.get_value(constant_name)
		(
			Console
			. print_line(
				(
					"  [color=#c678dd]%s[/color] %s %s"
					% [
						constant_name,
						BgoConsoleSyntax.punctuation("="),
						_format_value(resolved.get("value")),
					]
				)
			)
		)


func _get_constant(constant_name: String) -> void:
	var resolved := BgoApiConstants.get_value(constant_name)
	if not bool(resolved.get("ok", false)):
		Console.print_error("Unknown BGO constant: %s" % constant_name)
		return
	(
		Console
		. print_line(
			(
				"[color=#c678dd]%s[/color] %s %s"
				% [
					constant_name,
					BgoConsoleSyntax.punctuation("="),
					_format_value(resolved.get("value")),
				]
			)
		)
	)
