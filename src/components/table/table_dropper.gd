class_name TableDropper
extends RefCounted

## What happens when something is let go on the table.
## A closed table accepts the drop only into a slot. An open table pulls the drop
## into a nearby slot (the magnet); anywhere else it stays loose, but it is
## snapped to the middle of a grid cell so the table always knows its cell.


## Drops an unplaced object at a pose. Returns {"ok", "placed_by", "slot_id", "cell"}
## or {"ok": false, "reason"}.
static func drop_object(
	tabletop: TabletopState,
	object_id: String,
	zone_id: String,
	pose: Dictionary,
	component_kind: String = ""
) -> Dictionary:
	if object_id.is_empty() or tabletop.is_placed(object_id) or not tabletop.zones.has(zone_id):
		return _refused("cannot_drop")
	var slot_id := nearest_slot(tabletop, zone_id, pose, component_kind)
	if not slot_id.is_empty():
		tabletop.place_object(object_id, slot_id, component_kind)
		return {"ok": true, "placed_by": "slot", "slot_id": slot_id}
	if tabletop.config.is_closed():
		return _refused("closed_table_needs_a_slot")
	return _drop_loose(tabletop, object_id, zone_id, pose, component_kind)


## The slot of the zone that pulls this pose in, or an empty text.
## A slot pulls when it is within one cell, has room and accepts the object.
static func nearest_slot(
	tabletop: TabletopState, zone_id: String, pose: Dictionary, component_kind: String
) -> String:
	var reach_units: float = tabletop.config.cell_size_cm * tabletop.config.world_units_per_cm
	var best_slot_id := ""
	var best_distance: float = reach_units
	for slot_id in tabletop.zones[zone_id]["slot_ids"]:
		var slot: Dictionary = tabletop.slots[slot_id]
		if slot["pose"].is_empty() or not tabletop.can_accept(str(slot_id), component_kind):
			continue
		var distance: float = _flat_distance(pose, slot["pose"])
		if distance <= best_distance:
			best_distance = distance
			best_slot_id = str(slot_id)
	return best_slot_id


static func _drop_loose(
	tabletop: TabletopState,
	object_id: String,
	zone_id: String,
	pose: Dictionary,
	component_kind: String
) -> Dictionary:
	var settings: TableConfigState = tabletop.config
	var position: Dictionary = pose["position"]
	var position_cm := (
		Vector2(float(position.get("x", 0.0)), float(position.get("z", 0.0)))
		/ settings.world_units_per_cm
	)
	var cell := TableCellMath.cell_containing(position_cm, settings.cell_size_cm)
	var middle_cm := TableCellMath.cell_center_cm(cell, settings.cell_size_cm)
	var snapped_pose: Dictionary = pose.duplicate(true)
	snapped_pose["position"] = {
		"x": middle_cm.x * settings.world_units_per_cm,
		"y": float(position.get("y", 0.0)),
		"z": middle_cm.y * settings.world_units_per_cm,
	}
	if not tabletop.place_object_free(object_id, zone_id, snapped_pose, component_kind):
		return _refused("drop_outside_the_zone")
	var cell_record := {"x": cell.x, "y": cell.y}
	tabletop.object_poses[object_id]["cell"] = cell_record
	return {"ok": true, "placed_by": "loose", "slot_id": "", "cell": cell_record}


static func _flat_distance(first_pose: Dictionary, second_pose: Dictionary) -> float:
	var first: Dictionary = first_pose["position"]
	var second: Dictionary = second_pose["position"]
	var first_point := Vector2(float(first.get("x", 0.0)), float(first.get("z", 0.0)))
	var second_point := Vector2(float(second.get("x", 0.0)), float(second.get("z", 0.0)))
	return first_point.distance_to(second_point)


static func _refused(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
