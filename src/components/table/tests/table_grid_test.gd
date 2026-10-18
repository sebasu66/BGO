class_name TableGridTest
extends RefCounted

## Tests of cells, containment, dropping and private zones.
## They start from the real game (games/test001), loaded the way the product
## loads it, and change it with the real verbs. Nothing is assembled by hand.

const GAME_PATH := "res://games/test001/game.jsonh"
const HOST := "player_1"
const GUEST := "player_2"
const ROTATION := {"x": 0, "y": 0, "z": 0}
# Real objects of games/test001: two pieces owned by the players, one neutral.
const PIECE_1 := "player_1_piece"
const STACK_2 := "player_2_stack"
const NEUTRAL := "neutral_stack"


static func run(check: Callable) -> void:
	_test_cell_math(check)
	_test_cell_size_verb(check)
	_test_deck_in_a_slot_is_found_both_ways(check)
	_test_open_table_drops(check)
	_test_closed_table_drops(check)
	_test_private_zone_is_invisible_to_the_other_player(check)
	_test_a_snapshot_keeps_the_new_state(check)


static func _test_cell_math(check: Callable) -> void:
	var poker_card := Vector2(6.3, 8.8)
	check.call(TableCellMath.cells_covering(poker_card) == Vector2i(2, 2), "a card covers 2 x 2")
	check.call(TableCellMath.cells_covering(Vector2(3, 3)) == Vector2i(1, 1), "a token covers 1")
	check.call(TableCellMath.cells_covering(Vector2(5, 5)) == Vector2i(1, 1), "an exact fit is 1")
	check.call(TableCellMath.cells_covering(poker_card, 4.0) == Vector2i(2, 3), "4 cm cells: 2 x 3")
	check.call(TableCellMath.cells_covering(poker_card, 3.0) == Vector2i(3, 3), "3 cm cells: 3 x 3")
	check.call(TableCellMath.cell_containing(Vector2(2.5, 7.0)) == Vector2i(0, 1), "finds a cell")
	check.call(TableCellMath.cell_containing(Vector2(-0.1, -5.1)) == Vector2i(-1, -2), "negatives")
	check.call(TableCellMath.cell_center_cm(Vector2i(0, 0)) == Vector2(2.5, 2.5), "cell center")
	var group_center := TableCellMath.group_center_cm(Vector2i(1, 1), Vector2i(2, 2))
	check.call(group_center == Vector2(10, 10), "a group is centered on its middle")


static func _test_cell_size_verb(check: Callable) -> void:
	var game := _real_game(check)
	check.call(game.tabletop.config.cell_size_cm == 5.0, "the real game starts with 5 cm cells")
	var changed := game.execute(_command(HOST, "table.set_cell_size", {"cell_size_cm": 4}))
	check.call(bool(changed["ok"]), "the host changes the cell size")
	check.call(game.tabletop.config.cell_size_cm == 4.0, "the table uses the new size")
	var denied := game.execute(_command(GUEST, "table.set_cell_size", {"cell_size_cm": 3}))
	check.call(denied["reason"] == "host_only", "a guest cannot change the cell size")
	var zero := game.execute(_command(HOST, "table.set_cell_size", {"cell_size_cm": 0}))
	check.call(zero["reason"] == "invalid_cell_size", "a zero size is refused")
	var text := game.execute(_command(HOST, "table.set_cell_size", {"cell_size_cm": "big"}))
	check.call(text["reason"] == "invalid_cell_size", "a text size is refused")
	check.call(game.tabletop.config.cell_size_cm == 4.0, "refusals change nothing")


static func _test_deck_in_a_slot_is_found_both_ways(check: Callable) -> void:
	var game := _real_game(check)
	var ids: Array[String] = [PIECE_1, NEUTRAL, STACK_2]
	var slot := {"slot_id": "event_slot", "zone_id": "board_area", "capacity": 1}
	slot["anchor"] = {"kind": "table", "cell": [1, 1]}
	check.call(bool(game.execute(_command(HOST, "slot.add", slot))["ok"]), "the host adds a slot")
	check.call(_move(game, HOST, ids[0], "event_slot"), "the deck goes into the slot")
	var links: TableContainmentState = game.tabletop.containment
	check.call(links.put_inside(ids[1], ids[0]), "a card goes into the deck")
	check.call(links.put_inside(ids[2], ids[0]), "a second card goes into the deck")
	var card_place := TableLocator.where_is(game.tabletop, ids[1])
	check.call(card_place["containers"] == [ids[0]], "the card knows its deck")
	check.call(card_place["slot_id"] == "event_slot", "the card knows the slot of its deck")
	check.call(card_place["cell"] == {"x": 1, "y": 1}, "the card knows its cell")
	var cell_report := TableLocator.what_is_at_cell(game.tabletop, Vector2i(1, 1))
	var held: Dictionary = cell_report["slots"][0]["holds"][0]
	check.call(held["object_id"] == ids[0], "the cell knows the deck")
	check.call(held["inside"] == [ids[1], ids[2]], "the deck knows its cards, in order")
	check.call(not links.put_inside(ids[0], ids[1]), "a deck cannot go inside its own card")


