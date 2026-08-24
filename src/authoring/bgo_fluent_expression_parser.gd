class_name BgoFluentExpressionParser
extends RefCounted
# gdlint: disable=max-returns

const PUBLIC_ROOTS := ["Game", "Match", "System"]

var _source := ""
var _position := 0
var _registry: BgoBuilderRegistry
var _namespace_invoker := Callable()


func _init(registry: BgoBuilderRegistry) -> void:
	_registry = registry


func set_namespace_invoker(invoker: Callable) -> void:
	_namespace_invoker = invoker


func recognizes(source: String) -> bool:
	var first := source.strip_edges().get_slice(".", 0)
	return first in PUBLIC_ROOTS


func complete(source: String) -> Array[String]:
	var result: Array[String] = []
	var stripped := source.strip_edges()
	if stripped.begins_with("Game.") and "(" not in stripped:
		return _complete_game_namespace(stripped)
	if stripped.begins_with("System.") and "(" not in stripped:
		return _complete_system_namespace(stripped)
	var context := _find_completion_context(source)
	if context.is_empty():
		return result
	var type_name := str(context.get("type", ""))
	var replacement_start := int(context.get("replacement_start", source.length()))
	var method_prefix := source.substr(replacement_start)
	if "(" in method_prefix or ")" in method_prefix:
		return result
	var base := source.left(replacement_start)
	for method_name in _registry.describe(type_name).get("methods", []):
		if str(method_name).begins_with(method_prefix):
			var suffix := (
				"()"
				if (
					method_name
					in [
						"getDefinition",
						"getJson",
						"getWarnings",
						"validate",
						"isValid",
						"build",
						"migrateToCurrent",
					]
				)
				else "("
			)
			result.append("%s%s%s" % [base, method_name, suffix])
	return result


func _complete_game_namespace(source: String) -> Array[String]:
	var result: Array[String] = []
	var member_prefix := source.trim_prefix("Game.")
	for factory in ["create()", "current()", "load("]:
		if factory.begins_with(member_prefix):
			result.append("Game.%s" % factory)
	for type_name in _registry.get_types():
		if type_name == "Game":
			continue
		var member := "%s." % type_name
		if member.begins_with(member_prefix):
			result.append("Game.%s" % member)
	if member_prefix.get_slice_count(".") == 2:
		var type_name := member_prefix.get_slice(".", 0)
		var factory_prefix := member_prefix.get_slice(".", 1)
		if type_name in _registry.get_types() and "create()".begins_with(factory_prefix):
			result.append("Game.%s.create()" % type_name)
	return result


func _complete_system_namespace(source: String) -> Array[String]:
	var static_paths := [
		"System.api.",
		"System.builders.",
		"System.constants.",
		"System.api.getEntities()",
		"System.api.getMethods(",
		"System.api.describe(",
		"System.builders.getTypes()",
		"System.builders.describe(",
		"System.constants.getAll()",
		"System.constants.get(",
	]
	var result: Array[String] = []
	for path in static_paths:
		if path != source and path.begins_with(source):
			result.append(path)
	if source.begins_with("System.constants."):
		var constant_prefix := source.trim_prefix("System.constants.")
		for constant_name in BgoApiConstants.names():
			var short_name := str(constant_name).trim_prefix("G.")
			if "." not in short_name and short_name.begins_with(constant_prefix):
				result.append("System.constants.%s" % short_name)
	return result


func _find_completion_context(source: String) -> Dictionary:
	var best_start := -1
	var best_type := ""
	for type_name in _registry.get_types():
		var markers: Array[String] = []
		if type_name == "Game":
			markers = ["Game.create()", "Game.current()"]
		else:
			markers = ["Game.%s.create()" % type_name]
		for marker in markers:
			var marker_start := source.rfind(marker)
			if marker_start > best_start:
				best_start = marker_start
				best_type = type_name
	if best_start < 0:
		return {}
	var method_separator := source.rfind(".")
	if method_separator < best_start:
		return {}
	return {"type": best_type, "replacement_start": method_separator + 1}


