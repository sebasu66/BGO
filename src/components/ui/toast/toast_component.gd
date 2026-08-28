class_name BgoToastComponent
extends Control

signal toast_shown(id: String)
signal toast_dismissed(id: String, reason: int)
signal toast_clicked(id: String)
signal loading_progress_updated(id: String, progress: float)
signal loading_completed(id: String, success: bool)

@export var default_style := "info"
@export var default_time_seconds := 4.0

var _toast_service: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_toast_service()


## Updates the default toast style used when no override is supplied.
func set_default_style(value: String) -> bool:
	if value.is_empty():
		return false
	default_style = value
	return true


## Updates the default toast duration in seconds.
func set_default_time_seconds(value: float) -> void:
	default_time_seconds = maxf(value, 0.0)


## Returns the stable console, GUI, and MCP method surface for this component.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.ui.toast",
			"BgoToastComponent",
			"Transient notification and loading-progress presentation controls.",
			{
				"setDefaultStyle":
				BgoComponentApiDescriptor.setter(
					"set_default_style", "default_style", "string", "bool"
				),
				"setDefaultTimeSeconds":
				BgoComponentApiDescriptor.setter(
					"set_default_time_seconds", "default_time_seconds", "float"
				),
				"show":
				BgoComponentApiDescriptor.method(
					"show_message",
					[
						{"name": "message", "type": "string"},
						{"name": "style", "type": "string"},
						{"name": "time", "type": "float"}
					],
					"string",
					"",
					1
				),
				"success":
				BgoComponentApiDescriptor.method(
					"success",
					[{"name": "message", "type": "string"}, {"name": "time", "type": "float"}],
					"string",
					"",
					1
				),
				"error":
				BgoComponentApiDescriptor.method(
					"error",
					[{"name": "message", "type": "string"}, {"name": "time", "type": "float"}],
					"string",
					"",
					1
				),
				"warning":
				BgoComponentApiDescriptor.method(
					"warning",
					[{"name": "message", "type": "string"}, {"name": "time", "type": "float"}],
					"string",
					"",
					1
				),
				"info":
				BgoComponentApiDescriptor.method(
					"info",
					[{"name": "message", "type": "string"}, {"name": "time", "type": "float"}],
					"string",
					"",
					1
				),
				"dismiss":
				BgoComponentApiDescriptor.method(
					"dismiss", [{"name": "toast_id", "type": "string"}], "bool"
				),
				"clearAll": BgoComponentApiDescriptor.method("clear_all"),
			},
		)
	)


## Describes the developer-facing methods exposed by this component.
func console_help() -> Dictionary:
	return {
		"_summary": "Controls transient client notifications through GodotX Toast.",
		"show_message": "Shows a notification with optional style and duration.",
		"show_loading": "Shows a loading notification and returns its id.",
		"update_loading": "Updates loading progress and optional message.",
		"complete_loading": "Completes a loading notification.",
		"dismiss": "Dismisses one notification by id.",
		"clear_all": "Dismisses all active notifications.",
	}


## Shows a toast through the installed GodotX Toast runtime.
func show_message(message: String, style: Variant = null, time: Variant = null) -> String:
	if not _bind_toast_service():
		return ""
	var resolved_style: Variant = default_style if style == null else style
	var resolved_time: Variant = default_time_seconds if time == null else time
	var toast_id := str(_toast_service.call("show", message, resolved_style, resolved_time))
	return toast_id


## Shows a success notification.
func success(message: String, time: Variant = null) -> String:
	return _call_shortcut("success", message, time)


## Shows an error notification.
func error(message: String, time: Variant = null) -> String:
	return _call_shortcut("error", message, time)


## Shows a warning notification.
func warning(message: String, time: Variant = null) -> String:
	return _call_shortcut("warning", message, time)


## Shows an informational notification.
func info(message: String, time: Variant = null) -> String:
	return _call_shortcut("info", message, time)


## Shows a loading notification and returns its stable runtime id.
func show_loading(message: String, style: Variant = null) -> String:
	if not _bind_toast_service():
		return ""
	var resolved_style: Variant = default_style if style == null else style
	return str(_toast_service.call("show_loading", message, resolved_style))


## Updates loading progress and an optional replacement message.
func update_loading(toast_id: String, progress: float, new_message := "") -> bool:
	return (
		_bind_toast_service()
		and bool(_toast_service.call("update_loading", toast_id, progress, new_message))
	)


## Completes a loading notification with success or failure state.
func complete_loading(toast_id: String, success_value := true, final_message := "") -> bool:
	return (
		_bind_toast_service()
		and bool(_toast_service.call("complete_loading", toast_id, success_value, final_message))
	)


## Dismisses one active notification by id.
func dismiss(toast_id: String) -> bool:
	return _bind_toast_service() and bool(_toast_service.call("dismiss", toast_id))


## Dismisses every active notification.
func clear_all() -> void:
	if _bind_toast_service():
		_toast_service.call("clear_all")


func _call_shortcut(method_name: String, message: String, time: Variant) -> String:
	if not _bind_toast_service():
		return ""
	var resolved_time: Variant = default_time_seconds if time == null else time
	return str(_toast_service.call(method_name, message, resolved_time))


func _bind_toast_service() -> bool:
	if is_instance_valid(_toast_service):
		return true
	_toast_service = get_node_or_null("/root/GodotxToast")
	if _toast_service == null:
		push_warning("BgoToastComponent requires the GodotX Toast addon runtime.")
		return false
	_connect_service_signal("toast_shown", toast_shown)
	_connect_service_signal("toast_dismissed", toast_dismissed)
	_connect_service_signal("toast_clicked", toast_clicked)
	_connect_service_signal("loading_progress_updated", loading_progress_updated)
	_connect_service_signal("loading_completed", loading_completed)
	return true


func _connect_service_signal(signal_name: StringName, target_signal: Signal) -> void:
	if (
		_toast_service.has_signal(signal_name)
		and not _toast_service.is_connected(signal_name, target_signal.emit)
	):
		_toast_service.connect(signal_name, target_signal.emit)
