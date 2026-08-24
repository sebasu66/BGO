class_name BgoContextMenuComponent
extends Control

# --- Visual tuning ---------------------------------------------------------
# Normal row: black at 20%, white at 80%.
const COLOR_NORMAL_BACKGROUND := Color(0.0, 0.0, 0.0, 0.20)
const COLOR_NORMAL_TEXT := Color(0.80, 0.80, 0.80, 1.0)
# Expanded parent row: black at 60%, white at 100%.
const COLOR_PARENT_BACKGROUND := Color(0.0, 0.0, 0.0, 0.60)
const COLOR_PARENT_TEXT := Color(1.0, 1.0, 1.0, 1.0)
# Nested rows: black at 35%, white at 90%.
const COLOR_SUBMENU_BACKGROUND := Color(0.0, 0.0, 0.0, 0.35)
const COLOR_SUBMENU_TEXT := Color(0.90, 0.90, 0.90, 1.0)
# Activated action: black at 90%, white at 100%.
const COLOR_ACTIVE_BACKGROUND := Color(0.0, 0.0, 0.0, 0.90)
const COLOR_ACTIVE_TEXT := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_LINE := Color(1.0, 1.0, 1.0, 0.62)
const TEXT_OUTLINE_SIZE := 2
const MAIN_FONT_SIZE := 56
const CHILD_FONT_SIZE := 46
const MAIN_ROW_HEIGHT := 140
const CHILD_ROW_HEIGHT := 116
const ROW_SEPARATION := 12
const LINE_INSET := 118.0
const CHILD_LINE_INSET := 148.0
const LINE_WIDTH := 4.0
const CHILD_LINE_WIDTH := 3.2
const MAIN_LINE_ALPHA := 0.72
const CHILD_LINE_ALPHA := 0.46
# Internal content rectangle in the narrowed 960x720 menu texture.
const CONTENT_POSITION := Vector2(18, 28)
const CONTENT_SIZE := Vector2(924, 660)
const SELECTED_RECT_INSET_X := 18.0
const PARENT_BACK_ARROW_SIZE := 18.0
const PARENT_BACK_ARROW_COLOR := Color(1.0, 1.0, 1.0, 1.0)

var reactive_root: ReactiveRootNode
var _props: Dictionary = {}


## Mounts the reactive menu into this reusable Control component.
func setup(menu_props: Dictionary = {}) -> BgoContextMenuComponent:
	_props = menu_props.duplicate()
	reactive_root = ReactiveRootNode.new()
	reactive_root.name = "ReactiveContextMenuRoot"
	reactive_root.position = Vector2.ZERO
	reactive_root.size = CONTENT_SIZE + CONTENT_POSITION
	reactive_root.setup(render, _props)
	add_child(reactive_root)
	return self


## Returns the action ids currently rendered by this menu.
func action_ids() -> Array[String]:
	var result: Array[String] = []
	for action in _props.get("actions", []):
		if action is Dictionary:
			result.append(str(action.get("id", "")))
	return result


## Updates the menu state without replacing the component instance.
func rerender(menu_props: Dictionary = {}) -> void:
	_props = menu_props.duplicate()
	if reactive_root != null:
		reactive_root.rerender(render, _props)


static func render(props: Dictionary, _children: Array) -> RUIVNode:
	var expanded := bool(props.get("expanded", false))
	var selected_id := String(props.get("selected_id", ""))
	var on_toggle: Callable = props.get("on_toggle", Callable())
	var on_action: Callable = props.get("on_action", Callable())
	var row_specs: Array = []
	for action in props.get("actions", []):
		if not action is Dictionary:
			continue
		if bool(action.get("submenu", false)) and not expanded:
			row_specs.append([str(action.get("label", action.get("id", ""))), 0, false, on_toggle])
			continue
		row_specs.append([
			str(action.get("label", action.get("id", ""))),
			int(action.get("depth", 0)),
			selected_id == str(action.get("id", "")),
			on_action.bind(str(action.get("id", ""))),
		])
	if row_specs.is_empty():
		row_specs.append(["SIN ACCIONES", 0, false, Callable()])
	var rows: Array = []
	for index in row_specs.size():
		var spec: Array = row_specs[index]
		var state := _state_for(spec[0], spec[1], selected_id, expanded)
		rows.append(_row(spec[0], spec[1], state, spec[3], index < row_specs.size() - 1))
	return V.h(
		"VBoxContainer",
		{
			"position": CONTENT_POSITION,
			"size": CONTENT_SIZE,
			"theme_override_constants/separation": ROW_SEPARATION,
		},
		rows,
	)


