extends Node

## Manages slide-in drawer panels
## Automatically finds correct parent and handles animations

signal drawer_opened(drawer: Control)
signal drawer_closed(drawer: Control)

var _active_drawers: Array[Control] = []
var _drawer_layer: CanvasLayer = null
var _drawer_root: Control = null

## Optional debug logger autoload name. Set to match your project's logger singleton.
## The addon works fully without any logger; calls are silently skipped when absent.
var debug_logger_name: String = "DebugLogger"

## Show a drawer with slide-in animation
## @param content: Control node or PackedScene to show as drawer content
## @param options: Dictionary with drawer configuration
##   - side: String ("left", "right", "top", "bottom") - Which side to slide from. Default: "right"
##   - width: int - Width in pixels for left/right drawers. Default: 400
##   - height: int - Height in pixels for top/bottom drawers. Default: 300
##   - slide_duration: float - Animation duration in seconds. Default: 0.3
func show_drawer(content, options: Dictionary = {}) -> Control:
	var content_node: Control
	if content is PackedScene:
		content_node = content.instantiate()
	elif content is Control:
		content_node = content
	else:
		push_error("DrawerManager: content must be PackedScene or Control")
		return null

	var side: String = options.get("side", "right")
	var width: int = options.get("width", 400)
	var height: int = options.get("height", 300)
	var slide_duration: float = options.get("slide_duration", 0.3)

	var parent = _find_drawer_parent()
	if not parent:
		push_error("DrawerManager: Could not find suitable parent for drawer")
		content_node.queue_free()
		return null
	_log_ui("[DrawerManager] show_drawer parent=%s side=%s" % [parent.name, side])

	_setup_drawer_anchors(content_node, side, width, height)

	parent.add_child(content_node)

	if content_node.has_signal("closed"):
		content_node.closed.connect(_on_drawer_closed.bind(content_node))
	elif content_node.has_signal("cancelled"):
		content_node.cancelled.connect(_on_drawer_closed.bind(content_node))

	_animate_slide_in(content_node, side, slide_duration)

	_active_drawers.append(content_node)
	_log_ui("[DrawerManager] drawer_opened name=%s children=%d" % [content_node.name, content_node.get_child_count()])
	drawer_opened.emit(content_node)

	return content_node

## Find a suitable parent that supports anchor-based layout
func _find_drawer_parent() -> Node:
	# Try to find a CanvasLayer in the scene tree
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasLayer:
			# Found a CanvasLayer, look for MarginContainer child
			var margin = child.get_node_or_null("MarginContainer")
			if margin and margin is Control:
				return margin
			# Fallback: return the CanvasLayer itself
			return child

	_ensure_drawer_overlay()
	if _drawer_root:
		return _drawer_root
	return root


func _ensure_drawer_overlay() -> void:
	if _drawer_root and is_instance_valid(_drawer_root):
		return
	if _drawer_layer and is_instance_valid(_drawer_layer):
		var existing_root := _drawer_layer.get_node_or_null("DrawerRoot") as Control
		if existing_root:
			_drawer_root = existing_root
			return

	_drawer_layer = CanvasLayer.new()
	_drawer_layer.name = "DrawerOverlay"
	_drawer_layer.layer = 120
	get_tree().root.add_child(_drawer_layer)

	_drawer_root = Control.new()
	_drawer_root.name = "DrawerRoot"
	_drawer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer_layer.add_child(_drawer_root)


func _log_ui(message: String) -> void:
	var logger = Engine.get_singleton(debug_logger_name) if Engine.has_singleton(debug_logger_name) else null
	if logger == null and get_tree().root.has_node("/root/" + debug_logger_name):
		logger = get_node("/root/" + debug_logger_name)
	if logger and logger.has_method("ui"):
		logger.ui(message)

