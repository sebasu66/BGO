class_name BgoPlayerHandController
extends RefCounted


func build_raw_items(
	pieces: Dictionary, player_id: String, color_for_owner: Callable
) -> Array:
	var raw_items: Array = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if piece == null:
			continue
		if str(piece.get_meta("location_type", "slot")) != "hand":
			continue
		if str(piece.get_meta("holder_id", "")) != player_id:
			continue
		raw_items.append(
			{
				"id": str(key),
				"label": str(key).to_upper().replace("_", " "),
				"quantity": int(piece.get_meta("quantity", 1)),
				"component_id": str(piece.get_meta("component_id", "")),
				"owner_id": str(piece.get_meta("owner_id", "")),
				"color": color_for_owner.call(str(piece.get_meta("owner_id", player_id))),
				"hand_order": float(piece.get_meta("hand_order", 0.0)),
				"stack_key": str(piece.get_meta("hand_stack_key", str(key))),
			}
		)
	raw_items.sort_custom(_sort_items)
	return raw_items


func resolve_selected_id(raw_items: Array, selected_piece: Node3D, player_id: String) -> String:
	if raw_items.is_empty():
		return ""
	if (
		selected_piece != null
		and str(selected_piece.get_meta("location_type", "")) == "hand"
		and str(selected_piece.get_meta("holder_id", "")) == player_id
	):
		return str(selected_piece.get_meta("entity_id", ""))
	return str((raw_items[0] as Dictionary).get("id", ""))


func stack_items(raw_items: Array, selected_id: String) -> Array:
	var grouped: Dictionary = {}
	var order: Array[String] = []
	for value in raw_items:
		if not value is Dictionary:
			continue
		var item: Dictionary = value
		var stack_key := str(item.get("stack_key", item.get("id", "")))
		if not grouped.has(stack_key):
			var group := item.duplicate(true)
			group["member_ids"] = [str(item.get("id", ""))]
			grouped[stack_key] = group
			order.append(stack_key)
			continue
		var group: Dictionary = grouped[stack_key]
		group["quantity"] = int(group.get("quantity", 1)) + int(item.get("quantity", 1))
		var member_ids: Array = group.get("member_ids", [])
		member_ids.append(str(item.get("id", "")))
		group["member_ids"] = member_ids
		if not selected_id.is_empty() and member_ids.has(selected_id):
			group["id"] = selected_id
		grouped[stack_key] = group
	var result: Array = []
	for stack_key in order:
		result.append(grouped[stack_key])
	return result


func top_piece_id(pieces: Dictionary, player_id: String) -> String:
	var candidates: Array[Dictionary] = []
	for key in pieces.keys():
		var piece := pieces[key] as Node3D
		if (
			piece != null
			and str(piece.get_meta("location_type", "")) == "hand"
			and str(piece.get_meta("holder_id", "")) == player_id
		):
			candidates.append(
				{"id": str(key), "hand_order": float(piece.get_meta("hand_order", 0.0))}
			)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(_sort_items)
	return str(candidates[0].get("id", ""))


func _sort_items(left: Dictionary, right: Dictionary) -> bool:
	var left_order := float(left.get("hand_order", 0.0))
	var right_order := float(right.get("hand_order", 0.0))
	if is_equal_approx(left_order, right_order):
		return str(left.get("id", "")) < str(right.get("id", ""))
	return left_order > right_order