static func _state_for(label: String, depth: int, selected_id: String, expanded: bool) -> int:
	var item_id := ""
	match label:
		"TOMAR": item_id = "take"
		"MOVER": item_id = "move"
		"A CASILLA": item_id = "move_slot"
		"A MANO": item_id = "move_hand"
		"A ÁREA": item_id = "move_area"
		"DEVOLVER": item_id = "return"
	if selected_id == item_id:
		return 3
	if depth == 1:
		return 2
	if label == "MOVER" and expanded:
		return 1
	return 0


static func _row(
	label: String,
	depth: int,
	state: int,
	callback: Callable,
	has_separator: bool
) -> RUIVNode:
	var text_color := COLOR_NORMAL_TEXT
	var background_color := COLOR_NORMAL_BACKGROUND
	match state:
		1:
			text_color = COLOR_PARENT_TEXT
			background_color = COLOR_PARENT_BACKGROUND
		2:
			text_color = COLOR_SUBMENU_TEXT
			background_color = COLOR_SUBMENU_BACKGROUND
		3:
			text_color = COLOR_ACTIVE_TEXT
			background_color = COLOR_ACTIVE_BACKGROUND
	var row_height := MAIN_ROW_HEIGHT if depth == 0 else CHILD_ROW_HEIGHT
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	var button_style := {
		"bg_color": transparent,
		"font_color": text_color,
		"font_outline_color": text_color,
		"outline_size": TEXT_OUTLINE_SIZE,
		"content_margin_left": SELECTED_RECT_INSET_X,
		"content_margin_right": SELECTED_RECT_INSET_X,
		"colors": {
			"font_hover_color": text_color,
			"font_pressed_color": text_color,
			"font_focus_color": text_color,
		},
		"font_sizes": {"font_size": MAIN_FONT_SIZE if depth == 0 else CHILD_FONT_SIZE},
		"hover": {"bg_color": transparent},
		"pressed": {"bg_color": transparent},
		"focus": {"bg_color": transparent},
	}
	return V.h(
		"Panel",
		{
			"custom_minimum_size": Vector2(0, row_height),
			"size_flags_horizontal": Control.SIZE_EXPAND_FILL,
			"style": {"bg_color": background_color},
			"draw_fn": _draw_row.bind(depth, state, background_color, has_separator),
		},
		[
			V.h(
				"Button",
				{
					"text": label,
					"flat": true,
					"alignment": HORIZONTAL_ALIGNMENT_CENTER,
					"focus_mode": Control.FOCUS_ALL,
					"mouse_default_cursor_shape": Control.CURSOR_POINTING_HAND,
					"position": Vector2.ZERO,
					"size": Vector2(CONTENT_SIZE.x, row_height),
					"style": button_style,
					"onPressed": callback,
				},
				[],
			),
		],
	)


static func _draw_row(
	canvas: CanvasItem,
	depth: int,
	state: int,
	_background_color: Color,
	has_separator: bool
) -> void:
	var control := canvas as Control
	if control == null:
		return
	if state == 1:
		var arrow_x := control.size.x - 34.0
		var arrow_y := control.size.y * 0.5
		control.draw_colored_polygon(
			PackedVector2Array([
				Vector2(arrow_x + PARENT_BACK_ARROW_SIZE * 0.5, arrow_y - PARENT_BACK_ARROW_SIZE * 0.7),
				Vector2(arrow_x - PARENT_BACK_ARROW_SIZE * 0.5, arrow_y),
				Vector2(arrow_x + PARENT_BACK_ARROW_SIZE * 0.5, arrow_y + PARENT_BACK_ARROW_SIZE * 0.7),
			]),
			PARENT_BACK_ARROW_COLOR,
		)
	if has_separator:
		var inset := LINE_INSET + depth * CHILD_LINE_INSET
		var right := control.size.x - inset
		var alpha := MAIN_LINE_ALPHA if depth == 0 else CHILD_LINE_ALPHA
		var color := Color(COLOR_LINE, alpha)
		_draw_faded_line(
			control,
			Vector2(inset, control.size.y - 4.0),
			Vector2(right, control.size.y - 4.0),
			color,
			LINE_WIDTH if depth == 0 else CHILD_LINE_WIDTH,
		)


static func _draw_faded_line(
	canvas: CanvasItem,
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float
) -> void:
	const SEGMENTS := 48
	for index in SEGMENTS:
		var t0 := float(index) / SEGMENTS
		var t1 := float(index + 1) / SEGMENTS
		var center_weight := sin(PI * (t0 + t1) * 0.5)
		var segment_color := color
		segment_color.a *= pow(center_weight, 0.55)
		canvas.draw_line(from.lerp(to, t0), from.lerp(to, t1), segment_color, width, true)
