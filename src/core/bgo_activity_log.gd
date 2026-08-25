extends Node

const MAX_ENTRIES := 500
var entries: Array[Dictionary] = []
var file_enabled := true
var _file_path := "user://logs/bgo-activity.jsonl"
var _session_repository: Node
var _session_id := ""
var _pending_shared_events: Array[Dictionary] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))

func bind_session_repository(repository: Node, session_id: String) -> void:
	_session_repository = repository
	_session_id = session_id
	_flush_pending_shared_events()


func recover_shared_events(events: Dictionary) -> void:
	entries.clear()
	var recovered: Array[Dictionary] = []
	for event_id_variant in events:
		var event: Variant = events[event_id_variant]
		if event is Dictionary:
			recovered.append(event.duplicate(true))
	recovered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("event_id", "")) < str(right.get("event_id", ""))
	)
	for event in recovered.slice(maxi(0, recovered.size() - MAX_ENTRIES)):
		entries.append(event)


func record_invocation(method_path: String, source: String, context: Dictionary = {}, result: Variant = null) -> void:
	var result_summary: Dictionary = {}
	if result is Dictionary:
		result_summary = {
			"status": "completed" if bool(result.get("ok", false)) else "rejected",
			"ok": bool(result.get("ok", false)),
			"reason": str(result.get("reason", "")),
		}
	else:
		result_summary = {"status": "invoked"}
	var entry := {
		"schema_version": 1,
		"event_id": "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()],
		"timestamp": Time.get_unix_time_from_system(),
		"event": "PUBLIC_API_INVOCATION",
		"source": source,
		"transport": source,
		"session_id": str(context.get("session_id", _session_id)),
		"method": method_path,
		"command": method_path,
		"entity": str(context.get("entity", "")),
		"actor": _actor_metadata(context),
		"arguments_summary": _arguments_summary(context),
		"result_summary": result_summary,
		"context": context.duplicate(true),
		"result_ok": bool(result.get("ok", false)) if result is Dictionary else true,
	}
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	if _session_repository != null and _session_repository.has_method("persist_activity_event"):
		_session_repository.persist_activity_event(entry)
	else:
		_pending_shared_events.append(entry)
		while _pending_shared_events.size() > MAX_ENTRIES:
			_pending_shared_events.pop_front()
	if file_enabled:
		var file := FileAccess.open(_file_path, FileAccess.READ_WRITE if FileAccess.file_exists(_file_path) else FileAccess.WRITE)
		if file != null:
			file.seek_end()
			file.store_line(JSON.stringify(entry))
			file.close()


func _actor_metadata(context: Dictionary) -> Dictionary:
	var actor := {}
	for key in ["actor_id", "participant_id", "controller_id", "role"]:
		if context.has(key):
			actor[key] = context[key]
	return actor


func _arguments_summary(context: Dictionary) -> Variant:
	if context.has("arguments"):
		return context["arguments"].duplicate(true) if context["arguments"] is Array or context["arguments"] is Dictionary else str(context["arguments"])
	return {}


func _flush_pending_shared_events() -> void:
	if _session_repository == null or not _session_repository.has_method("persist_activity_event"):
		return
	for event in _pending_shared_events:
		_session_repository.persist_activity_event(event)
	_pending_shared_events.clear()

func clear_for_tests() -> void:
	entries.clear()
	_pending_shared_events.clear()
