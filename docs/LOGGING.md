# Logging

BGO combines Godot 4.7 native file logging with structured domain/component events.

## Native rotation

`project.godot` enables the engine file sink at `user://logs/bgo.log` and retains ten
session files through `debug/file_logging/max_log_files`. Godot rotates the previous
session log automatically. On Windows, `user://logs` resolves below the BGO Godot
application-data directory.

## Structured BGO events

`BgoLogger` writes JSON events to the Godot output, the per-run JSONL diagnostic sink
and the existing prototype remote sink. In debug builds it also forwards every accepted
event to the jitspoe in-game console, preserving info, warning and error coloring without
printing the console line back into Godot and creating a loop. Its minimum level is configurable through
`set_minimum_level()` and accepts `debug`, `info`, `warning`, or `error`. Debug builds
default to `debug`; release builds default to `info`.

Declarative composition records, among others:

- `COMPONENT_INSTANTIATION_STARTED`;
- `COMPONENT_PROPERTY_APPLIED`;
- `COMPONENT_PLACED`;
- `COMPONENT_INSTANCE_READY`;
- component-owned lifecycle events such as `COMPONENT_READY`,
  `COMPONENT_CONFIGURED`, and `COMPONENT_REBUILT`;
- `TABLE_COMPOSITION_READY`.

Components emit `component_event(event_name, payload)`. The composition/runtime adapter
adds stable instance and component IDs before forwarding the event to `BgoLogger`.
