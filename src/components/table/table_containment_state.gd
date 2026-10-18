class_name TableContainmentState
extends RefCounted

## Who holds whom. A card is inside a deck; a deck sits in a slot. This class
## only remembers the "is inside" links, in both directions, so the table can
## walk from a card up to its deck and from a deck down to its cards.

var _container_of: Dictionary = {}
var _contents_of: Dictionary = {}


## Puts an object inside a container, at the end of its contents.
## Refused when either id is empty, the object is already inside something,
## or the container is the object itself or already inside the object.
func put_inside(object_id: String, container_id: String) -> bool:
	if object_id.is_empty() or container_id.is_empty() or object_id == container_id:
		return false
	if _container_of.has(object_id):
		return false
	if containers_above(container_id).has(object_id):
		return false
	_container_of[object_id] = container_id
	var contents: Array = _contents_of.get(container_id, [])
	contents.append(object_id)
	_contents_of[container_id] = contents
	return true


## Takes an object out of whatever holds it.
func take_out(object_id: String) -> bool:
	if not _container_of.has(object_id):
		return false
	var container_id := str(_container_of[object_id])
	var contents: Array = _contents_of[container_id]
	contents.erase(object_id)
	if contents.is_empty():
		_contents_of.erase(container_id)
	_container_of.erase(object_id)
	return true


## The container that directly holds an object, or an empty text.
func container_of(object_id: String) -> String:
	return str(_container_of.get(object_id, ""))


## The objects directly inside a container, in order.
func contents_of(container_id: String) -> Array[String]:
	var result: Array[String] = []
	for object_id in _contents_of.get(container_id, []):
		result.append(str(object_id))
	return result


## Every container above an object, the nearest first: card -> deck -> box.
func containers_above(object_id: String) -> Array[String]:
	var result: Array[String] = []
	var current := container_of(object_id)
	while not current.is_empty() and not result.has(current):
		result.append(current)
		current = container_of(current)
	return result


## Everything inside a container at any depth.
func everything_inside(container_id: String) -> Array[String]:
	var result: Array[String] = []
	for object_id in contents_of(container_id):
		result.append(object_id)
		result.append_array(everything_inside(object_id))
	return result


## A deterministic copy for snapshots.
func to_dictionary() -> Dictionary:
	return {"container_of": _container_of.duplicate(true)}


## Replaces the links with a snapshot. A broken snapshot changes nothing.
func load_dictionary(snapshot: Dictionary) -> bool:
	var links: Variant = snapshot.get("container_of", {})
	if not links is Dictionary:
		return false
	var loaded := TableContainmentState.new()
	for object_id in links:
		if not loaded.put_inside(str(object_id), str(links[object_id])):
			return false
	_container_of = loaded._container_of
	_contents_of = loaded._contents_of
	return true
