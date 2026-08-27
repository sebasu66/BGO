@tool
class_name BgoPrimitiveRepresentation
extends "res://src/authoring/nodes/bgo_representation_3d.gd"

enum Shape { BOX, CYLINDER, SPHERE, CONE }

@export_category("BGO Primitive Representation")
@export var shape: Shape = Shape.CYLINDER:
	set(value):
		shape = value
		_queue_refresh()
@export var size := Vector3(1.0, 0.25, 1.0):
	set(value):
		size = Vector3(maxf(value.x, 0.01), maxf(value.y, 0.01), maxf(value.z, 0.01))
		_queue_refresh()
@export var color := Color.WHITE:
	set(value):
		color = value
		_queue_refresh()
@export var texture: Texture2D:
	set(value):
		texture = value
		_queue_refresh()
## Optional complete material override; ShaderMaterial is supported.
@export var material: Material:
	set(value):
		material = value
		_queue_refresh()
@export_range(0.0, 1.0, 0.01) var roughness := 0.65:
	set(value):
		roughness = clampf(value, 0.0, 1.0)
		_queue_refresh()

var _refresh_queued := false

func _init() -> void:
	representation_id = &"primitive"

func _ready() -> void:
	refresh_from_definition()

func get_definition_schema() -> Dictionary:
	var schema := {
		"primitive_shape": {"type": "enum", "values": ["box", "cylinder", "sphere", "cone"], "default": _shape_name(shape)},
		"size_x": {"type": "float", "min": 0.01, "default": size.x},
		"size_y": {"type": "float", "min": 0.01, "default": size.y},
		"size_z": {"type": "float", "min": 0.01, "default": size.z},
		"color": {"type": "color", "default": color.to_html()},
		"texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
	}
	schema.merge(property_schema, true)
	return schema

func refresh_from_definition() -> void:
	_refresh_queued = false
	var resolved_size := Vector3(
		float(definition_value(&"size_x", size.x)),
		float(definition_value(&"size_y", size.y)),
		float(definition_value(&"size_z", size.z))
	)
	var resolved_shape := _shape_from_name(String(definition_value(&"primitive_shape", _shape_name(shape))))
	var visual := visual_mesh()
	visual.mesh = _make_mesh(resolved_shape, resolved_size)
	if material != null:
		visual.material_override = material
		return
	var standard := StandardMaterial3D.new()
	standard.albedo_color = definition_color(&"color", color)
	standard.roughness = roughness
	var resolved_texture := definition_texture(&"texture_path")
	standard.albedo_texture = texture if resolved_texture == null else resolved_texture
	visual.material_override = standard

func _make_mesh(target_shape: Shape, target_size: Vector3) -> PrimitiveMesh:
	match target_shape:
		Shape.BOX:
			var box := BoxMesh.new()
			box.size = target_size
			return box
		Shape.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = maxf(target_size.x, target_size.z) * 0.5
			sphere.height = target_size.y
			return sphere
		Shape.CONE:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = maxf(target_size.x, target_size.z) * 0.5
			cone.height = target_size.y
			return cone
		_:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = maxf(target_size.x, target_size.z) * 0.5
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = target_size.y
			return cylinder

func _shape_name(value: Shape) -> String:
	return ["box", "cylinder", "sphere", "cone"][int(value)]

func _shape_from_name(value: String) -> Shape:
	match value.to_lower():
		"box": return Shape.BOX
		"sphere": return Shape.SPHERE
		"cone": return Shape.CONE
		_: return Shape.CYLINDER

func _queue_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("refresh_from_definition")
