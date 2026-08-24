class_name BgoLogger
extends Node

const LOG_ROOT := "debug"
const PUBLIC_LOG_ROOT := "debug_public"
const MAX_BUFFER_ENTRIES := 250
const WEB_POLL_SECONDS := 0.25
const LEVEL_PRIORITY := {"debug": 10, "info": 20, "warning": 30, "error": 40}

var game_id := "TEST001"
var client_id := "unknown"
var firebase_enabled := true
var console_enabled := true
var file_enabled := true
var game_console_enabled := OS.is_debug_build()
var minimum_level := "debug" if OS.is_debug_build() else "info"

var _adapter: FirebaseRestAdapter
var _file_path := ""
var _run_id := ""
var _buffer: Array[Dictionary] = []
var _web_poll_timer: Timer
var _last_uploaded_generation := 0
var _recorder_missing_reported := false


## Configures this object from the supplied project data.
func configure(target_game_id: String, target_client_id: String) -> void:
	game_id = target_game_id
	client_id = _sanitize_key(target_client_id)
	_run_id = "%d-%s" % [Time.get_unix_time_from_system(), client_id]

	_adapter = FirebaseRestAdapter.new()
	add_child(_adapter)
	_adapter.request_failed.connect(_on_log_request_failed)

	if OS.has_feature("web"):
		_start_web_flight_recorder_poll()
	elif file_enabled:
		var directory := ProjectSettings.globalize_path("user://logs")
		DirAccess.make_dir_recursive_absolute(directory)
		_file_path = "user://logs/bgo-%s.jsonl" % client_id

	log_event(
		"LOGGER_STARTED",
		{"platform": OS.get_name(), "web": OS.has_feature("web"), "run_id": _run_id}
	)


## Records a structured BGO event using the configured logging sinks.
func log_event(event_name: String, payload: Dictionary = {}, level: String = "info") -> void:
	if not _should_log(level):
		return
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"ticks_ms": Time.get_ticks_msec(),
		"level": level,
		"event": event_name,
		"game_id": game_id,
		"client_id": client_id,
		"run_id": _run_id,
		"payload": payload
	}
	_buffer.append(entry)
	while _buffer.size() > MAX_BUFFER_ENTRIES:
		_buffer.pop_front()

	var line := JSON.stringify(entry)
	if console_enabled:
		print("[BGO] %s" % line)
	_write_game_console(event_name, payload, level)

	if not OS.has_feature("web") and file_enabled:
		_append_file(line)

	if level == "error":
		_mark_web_error("bgo_logger:%s" % event_name)
		if OS.has_feature("web"):
			# Do not wait for the periodic timer: a fatal browser/runtime error can
			# navigate or terminate the page before the next tick.
			_poll_web_flight_recorder.call_deferred()
		else:
			_flush_structured_error_run("bgo_logger")


## Changes the minimum structured-event level accepted by every BGO sink.
func set_minimum_level(level: String) -> bool:
	var normalized := level.to_lower()
	if not LEVEL_PRIORITY.has(normalized):
		return false
	minimum_level = normalized
	info("LOGGER_LEVEL_CHANGED", {"minimum_level": minimum_level})
	return true


func _should_log(level: String) -> bool:
	var normalized := level.to_lower()
	return int(LEVEL_PRIORITY.get(normalized, 20)) >= int(LEVEL_PRIORITY.get(minimum_level, 10))


func _write_game_console(event_name: String, payload: Dictionary, level: String) -> void:
	if not game_console_enabled or not is_inside_tree():
		return
	var game_console := get_node_or_null("/root/Console")
	if game_console == null:
		return
	var message := "[BGO] %s %s" % [event_name, JSON.stringify(payload)]
	match level:
		"error":
			game_console.call("print_error", message, false)
		"warning":
			game_console.call("print_warning", message, false)
		"info":
			game_console.call("print_info", message, false)
		_:
			game_console.call("print_line", "[DEBUG] %s" % message, false)


## Records a debug-level BGO log entry.
func debug(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "debug")


## Records an informational BGO log entry.
func info(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "info")


## Records a warning-level BGO log entry.
func warning(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "warning")


## Records an error-level BGO log entry.
func error(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "error")


func _start_web_flight_recorder_poll() -> void:
	_web_poll_timer = Timer.new()
	_web_poll_timer.wait_time = WEB_POLL_SECONDS
	_web_poll_timer.one_shot = false
	_web_poll_timer.autostart = true
	add_child(_web_poll_timer)
	_web_poll_timer.timeout.connect(_poll_web_flight_recorder)
	_poll_web_flight_recorder.call_deferred()


