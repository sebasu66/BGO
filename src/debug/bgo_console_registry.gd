extends RefCounted

const MAX_METHOD_ARGUMENTS := 8
const API_DESCRIPTOR_METHOD := &"console_api"
const API_SCOPES := ["Game", "Match", "System"]

var _registered_commands: Dictionary
var _commands_by_node: Dictionary
var _registered_console_commands: Array[String]
var _api_entities: Dictionary
var _adapter_provider: Callable


func _configure(
	registered_commands: Dictionary,
	commands_by_node: Dictionary,
	registered_console_commands: Array[String],
	api_entities: Dictionary,
	adapter_provider: Callable,
) -> void:
	_registered_commands = registered_commands
	_commands_by_node = commands_by_node
	_registered_console_commands = registered_console_commands
	_api_entities = api_entities
	_adapter_provider = adapter_provider


func _scan_node(node: Node) -> void:
	if node.has_method(API_DESCRIPTOR_METHOD):
		_register_curated_api(node)
	for child in node.get_children():
		_scan_node(child)


func _register_curated_api(node: Node) -> void:
	var fallback_name := _slug(node.name)
	var descriptor_value: Variant = node.call(API_DESCRIPTOR_METHOD)
	if not descriptor_value is Dictionary:
		Console.print_warning("Ignoring invalid console_api descriptor on %s." % fallback_name)
		return
	var descriptor: Dictionary = descriptor_value
	var entity_name := _api_entity_path(
		str(descriptor.get("scope", "Match")), str(descriptor.get("entity", fallback_name))
	)
	var methods_value: Variant = descriptor.get("methods", {})
	if entity_name.is_empty() or not methods_value is Dictionary:
		Console.print_warning("Ignoring incomplete console_api descriptor on %s." % fallback_name)
		return
	if _api_entities.has(entity_name):
		Console.print_warning("Ignoring duplicate curated API entity: %s." % entity_name)
		return

	var node_id := node.get_instance_id()
	var node_commands: Array[String] = []
	_commands_by_node[node_id] = node_commands
	var entity_class := str(descriptor.get("class", node.get_class()))
	var entity_record := {
		"target": node,
		"node_id": node_id,
		"component_id": str(descriptor.get("component_id", "")),
		"class": entity_class,
		"description": str(descriptor.get("description", "")),
		"methods": {},
	}
	_api_entities[entity_name] = entity_record
	var methods: Dictionary = methods_value
	var api_names := methods.keys()
	api_names.sort()
	for api_name_variant in api_names:
		_register_curated_method(
			node,
			entity_name,
			entity_class,
			str(api_name_variant),
			methods[api_name_variant],
			entity_record,
			node_commands,
		)


func _register_curated_method(
	node: Node,
	entity_name: String,
	entity_class: String,
	api_name: String,
	method_value: Variant,
	entity_record: Dictionary,
	node_commands: Array[String],
) -> void:
	if not method_value is Dictionary:
		return
	var method: Dictionary = method_value
	var call_name := str(method.get("call", ""))
	var args_value: Variant = method.get("args", [])
	if not _is_safe_api_name(api_name) or call_name.is_empty() or not node.has_method(call_name):
		Console.print_warning("Skipping invalid curated method %s.%s." % [entity_name, api_name])
		return
	if not args_value is Array or args_value.size() > MAX_METHOD_ARGUMENTS:
		Console.print_warning(
			"Skipping invalid argument schema for %s.%s." % [entity_name, api_name]
		)
		return
	var args: Array = args_value
	var bound_args_value: Variant = method.get("bound_args", [])
	if not bound_args_value is Array:
		Console.print_warning(
			"Skipping invalid bound arguments for %s.%s." % [entity_name, api_name]
		)
		return
	var bound_args: Array = bound_args_value
	var required := int(method.get("required", args.size()))
	if required < 0 or required > args.size():
		Console.print_warning("Skipping invalid arity for %s.%s." % [entity_name, api_name])
		return
	var command_name := "%s.%s" % [entity_name, api_name]
	if _registered_commands.has(command_name):
		Console.print_warning("Skipping duplicate curated method: %s." % command_name)
		return

	var callable: Callable = _adapter_provider.call(args.size()).bind(command_name)
	var description := str(method.get("description", ""))
	Console.add_command(command_name, callable, _argument_names(args), required, description)
	_registered_console_commands.append(command_name)
	var registration := {
		"kind": "curated",
		"target": node,
		"method": call_name,
		"api_name": api_name,
		"object_name": entity_name,
		"class_name": entity_class,
		"args": args,
		"bound_args": bound_args,
		"required": required,
		"returns": str(method.get("returns", "Variant")),
		"description": description,
	}
	_registered_commands[command_name] = registration
	(entity_record["methods"] as Dictionary)[api_name] = registration
	node_commands.append(command_name)


func _is_safe_api_name(method_name: String) -> bool:
	return (
		not method_name.is_empty()
		and not method_name.begins_with("_")
		and "@" not in method_name
		and method_name.is_valid_identifier()
	)


func _slug(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", "/", "\\", ":", "-", "@", "."]:
		result = result.replace(character, "_")
	while "__" in result:
		result = result.replace("__", "_")
	return result.strip_edges().trim_prefix("_").trim_suffix("_")


func _api_entity_path(scope: String, entity_name: String) -> String:
	var canonical_scope := ""
	for allowed_scope in API_SCOPES:
		if allowed_scope.to_lower() == scope.to_lower():
			canonical_scope = allowed_scope
			break
	if canonical_scope.is_empty():
		return ""
	var normalized_entity := _slug(entity_name)
	return "" if normalized_entity.is_empty() else "%s.%s" % [canonical_scope, normalized_entity]


func _canonical_api_entity(value: String) -> String:
	var separator := value.find(".")
	if separator <= 0 or separator == value.length() - 1:
		return ""
	return _api_entity_path(value.left(separator), value.substr(separator + 1))


func _argument_names(args: Array) -> Array[String]:
	var result: Array[String] = []
	for index in range(args.size()):
		var argument: Dictionary = args[index]
		var name := str(argument.get("name", "arg_%d" % (index + 1)))
		result.append(name if not name.is_empty() else "arg_%d" % (index + 1))
	return result
