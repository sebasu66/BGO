@tool
class_name BgoBasicCylinderPiece
extends StaticBody3D

signal component_event(event_name: String, payload: Dictionary)

@export_enum("cylinder", "cube", "cone", "sphere") var piece_shape := "cylinder":
	set(value):
		piece_shape = value if value in ["cylinder", "cube", "cone", "sphere"] else "cylinder"
		_apply_visuals()
@export_range(0.1, 2.0, 0.01) var piece_radius := 0.38:
	set(value):
		piece_radius = clampf(value, 0.1, 2.0)
		_apply_visuals()
@export_range(0.05, 2.0, 0.01) var piece_height := 0.32:
	set(value):
		piece_height = clampf(value, 0.05, 2.0)
		_apply_visuals()
@export var piece_color := Color(0.95, 0.72, 0.22):
	set(value):
		piece_color = value
		_apply_visuals()
@export_range(0.0, 1.0, 0.01) var material_roughness := 0.38:
	set(value):
		material_roughness = clampf(value, 0.0, 1.0)
		_apply_visuals()
@export_range(0.0, 1.0, 0.01) var material_metallic := 0.08:
	set(value):
		material_metallic = clampf(value, 0.0, 1.0)
		_apply_visuals()
@export_range(0.0, 5.0, 0.05) var emission_strength := 0.0:
	set(value):
		emission_strength = clampf(value, 0.0, 5.0)
		_apply_visuals()
@export_range(1, 99, 1) var quantity: int = 1:
	set(value):
		quantity = maxi(value, 1)
		_apply_visuals()

var _owner_color := Color(0.95, 0.72, 0.22)
var _color_source := "player"
var _configuration: Dictionary = {}

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
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


## Returns whether this simple geometric piece can represent a quantity stack.
func is_stackable() -> bool:
	return true


## Updates the rendered primitive shape when the value is supported.
func set_shape(value: String) -> bool:
	if value not in ["cylinder", "cube", "cone", "sphere"]:
		return false
	piece_shape = value
	_configuration["shape"] = value
	return true


## Updates the rendered horizontal radius or half-width.
func set_radius(value: float) -> void:
	piece_radius = value
	_configuration["radius"] = piece_radius


## Updates the rendered piece height.
func set_height(value: float) -> void:
	piece_height = value
	_configuration["height"] = piece_height


## Selects owner-derived or fixed component color.
func set_color_source(value: String) -> bool:
	if value not in ["player", "fixed"]:
		return false
	_color_source = value
	_configuration["color_source"] = value
	piece_color = _owner_color if value == "player" else piece_color
	return true


## Updates the fixed component color from a CSS-style string.
func set_color_string(value: String) -> bool:
	var parsed := Color.from_string(value, Color.TRANSPARENT)
	if parsed == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	_configuration["color"] = value
	if _color_source == "fixed":
		piece_color = parsed
	return true


## Updates material roughness within the manifest range.
func set_roughness(value: float) -> void:
	material_roughness = value
	_configuration["roughness"] = material_roughness


## Updates material metallic response within the manifest range.
func set_metallic(value: float) -> void:
	material_metallic = value
	_configuration["metallic"] = material_metallic


## Updates material emission strength within the manifest range.
func set_emission_strength(value: float) -> void:
	emission_strength = value
	_configuration["emission_strength"] = emission_strength


## Applies manifest-validated appearance configuration to this runtime piece.
func apply_configuration(config: Dictionary) -> void:
	_configuration = config.duplicate(true)
	if config.has("shape"):
		piece_shape = str(config["shape"])
	if config.has("radius"):
		piece_radius = float(config["radius"])
	if config.has("height"):
		piece_height = float(config["height"])
	if config.has("roughness"):
		material_roughness = float(config["roughness"])
	if config.has("metallic"):
		material_metallic = float(config["metallic"])
	if config.has("emission_strength"):
		emission_strength = float(config["emission_strength"])
	_color_source = str(config.get("color_source", _color_source))
	if _color_source == "fixed":
		piece_color = Color.from_string(str(config.get("color", "#ffffff")), piece_color)
	else:
		piece_color = _owner_color
	_apply_visuals()
	(
		component_event
		. emit(
			"appearance_configured",
			{
				"entity_id": str(get_meta("entity_id", name)),
				"shape": piece_shape,
				"roughness": material_roughness,
				"metallic": material_metallic,
				"emission_strength": emission_strength,
			}
		)
	)


func _api_get_name() -> String:
	return str(get_meta("entity_id", name))


func _api_get_desc() -> String:
	return "Stackable configurable geometric piece"


func _api_get_owner() -> String:
	return str(get_meta("owner_id", ""))


func _api_get_holder() -> String:
	return str(get_meta("holder_id", ""))


