class_name BgoAssetPlacerGridBridge
extends RefCounted

## Finds the first BGO table grid in the edited scene.
static func find_grid(scene_root: Node) -> Node:
	if scene_root == null:
		return null
	if scene_root.has_method("world_to_point") and scene_root.has_method("snap_world_position"):
		return scene_root
	for child in scene_root.get_children():
		var grid := find_grid(child)
		if grid != null:
			return grid
	return null


## Snaps Asset Placer's preview position to the BGO grid when one is present.
static func snap_position(position: Vector3, scene_root: Node) -> Vector3:
	var grid: Node = find_grid(scene_root)
	if grid == null:
		return position
	var point: Vector2i = grid.call("world_to_point", position)
	if not bool(grid.call("is_valid_point", point)):
		return position
	return grid.call("snap_world_position", position)


## Adds stable placement metadata for the runtime/editor bridge to consume later.
static func annotate_placed_node(node: Node3D, scene_root: Node) -> void:
	var grid: Node = find_grid(scene_root)
	if grid == null or node == null:
		return
	var footprint: Vector2i = node.get_meta("bgo_grid_footprint", Vector2i.ONE)
	var metadata: Dictionary = grid.call("placement_metadata", node.global_position, footprint)
	node.set_meta("bgo_placeable", true)
	node.set_meta("bgo_grid_path", metadata["grid_path"])
	node.set_meta("bgo_grid_origin", metadata["origin"])
	node.set_meta("bgo_grid_footprint", metadata["footprint"])
	node.set_meta("bgo_grid_spacing_cm", metadata["point_spacing_cm"])
