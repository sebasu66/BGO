extends PanelContainer

## Template script for drawer content
## Copy this file and customize for your drawer

signal closed()

enum DrawerSide {
	LEFT,   ## Drawer slides in from left
	RIGHT,  ## Drawer slides in from right
	TOP,    ## Drawer slides in from top
	BOTTOM  ## Drawer slides in from bottom
}

enum DrawerScope {
	PARENT_CONTAINED,  ## Drawer positioned relative to parent container
	SCREEN_WIDE        ## Drawer overlays entire screen via CanvasLayer
}

## Which side the drawer slides from
@export var slide_side: DrawerSide = DrawerSide.RIGHT
## Positioning scope: parent-contained or screen-wide overlay
@export var drawer_scope: DrawerScope = DrawerScope.SCREEN_WIDE
## Width of the drawer (for left/right drawers)
@export var drawer_width: float = 400.0
## Height of the drawer (for top/bottom drawers)
@export var drawer_height: float = 300.0

@onready var close_button: Button = %CloseButton
@onready var content: VBoxContainer = %Content

var _initial_offsets_set: bool = false

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)

	# Handle positioning based on scope (from LaborDrawer pattern)
	if drawer_scope == DrawerScope.SCREEN_WIDE:
		# Drawer will be reparented to CanvasLayer at runtime
		# Parent script should handle this via the same pattern as LaborDrawer
		pass

## Optional: Setup method for passing data to the drawer
func setup(data: Dictionary) -> void:
	# Initialize your drawer with data
	pass

func _on_close_pressed() -> void:
	# Emit closed signal - parent script will handle slide-out animation
	closed.emit()
