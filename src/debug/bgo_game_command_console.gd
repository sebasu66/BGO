extends Node
# gdlint: disable=max-returns,max-file-lines

## DEV-only bridge between BGO game objects and jitspoe/console.
##
## The bridge discovers public methods declared by BGOGameObject instances and
## component scripts under src/components. It never exposes inherited Godot
## engine methods or private methods beginning with '_'. Gameplay authority
## remains in the domain command/state layer; this is a developer convenience.

const COMMAND_PREFIX := "game."
const GAME_OBJECT_SCRIPT_ROOT := "res://src/components/"
const MAX_METHOD_ARGUMENTS := 8
const CONTROL_COMMANDS := ["game.commands", "game.objects", "game.refresh", "game.call"]
const CONSOLE_HELP_METHODS := ["consoleHelp", "console_help"]
const API_DESCRIPTOR_METHOD := &"console_api"
const API_CONTROL_COMMANDS := [
	"System.api.getEntities",
	"System.api.getMethods",
	"System.api.describe",
	"System.constants.getAll",
	"System.constants.get",
	"System.builders.getTypes",
	"System.builders.describe",
]
const API_SCOPES := ["Game", "Match", "System"]

var _initialized := false
var _refresh_queued := false
var _registered_commands: Dictionary = {}
var _commands_by_node: Dictionary = {}
var _help_by_node: Dictionary = {}
var _registered_console_commands: Array[String] = []
var _api_entities: Dictionary = {}
var _builder_registry := BgoBuilderRegistry.new()
var _fluent_parser := BgoFluentExpressionParser.new(_builder_registry)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build() or Engine.is_editor_hint():
		return
	call_deferred("_initialize")


func _initialize() -> void:
	if get_node_or_null("/root/Console") == null:
		push_warning("BGO game command console disabled: Console autoload is missing.")
		return
	if not BgoConsoleIdeTheme.apply_to(Console):
		push_warning("BGO game command console theme could not be applied.")
	_fluent_parser.set_namespace_invoker(_invoke_python_namespace)
	Console.set_expression_handler(_execute_fluent_expression)
	Console.set_autocomplete_provider(_complete_fluent_expression)
	_initialized = true
	get_tree().node_added.connect(_on_tree_node_added)
	get_tree().node_removed.connect(_on_tree_node_removed)
	_register_control_commands()
	_refresh_registry()


func _register_control_commands() -> void:
	Console.add_command(
		"game.commands",
		_list_commands,
		0,
		0,
		"Lists auto-registered public commands for live game objects."
	)
	Console.add_command(
		"game.objects",
		_list_objects,
		0,
		0,
		"Lists live objects that provide auto-registered commands."
	)
	Console.add_command(
		"game.refresh", _refresh_registry, 0, 0, "Rebuilds the live game-object command registry."
	)
	Console.add_command(
		"game.call",
		_call_from_console,
		["object", "method", "arguments"],
		2,
		"Calls game.<object>.<method>; quote arguments as one string."
	)
	Console.add_command(
		"System.api.getEntities", _list_api_entities, 0, 0, "Lists curated API entities."
	)
	Console.add_command(
		"System.api.getMethods",
		_list_api_methods,
		["entity"],
		1,
		"Lists curated methods for one entity."
	)
	Console.add_command(
		"System.api.describe",
		_describe_api,
		["entity", "method"],
		1,
		"Describes a curated entity or one of its methods."
	)
	Console.add_command(
		"System.constants.getAll", _list_constants, 0, 0, "Lists public BGO constants."
	)
	Console.add_command(
		"System.constants.get",
		_get_constant,
		["constant"],
		1,
		"Resolves one public BGO constant to its stable value."
	)
	Console.add_command(
		"System.builders.getTypes", _list_builder_types, 0, 0, "Lists fluent definition builders."
	)
	Console.add_command(
		"System.builders.describe",
		_describe_builder,
		["type"],
		1,
		"Lists the curated methods for one fluent builder."
	)
	_registered_console_commands.append_array(CONTROL_COMMANDS + API_CONTROL_COMMANDS)


