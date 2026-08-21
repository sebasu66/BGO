class_name TabletopDefinitionBuilder
extends RefCounted


## Builds authoritative tabletop structure from one validated game definition.
static func build(game_definition: Dictionary) -> TabletopState:
	var tabletop := TabletopState.new()
	if not tabletop.add_section("main"):
		return null
	var table: Dictionary = game_definition.get("table", {})
	if not _add_areas(tabletop, table.get("areas", [])):
		return null
	if not _add_board(tabletop, game_definition.get("board", {})):
		return null
	return tabletop


static func _add_areas(tabletop: TabletopState, areas: Variant) -> bool:
	if not areas is Array:
		return false
	for area_variant in areas:
		if not area_variant is Dictionary or not _add_area(tabletop, area_variant):
			return false
	return true


static func _add_area(tabletop: TabletopState, area: Dictionary) -> bool:
	var area_id := str(area.get("id", ""))
	if not tabletop.add_zone(area_id, "main", area):
		return false
	var slots: Variant = area.get("slots", [])
	if not slots is Array:
		return false
	for slot_variant in slots:
		if not slot_variant is Dictionary:
			return false
		var slot: Dictionary = slot_variant
		if not tabletop.add_slot(
			str(slot.get("id", "")), area_id, int(slot.get("capacity", 1)), slot
		):
			return false
	return true


static func _add_board(tabletop: TabletopState, board: Variant) -> bool:
	if not board is Dictionary or board.is_empty():
		return true
	var config: Dictionary = board.get("config", {})
	var columns := int(config.get("columns", 0))
	var rows := int(config.get("rows", 0))
	if columns < 1 or rows < 1 or not tabletop.add_zone("board", "main"):
		return false
	for y in rows:
		for x in columns:
			if not tabletop.add_slot("board:%d:%d" % [x, y], "board", 1):
				return false
	return true
