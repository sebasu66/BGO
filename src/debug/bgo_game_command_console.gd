extends Node

## DEV-only facade between BGO game objects and jitspoe/console.
##
## Discovery, API projection, invocation/conversion and presentation details are
## delegated to focused debug services. Gameplay authority remains in the
## domain command/state layer; this is a developer convenience.

const CONTROL_COMMANDS := ["game.commands", "game.objects", "game.refresh", "game.call"]
const API_CONTROL_COMMANDS := [
	"System.api.getEntities",
	"System.api.getMethods",
	"System.api.describe",
	"System.constants.getAll",
	"System.constants.get",
	"System.builders.getTypes",
	"System.builders.describe",
]
const REGISTRY_SCRIPT := preload("res://src/debug/bgo_console_registry.gd")
const API_SERVICE_SCRIPT := preload("res://src/debug/bgo_console_api_service.gd")
const INVOCATION_SERVICE_SCRIPT := preload("res://src/debug/bgo_console_invocation_service.gd")
const INVOKE_METHOD_NAMES := [
	"_invoke_0",
	"_invoke_1",
	"_invoke_2",
	"_invoke_3",
	"_invoke_4",
	"_invoke_5",
	"_invoke_6",
	"_invoke_7",
	"_invoke_8",
]

var _initialized := false
var _refresh_queued := false
var _registered_commands: Dictionary = {}
var _commands_by_node: Dictionary = {}
var _help_by_node: Dictionary = {}
var _registered_console_commands: Array[String] = []
var _api_entities: Dictionary = {}
var _builder_registry := BgoBuilderRegistry.new()
var _fluent_parser := BgoFluentExpressionParser.new(_builder_registry)
var _registry = REGISTRY_SCRIPT.new()
var _api_service = API_SERVICE_SCRIPT.new()
var _invocation = INVOCATION_SERVICE_SCRIPT.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize")


func _initialize() -> void:
	if get_node_or_null("/root/Console") == null:
		push_warning("BGO game command console disabled: Console autoload is missing.")
		return
	if not BgoConsoleIdeTheme.apply_to(Console):
		push_warning("BGO game command console theme could not be applied.")
	(
		_registry
		. _configure(
			_registered_commands,
			_commands_by_node,
			_help_by_node,
			_registered_console_commands,
			_api_entities,
			Callable(self, "_adapter_for_argument_count"),
		)
	)
	(
		_invocation
		. _configure(
			_registered_commands,
			_commands_by_node,
			_help_by_node,
			_registry,
			Callable(self, "_queue_refresh"),
			Callable(self, "_format_value"),
			Callable(self, "_record_console_invocation"),
		)
	)
	(
		_api_service
		. _configure(
			_registered_commands,
			_api_entities,
			_builder_registry,
			_fluent_parser,
			_registry,
			_invocation,
		)
	)
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

	_registry._scan_node(get_tree().root)

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
	return _api_service._execute_fluent_expression(source)


func _complete_fluent_expression(source: String) -> Array[String]:
	return _api_service._complete_fluent_expression(source)


func _invoke_python_namespace(path: String, arguments: Array) -> Dictionary:
	_record_console_invocation(path, arguments)
	return _api_service._invoke_python_namespace(path, arguments)


func _list_builder_types() -> void:
	_api_service._list_builder_types()


func _describe_builder(type_name: String) -> void:
	_api_service._describe_builder(type_name)


func _list_api_entities() -> void:
	_api_service._list_api_entities()


func _list_api_methods(entity_name: String) -> void:
	_api_service._list_api_methods(entity_name)


func _describe_api(entity_name: String, method_name: String = "") -> void:
	_api_service._describe_api(entity_name, method_name)


func _format_value(value: Variant) -> String:
	return _api_service._format_value(value)


func _record_console_invocation(method_name: String, arguments: Array) -> void:
	var activity_log := get_node_or_null("/root/BgoActivityLog")
	if activity_log != null:
		activity_log.record_invocation(method_name, "console", {"arguments": arguments})


func _list_constants() -> void:
	_api_service._list_constants()


func _get_constant(constant_name: String) -> void:
	_api_service._get_constant(constant_name)


func _list_commands() -> void:
	_invocation._list_commands()


func _list_objects() -> void:
	_invocation._list_objects()


func _call_from_console(object_name: String, method_name: String, arguments: String = "") -> void:
	_invocation._call_from_console(object_name, method_name, arguments)


func _adapter_for_argument_count(argument_count: int) -> Callable:
	if argument_count < 0 or argument_count >= INVOKE_METHOD_NAMES.size():
		return Callable()
	return Callable(self, INVOKE_METHOD_NAMES[argument_count])


func _invoke_0(command_name: String) -> void:
	_invocation._invoke_registered(command_name, [])


func _invoke_1(a1: String, command_name: String) -> void:
	_invocation._invoke_registered(command_name, [a1])


func _invoke_2(a1: String, a2: String, command_name: String) -> void:
	_invocation._invoke_registered(command_name, [a1, a2])


func _invoke_3(a1: String, a2: String, a3: String, command_name: String) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3])


func _invoke_4(a1: String, a2: String, a3: String, a4: String, command_name: String) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3, a4])


func _invoke_5(
	a1: String, a2: String, a3: String, a4: String, a5: String, command_name: String
) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3, a4, a5])


func _invoke_6(
	a1: String, a2: String, a3: String, a4: String, a5: String, a6: String, command_name: String
) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3, a4, a5, a6])


func _invoke_7(
	a1: String,
	a2: String,
	a3: String,
	a4: String,
	a5: String,
	a6: String,
	a7: String,
	command_name: String,
) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3, a4, a5, a6, a7])


func _invoke_8(
	a1: String,
	a2: String,
	a3: String,
	a4: String,
	a5: String,
	a6: String,
	a7: String,
	a8: String,
	command_name: String,
) -> void:
	_invocation._invoke_registered(command_name, [a1, a2, a3, a4, a5, a6, a7, a8])