func execute(source: String) -> Dictionary:
	_source = source
	_position = 0
	var parsed := _parse_value()
	if not bool(parsed.get("ok", false)):
		parsed["position"] = _position
		return parsed
	_skip_space()
	if _position != _source.length():
		return _failure("Unexpected text '%s'." % _source.substr(_position), _position)
	return {"ok": true, "value": parsed.get("value")}


func _parse_value() -> Dictionary:
	_skip_space()
	if _position >= _source.length():
		return _failure("Expected a value.", _position)
	var character := _source[_position]
	if character == '"':
		return _parse_string()
	if character == "-" or character.is_valid_int():
		return _parse_number()
	var identifier := _parse_identifier()
	if identifier.is_empty():
		return _failure("Expected an identifier, string or number.", _position)
	if identifier == "true":
		return {"ok": true, "value": true}
	if identifier == "false":
		return {"ok": true, "value": false}
	if identifier == "null":
		return {"ok": true, "value": null}
	if identifier == "Game":
		return _parse_game_expression()
	if identifier in ["Match", "System"]:
		return _parse_namespace_expression([identifier])
	return _failure("Public expressions must begin with Game, Match or System.", _position)


func _parse_game_expression() -> Dictionary:
	if not _consume("."):
		return _failure("Expected a Game member.", _position)
	var member := _parse_identifier()
	if member in ["create", "current", "load"]:
		return _start_builder("Game", member)
	if member in _registry.get_types() and member != "Game":
		if not _consume("."):
			return _failure("Expected Game.%s.create()." % member, _position)
		return _start_builder(member, _parse_identifier())
	return _parse_namespace_expression(["Game", member])


func _start_builder(type_name: String, factory: String) -> Dictionary:
	var builder: BgoDefinitionBuilder
	if factory == "create":
		var arguments := _parse_arguments()
		if not bool(arguments.get("ok", false)):
			return arguments
		if not (arguments.get("value", []) as Array).is_empty():
			return _failure("create() takes no arguments.", _position)
		builder = _registry.create(type_name)
	elif type_name == "Game" and factory == "current":
		var arguments := _parse_arguments()
		if not bool(arguments.get("ok", false)):
			return arguments
		builder = _registry.current_game
		if builder == null:
			return _failure("Game.current() requires Game.create() first.", _position)
	elif type_name == "Game" and factory == "load":
		var arguments := _parse_arguments()
		if not bool(arguments.get("ok", false)):
			return arguments
		if (arguments.get("value", []) as Array).size() != 1:
			return _failure("Game.load(path) expects one argument.", _position)
		var path := str(arguments.value[0])
		if not path.begins_with("res://games/") and not path.begins_with("user://"):
			return _failure("Game.load only accepts res://games/ or user:// paths.", _position)
		var loaded := BgoGameDefinitionLoader.load_game(path)
		if not bool(loaded.get("ok", false)):
			return _failure("Could not load game: %s" % loaded.get("errors", []), _position)
		builder = _registry.from_definition(loaded.get("data", {}))
	else:
		return _failure("Unknown factory Game.%s.%s()." % [type_name, factory], _position)
	return _parse_builder_methods(builder)


func _parse_builder_methods(builder: BgoDefinitionBuilder) -> Dictionary:
	var value: Variant = builder
	while _consume("."):
		if not value is BgoDefinitionBuilder:
			return _failure("Cannot chain after a terminal value.", _position)
		var method_name := _parse_identifier()
		var arguments := _parse_arguments()
		if not bool(arguments.get("ok", false)):
			return arguments
		var invoked := (value as BgoDefinitionBuilder).invoke(
			method_name, arguments.get("value", [])
		)
		if not bool(invoked.get("ok", false)):
			return _failure(str(invoked.get("error", "Call failed.")), _position)
		value = invoked.get("value")
	return {"ok": true, "value": value}