func _api_get_quantity() -> int:
	return quantity


## Returns the curated developer-console API for this logical piece.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.piece.basic_cylinder",
			"BgoBasicCylinderPiece",
			"Curated logical view and appearance controls for a geometric piece.",
			{
				"getName": {"call": "_api_get_name", "returns": "String"},
				"getDesc": {"call": "_api_get_desc", "returns": "String"},
				"getOwner": {"call": "_api_get_owner", "returns": "String"},
				"getHolder": {"call": "_api_get_holder", "returns": "String"},
				"getQuantity": {"call": "_api_get_quantity", "returns": "int"},
				"isStackable": BgoComponentApiDescriptor.method("is_stackable", [], "bool"),
				"setShape":
				BgoComponentApiDescriptor.setter("set_shape", "shape", "string", "bool"),
				"setRadius": BgoComponentApiDescriptor.setter("set_radius", "radius", "float"),
				"setHeight": BgoComponentApiDescriptor.setter("set_height", "height", "float"),
				"setColorSource":
				BgoComponentApiDescriptor.setter(
					"set_color_source", "color_source", "string", "bool"
				),
				"setColor":
				BgoComponentApiDescriptor.setter("set_color_string", "color", "string", "bool"),
				"setRoughness":
				BgoComponentApiDescriptor.setter("set_roughness", "roughness", "float"),
				"setMetallic":
				BgoComponentApiDescriptor.setter("set_metallic", "metallic", "float"),
				"setEmissionStrength":
				BgoComponentApiDescriptor.setter(
					"set_emission_strength", "emission_strength", "float"
				),
				"getPlacementAnchor":
				BgoComponentApiDescriptor.method("placement_anchor", [], "string"),
				"getMenuActions":
				(
					BgoComponentApiDescriptor
					. method(
						"menu_actions",
						[
							{"name": "viewer_role", "type": "string"},
							{"name": "viewer_id", "type": "string"},
						],
						"Array"
					)
				),
			},
		)
	)


## Configures identity, ownership, quantity, base color, and optional appearance.
func configure(
	entity_id: String,
	owner_id: String,
	holder_id: String,
	new_quantity: int,
	color: Color,
	configuration: Dictionary = {}
) -> void:
	name = entity_id
	set_meta("bgo_piece", true)
	set_meta("entity_id", entity_id)
	set_meta("owner_id", owner_id)
	set_meta("holder_id", holder_id)
	set_meta("quantity", new_quantity)
	_owner_color = color
	quantity = new_quantity
	piece_color = color
	if not configuration.is_empty():
		apply_configuration(configuration)
	else:
		_apply_visuals()
	component_event.emit(
		"configured",
		{"entity_id": entity_id, "owner_id": owner_id, "holder_id": holder_id, "quantity": quantity}
	)


## Returns context-menu actions allowed for the supplied viewer.
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
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape3D")
	if quantity_label == null:
		quantity_label = get_node_or_null("QuantityLabel")
	var support_height := piece_radius * 2.0 if piece_shape == "sphere" else piece_height
	if mesh_instance != null:
		mesh_instance.mesh = _build_mesh()
		mesh_instance.position.y = support_height * 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = piece_color
		material.roughness = material_roughness
		material.metallic = material_metallic
		material.emission_enabled = emission_strength > 0.0
		material.emission = piece_color
		material.set("emission_energy_multiplier", emission_strength)
		mesh_instance.material_override = material
	if collision_shape != null:
		collision_shape.shape = _build_collision_shape()
		collision_shape.position.y = support_height * 0.5
	if quantity_label != null:
		quantity_label.visible = quantity > 1
		quantity_label.text = str(quantity)
		quantity_label.position.y = support_height + 0.12


func _build_mesh() -> Mesh:
	match piece_shape:
		"cube":
			var box := BoxMesh.new()
			box.size = Vector3(piece_radius * 2.0, piece_height, piece_radius * 2.0)
			return box
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = piece_radius
			cone.height = piece_height
			cone.radial_segments = 32
			return cone
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = piece_radius
			sphere.height = piece_radius * 2.0
			return sphere
		_:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = piece_radius
			cylinder.bottom_radius = piece_radius
			cylinder.height = piece_height
			cylinder.radial_segments = 32
			return cylinder


func _build_collision_shape() -> Shape3D:
	match piece_shape:
		"cube":
			var box := BoxShape3D.new()
			box.size = Vector3(piece_radius * 2.0, piece_height, piece_radius * 2.0)
			return box
		"sphere":
			var sphere := SphereShape3D.new()
			sphere.radius = piece_radius
			return sphere
		_:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = piece_radius
			cylinder.height = piece_height
			return cylinder
