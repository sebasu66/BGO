class_name MovableComponent
extends Node

signal move_requested(entity: BGOGameObject, target_position: Vector2)
signal moved(entity: BGOGameObject, from_position: Vector2, to_position: Vector2)

@export var snap_size: Vector2 = Vector2.ZERO
@export var enabled: bool = true

var entity: BGOGameObject

func _ready() -> void:
	entity = get_parent() as BGOGameObject
	if entity == null:
		push_error("MovableComponent must be a child of BGOGameObject.")

func request_move(target_position: Vector2) -> void:
	if not enabled or entity == null:
		return
	move_requested.emit(entity, _snap(target_position))

func apply_move(target_position: Vector2) -> void:
	if entity == null:
		return
	var from_position := entity.position
	var final_position := _snap(target_position)
	entity.position = final_position
	moved.emit(entity, from_position, final_position)

func _snap(value: Vector2) -> Vector2:
	if snap_size.x <= 0.0 or snap_size.y <= 0.0:
		return value
	return Vector2(
		round(value.x / snap_size.x) * snap_size.x,
		round(value.y / snap_size.y) * snap_size.y
	)
