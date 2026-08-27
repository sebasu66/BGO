@tool
class_name BgoSlot
extends Area3D

@export var slot_id := "slot"
@export var size := Vector2(1.0, 1.0):
	set(value):
		size = Vector2(maxf(value.x, 0.01), maxf(value.y, 0.01))
		_refresh_visuals()
@export_range(1, 1000, 1) var capacity := 1
@export var accepted_kinds: PackedStringArray = []
@export var visible_marker := true
@export var marker_color := Color(0.35, 0.8, 0.55, 0.18)


func _ready() -> void:
	set_meta("bgo_slot", true)
	_refresh_visuals()


func accepts(component_kind: String) -> bool:
	return accepted_kinds.is_empty() or accepted_kinds.has(component_kind)


func configure_generated(
	new_id: String,
	new_size: Vector2,
	new_capacity: int,
	new_accepted_kinds: PackedStringArray
) -> void:
	slot_id = new_id
	size = new_size
	capacity = maxi(new_capacity, 1)
	accepted_kinds = new_accepted_kinds
	set_meta("slot_id", slot_id)
	set_meta("capacity", capacity)
	_refresh_visuals()


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	var marker := get_node_or_null("Marker") as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = "Marker"
		add_child(marker)
	var quad := QuadMesh.new()
	quad.size = size
	marker.mesh = quad
	marker.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	marker.position.y = 0.02
	marker.visible = visible_marker
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = marker_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.material_override = material
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		add_child(collision)
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.08, size.y)
	collision.shape = shape
