class_name BgoConsoleSyntaxPreview
extends RichTextLabel


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	selection_enabled = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 28)
	set_source("")


func set_source(source: String) -> void:
	text = BgoConsoleSyntax.highlight(source)
