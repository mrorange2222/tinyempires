# The Tiny Empire

A small, offline, turn-based strategy game. Development takes place on Linux,
with Linux and Windows as desktop targets. Mobile is deferred.

## Current milestone

[MAP-004: Empty grassland and non-clickable water](doc/tickets/MAP-004.md),
following [MAP-003: Larger scrollable board and natural still water](doc/tickets/MAP-003.md),
following [MAP-002: Tilted 2D board](doc/tickets/MAP-002.md),
[MAP-001: Clickable hex island mock-up](doc/tickets/MAP-001.md) and
[BOOT-001: Bootstrap the desktop canvas](doc/tickets/BOOT-001.md).
The project shows a fixed irregular hex island with 35 land tiles and
surrounding water. Left-click land to inspect its terrain and axial coordinates.
All land currently uses the default empty plains tile: softly textured grass,
subtle edge lighting, and earthy coastline sides, without letters or objects.
Forest and mountain placement is deferred until later terrain-art passes.
The map uses a tilted 2D projection, raised land edges, and subtle coastline
shadows, not a 3D scene. Visible coastline faces also select their land tile.
Hexes now use a fixed 76-pixel radius instead of shrinking to fit. Scrollbars
expose the full board: use the mouse wheel vertically, Shift + wheel horizontally,
or drag either scrollbar. The view starts centered on the island.
Water is a continuous static shader with deeper offshore blues, turquoise
shallows, subtle surface highlights, and shoreline accents. Water has no grid
lines or letter markers and is not clickable. Clicking it leaves the current
selection and readout unchanged. No animation or external assets are used.
The highlighted tile is a selection, not ownership. There are no turns,
resources, or combat yet.

## Tools

- Godot **4.7.2 stable**, standard edition (GDScript, not .NET).
- Compatibility renderer for the 2D desktop interface.
- No third-party plugins or package-manager dependencies.

The approved local editor lives in `.tools/godot/4.7.2/` and is not versioned.
It was downloaded from the official
[Godot builds release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
and checked against that release's SHA-512 checksum.
On another machine, install the same standard editor version and import
`project.godot`.

## Run on Linux

From the project directory:

```sh
# Open the editor; press F6 to run the current scene or F5 to run the project.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --editor --path .

# Run the game directly.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path .
```

The game opens in a resizable 1280 x 800 window with an 800 x 600 minimum.
Close the window to exit. There are no game actions or save files yet.

## Smoke checks

```sh
# Import and validate the project without a desktop window.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit

# Load the main scene and run ten frames without a desktop window.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 10

# Test map data, connectivity, scrolling, tilted hex/shore selection, and resizing.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/map_smoke.gd
```

Headless checks do not verify rendering. Also launch the game normally and check
the terrain, selection highlight, information readout, and resizing behavior.
Run the same map smoke script without `--headless` to exercise graphical startup.

## Structure and next steps

- `project.godot`: engine configuration and main-scene selection.
- `scenes/main.tscn`: the desktop map layout.
- `map/island_map.gd`: fixed terrain data and hex-neighbor directions.
- `ui/hex_board.gd`: hex rendering and pointer selection.
- `ui/water.gdshader`: static water depth colors, surface detail, and shoreline.
- `ui/main.gd`: selection information readout.
- `tests/map_smoke.gd`: executable map and interface checks.
- [Design specification](doc/the-tiny-empire-game-design-spec-v0.1.md): product
  concept and unresolved gameplay decisions.

Define the first playable rules and approve a follow-up ticket before adding
gameplay. Keep future game rules separate from scene/UI code.

## Desktop exports

Export templates and export presets are not installed/configured yet. Those
belong to a follow-up desktop-build milestone. Validate a Windows export on
Windows early; running this project on Linux is not Windows verification.

When distributing builds, include the required Godot and applicable bundled
third-party license notices. See
[Godot license compliance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).
