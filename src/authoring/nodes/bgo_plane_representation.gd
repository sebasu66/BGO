@tool
class_name BgoPlaneRepresentation
extends "res://src/authoring/nodes/bgo_representation_3d.gd"

## Flat two-sided representation used by cards, tiles, boards and other 2D artwork
## that lives in the 3D tabletop. During component authoring these properties are
## edited directly in the Godot inspector. A component can later choose which of
## them become part of its public authoring interface.

@export_category("BGO Flat Representation")

@export_group("Geometry")
@export_range(0.01, 1000.0, 0.01) var width := 1.0:
	set(value):
		width = maxf(value, 0.01)
		_queue_visual_refresh()
@export_range(0.01, 1000.0, 0.01) var height := 1.4:
	set(value):
		height = maxf(value, 0.01)
		_queue_visual_refresh()
@export_range(0.0, 0.1, 0.0005) var face_separation := 0.002:
	set(value):
		face_separation = maxf(value, 0.0)
		_queue_visual_refresh()

@export_group("Front Face")
@export var front_texture: Texture2D:
	set(value):
		front_texture = value
		_queue_visual_refresh()
@export var front_color := Color.WHITE:
	set(value):
		front_color = value
		_queue_visual_refresh()
## Optional complete material override. Accepts StandardMaterial3D or ShaderMaterial.
## When set it owns the whole front-face appearance; front_texture/front_color are ignored.
@export var front_material: Material:
	set(value):
		front_material = value
		_queue_visual_refresh()

@export_group("Back Face")
@export var back_texture: Texture2D:
	set(value):
		back_texture = value
		_queue_visual_refresh()
@export var back_color := Color.WHITE:
	set(value):
		back_color = value
		_queue_visual_refresh()
## Optional complete material override. Accepts StandardMaterial3D or ShaderMaterial.
## When set it owns the whole back-face appearance; back_texture/back_color are ignored.
@export var back_material: Material:
	set(value):
		back_material = value
		_queue_visual_refresh()

@export_group("Rendering")
@export_range(0.0, 1.0, 0.01) var roughness := 0.72:
	set(value):
		roughness = clampf(value, 0.0, 1.0)
		_queue_visual_refresh()
@export var transparent := true:
	set(value):
		transparent = value
		_queue_visual_refresh()
@export var cast_shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
	set(value):
		cast_shadow = value
		_queue_visual_refresh()

var _visual_refresh_queued := false


func _init() -> void:
	representation_id = &"plane"


func _ready() -> void:
	refresh_from_definition()


func get_definition_schema() -> Dictionary:
	var schema := {
		"width": {"type": "float", "min": 0.01, "default": width},
		"height": {"type": "float", "min": 0.01, "default": height},
		"front_texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
		"back_texture_path": {"type": "asset", "asset_kind": "texture", "default": ""},
		"front_color": {"type": "color", "default": front_color.to_html()},
		"back_color": {"type": "color", "default": back_color.to_html()},
	}
	schema.merge(property_schema, true)
	return schema


func refresh_from_definition() -> void:
	_visual_refresh_queued = false
	var resolved_width := float(definition_value(&"width", width))
	var resolved_height := float(definition_value(&"height", height))
	var resolved_front_color := definition_color(
		&"front_color",
		definition_color(&"color", front_color)
	)
	var resolved_back_color := definition_color(&"back_color", back_color)
	var resolved_front_texture := _definition_texture_with_legacy(
		&"front_texture_path",
		&"texture_path",
		front_texture
	)
	var resolved_back_texture := _definition_texture_or(&"back_texture_path", back_texture)

	_configure_face(
		_front_visual(),
		Vector2(resolved_width, resolved_height),
		face_separation * 0.5,
		-90.0,
		front_material,
		resolved_front_texture,
		resolved_front_color
	)
	_configure_face(
		_back_visual(),
		Vector2(resolved_width, resolved_height),
		-face_separation * 0.5,
		90.0,
		back_material,
		resolved_back_texture,
		resolved_back_color
	)


func _configure_face(
	visual: MeshInstance3D,
	size: Vector2,
	y_offset: float,
	x_rotation_degrees: float,
	custom_material: Material,
	texture: Texture2D,
	color: Color
) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position.y = y_offset
	visual.rotation_degrees = Vector3(x_rotation_degrees, 0.0, 0.0)
	visual.cast_shadow = cast_shadow
	if custom_material != null:
		visual.material_override = custom_material
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if texture != null:
		material.albedo_texture = texture
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = material


func _front_visual() -> MeshInstance3D:
	var visual := get_node_or_null("Front") as MeshInstance3D
	if visual == null:
		visual = MeshInstance3D.new()
		visual.name = "Front"
		add_child(visual)
	return visual


func _back_visual() -> MeshInstance3D:
	var visual := get_node_or_null("Back") as MeshInstance3D
	if visual == null:
		visual = MeshInstance3D.new()
		visual.name = "Back"
		add_child(visual)
	return visual


func _definition_texture_or(key: StringName, authored_texture: Texture2D) -> Texture2D:
	var path := String(definition_value(key, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	return authored_texture


func _definition_texture_with_legacy(
	key: StringName,
	legacy_key: StringName,
	authored_texture: Texture2D
) -> Texture2D:
	var path := String(definition_value(key, ""))
	if path.is_empty():
		path = String(definition_value(legacy_key, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	return authored_texture


func _queue_visual_refresh() -> void:
	if not is_inside_tree() or _visual_refresh_queued:
		return
	_visual_refresh_queued = true
	call_deferred("refresh_from_definition")
