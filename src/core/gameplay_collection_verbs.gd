class_name GameplayCollectionVerbs
extends RefCounted

## Canonical verbs for hands and the asset box.
##
## These verbs belong to the hand and asset-box modules, so they live apart from
## GameplayState to keep the kernel small. Each handler receives the state it
## acts on as its last argument, bound when the verb is registered.


## Reorders one object inside the actor's own hand. Allowed at any time, even
## out of turn, because it changes nothing on the table.
static func reorder_in_hand(command: Dictionary, state: GameplayState) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command.get("target_id", ""))
	var args: Dictionary = command.get("args", {})
	if state.session == null or not state.session.is_active():
		return _rejected("session_not_active")
	var hand: HandState = state.hands.get(actor_id)
	if hand == null or not hand.contains(object_id):
		return _rejected("object_not_in_hand")
	var raw_index: Variant = args.get("index")
	if typeof(raw_index) not in [TYPE_INT, TYPE_FLOAT]:
		return _rejected("invalid_index")
	var from_index := hand.object_ids.find(object_id)
	var to_index := int(raw_index)
	if not hand.move_to_index(object_id, to_index):
		return _rejected("invalid_index")
	return _events(
		[
			{
				"type": "hand.reordered",
				"source_id": object_id,
				"actor_id": actor_id,
				"data":
				{
					"participant_id": actor_id,
					"from_index": from_index,
					"to_index": to_index,
					"order": hand.to_array(),
				},
			}
		]
	)


## Takes an object out of the asset box onto the table grid.
## Optional args: origin_x/origin_y, footprint_x/footprint_y, allow_overlap, acquire_neutral.
static func take_from_box(command: Dictionary, state: GameplayState) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command.get("target_id", ""))
	var args: Dictionary = command.get("args", {})
	var origin: Variant = _point_arg(args, "origin", Vector2i(-1, -1))
	var footprint: Variant = _point_arg(args, "footprint", Vector2i.ZERO)
	if origin == null:
		return _rejected("invalid_origin")
	if footprint == null:
		return _rejected("invalid_footprint")
	var result := state.take_object_from_box(
		actor_id,
		object_id,
		origin,
		footprint,
		bool(args.get("allow_overlap", false)),
		bool(args.get("acquire_neutral", false))
	)
	if not bool(result.get("ok", false)):
		return result
	var fact: Dictionary = result["event"]
	var to_origin: Dictionary = fact["to_origin"]
	return _events(
		[
			{
				"type": "object.moved",
				"source_id": object_id,
				"actor_id": actor_id,
				"data":
				{
					"from_type": "asset_box",
					"from_id": str(fact["box_id"]),
					"to_type": "grid",
					"to_id": "grid:%d:%d" % [int(to_origin["x"]), int(to_origin["y"])],
					"origin": to_origin,
					"footprint": fact["to_footprint"],
				},
			}
		]
	)


## Returns an object from the table to the asset box catalog.
static func return_to_box(command: Dictionary, state: GameplayState) -> Dictionary:
	var actor_id := str(command["actor_id"])
	var object_id := str(command.get("target_id", ""))
	var args: Dictionary = command.get("args", {})
	var source_type := ""
	var source_id := ""
	if state.objects.has(object_id):
		var object: LogicalObjectState = state.objects[object_id]
		source_type = object.location_type
		source_id = object.location_id
	var result := state.store_object_in_box(
		actor_id,
		object_id,
		Vector2i(-1, -1),
		Vector2i.ZERO,
		false,
		bool(args.get("acquire_neutral", false))
	)
	if not bool(result.get("ok", false)):
		return result
	return _events(
		[
			{
				"type": "object.moved",
				"source_id": object_id,
				"actor_id": actor_id,
				"data":
				{
					"from_type": source_type,
					"from_id": source_id,
					"to_type": "asset_box",
					"to_id": str((result["event"] as Dictionary)["box_id"]),
				},
			}
		]
	)


## Reads "<prefix>_x"/"<prefix>_y" command args. Returns the fallback when both
## are absent and null when only one is given or a value is not a number.
static func _point_arg(args: Dictionary, prefix: String, fallback: Vector2i) -> Variant:
	var has_x := args.has(prefix + "_x")
	var has_y := args.has(prefix + "_y")
	if not has_x and not has_y:
		return fallback
	if not (has_x and has_y):
		return null
	var x: Variant = args[prefix + "_x"]
	var y: Variant = args[prefix + "_y"]
	if typeof(x) not in [TYPE_INT, TYPE_FLOAT] or typeof(y) not in [TYPE_INT, TYPE_FLOAT]:
		return null
	return Vector2i(int(x), int(y))


static func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _events(events: Array[Dictionary]) -> Dictionary:
	return {"ok": true, "events": events}
