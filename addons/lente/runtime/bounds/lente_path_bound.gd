@tool
@icon("res://addons/lente/icons/lente_path_bound.svg")
class_name LentePathBound
extends LenteBoundVolume

## A tube-shaped corridor following a Curve3D.

@export var curve: Curve3D:
	set(value):
		if curve and curve.changed.is_connected(_on_curve_changed):
			curve.changed.disconnect(_on_curve_changed)
		curve = value
		if curve and not curve.changed.is_connected(_on_curve_changed):
			curve.changed.connect(_on_curve_changed)
		_notify_gizmo_changed()

@export_range(0.1, 1000.0, 0.1, "or_greater") var radius: float = 3.0:
	set(value):
		radius = maxf(value, 0.1)
		_notify_gizmo_changed()


func _ready() -> void:
	if curve and not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)


func get_margin(world_position: Vector3) -> float:
	var local_position := to_local(world_position)
	var closest := Vector3.ZERO
	if curve and curve.point_count > 0:
		closest = curve.get_closest_point(local_position)
	return (radius - local_position.distance_to(closest)) * _minimum_global_scale()


func get_closest_point(world_position: Vector3) -> Vector3:
	var local_position := to_local(world_position)
	var center := Vector3.ZERO
	if curve and curve.point_count > 0:
		center = curve.get_closest_point(local_position)
	var offset := local_position - center
	if offset.length_squared() <= radius * radius:
		return world_position
	if offset.is_zero_approx():
		offset = Vector3.UP
	return to_global(center + offset.normalized() * radius)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not curve or curve.point_count < 2:
		warnings.append("The corridor needs a Curve3D with at least two points.")
	return warnings


func _on_curve_changed() -> void:
	_notify_gizmo_changed()
