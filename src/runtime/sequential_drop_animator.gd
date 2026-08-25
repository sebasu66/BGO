class_name BgoSequentialDropAnimator
extends Node

signal item_landed(target: Node3D)
signal sequence_finished

const DEFAULT_DURATION_SECONDS := 0.2
const DEFAULT_DROP_HEIGHT := 3.0

var duration_seconds := DEFAULT_DURATION_SECONDS
var drop_height := DEFAULT_DROP_HEIGHT

var _queue: Array[Dictionary] = []
var _running := false


## Returns whether one or more staged drop animations are waiting to play.
func has_pending() -> bool:
	return _running or not _queue.is_empty()


## Adds a valid node and final position to the staged drop animation queue.
func enqueue(target: Node3D, final_position: Vector3) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	(
		_queue
		. append(
			{
				"target": target,
				"final_position": final_position,
				"collision_states": _disable_collisions(target),
			}
		)
	)
	target.visible = false
	return true


## Plays queued drop animations in sequence, optionally yielding one frame before the first drop.
func play(show_table_first := false) -> void:
	if _running:
		return
	_running = true
	if show_table_first:
		await get_tree().process_frame

	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		var target := entry.get("target") as Node3D
		if target == null or not is_instance_valid(target):
			continue
		var final_position: Vector3 = entry.get("final_position", target.position)
		target.position = final_position + Vector3.UP * drop_height
		target.visible = true
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(target, "position", final_position, duration_seconds)
		await tween.finished
		if not is_instance_valid(target):
			continue
		target.position = final_position
		_restore_collisions(entry.get("collision_states", []))
		item_landed.emit(target)

	_running = false
	sequence_finished.emit()


func _disable_collisions(root: Node) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	_collect_collision_states(root, states)
	for state in states:
		var body := state.get("node") as CollisionObject3D
		if body != null:
			body.collision_layer = 0
			body.collision_mask = 0
	return states


func _collect_collision_states(node: Node, states: Array[Dictionary]) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		states.append(
			{
				"node": body,
				"collision_layer": body.collision_layer,
				"collision_mask": body.collision_mask
			}
		)
	for child in node.get_children():
		_collect_collision_states(child, states)


func _restore_collisions(states: Array) -> void:
	for state_variant in states:
		if not state_variant is Dictionary:
			continue
		var state: Dictionary = state_variant
		var body := state.get("node") as CollisionObject3D
		if body == null or not is_instance_valid(body):
			continue
		body.collision_layer = int(state.get("collision_layer", 0))
		body.collision_mask = int(state.get("collision_mask", 0))