func _on_tree_node_added(_node: Node) -> void:
	_queue_refresh()


func _on_tree_node_removed(_node: Node) -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	if not _initialized or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_registry")


func _refresh_registry() -> void:
	_refresh_queued = false
	if not _initialized:
		return

	for command_name in _registered_console_commands:
		if Console.console_commands.has(command_name):
			Console.remove_command(command_name)
	_registered_console_commands.clear()
	_registered_commands.clear()
	_commands_by_node.clear()
	_help_by_node.clear()
	_api_entities.clear()
	_register_control_commands()

	var root := get_tree().root
	_scan_node(root)

	var object_names := PackedStringArray()
	for registration in _registered_commands.values():
		var object_name := str(registration.get("object_name", ""))
		if not object_name.is_empty() and object_name not in object_names:
			object_names.append(object_name)
	Console.add_command_autocomplete_list("game.call", object_names)
	Console.add_command_autocomplete_list(
		"System.api.getMethods", PackedStringArray(_api_entities.keys())
	)
	Console.add_command_autocomplete_list(
		"System.api.describe", PackedStringArray(_api_entities.keys())
	)
	Console.add_command_autocomplete_list("System.constants.get", BgoApiConstants.names())
	Console.add_command_autocomplete_list("System.builders.describe", _builder_registry.get_types())


func _execute_fluent_expression(source: String) -> bool:
	if not _fluent_parser.recognizes(source):
		return false
	var result := _fluent_parser.execute(source)
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
	var result := _fluent_parser.complete(source)
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
		var converted := _convert_argument(str(arguments[index]), argument_specs[index])
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
	match path:
		"System.api.getEntities":
			if not arguments.is_empty():
				return _python_arity_error(path, 0, arguments.size())
			return {"ok": true, "value": _public_api_entities()}
		"System.api.getMethods":
			if arguments.size() != 1:
				return _python_arity_error(path, 1, arguments.size())
			return _python_get_methods(str(arguments[0]))
		"System.api.describe":
			if arguments.size() not in [1, 2]:
				return {"ok": false, "error": "%s expects one or two arguments." % path}
			return _python_describe(
				str(arguments[0]), str(arguments[1]) if arguments.size() == 2 else ""
			)
		"System.builders.getTypes":
			if not arguments.is_empty():
				return _python_arity_error(path, 0, arguments.size())
			return {"ok": true, "value": Array(_builder_registry.get_public_types())}
		"System.builders.describe":
			if arguments.size() != 1:
				return _python_arity_error(path, 1, arguments.size())
			var type_name := _internal_builder_type(str(arguments[0]))
			if type_name.is_empty():
				return {"ok": false, "error": "Unknown Game builder: %s" % arguments[0]}
			return {"ok": true, "value": _builder_registry.describe(type_name)}
		"System.constants.getAll":
			if not arguments.is_empty():
				return _python_arity_error(path, 0, arguments.size())
			return {"ok": true, "value": _system_constants()}
		"System.constants.get":
			if arguments.size() != 1:
				return _python_arity_error(path, 1, arguments.size())
			var resolved := _resolve_system_constant(str(arguments[0]))
			return resolved
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
	var normalized := _canonical_api_entity(entity_name)
	if not _api_entities.has(normalized):
		return {"ok": false, "error": "Unknown public API entity: %s" % entity_name}
	return {
		"ok": true, "value": (_api_entities[normalized].get("methods", {}) as Dictionary).keys()
	}


