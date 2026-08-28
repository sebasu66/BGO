@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("DrawerManager", "res://addons/properUI_drawer/DrawerManager.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("DrawerManager")
