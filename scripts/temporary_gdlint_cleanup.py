#!/usr/bin/env python3
from pathlib import Path


def update_main_3d_base() -> None:
    path = Path("src/demo/main_3d_base.gd")
    text = path.read_text(encoding="utf-8")
    onready = """@onready var camera: Camera3D = $Camera3D\n@onready var title_label: Label = $UI/Title\n@onready var hint_label: Label = $UI/Hint\n\n"""
    if onready not in text:
        raise RuntimeError("main_3d_base onready block not found")
    text = text.replace(onready, "", 1)
    marker = "var _place_button: Button\n\n\n"
    if marker not in text:
        raise RuntimeError("main_3d_base variable marker not found")
    text = text.replace(marker, "var _place_button: Button\n\n" + onready + "\n", 1)
    text = text.replace(
        '\t\thint_label.text = "Shared display · Firebase TEST001 · player hand areas live outside the board."',
        '\t\thint_label.text = (\n'
        '\t\t\t"Shared display · Firebase TEST001 · "\n'
        '\t\t\t+ "player hand areas live outside the board."\n'
        '\t\t)',
        1,
    )
    text = text.replace(
        '\thint_label.text = "Drag to orbit · PICK UP moves a piece into your hand · PLACE moves the active hand piece to the board."',
        '\thint_label.text = (\n'
        '\t\t"Drag to orbit · PICK UP moves a piece into your hand · "\n'
        '\t\t+ "PLACE moves the active hand piece to the board."\n'
        '\t)',
        1,
    )
    path.write_text(text, encoding="utf-8")


def update_main_componentized() -> None:
    path = Path("src/demo/main_componentized.gd")
    text = path.read_text(encoding="utf-8")
    old_orientation = '''\tif OS.has_feature("web"):\n\t\t(\n\t\t\tJavaScriptBridge\n\t\t\t. eval(\n\t\t\t\t"document.documentElement.style.background='#05070a'; document.body.style.margin='0'; document.body.style.overflow='hidden';",\n\t\t\t\ttrue\n\t\t\t)\n\t\t)'''
    new_orientation = '''\tif OS.has_feature("web"):\n\t\tvar page_style := (\n\t\t\t"document.documentElement.style.background='#05070a';"\n\t\t\t+ "document.body.style.margin='0';"\n\t\t\t+ "document.body.style.overflow='hidden';"\n\t\t)\n\t\tJavaScriptBridge.eval(page_style, true)'''
    if old_orientation not in text:
        raise RuntimeError("orientation JS block not found")
    text = text.replace(old_orientation, new_orientation, 1)

    old_fullscreen = '''\t(\n\t\tJavaScriptBridge\n\t\t. eval(\n\t\t\t"(async()=>{try{const e=document.documentElement;if(e.requestFullscreen)await e.requestFullscreen();if(screen.orientation&&screen.orientation.lock)await screen.orientation.lock('landscape');}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();",\n\t\t\ttrue\n\t\t)\n\t)'''
    new_fullscreen = '''\tvar fullscreen_script := (\n\t\t"(async()=>{try{const e=document.documentElement;"\n\t\t+ "if(e.requestFullscreen)await e.requestFullscreen();"\n\t\t+ "if(screen.orientation&&screen.orientation.lock)"\n\t\t+ "await screen.orientation.lock('landscape');"\n\t\t+ "}catch(e){console.warn('BGO fullscreen/orientation:',e);}})();"\n\t)\n\tJavaScriptBridge.eval(fullscreen_script, true)'''
    if old_fullscreen not in text:
        raise RuntimeError("fullscreen JS block not found")
    text = text.replace(old_fullscreen, new_fullscreen, 1)
    path.write_text(text, encoding="utf-8")


def main() -> None:
    update_main_3d_base()
    update_main_componentized()


if __name__ == "__main__":
    main()
