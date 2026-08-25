extends RefCounted

const COMMAND_PREFIX := "game."
const GAME_OBJECT_SCRIPT_ROOT := "res://src/components/"
const MAX_METHOD_ARGUMENTS := 8
const CONSOLE_HELP_METHODS := ["consoleHelp", "console_help"]
const API_DESCRIPTOR_METHOD := &"console_api"
const API_SCOPES := ["Game", "Match", "System"]

var _registered_commands: Dictionary
var _commands_by_node: Dictionary
var _help_by_node: Dictionary
var _registered_console_commands: Array[String]
var _api_entities: Dictionary
var _adapter_provider: Callable


func _configure(
	registered_commands: Dictionary,
	commands_by_node: Dictionary,
	help_by_node: Dictionary,
	registered_console_commands: Array[String],
	api_entities: Dictionary,
	adapter_provider: Callable,
) -> void:
	_registered_commands = registered_commands
	_commands_by_node = commands_by_node
	_help_by_node = help_by_node
	_registered_console_commands = registered_console_commands
	_api_entities = api_entities
	_adapter_provider = adapter_provider


func _scan_node(node: Node) -> void:
	if node != self and _is_game_object(node):
		_register_node_methods(node)
	for child in node.get_children():
		_scan_node(child)


func _is_game_object(node: Node) -> bool:
	if node is BGOGameObject:
		return true
	if node is GameSessionRepository:
		return true
	if node.has_meta("bgo_game_object") and bool(node.get_meta("bgo_game_object")):
		return true

	var script := node.get_script() as Script
	if script == null:
		return false
	return script.resource_path.begins_with(GAME_OBJECT_SCRIPT_ROOT)


func _register_node_methods(node: Node) -> void:
	var object_name := _object_name(node)
	var method_specs := _script_method_specs(node)
	if method_specs.is_empty():
		return

	var node_id := node.get_instance_id()
	var node_commands: Array[String] = []
	_commands_by_node[node_id] = node_commands
	var help_method := _find_console_help_method(method_specs)
	var help_data := _read_console_help(node, help_method)
	_register_curated_api(node, object_name, node_id, node_commands)
	if not help_method.is_empty():
		_help_by_node[node_id] = help_data
	for method_info in method_specs:
		var method_name := str(method_info.get("name", ""))
		if (
			method_name.is_empty()
			or method_name.begins_with("_")
			or method_name in CONSOLE_HELP_METHODS
			or method_name == API_DESCRIPTOR_METHOD
		):
			continue

		var args: Array = method_info.get("args", [])
		if args.size() > MAX_METHOD_ARGUMENTS:
			Console.print_warning(
				(
					"Skipping %s.%s: more than %d arguments."
					% [object_name, method_name, MAX_METHOD_ARGUMENTS]
				)
			)
			continue

		var default_args: Array = method_info.get("default_args", [])
		var required := maxi(args.size() - default_args.size(), 0)
		var command_name := _unique_command_name(object_name, method_name, node_id)
		var argument_names := _argument_names(args)
		var description := str(help_data.get(method_name, ""))
		if description.is_empty():
			description = "Auto-registered %s.%s" % [object_name, method_name]
		var callable: Callable = _adapter_provider.call(args.size()).bind(command_name)

		Console.add_command(command_name, callable, argument_names, required, description)
		_registered_console_commands.append(command_name)
		_registered_commands[command_name] = {
			"target": node,
			"method": method_name,
			"object_name": object_name,
			"args": args,
			"required": required,
			"description": description,
		}
		node_commands.append(command_name)

	if not help_method.is_empty():
		var help_command := _unique_command_name(object_name, "help", node_id)
		var help_callable: Callable = _adapter_provider.call(0).bind(help_command)
		Console.add_command(
			help_command, help_callable, 0, 0, "Shows consoleHelp() for %s." % object_name
		)
		_registered_console_commands.append(help_command)
		_registered_commands[help_command] = {
			"kind": "help",
			"target": node,
			"object_name": object_name,
			"args": [],
			"required": 0,
			"help_method": help_method,
		}
		node_commands.append(help_command)


func _register_curated_api(
	node: Node, fallback_name: String, node_id: int, node_commands: Array[String]
) -> void:
	if not node.has_method(API_DESCRIPTOR_METHOD):
		return
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

	var entity_class := str(descriptor.get("class", node.get_class()))
	var entity_record := {
		"target": node,
		"node_id": node_id,
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
	if api_name.is_empty() or call_name.is_empty() or not node.has_method(call_name):
		Console.print_warning("Skipping invalid curated method %s.%s." % [entity_name, api_name])
		return
	if not args_value is Array or args_value.size() > MAX_METHOD_ARGUMENTS:
		Console.print_warning(
			"Skipping invalid argument schema for %s.%s." % [entity_name, api_name]
		)
		return
	var args: Array = args_value
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
		"required": required,
		"returns": str(method.get("returns", "Variant")),
		"description": description,
	}
	_registered_commands[command_name] = registration
	(entity_record["methods"] as Dictionary)[api_name] = registration
	node_commands.append(command_name)


func _find_console_help_method(method_specs: Array) -> String:
	for method_info in method_specs:
		var method_name := str(method_info.get("name", ""))
		var args: Array = method_info.get("args", [])
		if method_name in CONSOLE_HELP_METHODS and args.is_empty():
			return method_name
	return ""


func _read_console_help(node: Node, method_name: String) -> Dictionary:
	if method_name.is_empty():
		return {}
	var value: Variant = node.call(StringName(method_name))
	if value is Dictionary:
		var help: Dictionary = {"_summary": str(value.get("_summary", value.get("summary", "")))}
		for key in value.keys():
			if str(key) not in ["_summary", "summary"]:
				help[str(key)] = str(value[key])
		return help
	if value is String:
		return {"_summary": value}
	return {}


func _script_method_specs(node: Node) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var script := node.get_script() as Script
	while script != null:
		for method_info in script.get_script_method_list():
			var method_name := str(method_info.get("name", ""))
			if method_name.is_empty() or seen.has(method_name):
				continue
			seen[method_name] = true
			result.append(method_info)
		script = script.get_base_script()
	return result


func _object_name(node: Node) -> String:
	var candidate := ""
	if node is BGOGameObject:
		candidate = str((node as BGOGameObject).entity_id)
	if candidate.is_empty() and node.has_meta("entity_id"):
		candidate = str(node.get_meta("entity_id"))
	if candidate.is_empty():
		candidate = node.name
	return _slug(candidate)


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


func _unique_command_name(object_name: String, method_name: String, node_id: int) -> String:
	var base := "%s%s.%s" % [COMMAND_PREFIX, object_name, method_name]
	if not _registered_commands.has(base):
		return base
	return "%s_%d" % [base, node_id]


func _argument_names(args: Array) -> Array[String]:
	var result: Array[String] = []
	for index in range(args.size()):
		var argument: Dictionary = args[index]
		var name := str(argument.get("name", "arg_%d" % (index + 1)))
		result.append(name if not name.is_empty() else "arg_%d" % (index + 1))
	return result
