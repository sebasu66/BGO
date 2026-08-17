# Lente 0.9999 — quick guide, if you want more details look at TECHNICAL.md or the readme on github (https://github.com/mbiggeri/lente-godot-photo-mode)

Enable the plugin, add one `LentePhotoMode` node to a 3D scene, and call:

```gdscript
$LentePhotoMode.enter_photo_mode()
```

With no configuration, the current `Camera3D` is inherited and movement is constrained to a fallback bubble around the entry point. Press **Escape** to return, or call `exit_photo_mode()`.

The default `P` binding belongs to the Godot Input Map action `lente_toggle`; it is not hardcoded. Rebind that action, assign a different action name to `activation_action`, or call `toggle_photo_mode()` directly from Steam Input or your own input router.

Use the Inspector’s **Box**, **Sphere**, and **Path** buttons to author the union of allowed movement volumes. Add living paused-world effects to the `lente_unpaused` group.

The UI follows the project locale for English, Italian, and Spanish, with English fallback. Selecting a color look applies its complete grade preset. Captures and JSON metadata default to the OS-resolved `<Documents>/<game name>/screenshots` directory; leave `gallery_directory` empty for this automatic behavior.

For a game-owned full-screen shader or color grade, add its `ColorRect` to **Game screen filters -> Screen Filter Paths**. **Include Screen Filters** fixes whether it appears in the live photo view and PNG; enable **Allow Player Screen Filter Toggle** to expose the localized **Keep game filter** choice instead.

World collision is controlled independently by `collision_enabled`, `collision_mask`, and `collision_radius`. Prefer a simplified wall/level-shell physics layer. Set `collision_enabled = false` when authored bounds alone provide the better feel.

The complete guide and UI contract are in the repository’s root `README.md`, [API.md](API.md), and [TECHNICAL.md](TECHNICAL.md).