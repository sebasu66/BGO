class_name BgoLogger
extends Node

const LOG_ROOT := "debug"
const MAX_BUFFER_ENTRIES := 250
const WEB_POLL_SECONDS := 1.0

var game_id := "TEST001"
var client_id := "unknown"
var firebase_enabled := true
var console_enabled := true
var file_enabled := true

var _adapter: FirebaseRestAdapter
var _file_path := ""
var _run_id := ""
var _buffer: Array[Dictionary] = []
var _web_poll_timer: Timer
var _last_uploaded_generation := 0

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

	log_event("LOGGER_STARTED", {
		"platform": OS.get_name(),
		"web": OS.has_feature("web"),
		"run_id": _run_id
	})

func log_event(event_name: String, payload: Dictionary = {}, level: String = "info") -> void:
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

	if not OS.has_feature("web") and file_enabled:
		_append_file(line)

	if level == "error":
		_mark_web_error("bgo_logger:%s" % event_name)
		if not OS.has_feature("web"):
			_flush_structured_error_run("bgo_logger")

func debug(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "debug")

func info(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "info")

func warning(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "warning")

func error(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "error")

func _start_web_flight_recorder_poll() -> void:
	_web_poll_timer = Timer.new()
	_web_poll_timer.wait_time = WEB_POLL_SECONDS
	_web_poll_timer.one_shot = false
	_web_poll_timer.autostart = true
	add_child(_web_poll_timer)
	_web_poll_timer.timeout.connect(_poll_web_flight_recorder)

func _mark_web_error(reason: String) -> void:
	if not OS.has_feature("web"):
		return
	var encoded_reason := JSON.stringify(reason)
	JavaScriptBridge.eval("window.__bgoFlightRecorder&&window.__bgoFlightRecorder.markError(%s);" % encoded_reason, true)

func _poll_web_flight_recorder() -> void:
	if not firebase_enabled or _adapter == null:
		return
	var snapshot_json: Variant = JavaScriptBridge.eval("window.__bgoFlightRecorder?JSON.stringify(window.__bgoFlightRecorder.snapshot()):'';", true)
	if not snapshot_json is String or snapshot_json.is_empty():
		return
	var snapshot: Variant = JSON.parse_string(snapshot_json)
	if not snapshot is Dictionary:
		return
	var generation := int(snapshot.get("error_generation", 0))
	if generation <= _last_uploaded_generation:
		return
	_last_uploaded_generation = generation
	_upload_error_run(snapshot, "web_flight_recorder")

func _flush_structured_error_run(source: String) -> void:
	if not firebase_enabled or _adapter == null:
		return
	_upload_error_run({
		"error_generation": _last_uploaded_generation + 1,
		"error_seen": true,
		"entries": _buffer.duplicate(true),
		"source": source,
	}, source)
	_last_uploaded_generation += 1

func _upload_error_run(snapshot: Dictionary, source: String) -> void:
	var payload := {
		"run_id": _run_id,
		"game_id": game_id,
		"client_id": client_id,
		"captured_at": Time.get_unix_time_from_system(),
		"source": source,
		"structured_events": _buffer.duplicate(true),
		"browser": snapshot,
	}
	_adapter.write("%s/%s/%s/error_runs/%s" % [LOG_ROOT, game_id, client_id, _run_id], payload)

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

func _on_log_request_failed(operation: StringName, path: String, http_code: int, message: String) -> void:
	# Never feed Firebase logging failures back into the Firebase logger itself.
	push_warning("BGO debug log upload failed: %s %s (%d) %s" % [operation, path, http_code, message])

func _sanitize_key(value: String) -> String:
	var result := value
	for forbidden in [".", "#", "$", "[", "]", "/"]:
		result = result.replace(forbidden, "_")
	return result