func _python_describe(entity_name: String, method_name: String) -> Dictionary:
	var builder_type := _internal_builder_type(entity_name)
	if not builder_type.is_empty():
		var descriptor := _builder_registry.describe(builder_type)
		if method_name.is_empty():
			return {"ok": true, "value": descriptor}
		if method_name not in _builder_public_methods(builder_type):
			return {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
		return {"ok": true, "value": {"entity": entity_name, "method": method_name}}
	var system_methods := _system_methods(entity_name)
	if not system_methods.is_empty():
		if not method_name.is_empty() and method_name not in system_methods:
			return {"ok": false, "error": "Unknown method %s.%s" % [entity_name, method_name]}
		return {"ok": true, "value": {"entity": entity_name, "methods": system_methods}}
	var normalized := _canonical_api_entity(entity_name)
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
	var result := {}
	for constant_name in BgoApiConstants.names():
		var short_name := str(constant_name).trim_prefix("G.")
		if "." not in short_name:
			result["System.constants.%s" % short_name] = (
				BgoApiConstants.get_value(constant_name).get("value")
			)
	return result


func _resolve_system_constant(name: String) -> Dictionary:
	var normalized := name.trim_prefix("System.constants.").trim_prefix("G.")
	var resolved := BgoApiConstants.get_value("G.%s" % normalized)
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
	var descriptor := _builder_registry.describe(internal_type)
	for factory in descriptor.get("factories", []):
		Console.print_line(str(factory))
	for method_name in descriptor.get("methods", []):
		Console.print_line("  .%s" % BgoConsoleSyntax.method(str(method_name)))


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
		var callable := _adapter_for_argument_count(args.size()).bind(command_name)

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
		var help_callable := _adapter_for_argument_count(0).bind(help_command)
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
	var scope := str(descriptor.get("scope", "Match"))
	var entity_name := _api_entity_path(scope, str(descriptor.get("entity", fallback_name)))
	var entity_class := str(descriptor.get("class", node.get_class()))
	var methods_value: Variant = descriptor.get("methods", {})
	if entity_name.is_empty() or not methods_value is Dictionary:
		Console.print_warning("Ignoring incomplete console_api descriptor on %s." % fallback_name)
		return
	if _api_entities.has(entity_name):
		Console.print_warning("Ignoring duplicate curated API entity: %s." % entity_name)
		return

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
		var api_name := str(api_name_variant)
		var method_value: Variant = methods[api_name_variant]
		if not method_value is Dictionary:
			continue
		var method: Dictionary = method_value
		var call_name := str(method.get("call", ""))
		var args_value: Variant = method.get("args", [])
		if api_name.is_empty() or call_name.is_empty() or not node.has_method(call_name):
			Console.print_warning(
				"Skipping invalid curated method %s.%s." % [entity_name, api_name]
			)
			continue
		if not args_value is Array or args_value.size() > MAX_METHOD_ARGUMENTS:
			Console.print_warning(
				"Skipping invalid argument schema for %s.%s." % [entity_name, api_name]
			)
			continue
		var args: Array = args_value
		var required := int(method.get("required", args.size()))
		if required < 0 or required > args.size():
			Console.print_warning("Skipping invalid arity for %s.%s." % [entity_name, api_name])
			continue
		var command_name := "%s.%s" % [entity_name, api_name]
		if _registered_commands.has(command_name):
			Console.print_warning("Skipping duplicate curated method: %s." % command_name)
			continue
		var callable := _adapter_for_argument_count(args.size()).bind(command_name)
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


func _adapter_for_argument_count(argument_count: int) -> Callable:
	match argument_count:
		0:
			return Callable(self, "_invoke_0")
		1:
			return Callable(self, "_invoke_1")
		2:
			return Callable(self, "_invoke_2")
		3:
			return Callable(self, "_invoke_3")
		4:
			return Callable(self, "_invoke_4")
		5:
			return Callable(self, "_invoke_5")
		6:
			return Callable(self, "_invoke_6")
		7:
			return Callable(self, "_invoke_7")
		8:
			return Callable(self, "_invoke_8")
	return Callable()


func _invoke_0(command_name: String) -> void:
	_invoke_registered(command_name, [])


func _invoke_1(a1: String, command_name: String) -> void:
	_invoke_registered(command_name, [a1])


func _invoke_2(a1: String, a2: String, command_name: String) -> void:
	_invoke_registered(command_name, [a1, a2])


func _invoke_3(a1: String, a2: String, a3: String, command_name: String) -> void:
	_invoke_registered(command_name, [a1, a2, a3])


func _invoke_4(a1: String, a2: String, a3: String, a4: String, command_name: String) -> void:
	_invoke_registered(command_name, [a1, a2, a3, a4])


func _invoke_5(
	a1: String, a2: String, a3: String, a4: String, a5: String, command_name: String
) -> void:
	_invoke_registered(command_name, [a1, a2, a3, a4, a5])


func _invoke_6(
	a1: String, a2: String, a3: String, a4: String, a5: String, a6: String, command_name: String
) -> void:
	_invoke_registered(command_name, [a1, a2, a3, a4, a5, a6])


func _invoke_7(
	a1: String,
	a2: String,
	a3: String,
	a4: String,
	a5: String,
	a6: String,
	a7: String,
	command_name: String
) -> void:
	_invoke_registered(command_name, [a1, a2, a3, a4, a5, a6, a7])


func _invoke_8(
	a1: String,
	a2: String,
	a3: String,
	a4: String,
	a5: String,
	a6: String,
	a7: String,
	a8: String,
	command_name: String
) -> void:
	_invoke_registered(command_name, [a1, a2, a3, a4, a5, a6, a7, a8])


func _invoke_registered(command_name: String, raw_args: Array) -> void:
	if not _registered_commands.has(command_name):
		Console.print_error("Unknown game command: %s" % command_name)
		return
	var registration: Dictionary = _registered_commands[command_name]
	var target: Object = registration.get("target")
	if not is_instance_valid(target):
		Console.print_error("Target for %s is no longer available." % command_name)
		_queue_refresh()
		return
	if str(registration.get("kind", "method")) == "help":
		_print_object_help(registration)
		return

	var argument_specs: Array = registration.get("args", [])
	var required := int(registration.get("required", 0))
	var typed_args: Array = []
	for index in range(argument_specs.size()):
		var raw := str(raw_args[index]) if index < raw_args.size() else ""
		if raw.is_empty() and index >= required:
			break
		var converted := _convert_argument(raw, argument_specs[index])
		if not bool(converted.get("ok", false)):
			Console.print_error(
				(
					"Invalid argument %d for %s: %s"
					% [index + 1, command_name, converted.get("error", "invalid value")]
				)
			)
			return
		typed_args.append(converted.get("value"))

	var result: Variant = target.callv(StringName(registration.get("method", "")), typed_args)
	if result != null:
		if str(registration.get("kind", "method")) == "curated":
			Console.print_line(
				(
					"%s %s %s"
					% [
						BgoConsoleSyntax.highlight(command_name),
						BgoConsoleSyntax.punctuation("=>"),
						_format_value(result)
					]
				)
			)
		else:
			Console.print_line("%s => %s" % [command_name, str(result)])


func _print_object_help(registration: Dictionary) -> void:
	var target: Object = registration.get("target")
	var node_id := target.get_instance_id()
	var object_name := str(registration.get("object_name", "object"))
	var help: Dictionary = _help_by_node.get(node_id, {})
	Console.print_line("Help for %s:" % object_name)
	var summary := str(help.get("_summary", ""))
	if not summary.is_empty():
		Console.print_line("  %s" % summary)
	var command_names: Array = _commands_by_node.get(node_id, [])
	for command_name in command_names:
		var command: Dictionary = _registered_commands.get(command_name, {})
		if str(command.get("kind", "method")) == "help":
			continue
		var method_name := str(command.get("method", ""))
		var description := str(help.get(method_name, ""))
		if description.is_empty():
			description = str(command.get("description", ""))
		Console.print_line(
			"  %s%s — %s" % [command_name, _format_arguments(command.get("args", [])), description]
		)


func _convert_argument(raw: String, argument: Dictionary) -> Dictionary:
	var type := int(argument.get("type", TYPE_STRING))
	var resolved := BgoApiConstants.get_value(raw) if raw.begins_with("G.") else {"ok": false}
	if bool(resolved.get("ok", false)):
		var constant_value: Variant = resolved.get("value")
		if type == TYPE_STRING:
			return {"ok": true, "value": str(constant_value)}
		if typeof(constant_value) == type:
			return {"ok": true, "value": constant_value}
	match type:
		TYPE_STRING:
			return {"ok": true, "value": raw}
		TYPE_STRING_NAME:
			return {"ok": true, "value": StringName(raw)}
		TYPE_BOOL:
			var lower := raw.to_lower()
			if lower in ["1", "true", "yes", "on"]:
				return {"ok": true, "value": true}
			if lower in ["0", "false", "no", "off"]:
				return {"ok": true, "value": false}
			return {"ok": false, "error": "expected true/false or on/off"}
		TYPE_INT:
			if raw.is_valid_int():
				return {"ok": true, "value": raw.to_int()}
			return {"ok": false, "error": "expected integer"}
		TYPE_FLOAT:
			if raw.is_valid_float():
				return {"ok": true, "value": raw.to_float()}
			return {"ok": false, "error": "expected number"}
		TYPE_NODE_PATH:
			return {"ok": true, "value": NodePath(raw)}
		TYPE_ARRAY, TYPE_DICTIONARY:
			var parsed_json: Variant = JSON.parse_string(raw)
			if (
				(type == TYPE_ARRAY and parsed_json is Array)
				or (type == TYPE_DICTIONARY and parsed_json is Dictionary)
			):
				return {"ok": true, "value": parsed_json}
			var parsed_literal: Variant = str_to_var(raw)
			if typeof(parsed_literal) == type:
				return {"ok": true, "value": parsed_literal}
			return {"ok": false, "error": "expected %s literal" % type_string(type)}
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I:
			var parsed: Variant = str_to_var(raw)
			if typeof(parsed) == type:
				return {"ok": true, "value": parsed}
			return {"ok": false, "error": "expected %s(...) literal" % type_string(type)}
		_:
			return {"ok": false, "error": "unsupported argument type %s" % type_string(type)}


func _list_commands() -> void:
	var names := _registered_commands.keys()
	names.sort()
	Console.print_line("Registered game commands (%d):" % names.size())
	for name in names:
		var registration: Dictionary = _registered_commands[name]
		var args: Array = registration.get("args", [])
		Console.print_line("  %s %s" % [name, _format_arguments(args)])


func _list_objects() -> void:
	var nodes := _commands_by_node.keys()
	nodes.sort()
	Console.print_line("Live game command hosts (%d):" % nodes.size())
	for node_id in nodes:
		var command_names: Array = _commands_by_node[node_id]
		if command_names.is_empty():
			continue
		var registration: Dictionary = _registered_commands[command_names[0]]
		Console.print_line(
			"  %s -> %s" % [registration.get("object_name", ""), command_names.size()]
		)


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
	var normalized := _canonical_api_entity(entity_name)
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
	var normalized := _canonical_api_entity(entity_name)
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


func _format_arguments(args: Array) -> String:
	var names := _argument_names(args)
	return "" if names.is_empty() else " " + " ".join(names)


func _call_from_console(object_name: String, method_name: String, arguments: String = "") -> void:
	var command_name := "%s%s.%s" % [COMMAND_PREFIX, _slug(object_name), method_name]
	if not _registered_commands.has(command_name):
		Console.print_error("Unknown game command: %s" % command_name)
		return
	var raw_args := (
		Console.parse_line_input(arguments) if not arguments.is_empty() else PackedStringArray()
	)
	_invoke_registered(command_name, Array(raw_args))
