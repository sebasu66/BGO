class_name BgoPlayerPresenceMask
extends Node3D

@onready var head: MeshInstance3D = $Head
@onready var nose: MeshInstance3D = $Nose
@onready var name_label: Label3D = $Name

func configure(player_name: String, player_color: Color) -> void:
	name = "Presence_%s" % player_name.replace(" ", "_")
	var material := StandardMaterial3D.new()
	material.albedo_color = player_color
	material.roughness = 0.72
	material.metallic = 0.0
	head.material_override = material
	nose.material_override = material
	name_label.text = player_name
	name_label.modulate = Color.WHITE

func set_pose(position: Vector3, forward: Vector3) -> void:
	global_position = position
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() > 0.0001:
		look_at(global_position + horizontal_forward.normalized(), Vector3.UP, true)
