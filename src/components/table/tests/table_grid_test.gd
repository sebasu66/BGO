class_name TableGridTest
extends RefCounted

const TABLETOP_STATE = preload("res://src/core/tabletop_state.gd")
const SCALE := 0.24
const ROTATION := {"x": 0, "y": 0, "z": 0}


## Runs the tests of cells, containment, dropping and private zones.
static func run(check: Callable) -> void:
	_test_cell_math(check)
	_test_containment_in_both_directions(check)
	_test_containment_refuses_loops(check)
	_test_where_is_and_what_is_at_cell(check)
	_test_open_table_magnet_and_snap(check)
	_test_closed_table_needs_slots(check)
	_test_private_zone_is_invisible_to_others(check)
	_test_cell_size_is_configurable(check)
	_test_containment_survives_a_snapshot(check)


static func _test_cell_math(check: Callable) -> void:
	var poker_card := Vector2(6.3, 8.8)
	check.call(
		TableCellMath.cells_covering(poker_card) == Vector2i(2, 2), "a card covers 2 x 2 cells"
	)
	check.call(
		TableCellMath.cells_covering(Vector2(3, 3)) == Vector2i(1, 1), "a token covers one cell"
	)
	check.call(
		TableCellMath.cells_covering(Vector2(5, 5)) == Vector2i(1, 1), "an exact fit stays one cell"
	)
	check.call(TableCellMath.cells_covering(poker_card, 4.0) == Vector2i(2, 3), "4 cm cells: 2 x 3")
	check.call(TableCellMath.cells_covering(poker_card, 3.0) == Vector2i(3, 3), "3 cm cells: 3 x 3")
	check.call(
		TableCellMath.cell_containing(Vector2(2.5, 7.0)) == Vector2i(0, 1),
		"a position finds its cell"
	)
	check.call(
		TableCellMath.cell_containing(Vector2(-0.1, -5.1)) == Vector2i(-1, -2),
		"negative cells work"
	)
	check.call(
		TableCellMath.cell_center_cm(Vector2i(0, 0)) == Vector2(2.5, 2.5),
		"a cell center is its middle"
	)
	var card_center := TableCellMath.group_center_cm(Vector2i(1, 1), Vector2i(2, 2))
	check.call(card_center == Vector2(10, 10), "a group is centered on its middle")


static func _test_containment_in_both_directions(check: Callable) -> void:
	var table := _new_table()
	table.add_slot("event_slot", "area", 1, {"anchor": {"kind": "table", "cell": [1, 1]}})
	table.place_object("event_deck", "event_slot")
	check.call(table.containment.put_inside("card-a", "event_deck"), "a card goes into the deck")
	check.call(table.containment.put_inside("card-b", "event_deck"), "a second card goes in")
	var down := table.containment.contents_of("event_deck")
	check.call(down == ["card-a", "card-b"], "the deck knows its cards in order")
	check.call(table.containment.container_of("card-a") == "event_deck", "the card knows its deck")
	var up := table.containment.containers_above("card-a")
	check.call(up == ["event_deck"], "the chain goes up from the card")
	check.call(table.containment.take_out("card-a"), "a card comes out of the deck")
	check.call(table.containment.contents_of("event_deck") == ["card-b"], "the deck forgets it")
	check.call(not table.containment.take_out("card-a"), "taking out twice is refused")


static func _test_containment_refuses_loops(check: Callable) -> void:
	var containment := TableContainmentState.new()
	check.call(containment.put_inside("card", "deck"), "a card goes into a deck")
	check.call(containment.put_inside("deck", "box"), "a deck goes into a box")
	check.call(not containment.put_inside("box", "card"), "a loop is refused")
	check.call(not containment.put_inside("card", "other"), "one object cannot be in two places")
	check.call(not containment.put_inside("x", "x"), "nothing contains itself")
	check.call(containment.everything_inside("box") == ["deck", "card"], "all depths")


static func _test_where_is_and_what_is_at_cell(check: Callable) -> void:
	var table := _new_table()
	table.add_slot("event_slot", "area", 1, {"anchor": {"kind": "table", "cell": [1, 1]}})
	table.place_object("event_deck", "event_slot")
	table.containment.put_inside("card-a", "event_deck")
	var card_place := TableLocator.where_is(table, "card-a")
	check.call(card_place["containers"] == ["event_deck"], "the card is in the deck")
	check.call(card_place["slot_id"] == "event_slot", "the card's deck is in the slot")
	check.call(card_place["cell"] == {"x": 1, "y": 1}, "the card is in cell (1, 1)")
	check.call(
		TableLocator.where_is(table, "ghost")["placed_by"] == "nowhere", "unknown is nowhere"
	)
	var here := TableLocator.what_is_at_cell(table, Vector2i(1, 1))
	var slot_report: Dictionary = here["slots"][0]
	check.call(slot_report["slot_id"] == "event_slot", "the cell reports its slot")
	check.call(slot_report["holds"][0]["object_id"] == "event_deck", "the slot reports its deck")
	check.call(slot_report["holds"][0]["inside"] == ["card-a"], "the deck reports its cards")
	check.call(
		TableLocator.what_is_at_cell(table, Vector2i(5, 5))["slots"].is_empty(),
		"an empty cell is empty"
	)


