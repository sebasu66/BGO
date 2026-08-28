extends Control

var active_drawer: Control = null

@onready var btn_right: Button = $CenterContainer/VBoxContainer/ButtonGrid/RightDrawerButton
@onready var btn_left: Button = $CenterContainer/VBoxContainer/ButtonGrid/LeftDrawerButton
@onready var btn_top: Button = $CenterContainer/VBoxContainer/ButtonGrid/TopDrawerButton
@onready var btn_bottom: Button = $CenterContainer/VBoxContainer/ButtonGrid/BottomDrawerButton
@onready var btn_dynamic: Button = $CenterContainer/VBoxContainer/DynamicDrawerButton
@onready var status_label: Label = %StatusLabel
@onready var scope_toggle: CheckBox = %ScopeToggle

@onready var right_drawer: PanelContainer = %RightDrawer
@onready var left_drawer: PanelContainer = %LeftDrawer
@onready var top_drawer: PanelContainer = %TopDrawer
@onready var bottom_drawer: PanelContainer = %BottomDrawer


func _ready() -> void:
	btn_right.pressed.connect(_on_right_pressed)
	btn_left.pressed.connect(_on_left_pressed)
	btn_top.pressed.connect(_on_top_pressed)
	btn_bottom.pressed.connect(_on_bottom_pressed)
	btn_dynamic.pressed.connect(_on_dynamic_pressed)

	# Scope toggle
	if scope_toggle:
		scope_toggle.pressed.connect(_on_scope_toggled)
		# Initialize with current state
		_update_scope_label()

	# Connect close buttons for each drawer
	var right_close = right_drawer.find_child("CloseButton", true, false)
	if right_close:
		right_close.pressed.connect(_close_right_drawer)

	var left_close = left_drawer.find_child("CloseButton", true, false)
	if left_close:
		left_close.pressed.connect(_close_left_drawer)

	var top_close = top_drawer.find_child("CloseButton", true, false)
	if top_close:
		top_close.pressed.connect(_close_top_drawer)

	var bottom_close = bottom_drawer.find_child("CloseButton", true, false)
	if bottom_close:
		bottom_close.pressed.connect(_close_bottom_drawer)


func _on_right_pressed() -> void:
	if active_drawer:
		status_label.text = "Close current drawer first!"
		return
	_show_right_drawer()
	status_label.text = "Right drawer opened (400px width)"


func _on_left_pressed() -> void:
	if active_drawer:
		status_label.text = "Close current drawer first!"
		return
	_show_left_drawer()
	status_label.text = "Left drawer opened (400px width)"


func _on_top_pressed() -> void:
	if active_drawer:
		status_label.text = "Close current drawer first!"
		return
	_show_top_drawer()
	status_label.text = "Top drawer opened (250px height)"


func _on_bottom_pressed() -> void:
	if active_drawer:
		status_label.text = "Close current drawer first!"
		return
	_show_bottom_drawer()
	status_label.text = "Bottom drawer opened (250px height)"


func _on_scope_toggled() -> void:
	# Note: Changing scope requires recreating drawers
	# For now, just show a message
	_update_scope_label()
	status_label.text = "Scope mode toggled - changes apply to new drawers"


func _update_scope_label() -> void:
	if not scope_toggle:
		return

	var is_screen_wide = scope_toggle.button_pressed
	scope_toggle.text = "Screen-Wide Mode" if is_screen_wide else "Parent-Contained Mode"


func _on_dynamic_pressed() -> void:
	if active_drawer:
		status_label.text = "Close current drawer first!"
		return

	var drawer_manager := get_node_or_null("/root/DrawerManager")
	if drawer_manager == null:
		status_label.text = "DrawerManager autoload is unavailable"
		return

	var content := _create_dynamic_drawer_content()
	var drawer := (
		drawer_manager.call(
			"show_drawer", content, {"side": "right", "width": 350, "slide_duration": 0.3}
		)
		as Control
	)

	if drawer:
		status_label.text = "Dynamic drawer via DrawerManager"
		# Track as active
		active_drawer = drawer
		drawer.tree_exited.connect(
			func():
				active_drawer = null
				status_label.text = "Dynamic drawer closed"
		)


