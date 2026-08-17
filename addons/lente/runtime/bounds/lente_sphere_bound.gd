@tool
@icon("res://addons/lente/icons/lente_sphere_bound.svg")
class_name LenteSphereBound
extends LenteBoundVolume

## A spherical volume that contributes to a LentePhotoMode's allowed space.

@export_range(0.1, 10000.0, 0.1, "or_greater") var radius: float = 8.0:
	set(value):
		radius = maxf(value, 0.1)
		_notify_gizmo_changed()


func get_margin(world_position: Vector3) -> float:
	return (radius - to_local(world_position).length()) * _minimum_global_scale()


func get_closest_point(world_position: Vector3) -> Vector3:
	var local_position := to_local(world_position)
	if local_position.length_squared() <= radius * radius:
		return world_position
	if local_position.is_zero_approx():
		return to_global(Vector3.RIGHT * radius)
	return to_global(local_position.normalized() * radius)