static func _test_open_table_magnet_and_snap(check: Callable) -> void:
	var table := _new_table()
	table.add_slot("deck_slot", "area", 1, {"pose": _pose(1.2, 1.2), "accepted_kinds": ["deck"]})
	var near := TableDropper.drop_object(table, "deck-1", "area", _pose(1.0, 1.0), "deck")
	check.call(
		near["placed_by"] == "slot" and near["slot_id"] == "deck_slot", "a drop near a slot snaps"
	)
	var far := TableDropper.drop_object(table, "coin", "area", _pose(3.1, 0.4), "token")
	check.call(far["placed_by"] == "loose", "a drop far from slots stays loose")
	check.call(far["cell"] == {"x": 2, "y": 0}, "a loose drop knows its cell")
	var snapped: Dictionary = table.object_poses["coin"]["pose"]["position"]
	check.call(
		is_equal_approx(snapped["x"], 2.5 * 5.0 * SCALE), "a loose drop is centered in its cell"
	)
	check.call(
		TableLocator.where_is(table, "coin")["cell"] == {"x": 2, "y": 0}, "the table finds it"
	)
	var wrong_kind := TableDropper.drop_object(table, "dice", "area", _pose(1.2, 1.2), "die")
	check.call(wrong_kind["placed_by"] == "loose", "a slot that refuses the kind does not pull")
	check.call(
		not TableDropper.drop_object(table, "coin", "area", _pose(0, 0))["ok"], "no double drop"
	)


static func _test_closed_table_needs_slots(check: Callable) -> void:
	var table := _new_table()
	table.add_slot("deck_slot", "area", 1, {"pose": _pose(1.2, 1.2)})
	table.config.set_mode("closed")
	var refused := TableDropper.drop_object(table, "coin", "area", _pose(3.0, 0.0))
	check.call(
		refused["reason"] == "closed_table_needs_a_slot", "a closed table refuses a loose drop"
	)
	check.call(not table.is_placed("coin"), "a refused drop places nothing")
	var accepted := TableDropper.drop_object(table, "coin", "area", _pose(1.1, 1.1))
	check.call(accepted["placed_by"] == "slot", "a closed table accepts a drop near a slot")


static func _test_private_zone_is_invisible_to_others(check: Callable) -> void:
	var table := _new_table()
	table.add_zone("p2_zone", "main", {"visibility": "private", "owner_id": "p2"})
	table.add_slot("p2_slot", "p2_zone", 1)
	table.place_object("p2_deck", "p2_slot")
	table.containment.put_inside("p2_card", "p2_deck")
	table.place_object("public_coin", "public_slot")
	check.call(
		TableVisibility.hidden_object_ids(table, "p1").has("p2_deck"), "others cannot see the deck"
	)
	check.call(
		TableVisibility.hidden_object_ids(table, "p1").has("p2_card"), "nor what is inside it"
	)
	check.call(
		TableVisibility.hidden_object_ids(table, "p2").is_empty(), "the owner sees everything"
	)
	check.call(
		not TableVisibility.hidden_object_ids(table, "p1").has("public_coin"),
		"public stays visible"
	)
	_test_filtered_snapshot(check, table)


static func _test_filtered_snapshot(check: Callable, table: TabletopState) -> void:
	var snapshot := {
		"objects": {"p2_deck": {}, "p2_card": {}, "public_coin": {}},
		"tabletop": table.to_dictionary()
	}
	var as_p1 := TableVisibility.snapshot_for_viewer(table, snapshot, "p1")
	check.call(not as_p1["objects"].has("p2_card"), "the filtered snapshot drops hidden objects")
	check.call(as_p1["objects"].has("public_coin"), "the filtered snapshot keeps public ones")
	check.call(not as_p1["tabletop"]["object_slots"].has("p2_deck"), "slots no longer list them")
	check.call(
		as_p1["tabletop"]["slots"]["p2_slot"]["occupants"].is_empty(), "occupants are removed"
	)
	check.call(snapshot["objects"].has("p2_card"), "the original snapshot is untouched")


static func _test_cell_size_is_configurable(check: Callable) -> void:
	var table := _new_table()
	check.call(table.config.cell_size_cm == 5.0, "the default cell is 5 cm")
	check.call(not table.config.set_cell_size(0), "a zero cell size is refused")
	check.call(not table.config.set_cell_size("big"), "a text cell size is refused")
	check.call(table.config.set_cell_size(4), "a game can choose another cell size")
	var snapshot := table.to_dictionary()
	var restored: TabletopState = TABLETOP_STATE.new()
	restored.load_dictionary(snapshot)
	check.call(restored.config.cell_size_cm == 4.0, "the cell size survives a snapshot")
	var from_game := TableConfigState.from_definition({"cell_size_cm": 3.0})
	check.call(from_game.cell_size_cm == 3.0, "a game definition sets the cell size")
	check.call(
		TableConfigState.from_definition({"cell_size_cm": -1}) == null, "a bad size is refused"
	)


static func _test_containment_survives_a_snapshot(check: Callable) -> void:
	var table := _new_table()
	table.containment.put_inside("card", "deck")
	var restored: TabletopState = TABLETOP_STATE.new()
	check.call(restored.load_dictionary(table.to_dictionary()), "a snapshot with links loads")
	check.call(restored.containment.container_of("card") == "deck", "the links survive")
	var broken := table.to_dictionary()
	broken["containment"] = {"container_of": {"a": "b", "b": "a"}}
	check.call(not restored.load_dictionary(broken), "a snapshot with a loop is refused")


static func _new_table() -> TabletopState:
	var table: TabletopState = TABLETOP_STATE.new()
	table.add_section("main")
	table.add_zone("area", "main")
	table.add_slot("public_slot", "area", 1)
	return table


static func _pose(x: float, z: float) -> Dictionary:
	return {"position": {"x": x, "y": 0.0, "z": z}, "rotation": ROTATION}