static func _test_open_table_drops(check: Callable) -> void:
	var game := _real_game(check)
	var ids := _picked_up(game, [PIECE_1, NEUTRAL])
	var slot := {"slot_id": "deck_slot", "zone_id": "board_area", "capacity": 1}
	slot["pose"] = _pose(1.2, 1.2)
	game.execute(_command(HOST, "slot.add", slot))
	var near := TableDropper.drop_object(game.tabletop, ids[0], "board_area", _pose(1.0, 1.0))
	check.call(near["placed_by"] == "slot", "a drop near a slot snaps to it")
	var far := TableDropper.drop_object(game.tabletop, ids[1], "board_area", _pose(3.1, 0.4))
	check.call(far["placed_by"] == "loose", "a drop far from slots stays loose")
	check.call(far["cell"] == {"x": 2, "y": 0}, "a loose drop knows its cell")
	var place := TableLocator.where_is(game.tabletop, ids[1])
	check.call(place["cell"] == {"x": 2, "y": 0}, "the table finds the loose object by its cell")
	var again := TableDropper.drop_object(game.tabletop, ids[1], "board_area", _pose(0, 0))
	check.call(not bool(again["ok"]), "an object already on the table cannot be dropped again")


static func _test_closed_table_drops(check: Callable) -> void:
	var game := _real_game(check)
	var ids := _picked_up(game, [PIECE_1, NEUTRAL])
	var slot := {"slot_id": "deck_slot", "zone_id": "board_area", "capacity": 1}
	slot["pose"] = _pose(1.2, 1.2)
	game.execute(_command(HOST, "slot.add", slot))
	var denied := game.execute(_command(GUEST, "table.set_mode", {"mode": "closed"}))
	check.call(denied["reason"] == "host_only", "a guest cannot close the table")
	game.execute(_command(HOST, "table.set_mode", {"mode": "closed"}))
	var loose := TableDropper.drop_object(game.tabletop, ids[0], "board_area", _pose(3.0, 0.0))
	check.call(loose["reason"] == "closed_table_needs_a_slot", "a closed table refuses it")
	check.call(not game.tabletop.is_placed(ids[0]), "a refused drop places nothing")
	var near := TableDropper.drop_object(game.tabletop, ids[1], "board_area", _pose(1.1, 1.1))
	check.call(near["placed_by"] == "slot", "a closed table accepts a drop near a slot")


static func _test_private_zone_is_invisible_to_the_other_player(check: Callable) -> void:
	var game := _real_game(check)
	var ids: Array[String] = [STACK_2, NEUTRAL]
	var slot := {"slot_id": "p2_slot", "zone_id": "player_2_area", "capacity": 2}
	game.execute(_command(HOST, "slot.add", slot))
	var privacy := {"zone_id": "player_2_area", "visibility": "private"}
	check.call(bool(game.execute(_command(HOST, "zone.set_visibility", privacy))["ok"]), "private")
	game.execute(_command(HOST, "turn.end", {}))
	check.call(_move(game, GUEST, ids[0], "p2_slot"), "player 2 puts a deck in its own zone")
	check.call(game.tabletop.containment.put_inside(ids[1], ids[0]), "a card goes in the deck")
	var hidden := TableVisibility.hidden_object_ids(game.tabletop, HOST)
	check.call(hidden.has(ids[0]) and hidden.has(ids[1]), "player 1 cannot see deck or card")
	check.call(TableVisibility.hidden_object_ids(game.tabletop, GUEST).is_empty(), "owner sees all")
	var seen := TableVisibility.snapshot_for_viewer(game.tabletop, game.to_dictionary(), HOST)
	check.call(not seen["objects"].has(ids[1]), "player 1's snapshot drops the hidden card")
	check.call(game.to_dictionary()["objects"].has(ids[1]), "the real state is untouched")


static func _test_a_snapshot_keeps_the_new_state(check: Callable) -> void:
	var game := _real_game(check)
	var ids: Array[String] = [STACK_2, NEUTRAL]
	game.execute(_command(HOST, "table.set_cell_size", {"cell_size_cm": 3}))
	game.tabletop.containment.put_inside(ids[1], ids[0])
	var restored := TabletopState.new()
	check.call(restored.load_dictionary(game.tabletop.to_dictionary()), "the snapshot loads")
	check.call(restored.config.cell_size_cm == 3.0, "the cell size survives")
	check.call(restored.containment.container_of(ids[1]) == ids[0], "the links survive")
	var broken := game.tabletop.to_dictionary()
	broken["containment"] = {"container_of": {"a": "b", "b": "a"}}
	check.call(not TabletopState.new().load_dictionary(broken), "a snapshot with a loop fails")


static func _real_game(check: Callable) -> GameplayState:
	var loaded := BgoGameDefinitionLoader.load_game(GAME_PATH)
	check.call(bool(loaded.get("ok", false)), "the real game test001 loads")
	var definition: Dictionary = loaded.get("data", {})
	var adapter := RuntimeSessionAdapter.new()
	var started := adapter.load_session("table-grid", definition, _repository_state(definition))
	check.call(bool(started.get("ok", false)), "the real game starts a session")
	return adapter.gameplay_state


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


## Picks real objects up from the table, the way the product does, so they can be dropped.
static func _picked_up(game: GameplayState, object_ids: Array[String]) -> Array[String]:
	for object_id in object_ids:
		game.tabletop.remove_object(object_id)
	return object_ids


static func _move(
	game: GameplayState, actor_id: String, object_id: String, slot_id: String
) -> bool:
	var args := {"slot_id": slot_id, "acquire_neutral": true}
	var command := _command(actor_id, "object.move", args)
	command["target_id"] = object_id
	return bool(game.execute(command).get("ok", false))


static func _command(actor_id: String, verb: String, args: Dictionary) -> Dictionary:
	return {"verb": verb, "actor_id": actor_id, "args": args}


static func _pose(x: float, z: float) -> Dictionary:
	return {"position": {"x": x, "y": 0.0, "z": z}, "rotation": ROTATION}
