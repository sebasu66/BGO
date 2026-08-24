# UI plugin stack

BGO uses the following presentation and editor-authoring addons:

| Addon | Version | Responsibility |
| --- | ---: | --- |
| Spark | 1.0.2 | Lightweight reactive bindings for conventional Controls and adapters. |
| Reactive UI | 0.12.1 | Declarative UI runtime and `.guitkx` rendering. |
| Reactive UI Editor | 0.10.1 | Godot editor authoring for Reactive UI. |
| GDSS | 0.7.0 | Themes, visual states, transitions, and stylesheet authoring. |
| GodotX Toast | 2.0.0 | Transient success, error, warning, and information feedback. |
| Developer Console | 1.5.0 | DEV-only runtime console with automatic BGO game-object command discovery. |
| Lucide Icons for Godot | 1.1.0 + fixed Lucide 1.33.0 subset | Consistent SVG-derived runtime and editor icons. |

Reactive UI Editor depends on Reactive UI and must be enabled after it. Its bundled
native analyzer is editor tooling. Both `reactive_ui_editor` and
`reactive_ui_analyzer` are excluded from Web exports.

These addons belong to presentation and authoring only. BGO Core remains the
authoritative source of game state and legality; UI bindings must not create a
second authoritative game state or couple domain rules to rendering or Firebase.

The Developer Console is a separate DEV tooling surface. Its BGO bridge
registers public methods from approved game-object/component hosts, supports
typed arguments and per-object `consoleHelp()`/`console_help()`, and removes
commands when objects leave the scene tree. It must not be used as a production
gameplay authority or as a way to bypass permissions and domain validation.

## Componentes de UI de BGO

Los componentes reutilizables de interfaz se publican mediante el registro
estable de BGO:

- `bgo.ui.context_menu`: menú contextual reactivo, con filas jerárquicas,
  estados de selección/activación y animaciones. Puede alojarse en un
  `SubViewport` transparente y mostrarse como billboard en el espacio 3D.
- `bgo.ui.toast`: fachada de componente para el runtime `GodotxToast` instalado.
  Centraliza mensajes informativos, éxito, error, advertencia y estados de
  carga sin duplicar el servicio del addon.
- `bgo.ui.action_strip`: tira lateral declarativa de acciones. Recibe IDs,
  etiquetas e IDs de Lucide; no contiene lógica de partida.
- `bgo.ui.session_header`: cabecera modular para sesión, modo, perfil y turno.

## Perfiles globales de apariencia

`BgoUiThemeProfiles` construye un único `Theme` compartido y lo aplica a los
controles superiores del `CanvasLayer` de UI. Los componentes usan variaciones
semánticas (`BgoShellPanel`, `BgoHeaderPanel`, `BgoShellButton` y
`BgoEmphasisButton`) en lugar de copiar estilos locales.

Settings expone actualmente el perfil base, escala de fuente/controles y color
de acento. Los valores se guardan en `user://client_settings.cfg` y se aplican
en vivo. Para añadir una plantilla se agrega una entrada a `PROFILES` en
`src/components/ui/theme_profiles/ui_theme_profiles.gd`; la lógica de los
componentes no cambia. Un juego podrá proponer una plantilla declarativa, pero
la preferencia local del cliente debe conservar prioridad.

Los juegos deben referenciar estos IDs y la configuración permitida, no las
rutas internas `.gd` o `.tscn`. El menú mantiene sus variables de estilo y
tamaño agrupadas al inicio de su clase para facilitar la personalización por
tema.

## Sources and licenses

- Spark: <https://github.com/CosmoMyzrailGorynych/spark>
- Reactive UI and Reactive UI Editor: <https://github.com/yanivkalfa/ReactiveUI-Godot>
- GDSS: <https://github.com/cruglet/gdss>
- GodotX Toast: <https://github.com/godot-x/toast>
- Developer Console: <https://store.godotengine.org/asset/jitspoe/console/>
- Lucide Icons for Godot: <https://github.com/Rodrigoalvesr/lucide-godot>
- Lucide icon sources: <https://github.com/lucide-icons/lucide>

The Lucide addon is pinned to commit
`bfc6e57430c67ce59d788aa0c674559aeb20fe4e`. BGO vendors a fixed subset of
Lucide 1.33.0 SVGs so editor startup and exported clients do not depend on a
GitHub download.

Spark, GDSS, and GodotX Toast include permissive licenses in their packages.
Reactive UI and Reactive UI Editor use the ReactiveUI Community License 1.0,
not MIT. It requires a "Made with ReactiveUI" notice and a commercial license
when the license's revenue/funding threshold is exceeded. Review
`addons/reactive_ui/LICENSE` and `addons/reactive_ui_editor/LICENSE` before any
commercial distribution.
