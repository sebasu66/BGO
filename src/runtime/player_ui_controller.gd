class_name BgoPlayerUiController
extends RefCounted

const VERTICAL_HAND_SCENE = preload("res://src/components/hands/vertical_hand/vertical_hand.tscn")


## Creates the floating player-hand UI root.
func create_landscape_root(ui_root: Node) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.name = "FloatingHandLayer"
	root.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	root.offset_left = -154.0
	root.offset_right = -10.0
	root.offset_top = 92.0
	root.offset_bottom = -22.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.add_child(root)
	return root


## Adds the current player identity header to the hand layer.
func add_identity(
	root: VBoxContainer, player_id: String, definition: Dictionary, color: Color
) -> void:
	var player_title := Label.new()
	player_title.text = (
		"%s Â· %s"
		% [
			str(definition.get("name", player_id.replace("_", " ").capitalize())),
			player_id.to_upper().replace("_", " "),
		]
	)
	player_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_title.add_theme_font_size_override("font_size", 18)
	player_title.add_theme_color_override("font_color", color)
	root.add_child(player_title)


## Adds and wires the vertical hand component.
func add_vertical_hand(
	root: VBoxContainer, preview_factory: Callable, item_selected: Callable, mode_selected: Callable
) -> BgoVerticalHand:
	var hand := VERTICAL_HAND_SCENE.instantiate() as BgoVerticalHand
	hand.name = "PlayerHand"
	hand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand.custom_minimum_size = Vector2(136, 0)
	hand.set_preview_factory(preview_factory)
	hand.item_selected.connect(item_selected)
	hand.mode_selected.connect(mode_selected)
	root.add_child(hand)
	return hand


## Adds fullscreen and asset-box actions to the player UI.
func add_action_controls(
	root: VBoxContainer, fullscreen_callback: Callable, asset_box_callback: Callable
) -> Button:
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	var fullscreen_button := Button.new()
	fullscreen_button.text = "FULL SCREEN"
	fullscreen_button.custom_minimum_size = Vector2(120, 54)
	fullscreen_button.pressed.connect(fullscreen_callback)
	action_row.add_child(fullscreen_button)
	var asset_box_button := Button.new()
	asset_box_button.text = "ASSET BOX"
	asset_box_button.custom_minimum_size = Vector2(120, 54)
	asset_box_button.pressed.connect(asset_box_callback)
	action_row.add_child(asset_box_button)
	return asset_box_button


## Builds a non-authoritative visual preview for one hand item.
func build_hand_preview(item: Dictionary, player_id: String, color_for_owner: Callable) -> Node3D:
	var packed_scene := BgoComponentRegistry.load_scene(str(item.get("component_id", "")))
	if packed_scene == null:
		return null
	var preview := packed_scene.instantiate() as Node3D
	if preview == null:
		return null
	var owner_id := str(item.get("owner_id", ""))
	var color: Color = item.get("color", color_for_owner.call(owner_id))
	if preview is BgoBasicCylinderPiece:
		(
			(preview as BgoBasicCylinderPiece)
			. configure(
				str(item.get("id", "preview")),
				owner_id,
				player_id,
				int(item.get("quantity", 1)),
				color,
			)
		)
	return preview


## Requests landscape presentation and browser page constraints for player UI.
func request_landscape_orientation() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if OS.has_feature("web"):
		var page_style := (
			"document.documentElement.style.background='#05070a';"
			+ "document.body.style.margin='0';"
			+ "document.body.style.overflow='hidden';"
		)
		JavaScriptBridge.eval(page_style, true)


## Enters fullscreen using the native or browser-specific path.
func enter_fullscreen() -> void:
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var fullscreen_script := (
		"(async()=>{const e=document.documentElement;"
		+ "if(!document.fullscreenElement&&e.requestFullscreen){await e.requestFullscreen();}"
		+ "})()"
	)
	JavaScriptBridge.eval(fullscreen_script, true)
