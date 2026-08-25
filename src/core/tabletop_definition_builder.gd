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
	var board := _find_board(game_definition, table)
	if not board.is_empty() and not _add_board(tabletop, board):
		return null
	var setup: Dictionary = game_definition.get("setup", {})
	var asset_box: Dictionary = setup.get("asset_box", {})
	if (
		not asset_box.is_empty()
		and not tabletop.configure_asset_box(
			str(asset_box.get("id", "game_box")),
			int(asset_box.get("point_columns", 0)),
			int(asset_box.get("point_rows", 0)),
			Vector2(5.0, 5.0),
			str(asset_box.get("label", "ASSET BOX"))
		)
	):
		return null
	return tabletop


static func _find_board(game_definition: Dictionary, table: Dictionary) -> Dictionary:
	for instance_variant in table.get("instances", []):
		if not instance_variant is Dictionary:
			continue
		var instance: Dictionary = instance_variant
		if BgoComponentRegistry.get_kind(str(instance.get("component", ""))) == "board":
			return instance
	var legacy: Variant = game_definition.get("board", {})
	return legacy if legacy is Dictionary else {}


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


static func _add_board(tabletop: TabletopState, board: Dictionary) -> bool:
	var config: Dictionary = board.get("config", {})
	var columns := int(config.get("columns", 0))
	var rows := int(config.get("rows", 0))
	if columns < 1 or rows < 1:
		return false
	if not tabletop.zones.has("board") and not tabletop.add_zone("board", "main"):
		return false
	for y in rows:
		for x in columns:
			var slot_id := "board:%d:%d" % [x, y]
			if not tabletop.slots.has(slot_id) and not tabletop.add_slot(slot_id, "board", 1):
				return false
	return true
