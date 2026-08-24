@tool
class_name BgoBasicCylinderPiece
extends StaticBody3D

signal component_event(event_name: String, payload: Dictionary)

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
	set_meta("bgo_placeable", true)
	set_meta("bgo_placement_anchor", "base_center")
	_apply_visuals()
	component_event.emit(
		"ready", {"entity_id": str(get_meta("entity_id", name)), "quantity": quantity}
	)


## Placeable pieces use their root origin at the centre of the supporting base.
func placement_anchor() -> String:
	return "base_center"


func is_stackable() -> bool:
	return true


func _api_get_name() -> String:
	return str(get_meta("entity_id", name))


func _api_get_desc() -> String:
	return "Stackable basic cylinder piece"


func _api_get_owner() -> String:
	return str(get_meta("owner_id", ""))


func _api_get_holder() -> String:
	return str(get_meta("holder_id", ""))


func _api_get_quantity() -> int:
	return quantity


func console_api() -> Dictionary:
	return {
		"scope": "Match",
		"entity": _api_get_name(),
		"class": "BgoBasicCylinderPiece",
		"description": "Curated logical view of a cylinder piece.",
		"methods":
		{
			"getName": {"call": "_api_get_name", "returns": "String"},
			"getDesc": {"call": "_api_get_desc", "returns": "String"},
			"getOwner": {"call": "_api_get_owner", "returns": "String"},
			"getHolder": {"call": "_api_get_holder", "returns": "String"},
			"getQuantity": {"call": "_api_get_quantity", "returns": "int"},
			"isStackable": {"call": "is_stackable", "returns": "bool"},
		},
	}


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
	component_event.emit(
		"configured",
		{"entity_id": entity_id, "owner_id": owner_id, "holder_id": holder_id, "quantity": quantity}
	)


## Optional developer-console help for this component's public methods.
func console_help() -> Dictionary:
	return {
		"_summary": "Developer commands for a logical cylinder piece.",
		"configure": "Updates identity, ownership metadata, quantity, and color.",
	}


func menu_actions(viewer_role: String, viewer_id: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = [
		{"id": "details", "label": "DETALLES", "authority": "read"},
		{"id": "details-2", "label": "DETALLES DEL COMPONENTE", "authority": "read"},
	]
	var is_host := viewer_role == "host"
	var is_owner := str(get_meta("owner_id", "")) == viewer_id
	if is_host or is_owner:
		actions.append({"id": "take", "label": "TOMAR", "authority": "control"})
		actions.append({"id": "move", "label": "MOVER", "authority": "control", "submenu": true})
	if is_host:
		actions.append({"id": "duplicate", "label": "DUPLICAR", "authority": "control"})
		actions.append(
			{"id": "change_owner", "label": "CAMBIAR PROPIETARIO", "authority": "control"}
		)
		actions.append({"id": "delete", "label": "BORRAR", "authority": "control"})
	return actions


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
