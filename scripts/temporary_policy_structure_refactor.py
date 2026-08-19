#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

FUNC_RE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.MULTILINE)


def function_spans(text: str) -> list[tuple[str, int, int]]:
    matches = list(FUNC_RE.finditer(text))
    spans: list[tuple[str, int, int]] = []
    for index, match in enumerate(matches):
        start = match.start()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        spans.append((match.group(1), start, end))
    return spans


def replace_function(text: str, name: str, replacement: str) -> str:
    for func_name, start, end in function_spans(text):
        if func_name == name:
            return text[:start] + replacement.rstrip() + "\n\n\n" + text[end:].lstrip("\n")
    raise RuntimeError(f"function {name} not found")


def split_main_3d() -> None:
    path = Path("src/demo/main_3d.gd")
    text = path.read_text(encoding="utf-8")
    first_func = FUNC_RE.search(text)
    animate = re.search(r"^func _animate_piece\s*\(", text, re.MULTILINE)
    if first_func is None or animate is None:
        raise RuntimeError("main_3d split points not found")

    header = text[: first_func.start()]
    tail = text[animate.start() :]
    middle = text[first_func.start() : animate.start()]

    base = header + tail
    derived = 'extends "res://src/demo/main_3d_base.gd"\n\n' + middle.lstrip("\n")

    new_input = '''func _input(event: InputEvent) -> void:
\tif client_role != ROLE_PLAYER:
\t\treturn
\tif event is InputEventScreenTouch:
\t\t_handle_pointer_screen_touch(event)
\t\treturn
\tif event is InputEventScreenDrag:
\t\t_handle_pointer_screen_drag(event)
\t\treturn
\tif event is InputEventMouseButton:
\t\t_handle_pointer_mouse_button(event)
\t\treturn
\tif event is InputEventMouseMotion:
\t\t_handle_pointer_mouse_motion(event)


func _handle_pointer_screen_touch(event: InputEventScreenTouch) -> void:
\tif _pointer_is_over_controls(event.position):
\t\treturn
\tif event.pressed:
\t\t_begin_pointer(event.position, "touch")
\telse:
\t\t_end_pointer(event.position, "touch")


func _handle_pointer_screen_drag(event: InputEventScreenDrag) -> void:
\tif _pointer_is_over_controls(event.position):
\t\treturn
\t_pointer_dragged = true
\t_orbit_camera(event.relative)


func _handle_pointer_mouse_button(event: InputEventMouseButton) -> void:
\tif event.button_index != MOUSE_BUTTON_LEFT or _pointer_is_over_controls(event.position):
\t\treturn
\tif event.pressed:
\t\t_begin_pointer(event.position, "mouse")
\telse:
\t\t_end_pointer(event.position, "mouse")


func _handle_pointer_mouse_motion(event: InputEventMouseMotion) -> void:
\tif not _pointer_down or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
\t\treturn
\tif event.position.distance_to(_pointer_start) <= 8.0:
\t\treturn
\t_pointer_dragged = true
\t_orbit_camera(event.relative)'''
    derived = replace_function(derived, "_input", new_input)

    Path("src/demo/main_3d_base.gd").write_text(base, encoding="utf-8")
    path.write_text(derived, encoding="utf-8")


