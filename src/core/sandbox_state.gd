class_name SandboxState
extends RefCounted

var definition: Dictionary = {}
var tabletop: TabletopState
var participants: Dictionary = {}
var objects: Dictionary = {}
var scores: Dictionary = {}
var snapshots: Dictionary = {}


## Creates a local, non-persistent authoring state from a game definition.
static func create(game_definition: Dictionary) -> SandboxState:
	var state := SandboxState.new()
	state.definition = game_definition.duplicate(true)
	state.tabletop = TabletopDefinitionBuilder.build(game_definition)
	if state.tabletop == null:
		return null
	for player_variant in game_definition.get("players", []):
		if player_variant is Dictionary:
			var player: Dictionary = player_variant
			var player_id := str(player.get("id", ""))
			state.participants[player_id] = player.duplicate(true)
			state.scores[player_id] = {}
	if not state._load_setup_objects():
		return null
	return state


## Executes an unrestricted sandbox command without event history or persistence.
func execute(command: Dictionary) -> Dictionary:
	var verb := str(command.get("verb", ""))
	var args: Dictionary = command.get("args", {})
	var result := {"ok": false, "reason": "unknown_sandbox_verb"}
	match verb:
		"sandbox.spawn":
			result = _spawn(args)
		"sandbox.remove":
			result = _remove(str(command.get("target_id", args.get("object_id", ""))))
		"sandbox.set_property":
			result = _set_property(str(command.get("target_id", "")), args)
		"sandbox.move_to_slot":
			result = _move_to_slot(str(command.get("target_id", "")), args)
		"sandbox.move_free":
			result = _move_free(str(command.get("target_id", "")), args)
		"sandbox.set_score":
			result = _set_score(args)
		"sandbox.snapshot.save":
			result = save_snapshot(str(args.get("name", "default")))
		"sandbox.snapshot.restore":
			result = restore_snapshot(str(args.get("name", "default")))
	return result


## Saves one named in-memory restore point.
func save_snapshot(snapshot_name: String) -> Dictionary:
	if snapshot_name.is_empty():
		return {"ok": false, "reason": "invalid_snapshot_name"}
	snapshots[snapshot_name] = _runtime_snapshot()
	return {"ok": true, "snapshot": snapshot_name}


## Restores one named in-memory restore point without creating history.
func restore_snapshot(snapshot_name: String) -> Dictionary:
	if not snapshots.has(snapshot_name):
		return {"ok": false, "reason": "snapshot_not_found"}
	if not _restore_runtime(snapshots[snapshot_name]):
		return {"ok": false, "reason": "invalid_snapshot"}
	return {"ok": true, "snapshot": snapshot_name, "state": to_dictionary()}


## Exports current objects and scores as a declarative initial-state fragment.
func export_initial_state() -> Dictionary:
	var setup_objects: Array[Dictionary] = []
	for object_id in objects:
		var object: LogicalObjectState = objects[object_id]
		var item := {
			"id": object.object_id,
			"component": object.component_id,
			"owner_id": object.owner_id,
			"quantity": object.quantity,
			"properties": object.properties.duplicate(true),
			"initial_location": _export_location(object),
		}
		setup_objects.append(item)
	return {"setup": {"objects": setup_objects}, "scores": scores.duplicate(true)}


## Returns the current ephemeral sandbox state.
func to_dictionary() -> Dictionary:
	var object_values: Dictionary = {}
	for object_id in objects:
		object_values[object_id] = (objects[object_id] as LogicalObjectState).to_dictionary()
	return {
		"mode": "sandbox",
		"persistent": false,
		"participants": participants.duplicate(true),
		"tabletop": tabletop.to_dictionary(),
		"objects": object_values,
		"scores": scores.duplicate(true),
		"snapshots": snapshots.keys(),
	}


func _load_setup_objects() -> bool:
	for value in (definition.get("setup", {}) as Dictionary).get("objects", []):
		if not value is Dictionary:
			return false
		var object_definition: Dictionary = value
		var result := _spawn(
			{
				"object_id": str(object_definition.get("id", "")),
				"component_id": str(object_definition.get("component", "")),
				"owner_id": str(object_definition.get("owner_id", "")),
				"quantity": int(object_definition.get("quantity", 1)),
				"properties": object_definition.get("properties", {}),
				"location": object_definition.get("initial_location", {}),
			}
		)
		if not bool(result.get("ok", false)):
			return false
	return true


func _spawn(args: Dictionary) -> Dictionary:
	var object_id := str(args.get("object_id", ""))
	var component_id := str(args.get("component_id", ""))
	if object_id.is_empty() or objects.has(object_id):
		return {"ok": false, "reason": "invalid_or_duplicate_object_id"}
	if not BgoComponentRegistry.has_component(component_id):
		return {"ok": false, "reason": "unknown_component"}
	var object := LogicalObjectState.create(
		object_id, component_id, str(args.get("owner_id", "")), int(args.get("quantity", 1))
	)
	object.properties = (args.get("properties", {}) as Dictionary).duplicate(true)
	var config: Dictionary = args.get("config", {})
	var config_errors := BgoComponentRegistry.validate_config(component_id, config)
	if not config_errors.is_empty():
		return {"ok": false, "reason": "invalid_component_config", "errors": config_errors}
	object.properties["config"] = config.duplicate(true)
	objects[object_id] = object
	var location: Dictionary = args.get("location", {})
	if not location.is_empty() and not _place(object, location):
		objects.erase(object_id)
		return {"ok": false, "reason": "invalid_location"}
	return {"ok": true, "object": object.to_dictionary()}


