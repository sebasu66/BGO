# UI plugin stack

BGO uses the following presentation and editor-authoring addons:

| Addon | Version | Responsibility |
| --- | ---: | --- |
| Spark | 1.0.2 | Lightweight reactive bindings for conventional Controls and adapters. |
| Reactive UI | 0.12.1 | Declarative UI runtime and `.guitkx` rendering. |
| Reactive UI Editor | 0.10.1 | Godot editor authoring for Reactive UI. |
| GDSS | 0.7.0 | Themes, visual states, transitions, and stylesheet authoring. |
| GodotX Toast | 2.0.0 | Transient success, error, warning, and information feedback. |

Reactive UI Editor depends on Reactive UI and must be enabled after it. Its bundled
native analyzer is editor tooling. Both `reactive_ui_editor` and
`reactive_ui_analyzer` are excluded from Web exports.

These addons belong to presentation and authoring only. BGO Core remains the
authoritative source of game state and legality; UI bindings must not create a
second authoritative game state or couple domain rules to rendering or Firebase.

## Sources and licenses

- Spark: <https://github.com/CosmoMyzrailGorynych/spark>
- Reactive UI and Reactive UI Editor: <https://github.com/yanivkalfa/ReactiveUI-Godot>
- GDSS: <https://github.com/cruglet/gdss>
- GodotX Toast: <https://github.com/godot-x/toast>

Spark, GDSS, and GodotX Toast include permissive licenses in their packages.
Reactive UI and Reactive UI Editor use the ReactiveUI Community License 1.0,
not MIT. It requires a "Made with ReactiveUI" notice and a commercial license
when the license's revenue/funding threshold is exceeded. Review
`addons/reactive_ui/LICENSE` and `addons/reactive_ui_editor/LICENSE` before any
commercial distribution.
