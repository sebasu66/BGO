class_name RuntimeSessionAdapterTest
extends RefCounted


static func run(check: Callable) -> void:
	var loaded := BgoGameDefinitionLoader.load_game("res://games/test001/game.jsonh")
	if not bool(loaded.get("ok", false)):
		printerr("Adapter fixture validation errors: %s" % [loaded.get("errors", [])])
	check.call(bool(loaded.get("ok", false)), "adapter fixture loads")
	if not bool(loaded.get("ok", false)):
		return
	var definition: Dictionary = loaded.get("data", {})
	var state := _repository_state(definition)
	var adapter := RuntimeSessionAdapter.new()
	var result := adapter.load_session("adapter-test", definition, state)
	if not bool(result.get("ok", false)):
		printerr("Adapter session build error: %s" % [result])
	check.call(bool(result.get("ok", false)), "adapter builds logical session")
	check.call(adapter.active_participant_id() == "player_1", "adapter exposes flow participant")
	var moved := adapter.move_object("player_1", "player_1_piece", "board:2:2")
	check.call(bool(moved.get("ok", false)), "adapter sends canonical move command")
	check.call(adapter.active_participant_id() == "player_1", "move never ends turn")
	var ended := adapter.end_turn("player_1")
	check.call(bool(ended.get("ok", false)), "adapter sends explicit turn.end")
	check.call(adapter.active_participant_id() == "player_2", "explicit end advances flow")
	var patch: Dictionary = ended.get("persistence_patch", {})
	check.call(patch.has("flow"), "persistence patch contains flow separately from session")


static func _repository_state(definition: Dictionary) -> Dictionary:
	var pieces: Dictionary = {}
	for object_definition in (definition.get("setup", {}) as Dictionary).get("objects", []):
		var location: Dictionary = object_definition.get("initial_location", {})
		pieces[str(object_definition.get("id", ""))] = {
			"component_id": str(object_definition.get("component", "")),
			"owner_id": str(object_definition.get("owner_id", "")),
			"holder_id": "",
			"quantity": int(object_definition.get("quantity", 1)),
			"visibility": "public",
			"location": location.duplicate(true),
		}
	return {"state_revision": 0, "pieces": pieces}
