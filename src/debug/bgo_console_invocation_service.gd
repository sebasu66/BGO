extends RefCounted

const COMMAND_PREFIX := "game."
const ARGUMENT_CONVERTER := preload("res://src/debug/bgo_console_argument_converter.gd")

var _registered_commands: Dictionary
var _commands_by_node: Dictionary
var _help_by_node: Dictionary
var _registry
var _queue_refresh_callback: Callable
var _format_value_callback: Callable
var _activity_callback: Callable


func _configure(
	registered_commands: Dictionary,
	commands_by_node: Dictionary,
	help_by_node: Dictionary,
	registry,
	queue_refresh_callback: Callable,
	format_value_callback: Callable,
	activity_callback: Callable = Callable(),
) -> void:
	_registered_commands = registered_commands
	_commands_by_node = commands_by_node
	_help_by_node = help_by_node
	_registry = registry
	_queue_refresh_callback = queue_refresh_callback
	_format_value_callback = format_value_callback
	_activity_callback = activity_callback


func _convert_argument(raw: String, argument: Dictionary) -> Dictionary:
	return ARGUMENT_CONVERTER._convert(raw, argument)


func _invoke_registered(command_name: String, raw_args: Array) -> void:
	if _activity_callback.is_valid():
		_activity_callback.call(command_name, raw_args)
	if not _registered_commands.has(command_name):
		Console.print_error("Unknown game command: %s" % command_name)
		return
	var registration: Dictionary = _registered_commands[command_name]
	var target: Object = registration.get("target")
	if not is_instance_valid(target):
		Console.print_error("Target for %s is no longer available." % command_name)
		_queue_refresh_callback.call()
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
		var converted: Dictionary = _convert_argument(raw, argument_specs[index])
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
						str(_format_value_callback.call(result))
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
			(
				"  %s%s Ã¢â‚¬â€ %s"
				% [command_name, _format_arguments(command.get("args", [])), description]
			)
		)


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


func _format_arguments(args: Array) -> String:
	var names: Array[String] = _registry._argument_names(args)
	return "" if names.is_empty() else " " + " ".join(names)


func _call_from_console(object_name: String, method_name: String, arguments: String = "") -> void:
	var command_name := "%s%s.%s" % [COMMAND_PREFIX, _registry._slug(object_name), method_name]
	if not _registered_commands.has(command_name):
		Console.print_error("Unknown game command: %s" % command_name)
		return
	var raw_args: PackedStringArray = (
		Console.parse_line_input(arguments) if not arguments.is_empty() else PackedStringArray()
	)
	_invoke_registered(command_name, Array(raw_args))
