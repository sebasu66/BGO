class_name TableLog
extends RefCounted

## What the table component writes to the activity log, so a change can be
## traced afterwards. It only records; it never decides anything.

const SOURCE := "table"


## Records that a table command was accepted.
static func command_accepted(verb: String, actor_id: String) -> void:
	_record("Table.accepted", {"verb": verb, "actor_id": actor_id}, {"ok": true})


## Records that a table command was refused, with the reason.
static func command_refused(verb: String, actor_id: String, reason: String) -> void:
	_record("Table.refused", {"verb": verb, "actor_id": actor_id}, {"ok": false, "reason": reason})


static func _record(event_name: String, context: Dictionary, result: Dictionary) -> void:
	var main_loop := Engine.get_main_loop()
	if main_loop == null:
		return
	var activity_log: Node = (main_loop as SceneTree).root.get_node_or_null("BgoActivityLog")
	if activity_log != null:
		activity_log.record_invocation(event_name, SOURCE, context, result)
