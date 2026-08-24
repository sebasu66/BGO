class_name BgoConsoleIdeTheme
extends RefCounted

## Presentation-only skin for the DEV console. Command registration and
## validation remain owned by the console bridge and domain APIs.

const HEADER_NAME := &"BgoConsoleIdeHeader"
const PREVIEW_NAME := &"BgoConsoleSyntaxPreview"
const BACKGROUND := Color("#090c10f7")
const SURFACE := Color("#111720ff")
const SURFACE_RAISED := Color("#171f2aff")
const BORDER := Color("#2b394aff")
const TEXT := Color("#d8e2edff")
const MUTED := Color("#7f91a5ff")
const ACCENT := Color("#56b6cfff")
const SUCCESS := Color("#73c991ff")


static func apply_to(console: Node) -> bool:
	if console == null:
		return false
	var shell := console.get("v_box_container") as VBoxContainer
	var output := console.get("rich_label") as RichTextLabel
	var panel := console.get("panel") as Panel
	var input := console.get("line_edit") as LineEdit
	if shell == null or output == null or panel == null or input == null:
		return false

	shell.theme = build()
	shell.add_theme_constant_override("separation", 0)
	output.add_theme_color_override("default_color", TEXT)
	output.add_theme_color_override("font_shadow_color", Color("#00000080"))
	output.add_theme_constant_override("shadow_offset_x", 1)
	output.add_theme_constant_override("shadow_offset_y", 1)
	input.placeholder_text = "Type a command — help, game.commands, game.objects"
	input.caret_blink = true
	input.caret_blink_interval = 0.55
	input.clear_button_enabled = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_header(shell)
	_add_syntax_preview(shell, input)

	return true


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = _mono_font()
	theme.default_font_size = 15
	theme.set_type_variation("BgoConsoleHeader", "PanelContainer")
	theme.set_type_variation("BgoConsoleTitle", "Label")
	theme.set_type_variation("BgoConsoleBadge", "Label")
	theme.set_type_variation("BgoConsoleHint", "Label")
	theme.set_type_variation("BgoConsolePreview", "RichTextLabel")

	var output_style := _style(BACKGROUND, 0, 14, 0)
	output_style.border_color = BORDER
	output_style.border_width_bottom = 1
	theme.set_stylebox("panel", "Panel", output_style)
	theme.set_stylebox("normal", "RichTextLabel", _style(BACKGROUND, 0, 16, 0))
	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_color("font_selected_color", "RichTextLabel", Color.WHITE)
	theme.set_color("selection_color", "RichTextLabel", Color("#264f78cc"))

	var input_style := _style(SURFACE, 0, 12, 0)
	input_style.border_color = BORDER
	input_style.border_width_top = 1
	theme.set_stylebox("normal", "LineEdit", input_style)
	var input_focus := input_style.duplicate() as StyleBoxFlat
	input_focus.border_color = ACCENT
	input_focus.border_width_top = 2
	theme.set_stylebox("focus", "LineEdit", input_focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color("#264f78cc"))
	theme.set_font_size("font_size", "LineEdit", 15)

	theme.set_stylebox("panel", "BgoConsoleHeader", _style(SURFACE_RAISED, 0, 10, 0))
	theme.set_color("font_color", "BgoConsoleTitle", TEXT)
	theme.set_font_size("font_size", "BgoConsoleTitle", 13)
	theme.set_color("font_color", "BgoConsoleBadge", SUCCESS)
	theme.set_font_size("font_size", "BgoConsoleBadge", 12)
	theme.set_color("font_color", "BgoConsoleHint", MUTED)
	theme.set_font_size("font_size", "BgoConsoleHint", 12)
	theme.set_stylebox("normal", "BgoConsolePreview", _style(SURFACE_RAISED, 0, 8, 0))
	theme.set_color("default_color", "BgoConsolePreview", MUTED)
	theme.set_font_size("normal_font_size", "BgoConsolePreview", 13)
	return theme


static func _add_header(shell: VBoxContainer) -> void:
	if shell.get_node_or_null(NodePath(str(HEADER_NAME))) != null:
		return
	var header := PanelContainer.new()
	header.name = HEADER_NAME
	header.theme_type_variation = &"BgoConsoleHeader"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)

	var badge := Label.new()
	badge.text = "●  DEV"
	badge.theme_type_variation = &"BgoConsoleBadge"
	row.add_child(badge)
	var title := Label.new()
	title.text = "BGO GAME CONSOLE"
	title.theme_type_variation = &"BgoConsoleTitle"
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var hint := Label.new()
	hint.text = "~ close   Ctrl+~ expand   ↑↓ history"
	hint.theme_type_variation = &"BgoConsoleHint"
	row.add_child(hint)

	shell.add_child(header)
	shell.move_child(header, 0)


static func _add_syntax_preview(shell: VBoxContainer, input: LineEdit) -> void:
	if shell.get_node_or_null(NodePath(str(PREVIEW_NAME))) != null:
		return
	var preview := BgoConsoleSyntaxPreview.new()
	preview.name = PREVIEW_NAME
	preview.theme_type_variation = &"BgoConsolePreview"
	shell.add_child(preview)
	shell.move_child(preview, maxi(input.get_index(), 1))
	input.text_changed.connect(preview.set_source)


static func _mono_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	font.font_weight = 450
	return font


static func _style(color: Color, radius: int, padding: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.border_color = BORDER
	style.set_border_width_all(border_width)
	return style
