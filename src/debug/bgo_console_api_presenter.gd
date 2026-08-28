extends RefCounted

var _api_entities: Dictionary
var _builder_registry
var _registry


func _configure(api_entities: Dictionary, builder_registry, registry) -> void:
	_api_entities = api_entities
	_builder_registry = builder_registry
	_registry = registry


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


func _audit_api(records: Array[Dictionary]) -> void:
	Console.print_line(JSON.stringify(records, "  "))


func _list_api_methods(entity_name: String) -> void:
	var normalized := _normalized_entity(entity_name)
	if normalized.is_empty():
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
	var normalized := _normalized_entity(entity_name)
	if normalized.is_empty():
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
	var canonical_method := _case_insensitive_key(methods, method_name)
	if canonical_method.is_empty():
		Console.print_error("Unknown curated API method: %s.%s" % [normalized, method_name])
		return
	_print_api_method(methods[canonical_method])


func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return BgoConsoleSyntax.literal_name('\"%s\"' % str(value))
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


func _normalized_entity(entity_name: String) -> String:
	return _case_insensitive_key(_api_entities, str(_registry._canonical_api_entity(entity_name)))


func _internal_builder_type(public_name: String) -> String:
	if public_name.to_lower() == "game":
		return "Game"
	if not public_name.to_lower().begins_with("game."):
		return ""
	return _case_insensitive_array_value(
		Array(_builder_registry.get_types()), public_name.substr("Game.".length())
	)


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