def split_main_componentized() -> None:
    path = Path("src/demo/main_componentized.gd")
    text = path.read_text(encoding="utf-8")
    first_func = FUNC_RE.search(text)
    if first_func is None:
        raise RuntimeError("main_componentized has no functions")

    header = text[: first_func.start()]
    header = header.replace(
        'extends "res://src/demo/main_3d.gd"',
        'extends "res://src/demo/main_3d.gd"',
        1,
    )
    move = {
        "_load_game_definition",
        "_show_definition_errors",
        "_create_board",
        "_create_player_areas",
        "_configure_player_area",
        "_player_definition",
        "_player_color",
        "_color_from_definition",
        "_configure_camera",
        "_create_piece_from_state",
        "_normalize_location_type",
        "_target_world_position",
        "_player_area_world_position",
        "_private_hand_proxy_world_position",
        "_collection_slot_index",
        "_cell_world",
    }

    moved_blocks: list[str] = []
    kept_blocks: list[str] = []
    for name, start, end in function_spans(text):
        block = text[start:end].rstrip() + "\n\n\n"
        (moved_blocks if name in move else kept_blocks).append(block)

    base = header + "".join(moved_blocks).rstrip() + "\n"
    child = 'extends "res://src/demo/main_componentized_base.gd"\n\n' + "".join(kept_blocks).lstrip()

    layout = '''func _apply_landscape_player_layout() -> void:
\tif _player_controls == null:
\t\treturn
\t_player_controls.visible = false
\tvar root := _create_landscape_player_root()
\t_add_landscape_player_identity(root)
\t_add_landscape_collection_controls(root)
\t_add_landscape_action_controls(root)
\tif _mode_label != null:
\t\t_mode_label.visible = false
\tif _debug_label != null:
\t\t_debug_label.visible = false
\t_set_mode(MODE_PICK_UP)
\t_refresh_hand_strip()


func _create_landscape_player_root() -> VBoxContainer:
\tvar panel := PanelContainer.new()
\tpanel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
\tpanel.offset_left = -410.0
\tpanel.offset_right = -12.0
\tpanel.offset_top = 14.0
\tpanel.offset_bottom = -14.0
\t$UI.add_child(panel)
\t_player_controls = panel
\tvar root := VBoxContainer.new()
\troot.add_theme_constant_override("separation", 8)
\tpanel.add_child(root)
\treturn root


func _add_landscape_player_identity(root: VBoxContainer) -> void:
\tvar player_title := Label.new()
\tvar definition := _player_definition(player_id)
\tplayer_title.text = (
\t\t"%s · %s"
\t\t% [
\t\t\tstr(definition.get("name", player_id.replace("_", " ").capitalize())),
\t\t\tplayer_id.to_upper().replace("_", " ")
\t\t]
\t)
\tplayer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\tplayer_title.add_theme_font_size_override("font_size", 18)
\tplayer_title.add_theme_color_override("font_color", _player_color(player_id))
\troot.add_child(player_title)


func _add_landscape_collection_controls(root: VBoxContainer) -> void:
\tvar area_title := Label.new()
\tarea_title.text = "PLAYER AREA"
\tarea_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\troot.add_child(area_title)
\tvar area_scroll := ScrollContainer.new()
\tarea_scroll.custom_minimum_size = Vector2(370, 74)
\tarea_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\tarea_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\troot.add_child(area_scroll)
\t_hand_strip = HBoxContainer.new()
\t_hand_strip.add_theme_constant_override("separation", 6)
\tarea_scroll.add_child(_hand_strip)

\tvar transfer_row := HBoxContainer.new()
\ttransfer_row.alignment = BoxContainer.ALIGNMENT_CENTER
\ttransfer_row.add_theme_constant_override("separation", 8)
\troot.add_child(transfer_row)
\t_transfer_to_hand_button = Button.new()
\t_transfer_to_hand_button.text = "TO HAND ↓"
\t_transfer_to_hand_button.custom_minimum_size = Vector2(150, 38)
\t_transfer_to_hand_button.pressed.connect(_move_selected_to_hand)
\ttransfer_row.add_child(_transfer_to_hand_button)
\t_transfer_to_area_button = Button.new()
\t_transfer_to_area_button.text = "↑ TO AREA"
\t_transfer_to_area_button.custom_minimum_size = Vector2(150, 38)
\t_transfer_to_area_button.pressed.connect(_move_selected_to_area)
\ttransfer_row.add_child(_transfer_to_area_button)

\tvar hand_title := Label.new()
\thand_title.text = "HAND"
\thand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\troot.add_child(hand_title)
\tvar hand_scroll := ScrollContainer.new()
\thand_scroll.custom_minimum_size = Vector2(370, 74)
\thand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
\thand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
\troot.add_child(hand_scroll)
\t_private_hand_strip = HBoxContainer.new()
\t_private_hand_strip.add_theme_constant_override("separation", 6)
\thand_scroll.add_child(_private_hand_strip)


func _add_landscape_action_controls(root: VBoxContainer) -> void:
\tvar action_row := HBoxContainer.new()
\taction_row.alignment = BoxContainer.ALIGNMENT_CENTER
\taction_row.add_theme_constant_override("separation", 8)
\troot.add_child(action_row)
\t_pickup_button = Button.new()
\t_pickup_button.text = "PICK UP"
\t_pickup_button.toggle_mode = true
\t_pickup_button.custom_minimum_size = Vector2(110, 54)
\t_pickup_button.pressed.connect(func(): _set_mode(MODE_PICK_UP))
\taction_row.add_child(_pickup_button)
\t_place_button = Button.new()
\t_place_button.text = "PLACE"
\t_place_button.toggle_mode = true
\t_place_button.custom_minimum_size = Vector2(110, 54)
\t_place_button.pressed.connect(func(): _set_mode(MODE_PLACE))
\taction_row.add_child(_place_button)
\tvar fullscreen_button := Button.new()
\tfullscreen_button.text = "FULL SCREEN"
\tfullscreen_button.custom_minimum_size = Vector2(120, 54)
\tfullscreen_button.pressed.connect(_enter_web_fullscreen)
\taction_row.add_child(fullscreen_button)'''
    child = replace_function(child, "_apply_landscape_player_layout", layout)

    Path("src/demo/main_componentized_base.gd").write_text(base, encoding="utf-8")
    path.write_text(child, encoding="utf-8")


def refactor_main_filtered_input() -> None:
    path = Path("src/demo/main_filtered.gd")
    text = path.read_text(encoding="utf-8")
    replacement = '''func _input(event: InputEvent) -> void:
\tif client_role != ROLE_PLAYER:
\t\treturn
\tif event is InputEventScreenTouch:
\t\t_handle_screen_touch(event)
\t\treturn
\tif event is InputEventScreenDrag:
\t\t_handle_screen_drag(event)
\t\treturn
\tif event is InputEventMouseButton:
\t\t_handle_player_mouse_button(event)
\t\treturn
\tif event is InputEventMouseMotion:
\t\t_handle_player_mouse_motion(event)


func _handle_player_mouse_button(event: InputEventMouseButton) -> void:
\tif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
\t\t_zoom_player_camera(0.90)
\t\treturn
\tif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
\t\t_zoom_player_camera(1.10)
\t\treturn
\tif event.button_index != MOUSE_BUTTON_LEFT or _pointer_is_over_controls(event.position):
\t\treturn
\tif event.pressed:
\t\t_begin_pointer(event.position, "mouse")
\telse:
\t\t_end_pointer(event.position, "mouse")


func _handle_player_mouse_motion(event: InputEventMouseMotion) -> void:
\tif not _pointer_down or (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
\t\treturn
\tif _pointer_is_over_controls(event.position):
\t\treturn
\tif event.position.distance_to(_pointer_start) <= 8.0:
\t\treturn
\t_pointer_dragged = true
\t_pan_player_camera(event.relative)'''
    path.write_text(replace_function(text, "_input", replacement), encoding="utf-8")


def main() -> None:
    split_main_3d()
    split_main_componentized()
    refactor_main_filtered_input()


if __name__ == "__main__":
    main()