## Setup anchors and initial position for the drawer based on side
func _setup_drawer_anchors(drawer: Control, side: String, width: int, height: int) -> void:
	drawer.set_anchors_preset(Control.PRESET_FULL_RECT)

	match side:
		"right":
			drawer.anchor_left = 1.0
			drawer.anchor_right = 1.0
			drawer.anchor_top = 0.0
			drawer.anchor_bottom = 1.0
			drawer.offset_left = 0  # Start offscreen
			drawer.offset_right = width
			drawer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			drawer.grow_vertical = Control.GROW_DIRECTION_BOTH
			drawer.custom_minimum_size = Vector2(width, 0)

		"left":
			drawer.anchor_left = 0.0
			drawer.anchor_right = 0.0
			drawer.anchor_top = 0.0
			drawer.anchor_bottom = 1.0
			drawer.offset_left = -width  # Start offscreen
			drawer.offset_right = 0
			drawer.grow_horizontal = Control.GROW_DIRECTION_END
			drawer.grow_vertical = Control.GROW_DIRECTION_BOTH
			drawer.custom_minimum_size = Vector2(width, 0)

		"top":
			drawer.anchor_left = 0.0
			drawer.anchor_right = 1.0
			drawer.anchor_top = 0.0
			drawer.anchor_bottom = 0.0
			drawer.offset_top = -height  # Start offscreen
			drawer.offset_bottom = 0
			drawer.grow_horizontal = Control.GROW_DIRECTION_BOTH
			drawer.grow_vertical = Control.GROW_DIRECTION_END
			drawer.custom_minimum_size = Vector2(0, height)

		"bottom":
			drawer.anchor_left = 0.0
			drawer.anchor_right = 1.0
			drawer.anchor_top = 1.0
			drawer.anchor_bottom = 1.0
			drawer.offset_top = 0
			drawer.offset_bottom = height  # Start offscreen
			drawer.grow_horizontal = Control.GROW_DIRECTION_BOTH
			drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN
			drawer.custom_minimum_size = Vector2(0, height)

	drawer.layout_mode = 1  # Anchors mode

## Animate drawer sliding in from its side
func _animate_slide_in(drawer: Control, side: String, duration: float) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	match side:
		"right":
			tween.tween_property(drawer, "offset_left", -drawer.custom_minimum_size.x, duration)
			tween.parallel().tween_property(drawer, "offset_right", 0, duration)
		"left":
			tween.tween_property(drawer, "offset_left", 0, duration)
			tween.parallel().tween_property(drawer, "offset_right", drawer.custom_minimum_size.x, duration)
		"top":
			tween.tween_property(drawer, "offset_top", 0, duration)
			tween.parallel().tween_property(drawer, "offset_bottom", drawer.custom_minimum_size.y, duration)
		"bottom":
			tween.tween_property(drawer, "offset_top", -drawer.custom_minimum_size.y, duration)
			tween.parallel().tween_property(drawer, "offset_bottom", 0, duration)

## Animate drawer sliding out before removal
func close_drawer(drawer: Control, duration: float = 0.3) -> void:
	if not drawer or not drawer.is_inside_tree():
		return

	# Determine side from current anchor configuration
	var side: String = "right"  # default
	if drawer.anchor_left == 1.0:
		side = "right"
	elif drawer.anchor_right == 0.0:
		side = "left"
	elif drawer.anchor_top == 0.0 and drawer.anchor_bottom == 0.0:
		side = "top"
	elif drawer.anchor_top == 1.0:
		side = "bottom"

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)

	match side:
		"right":
			tween.tween_property(drawer, "offset_left", 0, duration)
			tween.parallel().tween_property(drawer, "offset_right", drawer.custom_minimum_size.x, duration)
		"left":
			tween.tween_property(drawer, "offset_left", -drawer.custom_minimum_size.x, duration)
			tween.parallel().tween_property(drawer, "offset_right", 0, duration)
		"top":
			tween.tween_property(drawer, "offset_top", -drawer.custom_minimum_size.y, duration)
			tween.parallel().tween_property(drawer, "offset_bottom", 0, duration)
		"bottom":
			tween.tween_property(drawer, "offset_top", 0, duration)
			tween.parallel().tween_property(drawer, "offset_bottom", drawer.custom_minimum_size.y, duration)

	await tween.finished
	drawer.queue_free()

func _on_drawer_closed(drawer: Control) -> void:
	_active_drawers.erase(drawer)
	close_drawer(drawer)
	drawer_closed.emit(drawer)