func _mark_web_error(reason: String) -> void:
	if not OS.has_feature("web"):
		return
	var encoded_reason := JSON.stringify(reason)
	JavaScriptBridge.eval(
		"window.__bgoFlightRecorder&&window.__bgoFlightRecorder.markError(%s);" % encoded_reason,
		true
	)


func _poll_web_flight_recorder() -> void:
	if not firebase_enabled or _adapter == null:
		return
	var snapshot_json: Variant = JavaScriptBridge.eval(
		"window.__bgoFlightRecorder?JSON.stringify(window.__bgoFlightRecorder.snapshot()):'';", true
	)
	if not snapshot_json is String or snapshot_json.is_empty():
		_report_missing_web_recorder()
		return
	var snapshot: Variant = JSON.parse_string(snapshot_json)
	if not snapshot is Dictionary:
		_report_invalid_web_recorder_snapshot(str(snapshot_json))
		return
	var generation := int(snapshot.get("error_generation", 0))
	if generation <= _last_uploaded_generation:
		return
	_last_uploaded_generation = generation
	_upload_error_run(snapshot, "web_flight_recorder")


func _report_missing_web_recorder() -> void:
	if _recorder_missing_reported:
		return
	_recorder_missing_reported = true
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"ticks_ms": Time.get_ticks_msec(),
		"level": "error",
		"event": "WEB_FLIGHT_RECORDER_MISSING",
		"game_id": game_id,
		"client_id": client_id,
		"run_id": _run_id,
		"payload": {"message": "window.__bgoFlightRecorder is missing from exported HTML"}
	}
	_buffer.append(entry)
	_upload_error_run(
		{
			"error_generation": _last_uploaded_generation + 1,
			"error_seen": true,
			"entries": [],
			"recorder_available": false,
		},
		"flight_recorder_missing"
	)
	_last_uploaded_generation += 1


func _report_invalid_web_recorder_snapshot(raw_value: String) -> void:
	if _recorder_missing_reported:
		return
	_recorder_missing_reported = true
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"ticks_ms": Time.get_ticks_msec(),
		"level": "error",
		"event": "WEB_FLIGHT_RECORDER_INVALID",
		"game_id": game_id,
		"client_id": client_id,
		"run_id": _run_id,
		"payload": {"raw_snapshot": raw_value.left(512)}
	}
	_buffer.append(entry)
	_upload_error_run(
		{
			"error_generation": _last_uploaded_generation + 1,
			"error_seen": true,
			"entries": [],
			"recorder_available": true,
			"snapshot_valid": false,
		},
		"flight_recorder_invalid"
	)
	_last_uploaded_generation += 1


func _flush_structured_error_run(source: String) -> void:
	if not firebase_enabled or _adapter == null:
		return
	_upload_error_run(
		{
			"error_generation": _last_uploaded_generation + 1,
			"error_seen": true,
			"entries": _buffer.duplicate(true),
			"source": source,
		},
		source
	)
	_last_uploaded_generation += 1


func _upload_error_run(snapshot: Dictionary, source: String) -> void:
	var payload := {
		"schema_version": 1,
		"run_id": _run_id,
		"game_id": game_id,
		"client_id": client_id,
		"captured_at": Time.get_unix_time_from_system(),
		"source": source,
		"structured_events": _buffer.duplicate(true),
		"browser": snapshot,
	}
	_adapter.write("%s/%s/%s/error_runs/%s" % [LOG_ROOT, game_id, client_id, _run_id], payload)
	_adapter.write("%s/latest_error/%s" % [PUBLIC_LOG_ROOT, _sanitize_key(game_id)], payload)


func _append_file(line: String) -> void:
	var file: FileAccess
	if FileAccess.file_exists(_file_path):
		file = FileAccess.open(_file_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(_file_path, FileAccess.WRITE)

	if file == null:
		return
	file.store_line(line)
	file.close()


func _on_log_request_failed(
	operation: StringName, path: String, http_code: int, message: String
) -> void:
	# Never feed Firebase logging failures back into the Firebase logger itself.
	push_warning(
		"BGO debug log upload failed: %s %s (%d) %s" % [operation, path, http_code, message]
	)


func _sanitize_key(value: String) -> String:
	var result := value
	for forbidden in [".", "#", "$", "[", "]", "/"]:
		result = result.replace(forbidden, "_")
	return result
