class_name BgoConsoleSyntax
extends RefCounted

const ENTITY_COLOR := "#61afef"
const METHOD_COLOR := "#e5c07b"
const TYPE_COLOR := "#c678dd"
const STRING_COLOR := "#98c379"
const NUMBER_COLOR := "#d19a66"
const BOOLEAN_COLOR := "#56b6c2"
const CONSTANT_COLOR := "#c678dd"
const PUNCTUATION_COLOR := "#7f91a5"


static func highlight(source: String) -> String:
	var tokens := _tokens(source)
	if tokens.is_empty():
		return muted("Game.Player.create()  ·  Match.entity.getName()  ·  System.api.getEntities()")
	var result: Array[String] = []
	result.append(_highlight_command(tokens[0]))
	for index in range(1, tokens.size()):
		result.append(_highlight_literal(tokens[index]))
	return " ".join(result)


static func signature(
	entity_name: String, method_name: String, args: Array, return_type: String = "Variant"
) -> String:
	var formatted_args: Array[String] = []
	for argument_variant in args:
		var argument: Dictionary = argument_variant
		var argument_name := str(argument.get("name", "value"))
		var argument_type := _type_label(argument.get("type", TYPE_STRING))
		formatted_args.append("%s: %s" % [literal_name(argument_name), type_name(argument_type)])
	return (
		"%s%s%s%s%s %s %s"
		% [
			entity(entity_name),
			punctuation("."),
			method(method_name),
			punctuation("("),
			", ".join(formatted_args),
			punctuation(") ->"),
			type_name(return_type),
		]
	)


static func entity(value: String) -> String:
	return _color(ENTITY_COLOR, value)


static func method(value: String) -> String:
	return _color(METHOD_COLOR, value)


static func type_name(value: String) -> String:
	return _color(TYPE_COLOR, value)


static func literal_name(value: String) -> String:
	return _color(STRING_COLOR, value)


static func muted(value: String) -> String:
	return _color(PUNCTUATION_COLOR, value)


static func punctuation(value: String) -> String:
	return _color(PUNCTUATION_COLOR, value)


static func _highlight_command(command: String) -> String:
	var separator := command.rfind(".")
	if separator <= 0 or separator == command.length() - 1:
		return entity(command)
	return (
		"%s%s%s"
		% [
			entity(command.left(separator)),
			punctuation("."),
			method(command.substr(separator + 1)),
		]
	)


static func _highlight_literal(value: String) -> String:
	var lower := value.to_lower()
	if (
		(value.begins_with('"') and value.ends_with('"'))
		or (value.begins_with("'") and value.ends_with("'"))
	):
		return _color(STRING_COLOR, value)
	if lower in ["true", "false", "null"]:
		return _color(BOOLEAN_COLOR, value)
	if value.is_valid_int() or value.is_valid_float():
		return _color(NUMBER_COLOR, value)
	if value.begins_with("G."):
		return _color(CONSTANT_COLOR, value)
	return literal_name(value)


static func _tokens(source: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var quote := ""
	for character in source:
		if not quote.is_empty():
			current += character
			if character == quote:
				quote = ""
			continue
		if character in ['"', "'"]:
			quote = character
			current += character
		elif character == " " or character == "\t":
			if not current.is_empty():
				result.append(current)
				current = ""
		else:
			current += character
	if not current.is_empty():
		result.append(current)
	return result


static func _type_label(value: Variant) -> String:
	if value is int:
		return type_string(value)
	return str(value)


static func _color(color: String, value: String) -> String:
	return "[color=%s]%s[/color]" % [color, _escape(value)]


static func _escape(value: String) -> String:
	return value.replace("[", "[​").replace("]", "​]")
