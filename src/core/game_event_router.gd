class_name GameEventRouter
extends RefCounted

const MAX_EVENTS_PER_COMMAND := 256

var listeners: Array[Dictionary] = []


func configure(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	listeners.clear()
	var ids: Dictionary = {}
	for index in definitions.size():
		var definition: Variant = definitions[index]
		if not definition is Dictionary:
			errors.append("listeners[%d] must be an object." % index)
			continue
		var listener: Dictionary = definition
		var listener_id := str(listener.get("id", ""))
		var event_type := str(listener.get("event", ""))
		var commands: Variant = listener.get("commands", [])
		if listener_id.is_empty() or ids.has(listener_id):
			errors.append("listeners[%d].id must be unique and non-empty." % index)
		elif event_type.is_empty():
			errors.append("listeners[%d].event is required." % index)
		elif not commands is Array or commands.is_empty():
			errors.append("listeners[%d].commands must be a non-empty array." % index)
		else:
			ids[listener_id] = true
			listeners.append(listener.duplicate(true))
	return errors


func commands_for(event: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var event_type := str(event.get("type", ""))
	for listener in listeners:
		if str(listener.get("event", "")) != event_type:
			continue
		for command_value in listener.get("commands", []):
			if command_value is Dictionary:
				result.append(_resolve_template(command_value, event))
	return result


func _resolve_template(command: Dictionary, event: Dictionary) -> Dictionary:
	var resolved := command.duplicate(true)
	resolved["caused_by"] = event.get("id", "")
	return resolved
