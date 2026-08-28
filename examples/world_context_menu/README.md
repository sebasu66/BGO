# World context menu test scene

Open or run:

```text
res://examples/world_context_menu/world_context_menu_demo.tscn
```

The scene creates a 3D tabletop with a black selected piece, edge-case pieces,
and a world-space contextual menu. Click the black piece or the orange edge
piece to test:

- SubViewport + Reactive UI menu rendering on a billboard surface.
- Menu clamping when the selected object is near the screen edge.
- Background filtering of the other objects.
- Parent activation, nested submenu insertion, back arrow, and animated state
  changes.
- Action highlight followed by the animated menu close.

Press `Escape` or click outside the menu to close it.
