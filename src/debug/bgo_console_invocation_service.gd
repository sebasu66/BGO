extends RefCounted

const ARGUMENT_CONVERTER := preload("res://src/debug/bgo_console_argument_converter.gd")

var _registered_commands: Dictionary
var _queue_refresh_callback: Callable
var _format_value_callback: Callable
var _activity_callback: Callable


func _configure(
	registered_commands: Dictionary,
	queue_refresh_callback: Callable,
	format_value_callback: Callable,
	activity_callback: Callable = Callable(),
) -> void:
	_registered_commands = registered_commands
	_queue_refresh_callback = queue_refresh_callback
	_format_value_callback = format_value_callback
	_activity_callback = activity_callback


func _convert_argument(raw: String, argument: Dictionary) -> Dictionary:
	return ARGUMENT_CONVERTER._convert(raw, argument)


func _invoke_registered(command_name: String, raw_args: Array) -> void:
	if _activity_callback.is_valid():
		_activity_callback.call(command_name, raw_args)
	if not _registered_commands.has(command_name):
		Console.print_error("Unknown public API command: %s" % command_name)
		return
	var registration: Dictionary = _registered_commands[command_name]
	var target: Object = registration.get("target")
	if not is_instance_valid(target):
		Console.print_error("Target for %s is no longer available." % command_name)
		_queue_refresh_callback.call()
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
	typed_args.append_array(registration.get("bound_args", []))

	var result: Variant = target.callv(StringName(registration.get("method", "")), typed_args)
	if result != null:
		(
			Console
			. print_line(
				(
					"%s %s %s"
					% [
						BgoConsoleSyntax.highlight(command_name),
						BgoConsoleSyntax.punctuation("=>"),
						str(_format_value_callback.call(result)),
					]
				)
			)
		)
