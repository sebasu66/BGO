@tool
@icon("res://addons/lente/icons/lente_box_bound.svg")
class_name LenteBoxBound
extends LenteBoundVolume

## An oriented box that contributes to a LentePhotoMode's allowed space.

@export var size: Vector3 = Vector3(12.0, 8.0, 12.0):
	set(value):
		size = value.max(Vector3.ONE * 0.01)
		_notify_gizmo_changed()


func get_margin(world_position: Vector3) -> float:
	var local_position := to_local(world_position)
	var inner := size * 0.5 - local_position.abs()
	if inner.x >= 0.0 and inner.y >= 0.0 and inner.z >= 0.0:
		return minf(inner.x, minf(inner.y, inner.z)) * _minimum_global_scale()
	var outside := Vector3(maxf(-inner.x, 0.0), maxf(-inner.y, 0.0), maxf(-inner.z, 0.0))
	return -outside.length() * _minimum_global_scale()


func get_closest_point(world_position: Vector3) -> Vector3:
	var local_position := to_local(world_position)
	var half_size := size * 0.5
	var closest := local_position.clamp(-half_size, half_size)
	return to_global(closest)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01:
		warnings.append("The bound size is too small to contain the photo camera.")
	return warnings
