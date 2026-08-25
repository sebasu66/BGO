extends Node

const MAX_ENTRIES := 500
var entries: Array[Dictionary] = []
var file_enabled := true
var _file_path := "user://logs/bgo-activity.jsonl"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))

func record_invocation(method_path: String, source: String, context: Dictionary = {}, result: Variant = null) -> void:
	var entry := {"schema_version": 1, "ts": Time.get_unix_time_from_system(), "event": "PUBLIC_API_INVOCATION", "method": method_path, "source": source, "context": context.duplicate(true), "result_ok": bool(result.get("ok", false)) if result is Dictionary else true}
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	if file_enabled:
		var file := FileAccess.open(_file_path, FileAccess.READ_WRITE if FileAccess.file_exists(_file_path) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(JSON.stringify(entry))
			file.close()

func clear_for_tests() -> void:
	entries.clear()