func _remove(object_id: String) -> Dictionary:
	if not objects.has(object_id):
		return {"ok": false, "reason": "object_not_found"}
	tabletop.remove_object(object_id)
	objects.erase(object_id)
	return {"ok": true}


func _set_property(object_id: String, args: Dictionary) -> Dictionary:
	if not objects.has(object_id):
		return {"ok": false, "reason": "object_not_found"}
	var name := str(args.get("name", ""))
	if not (objects[object_id] as LogicalObjectState).set_property_value(name, args.get("value")):
		return {"ok": false, "reason": "invalid_property"}
	return {"ok": true}


func _move_to_slot(object_id: String, args: Dictionary) -> Dictionary:
	if not objects.has(object_id):
		return {"ok": false, "reason": "object_not_found"}
	var object: LogicalObjectState = objects[object_id]
	var kind := BgoComponentRegistry.get_kind(object.component_id)
	var slot_id := str(args.get("slot_id", ""))
	var moved := (
		tabletop.move_object(object_id, slot_id, kind, object.component_id)
		if tabletop.is_placed(object_id)
		else tabletop.place_object(object_id, slot_id, kind, object.component_id)
	)
	if not moved:
		return {"ok": false, "reason": "slot_rejected"}
	object.set_location("slot", slot_id)
	return {"ok": true}


func _move_free(object_id: String, args: Dictionary) -> Dictionary:
	if not objects.has(object_id):
		return {"ok": false, "reason": "object_not_found"}
	var object: LogicalObjectState = objects[object_id]
	var zone_id := str(args.get("zone_id", ""))
	var pose: Dictionary = args.get("pose", {})
	var kind := BgoComponentRegistry.get_kind(object.component_id)
	var moved := (
		tabletop.move_object_free(object_id, zone_id, pose, kind)
		if tabletop.is_placed(object_id)
		else tabletop.place_object_free(object_id, zone_id, pose, kind)
	)
	if not moved:
		return {"ok": false, "reason": "free_placement_rejected"}
	object.set_location("zone", zone_id)
	return {"ok": true}


func _set_score(args: Dictionary) -> Dictionary:
	var player_id := str(args.get("player_id", ""))
	var track := str(args.get("track", "points"))
	if not participants.has(player_id) or track.is_empty():
		return {"ok": false, "reason": "invalid_score_target"}
	(scores[player_id] as Dictionary)[track] = args.get("value", 0)
	return {"ok": true}


func _place(object: LogicalObjectState, location: Dictionary) -> bool:
	var location_type := str(location.get("type", ""))
	if location_type == "slot":
		return bool(
			(
				_move_to_slot(
					object.object_id, {"slot_id": location.get("slot_id", location.get("id"))}
				)
				. get("ok", false)
			)
		)
	if location_type == "zone":
		return bool(
			(
				_move_free(
					object.object_id,
					{
						"zone_id": location.get("zone_id", location.get("id")),
						"pose": location.get("pose", {})
					},
				)
				. get("ok", false)
			)
		)
	return object.set_location(location_type, str(location.get("id", "")))


func _runtime_snapshot() -> Dictionary:
	return to_dictionary()


func _export_location(object: LogicalObjectState) -> Dictionary:
	if object.location_type == "slot":
		return {"type": "slot", "slot_id": object.location_id}
	if object.location_type == "zone" and tabletop.object_poses.has(object.object_id):
		var placement: Dictionary = tabletop.object_poses[object.object_id]
		return {
			"type": "zone",
			"zone_id": object.location_id,
			"pose": (placement.get("pose", {}) as Dictionary).duplicate(true),
		}
	return {"type": object.location_type, "id": object.location_id}


func _restore_runtime(snapshot: Dictionary) -> bool:
	if not tabletop.load_dictionary(snapshot.get("tabletop", {})):
		return false
	participants = (snapshot.get("participants", {}) as Dictionary).duplicate(true)
	scores = (snapshot.get("scores", {}) as Dictionary).duplicate(true)
	objects.clear()
	for object_id in snapshot.get("objects", {}) as Dictionary:
		var value: Dictionary = snapshot["objects"][object_id]
		var object := (
			LogicalObjectState
			. create(
				str(object_id),
				str(value.get("component_id", "")),
				str(value.get("owner_id", "")),
				int(value.get("quantity", 1)),
			)
		)
		object.holder_id = str(value.get("holder_id", ""))
		object.location_type = str(value.get("location_type", ""))
		object.location_id = str(value.get("location_id", ""))
		object.visibility = str(value.get("visibility", "public"))
		object.state_id = str(value.get("state_id", "default"))
		object.properties = (value.get("properties", {}) as Dictionary).duplicate(true)
		objects[object_id] = object
	return true
