extends Node3D

@export var component_id := ""

func _ready() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "BGO WORKBENCH  |  %s\nPreview uses the registered component scene." % component_id
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 18)
	layer.add_child(label)
	add_child(layer)
