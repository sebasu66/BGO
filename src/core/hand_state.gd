class_name HandState
extends RefCounted

## Logical hand for one participant. The hand stores order and identity only;
## its visual representation is a viewport-attached UI component.

var player_id: String = ""
var object_ids: Array[String] = []


static func create(p_player_id: String) -> HandState:
	var state := HandState.new()
	state.player_id = p_player_id
	return state


## Adds an object to the top of the FILO hand.
func add_object(object_id: String) -> bool:
	if object_id.is_empty() or object_ids.has(object_id):
		return false
	object_ids.push_front(object_id)
	return true


## Removes one object while preserving the remaining hand order.
func remove_object(object_id: String) -> bool:
	if not object_ids.has(object_id):
		return false
	object_ids.erase(object_id)
	return true


func contains(object_id: String) -> bool:
	return object_ids.has(object_id)


## Returns the first visible/FILO object, or an empty id when the hand is empty.
func top_object_id() -> String:
	return str(object_ids[0]) if not object_ids.is_empty() else ""


func to_array() -> Array[String]:
	return object_ids.duplicate()


func to_dictionary() -> Dictionary:
	return {"player_id": player_id, "object_ids": object_ids.duplicate()}