func _create_dynamic_drawer_content() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	var title = Label.new()
	title.text = "Dynamic Drawer"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var content = Label.new()
	content.text = (
		"This drawer was created dynamically using DrawerManager.show_drawer().\n\n"
		+ "It overlays the entire screen using anchor-based positioning on a CanvasLayer."
	)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(content)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(
		func():
			var drawer_manager := get_node_or_null("/root/DrawerManager")
			if drawer_manager:
				drawer_manager.call("close_drawer", active_drawer)
	)
	vbox.add_child(close_btn)

	return vbox


## Right drawer (slides from right)
func _show_right_drawer() -> void:
	# Set initial offscreen position
	right_drawer.offset_left = 0.0
	right_drawer.offset_right = 400.0

	right_drawer.visible = true
	active_drawer = right_drawer

	# Wait for layout
	await get_tree().process_frame

	# Animate slide in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(right_drawer, "offset_left", -400.0, 0.3)
	tween.parallel().tween_property(right_drawer, "offset_right", 0.0, 0.3)


func _close_right_drawer() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(right_drawer, "offset_left", 0.0, 0.2)
	tween.parallel().tween_property(right_drawer, "offset_right", 400.0, 0.2)
	await tween.finished
	right_drawer.visible = false
	active_drawer = null
	status_label.text = "Right drawer closed"


## Left drawer (slides from left)
func _show_left_drawer() -> void:
	# Set initial offscreen position
	left_drawer.offset_left = -400.0
	left_drawer.offset_right = 0.0

	left_drawer.visible = true
	active_drawer = left_drawer

	await get_tree().process_frame

	# Animate slide in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(left_drawer, "offset_left", 0.0, 0.3)
	tween.parallel().tween_property(left_drawer, "offset_right", 400.0, 0.3)


func _close_left_drawer() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(left_drawer, "offset_left", -400.0, 0.2)
	tween.parallel().tween_property(left_drawer, "offset_right", 0.0, 0.2)
	await tween.finished
	left_drawer.visible = false
	active_drawer = null
	status_label.text = "Left drawer closed"


## Top drawer (slides from top)
func _show_top_drawer() -> void:
	# Set initial offscreen position
	top_drawer.offset_top = -250.0
	top_drawer.offset_bottom = 0.0

	top_drawer.visible = true
	active_drawer = top_drawer

	await get_tree().process_frame

	# Animate slide in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(top_drawer, "offset_top", 0.0, 0.3)
	tween.parallel().tween_property(top_drawer, "offset_bottom", 250.0, 0.3)


func _close_top_drawer() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(top_drawer, "offset_top", -250.0, 0.2)
	tween.parallel().tween_property(top_drawer, "offset_bottom", 0.0, 0.2)
	await tween.finished
	top_drawer.visible = false
	active_drawer = null
	status_label.text = "Top drawer closed"


## Bottom drawer (slides from bottom)
func _show_bottom_drawer() -> void:
	# Set initial offscreen position
	bottom_drawer.offset_top = 0.0
	bottom_drawer.offset_bottom = 250.0

	bottom_drawer.visible = true
	active_drawer = bottom_drawer

	await get_tree().process_frame

	# Animate slide in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bottom_drawer, "offset_top", -250.0, 0.3)
	tween.parallel().tween_property(bottom_drawer, "offset_bottom", 0.0, 0.3)


func _close_bottom_drawer() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bottom_drawer, "offset_top", 0.0, 0.2)
	tween.parallel().tween_property(bottom_drawer, "offset_bottom", 250.0, 0.2)
	await tween.finished
	bottom_drawer.visible = false
	active_drawer = null
	status_label.text = "Bottom drawer closed"
