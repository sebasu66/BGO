class_name TableVisibility
extends RefCounted

## What each player may see. Inside a private zone the other players see
## nothing: not the objects in it and not what those objects contain.


## Ids of everything the viewer must not see, including what is inside it.
static func hidden_object_ids(tabletop: TabletopState, viewer_id: String) -> Array[String]:
	var hidden: Array[String] = []
	for zone_id in tabletop.zones:
		var zone: Dictionary = tabletop.zones[zone_id]
		if _is_private_to_someone_else(zone, viewer_id):
			for object_id in _objects_in_zone(tabletop, str(zone_id)):
				_add_with_contents(tabletop, object_id, hidden)
	return hidden


## A copy of a gameplay snapshot with the hidden objects removed everywhere.
static func snapshot_for_viewer(
	tabletop: TabletopState, snapshot: Dictionary, viewer_id: String
) -> Dictionary:
	var seen: Dictionary = snapshot.duplicate(true)
	var hidden := hidden_object_ids(tabletop, viewer_id)
	var table_part: Dictionary = seen.get("tabletop", {})
	for object_id in hidden:
		(seen.get("objects", {}) as Dictionary).erase(object_id)
		(table_part.get("object_slots", {}) as Dictionary).erase(object_id)
		(table_part.get("object_poses", {}) as Dictionary).erase(object_id)
		_remove_from_slots(table_part.get("slots", {}), object_id)
	return seen


static func _is_private_to_someone_else(zone: Dictionary, viewer_id: String) -> bool:
	return (
		str(zone.get("visibility", "public")) == "private"
		and str(zone.get("owner_id", "")) != viewer_id
	)


static func _objects_in_zone(tabletop: TabletopState, zone_id: String) -> Array[String]:
	var found: Array[String] = []
	for object_id in tabletop.object_poses:
		if str(tabletop.object_poses[object_id]["zone_id"]) == zone_id:
			found.append(str(object_id))
	for slot_id in tabletop.zones[zone_id]["slot_ids"]:
		found.append_array(tabletop.slot_occupants(str(slot_id)))
	return found


static func _add_with_contents(
	tabletop: TabletopState, object_id: String, hidden: Array[String]
) -> void:
	if not hidden.has(object_id):
		hidden.append(object_id)
	for inside_id in tabletop.containment.everything_inside(object_id):
		if not hidden.has(inside_id):
			hidden.append(inside_id)


static func _remove_from_slots(slots: Dictionary, object_id: String) -> void:
	for slot_id in slots:
		(slots[slot_id]["occupants"] as Array).erase(object_id)
