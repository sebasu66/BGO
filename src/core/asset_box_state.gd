class_name AssetBoxState
extends RefCounted

## Logical catalog/container for assets declared by a game package.
##
## The Asset Placer palette/grid is a presentation and authoring surface. The
## runtime box intentionally does not track physical positions or occupancy.
## Its source of truth is membership, quantity, availability and ownership.

var box_id: String = "box"
var label: String = "ASSET BOX"

## Asset instances keyed by stable object id.
## Each value stores only logical catalog data.
var assets: Dictionary = {}


## Configures an empty logical catalog. Existing assets are never discarded implicitly.
func configure(
	p_box_id: String,
	_point_columns: int = 0,
	_point_rows: int = 0,
	_point_spacing_cm: Vector2 = Vector2(5.0, 5.0),
	p_label: String = "ASSET BOX"
) -> bool:
	if p_box_id.is_empty() or not assets.is_empty():
		return false
	box_id = p_box_id
	label = p_label if not p_label.is_empty() else "ASSET BOX"
	return true


## Returns whether the catalog has a usable logical identity.
func is_configured() -> bool:
	return not box_id.is_empty()


## Adds a game-defined asset instance to the catalog.
func add_asset(
	object_id: String,
	component_id: String,
	config: Dictionary = {},
	quantity: int = 1,
	_origin: Vector2i = Vector2i(-1, -1),
	_footprint: Vector2i = Vector2i.ONE,
	_allow_overlap: bool = false,
	availability_mode: String = "unique",
	owner_id: String = "",
	available_quantity: int = -1
) -> bool:
	if (
		object_id.is_empty()
		or component_id.is_empty()
		or quantity < 1
		or assets.has(object_id)
	):
		return false
	assets[object_id] = {
		"component_id": component_id,
		"config": config.duplicate(true),
		"quantity": quantity,
		"available_quantity": available_quantity if available_quantity > 0 else quantity,
		"availability": availability_mode,
		"owner_id": owner_id,
	}
	return true


## Returns whether an asset instance is currently stored in this box.
func has_asset(object_id: String) -> bool:
	return assets.has(object_id)


## Returns stable asset ids in deterministic order.
func asset_ids() -> Array[String]:
	var result: Array[String] = []
	for object_id in assets:
		result.append(str(object_id))
	result.sort()
	return result


## Returns a defensive copy of one asset definition, or an empty dictionary.
func get_asset(object_id: String) -> Dictionary:
	if not assets.has(object_id):
		return {}
	return (assets[object_id] as Dictionary).duplicate(true)


## Removes an asset from the catalog and returns its logical definition.
func remove_asset(object_id: String) -> Dictionary:
	if not assets.has(object_id):
		return {}
	var result := get_asset(object_id)
	assets.erase(object_id)
	return result


## Compatibility helper for callers that used the old physical-box API.
## The conceptual catalog has no placement points, so every request resolves to
## the same neutral origin and callers must not use it for occupancy checks.
func find_free_origin(_footprint: Vector2i = Vector2i.ONE) -> Vector2i:
	return Vector2i.ZERO


## Deprecated compatibility query. The box has no physical occupancy.
func objects_at(_point: Vector2i) -> Array[String]:
	return []


## Deprecated compatibility query. The box has no physical occupancy.
func objects_in_area(_from_point: Vector2i, _to_point: Vector2i) -> Array[String]:
	return []


## Returns a defensive snapshot for persistence and network adapters.
func to_dictionary() -> Dictionary:
	return {
		"box_id": box_id,
		"label": label,
		"assets": assets.duplicate(true),
	}
