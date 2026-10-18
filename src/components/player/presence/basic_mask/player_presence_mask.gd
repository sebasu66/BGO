class_name BgoPlayerPresenceMask
extends Node3D

var _player_name := "PLAYER"
var _player_color := Color.WHITE

@onready var head: MeshInstance3D = $Head
@onready var nose: MeshInstance3D = $Nose
@onready var name_label: Label3D = $Name


func _ready() -> void:
	_apply_appearance()


## Configures this object from the supplied project data.
func configure(player_name: String, player_color: Color) -> void:
	_player_name = player_name
	_player_color = player_color
	_apply_appearance()


## Updates the rendered player name.
func set_player_name(value: String) -> void:
	_player_name = value
	_apply_appearance()


## Updates the mask color from a CSS-style color string.
func set_player_color_string(value: String) -> bool:
	var parsed := Color.from_string(value, Color.TRANSPARENT)
	if parsed == Color.TRANSPARENT and value.to_lower() not in ["transparent", "#00000000"]:
		return false
	_player_color = parsed
	_apply_appearance()
	return true


## Returns the stable console, GUI, and MCP method surface for this component.
func console_api() -> Dictionary:
	return (
		BgoComponentApiDescriptor
		. create(
			self,
			"bgo.player_presence.basic_mask",
			"BgoPlayerPresenceMask",
			"Authorized seated-player presence presentation controls.",
			{
				"setPlayerName":
				BgoComponentApiDescriptor.method(
					"set_player_name", [{"name": "value", "type": "string"}]
				),
				"setPlayerColor":
				BgoComponentApiDescriptor.method(
					"set_player_color_string", [{"name": "value", "type": "string"}], "bool"
				),
				"setPose":
				BgoComponentApiDescriptor.method(
					"set_pose",
					[
						{"name": "position", "type": "Vector3"},
						{"name": "forward", "type": "Vector3"}
					]
				),
			},
		)
	)


func _apply_appearance() -> void:
	name = "Presence_%s" % _player_name.replace(" ", "_")
	if head == null or nose == null or name_label == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = _player_color
	material.roughness = 0.72
	material.metallic = 0.0
	head.material_override = material
	nose.material_override = material
	name_label.text = _player_name
	name_label.modulate = Color.WHITE


## Updates the published player-presence pose.
func set_pose(position: Vector3, forward: Vector3) -> void:
	global_position = position
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() > 0.0001:
		look_at(global_position + horizontal_forward.normalized(), Vector3.UP, true)