func _parse_namespace_expression(initial_segments: Array[String]) -> Dictionary:
	var segments := initial_segments.duplicate()
	while _consume("."):
		var segment := _parse_identifier()
		if segment.is_empty():
			return _failure("Expected a namespace member.", _position)
		segments.append(segment)
		_skip_space()
		if _peek() == "(":
			var arguments := _parse_arguments()
			if not bool(arguments.get("ok", false)):
				return arguments
			return _invoke_namespace(".".join(segments), arguments.get("value", []))
	if segments.size() == 3 and segments[0] == "System" and segments[1] == "constants":
		return _resolve_system_constant(segments[2])
	return _failure("Expected a method call with parentheses.", _position)


func _invoke_namespace(path: String, arguments: Array) -> Dictionary:
	if not _namespace_invoker.is_valid():
		return _failure("The public API namespace is not connected.", _position)
	var result: Variant = _namespace_invoker.call(path, arguments)
	if not result is Dictionary:
		return _failure("Invalid namespace result for %s." % path, _position)
	if not bool(result.get("ok", false)):
		return _failure(str(result.get("error", "Call failed.")), _position)
	return {"ok": true, "value": result.get("value")}


func _resolve_system_constant(short_name: String) -> Dictionary:
	var resolved := BgoApiConstants.get_value("G.%s" % short_name)
	if not bool(resolved.get("ok", false)):
		return _failure("Unknown constant System.constants.%s." % short_name, _position)
	return {"ok": true, "value": resolved.get("value")}


func _parse_arguments() -> Dictionary:
	if not _consume("("):
		return _failure("Expected (.", _position)
	var result: Array = []
	_skip_space()
	if _consume(")"):
		return {"ok": true, "value": result}
	while true:
		var argument := _parse_value()
		if not bool(argument.get("ok", false)):
			return argument
		result.append(argument.get("value"))
		_skip_space()
		if _consume(")"):
			break
		if not _consume(","):
			return _failure("Expected , or ).", _position)
	return {"ok": true, "value": result}


func _parse_string() -> Dictionary:
	_position += 1
	var result := ""
	while _position < _source.length():
		var character := _source[_position]
		_position += 1
		if character == '"':
			return {"ok": true, "value": result}
		if character == "\\" and _position < _source.length():
			var escaped := _source[_position]
			_position += 1
			result += "\n" if escaped == "n" else "\t" if escaped == "t" else escaped
		else:
			result += character
	return _failure("Unterminated string.", _position)


func _parse_number() -> Dictionary:
	var start := _position
	if _source[_position] == "-":
		_position += 1
	while (
		_position < _source.length()
		and (_source[_position].is_valid_int() or _source[_position] in [".", "e", "E", "+", "-"])
	):
		_position += 1
	var token := _source.substr(start, _position - start)
	if not token.is_valid_float():
		return _failure("Invalid number %s." % token, start)
	return {
		"ok": true,
		"value": token.to_float() if "." in token or "e" in token.to_lower() else token.to_int(),
	}


func _parse_identifier() -> String:
	_skip_space()
	var start := _position
	while _position < _source.length():
		var character := _source[_position]
		if not (character == "_" or character.is_valid_identifier() or character.is_valid_int()):
			break
		_position += 1
	return _source.substr(start, _position - start)


func _peek() -> String:
	return "" if _position >= _source.length() else _source[_position]


func _consume(token: String) -> bool:
	_skip_space()
	if _source.substr(_position, token.length()) != token:
		return false
	_position += token.length()
	return true


func _skip_space() -> void:
	while _position < _source.length() and _source[_position] in [" ", "\t", "\r", "\n"]:
		_position += 1


func _failure(message: String, at: int) -> Dictionary:
	return {"ok": false, "error": message, "position": at}
