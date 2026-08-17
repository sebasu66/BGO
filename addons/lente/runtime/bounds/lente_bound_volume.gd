@tool
@icon("res://addons/lente/icons/lente_bound.svg")
class_name LenteBoundVolume
extends Node3D

## Base class for volumes that define the union of allowed photo-mode positions.


func get_margin(_world_position: Vector3) -> float:
	return -INF


func get_closest_point(world_position: Vector3) -> Vector3:
	return world_position


func contains_point(world_position: Vector3) -> bool:
	return get_margin(world_position) >= 0.0


func _notify_gizmo_changed() -> void:
	if Engine.is_editor_hint():
		update_gizmos()
		notify_property_list_changed()


func _minimum_global_scale() -> float:
	var global_basis := global_transform.basis
	return maxf(0.0001, minf(global_basis.x.length(), minf(global_basis.y.length(), global_basis.z.length())))
