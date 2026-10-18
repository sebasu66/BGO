class_name TableLocator
extends RefCounted

## Answers "where is it?" and "what is here?" for the table, in both directions.
## It only reads the tabletop; it never moves anything.


## Where an object is: the containers above it, and the slot, zone and cell of
## the thing that physically sits on the table.
static func where_is(tabletop: TabletopState, object_id: String) -> Dictionary:
	var containers := tabletop.containment.containers_above(object_id)
	var on_the_table := containers[-1] if not containers.is_empty() else object_id
	var place := _physical_place(tabletop, on_the_table)
	place["object_id"] = object_id
	place["containers"] = containers
	place["on_the_table"] = on_the_table
	return place


## What is in one cell: the slots anchored there with what they hold (and what
## that holds in turn), plus the objects lying loose or on the grid there.
static func what_is_at_cell(tabletop: TabletopState, cell: Vector2i) -> Dictionary:
	var slots_here: Array = []
	for slot_id in tabletop.slots:
		var anchor_cell: Variant = _anchor_cell(tabletop.slots[slot_id])
		if anchor_cell == null or anchor_cell != cell:
			continue
		slots_here.append(_describe_slot(tabletop, str(slot_id)))
	return {
		"cell": {"x": cell.x, "y": cell.y}, "slots": slots_here, "loose": _loose_at(tabletop, cell)
	}


static func _physical_place(tabletop: TabletopState, object_id: String) -> Dictionary:
	var slot_id := tabletop.object_slot(object_id)
	if not slot_id.is_empty():
		var slot: Dictionary = tabletop.slots[slot_id]
		return {
			"placed_by": "slot",
			"slot_id": slot_id,
			"zone_id": str(slot["zone_id"]),
			"cell": _cell_as_dictionary(_anchor_cell(slot)),
		}
	if tabletop.object_poses.has(object_id):
		var loose: Dictionary = tabletop.object_poses[object_id]
		return {
			"placed_by": "loose",
			"slot_id": "",
			"zone_id": str(loose["zone_id"]),
			"cell": loose.get("cell"),
		}
	if tabletop.grid.has_object(object_id):
		var origin := tabletop.object_grid_origin(object_id)
		return {
			"placed_by": "grid", "slot_id": "", "zone_id": "", "cell": _cell_as_dictionary(origin)
		}
	return {"placed_by": "nowhere", "slot_id": "", "zone_id": "", "cell": null}


static func _describe_slot(tabletop: TabletopState, slot_id: String) -> Dictionary:
	var holds: Array = []
	for occupant_id in tabletop.slot_occupants(slot_id):
		holds.append(
			{
				"object_id": occupant_id,
				"inside": tabletop.containment.everything_inside(occupant_id)
			}
		)
	return {"slot_id": slot_id, "holds": holds}


static func _loose_at(tabletop: TabletopState, cell: Vector2i) -> Array:
	var found: Array = []
	for object_id in tabletop.object_poses:
		var stored_cell: Variant = tabletop.object_poses[object_id].get("cell")
		if stored_cell is Dictionary and _same_cell(stored_cell, cell):
			found.append(str(object_id))
	return found


static func _same_cell(stored_cell: Dictionary, cell: Vector2i) -> bool:
	return int(stored_cell.get("x", 0)) == cell.x and int(stored_cell.get("y", 0)) == cell.y


static func _anchor_cell(slot: Dictionary) -> Variant:
	var anchor: Dictionary = slot.get("anchor", {})
	var cell: Variant = anchor.get("cell")
	if cell is Array and (cell as Array).size() == 2:
		return Vector2i(int(cell[0]), int(cell[1]))
	return null


static func _cell_as_dictionary(cell: Variant) -> Variant:
	if cell is Vector2i:
		return {"x": (cell as Vector2i).x, "y": (cell as Vector2i).y}
	return null
