class_name TableVerbs
extends RefCounted

## Canonical verbs that change the table, its zones and its slots.
##
## They belong to the table module, so they live apart from GameplayState.
## Only the host may run them. Each handler receives the state it acts on as
## its last argument, bound when the verb is registered.


## Registers every table verb on the given gameplay state.
static func register(state: GameplayState) -> void:
	var handlers := {
		"table.set_mode": set_mode,
		"table.set_surface": set_surface,
		"table.add_light": add_light,
		"table.remove_light": remove_light,
		"zone.set_visibility": set_visibility,
		"zone.resize": resize_zone,
		"slot.add": add_slot,
		"slot.remove": remove_slot,
	}
	for verb in handlers:
		state.register_verb(verb, run_and_log.bind(verb, handlers[verb], state))


## Runs one table verb and writes the outcome to the table log.
static func run_and_log(
	command: Dictionary, verb: String, handler: Callable, state: GameplayState
) -> Dictionary:
	var result: Dictionary = handler.call(command, state)
	var actor_id := str(command.get("actor_id", ""))
	if bool(result.get("ok", false)):
		TableLog.command_accepted(verb, actor_id)
	else:
		TableLog.command_refused(verb, actor_id, str(result.get("reason", "")))
	return result


## Args: mode ("free" or "closed").
static func set_mode(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var mode := str(_args(command).get("mode", ""))
	var before: String = state.tabletop.config.mode
	if not state.tabletop.config.set_mode(mode):
		return _rejected("invalid_mode")
	return _event(command, "table.mode_changed", {"from": before, "to": mode})


## Args: any of preset (string), tint (HTML color), uv_scale (number > 0).
static func set_surface(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var changes := _args(command)
	if changes.is_empty():
		return _rejected("nothing_to_change")
	if not state.tabletop.config.set_surface(changes):
		return _rejected("invalid_surface")
	return _event(command, "table.surface_changed", {"surface": state.tabletop.config.surface})


## Args: id, type (point/spot/directional), position {x,y,z}, intensity, color.
static func add_light(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var definition := _args(command)
	if not state.tabletop.config.add_light(definition):
		return _rejected("invalid_light")
	var light_id := str(definition["id"])
	return _event(command, "table.light_added", {"light": state.tabletop.config.lights[light_id]})


## Args: id.
static func remove_light(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var light_id := str(_args(command).get("id", ""))
	if not state.tabletop.config.remove_light(light_id):
		return _rejected("unknown_light")
	return _event(command, "table.light_removed", {"id": light_id})


## Args: zone_id, visibility ("public" or "private").
static func set_visibility(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var args := _args(command)
	var zone_id := str(args.get("zone_id", ""))
	var visibility := str(args.get("visibility", ""))
	if not state.tabletop.set_zone_visibility(zone_id, visibility):
		return _rejected("invalid_zone_visibility")
	return _event(
		command, "zone.visibility_changed", {"zone_id": zone_id, "visibility": visibility}
	)


## Args: zone_id, width, depth. Keeps the zone center.
static func resize_zone(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var args := _args(command)
	if typeof(args.get("width")) not in [TYPE_INT, TYPE_FLOAT]:
		return _rejected("invalid_size")
	if typeof(args.get("depth")) not in [TYPE_INT, TYPE_FLOAT]:
		return _rejected("invalid_size")
	var zone_id := str(args.get("zone_id", ""))
	var width := float(args["width"])
	var depth := float(args["depth"])
	if not state.tabletop.resize_zone(zone_id, width, depth):
		return _rejected("zone_resize_rejected")
	return _event(command, "zone.resized", {"zone_id": zone_id, "width": width, "depth": depth})


## Args: slot_id, zone_id, capacity, accepted_kinds, accepted_components, pose, anchor.
## anchor: {kind: table|zone|board|card, id, cell: [x, y]}.
## The cell counts from the anchor's center, x to the right and y upward.
static func add_slot(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var args := _args(command)
	var slot_id := str(args.get("slot_id", ""))
	var zone_id := str(args.get("zone_id", ""))
	var capacity := int(args.get("capacity", 1))
	if not state.tabletop.add_slot(slot_id, zone_id, capacity, args):
		return _rejected("slot_rejected")
	return _event(
		command, "slot.added", {"slot_id": slot_id, "slot": state.tabletop.slots[slot_id]}
	)


## Args: slot_id. Only an empty slot can be removed.
static func remove_slot(command: Dictionary, state: GameplayState) -> Dictionary:
	var denied := _host_only(command, state)
	if not denied.is_empty():
		return denied
	var slot_id := str(_args(command).get("slot_id", ""))
	if not state.tabletop.remove_slot(slot_id):
		return _rejected("slot_remove_rejected")
	return _event(command, "slot.removed", {"slot_id": slot_id})


static func _host_only(command: Dictionary, state: GameplayState) -> Dictionary:
	if state.session == null or not state.session.is_active():
		return _rejected("session_not_active")
	if state.tabletop == null:
		return _rejected("tabletop_unavailable")
	if not state.session.is_host(str(command["actor_id"])):
		return _rejected("host_only")
	return {}


static func _args(command: Dictionary) -> Dictionary:
	var args: Variant = command.get("args", {})
	return (args as Dictionary).duplicate(true) if args is Dictionary else {}


static func _event(command: Dictionary, event_type: String, data: Dictionary) -> Dictionary:
	var events: Array[Dictionary] = [
		{
			"type": event_type,
			"source_id": "table",
			"actor_id": str(command["actor_id"]),
			"data": data.duplicate(true),
		}
	]
	return {"ok": true, "events": events}


static func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
