class_name BgoLogger
extends Node

const LOG_ROOT := "debug"

var game_id := "TEST001"
var client_id := "unknown"
var firebase_enabled := true
var console_enabled := true
var file_enabled := true

var _adapter: FirebaseRestAdapter
var _file_path := ""

func configure(target_game_id: String, target_client_id: String) -> void:
	game_id = target_game_id
	client_id = _sanitize_key(target_client_id)

	_adapter = FirebaseRestAdapter.new()
	add_child(_adapter)
	_adapter.request_failed.connect(_on_log_request_failed)

	if not OS.has_feature("web") and file_enabled:
		var directory := ProjectSettings.globalize_path("user://logs")
		DirAccess.make_dir_recursive_absolute(directory)
		_file_path = "user://logs/bgo-%s.jsonl" % client_id

	log_event("LOGGER_STARTED", {
		"platform": OS.get_name(),
		"web": OS.has_feature("web")
	})

func log_event(event_name: String, payload: Dictionary = {}, level: String = "info") -> void:
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"ticks_ms": Time.get_ticks_msec(),
		"level": level,
		"event": event_name,
		"game_id": game_id,
		"client_id": client_id,
		"payload": payload
	}
	var line := JSON.stringify(entry)

	if console_enabled:
		print("[BGO] %s" % line)

	if not OS.has_feature("web") and file_enabled:
		_append_file(line)

	if firebase_enabled and _adapter != null:
		_adapter.push("%s/%s/%s" % [LOG_ROOT, game_id, client_id], entry)

func info(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "info")

func warning(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "warning")

func error(event_name: String, payload: Dictionary = {}) -> void:
	log_event(event_name, payload, "error")

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
