@tool
class_name BgoBasicCylinderPiece
extends StaticBody3D

@export var piece_color := Color(0.95, 0.72, 0.22):
	set(value):
		piece_color = value
		_apply_visuals()
@export_range(1, 99, 1) var quantity: int = 1:
	set(value):
		quantity = maxi(value, 1)
		_apply_visuals()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var quantity_label: Label3D = $QuantityLabel


func _ready() -> void:
	_apply_visuals()


## Configures this object from the supplied project data.
func configure(
	entity_id: String, owner_id: String, holder_id: String, new_quantity: int, color: Color
) -> void:
	name = entity_id
	set_meta("bgo_piece", true)
	set_meta("entity_id", entity_id)
	set_meta("owner_id", owner_id)
	set_meta("holder_id", holder_id)
	set_meta("quantity", new_quantity)
	quantity = new_quantity
	piece_color = color
	_apply_visuals()


func _apply_visuals() -> void:
	if not is_inside_tree():
		return
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if quantity_label == null:
		quantity_label = get_node_or_null("QuantityLabel")
	if mesh_instance != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = piece_color
		material.roughness = 0.38
		material.metallic = 0.08
		mesh_instance.material_override = material
	if quantity_label != null:
		quantity_label.visible = quantity > 1
		quantity_label.text = str(quantity)
