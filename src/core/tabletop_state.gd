class_name TabletopState
extends RefCounted

## Named logical tabletop sections keyed by stable section id.
var sections: Dictionary = {}

## Logical zones keyed by stable zone id.
var zones: Dictionary = {}

## Logical slots keyed by stable slot id.
var slots: Dictionary = {}

## Current logical slot for each placed object id.
var object_slots: Dictionary = {}


## Adds a named tabletop section.
func add_section(section_id: String) -> bool:
	if section_id.is_empty() or sections.has(section_id):
		return false
	sections[section_id] = {"zone_ids": []}
	return true


## Adds a zone owned by an existing section.
func add_zone(zone_id: String, section_id: String) -> bool:
	if zone_id.is_empty() or zones.has(zone_id) or not sections.has(section_id):
		return false
	zones[zone_id] = {"section_id": section_id, "slot_ids": []}
	var zone_ids: Array = sections[section_id]["zone_ids"]
	zone_ids.append(zone_id)
	return true


## Adds a slot owned by an existing zone with a positive capacity.
func add_slot(slot_id: String, zone_id: String, capacity: int = 1) -> bool:
	if slot_id.is_empty() or slots.has(slot_id) or not zones.has(zone_id) or capacity < 1:
		return false
	slots[slot_id] = {"zone_id": zone_id, "capacity": capacity, "occupants": []}
	var slot_ids: Array = zones[zone_id]["slot_ids"]
	slot_ids.append(slot_id)
	return true


## Places an unplaced object into a slot when capacity allows.
func place_object(object_id: String, slot_id: String) -> bool:
	if object_id.is_empty() or object_slots.has(object_id) or not can_accept(slot_id):
		return false
	var occupants: Array = slots[slot_id]["occupants"]
	occupants.append(object_id)
	object_slots[object_id] = slot_id
	return true


## Moves a placed object atomically to another slot when the destination is valid.
func move_object(object_id: String, target_slot_id: String) -> bool:
	if not object_slots.has(object_id):
		return false
	var source_slot_id := str(object_slots[object_id])
	if source_slot_id == target_slot_id or not can_accept(target_slot_id):
		return false
	var source_occupants: Array = slots[source_slot_id]["occupants"]
	var target_occupants: Array = slots[target_slot_id]["occupants"]
	source_occupants.erase(object_id)
	target_occupants.append(object_id)
	object_slots[object_id] = target_slot_id
	return true


## Removes an object from its current logical slot.
func remove_object(object_id: String) -> bool:
	if not object_slots.has(object_id):
		return false
	var slot_id := str(object_slots[object_id])
	var occupants: Array = slots[slot_id]["occupants"]
	occupants.erase(object_id)
	object_slots.erase(object_id)
	return true


## Returns whether a slot exists and currently has free capacity.
func can_accept(slot_id: String) -> bool:
	if not slots.has(slot_id):
		return false
	var slot: Dictionary = slots[slot_id]
	var occupants: Array = slot["occupants"]
	return occupants.size() < int(slot["capacity"])


## Returns a copy of the current occupants for a slot.
func slot_occupants(slot_id: String) -> Array[String]:
	var result: Array[String] = []
	if not slots.has(slot_id):
		return result
	for object_id in slots[slot_id]["occupants"]:
		result.append(str(object_id))
	return result


## Returns the logical slot containing an object, or an empty string when unplaced.
func object_slot(object_id: String) -> String:
	return str(object_slots.get(object_id, ""))


## Returns a deep-copy snapshot suitable for tests and persistence adapters.
func to_dictionary() -> Dictionary:
	return {
		"sections": sections.duplicate(true),
		"zones": zones.duplicate(true),
		"slots": slots.duplicate(true),
		"object_slots": object_slots.duplicate(true),
	}
