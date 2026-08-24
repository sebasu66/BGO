class_name BgoUiThemeProfiles
extends RefCounted

## Centralized visual templates for every BGO runtime UI component.
## Add profiles here, or load an equivalent declarative dictionary from a game package later.
const PROFILES := {
	"boardroom": {
		"surface": Color("#0b0d10f0"),
		"surface_raised": Color("#171b20f7"),
		"surface_hover": Color("#292e33ff"),
		"text": Color("#f5f2e8ff"),
		"muted": Color("#adb0b3ff"),
		"accent": Color("#d7aa4cff"),
		"radius": 10,
		"font_size": 15,
		"touch_size": 48,
	},
	"high_contrast": {
		"surface": Color("#000000fa"),
		"surface_raised": Color("#111111ff"),
		"surface_hover": Color("#353535ff"),
		"text": Color.WHITE,
		"muted": Color("#e1e1e1ff"),
		"accent": Color("#ffd85aff"),
		"radius": 5,
		"font_size": 17,
		"touch_size": 52,
	},
}


static func build(profile_id := "boardroom", overrides: Dictionary = {}) -> Theme:
	var tokens: Dictionary = PROFILES.get(profile_id, PROFILES["boardroom"])
	tokens = tokens.duplicate(true)
	for key in overrides:
		tokens[key] = overrides[key]
	var theme := Theme.new()
	theme.default_font_size = roundi(int(tokens["font_size"]) * float(tokens.get("font_scale", 1.0)))
	theme.set_type_variation("BgoShellPanel", "PanelContainer")
	theme.set_type_variation("BgoHeaderPanel", "PanelContainer")
	theme.set_type_variation("BgoShellButton", "Button")
	theme.set_type_variation("BgoEmphasisButton", "Button")

	var radius := int(tokens["radius"])
	theme.set_stylebox("panel", "BgoShellPanel", _style(tokens["surface"], radius, 8))
	theme.set_stylebox("panel", "BgoHeaderPanel", _style(tokens["surface"], radius + 2, 12))
	for type_name in ["BgoShellButton", "BgoEmphasisButton"]:
		theme.set_stylebox("normal", type_name, _style(tokens["surface_raised"], radius, 8))
		theme.set_stylebox("hover", type_name, _style(tokens["surface_hover"], radius, 8))
		var pressed_style := _style(tokens["surface_hover"].darkened(0.2), radius, 8)
		pressed_style.border_color = tokens["accent"]
		pressed_style.set_border_width_all(2)
		theme.set_stylebox("pressed", type_name, pressed_style)
		theme.set_stylebox("focus", type_name, _outline(tokens["accent"], radius))
		theme.set_color("font_hover_color", type_name, tokens["text"])
		theme.set_color("font_pressed_color", type_name, tokens["text"])
		theme.set_font_size("font_size", type_name, int(tokens["font_size"]))
	theme.set_color("font_color", "BgoShellButton", tokens["muted"])
	theme.set_color("font_color", "BgoEmphasisButton", tokens["text"])
	return theme


static func tokens(profile_id := "boardroom") -> Dictionary:
	return (PROFILES.get(profile_id, PROFILES["boardroom"]) as Dictionary).duplicate(true)


## Applies one shared Theme resource to every top-level Control below a UI root.
static func apply_to(root: Node, profile_id := "boardroom", overrides: Dictionary = {}) -> Theme:
	var shared_theme := build(profile_id, overrides)
	for child in root.get_children():
		if child is Control:
			(child as Control).theme = shared_theme
	return shared_theme


static func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding + 2
	style.content_margin_right = padding + 2
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


static func _outline(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
