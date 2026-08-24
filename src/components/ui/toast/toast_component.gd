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


## Shows a toast through the installed GodotX Toast runtime.
func show_message(message: String, style: Variant = null, time: Variant = null) -> String:
	if not _bind_toast_service():
		return ""
	var resolved_style: Variant = default_style if style == null else style
	var resolved_time: Variant = default_time_seconds if time == null else time
	var toast_id := str(_toast_service.call("show", message, resolved_style, resolved_time))
	return toast_id


func success(message: String, time: Variant = null) -> String:
	return _call_shortcut("success", message, time)


func error(message: String, time: Variant = null) -> String:
	return _call_shortcut("error", message, time)


func warning(message: String, time: Variant = null) -> String:
	return _call_shortcut("warning", message, time)


func info(message: String, time: Variant = null) -> String:
	return _call_shortcut("info", message, time)


func show_loading(message: String, style: Variant = null) -> String:
	if not _bind_toast_service():
		return ""
	var resolved_style: Variant = default_style if style == null else style
	return str(_toast_service.call("show_loading", message, resolved_style))


func update_loading(toast_id: String, progress: float, new_message := "") -> bool:
	return _bind_toast_service() and bool(
		_toast_service.call("update_loading", toast_id, progress, new_message)
	)


func complete_loading(toast_id: String, success_value := true, final_message := "") -> bool:
	return _bind_toast_service() and bool(
		_toast_service.call("complete_loading", toast_id, success_value, final_message)
	)


func dismiss(toast_id: String) -> bool:
	return _bind_toast_service() and bool(_toast_service.call("dismiss", toast_id))


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
	if _toast_service.has_signal(signal_name) and not _toast_service.is_connected(signal_name, target_signal.emit):
		_toast_service.connect(signal_name, target_signal.emit)
