# Client settings

The Godot client exposes a modular settings overlay through the gear button. These settings control presentation and local interaction preferences; they do not change game rules.

## Current sections

- **Video:** dynamic 3D resolution and its minimum/maximum render scale.
- **3D Quality:** low, medium, and high profiles controlling MSAA and shadow quality.
  It also contains `VISUAL DEBUG`, which toggles runtime diagnostic text,
  one-centimetre grid points, and RGB model-pivot axes. It is disabled by default.
- **Appearance:** global UI template, font/control scale, and accent color,
  applied live to modular UI components and persisted per client.
- **Lighting:** a client-side intensity multiplier for key, fill, and ambient scene light.
- **Gameplay:** hand pickup behavior for stackable components. `ONE AT A TIME`
  is the default and separates one logical unit; `WHOLE STACK` moves the complete
  stack. Non-stackable objects and quantity-one objects always move whole.

Values are saved locally in `user://client_settings.cfg` and applied immediately. The current Compatibility renderer uses bilinear 3D scaling; dynamic resolution adjusts that scale once per second according to observed FPS while respecting the selected bounds.

## Adding a setting

1. Add its default and normalization rule to `BgoClientSettingsController`.
2. Apply it in the appropriate controller method without coupling it to domain state.
3. Add the control under an existing section, or add a new tab in `BgoSettingsPanel`.
4. Add a focused test for its behavior and update this document.

The settings panel is registered as the stable public component `bgo.ui.settings_panel`.

The installed Lente plugin provides editor-only bound gizmos for its photo-mode
nodes. BGO's pivot and grid diagnostics use an owned runtime layer so the same
setting works in desktop and Web clients without coupling gameplay state to an
editor plugin.
