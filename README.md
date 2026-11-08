# The Tiny Empire

A small, offline, turn-based strategy game. Development takes place on Linux,
with Linux and Windows as desktop targets. Mobile is deferred.

## Current milestone

[Issue #2: Rules v0.2, armies on tiles](https://github.com/mrorange2222/tinyempires/issues/2),
following [issue #1](https://github.com/mrorange2222/tinyempires/issues/1).
One player (blue, starting at the bottom) against one computer rival (coral,
at the top) on a 35-tile island.
Full rules: [Rules v0.2](doc/rules-v0.2-armies-proposal.md).

### Play

- Each kingdom starts with 6 gold, 3 tiles, and armies on them: capital 3,
  the two other tiles 1 each. Armies are shown as little soldiers (one per army,
  at most three) with a tag giving the exact number.
- **Click one of your tiles.** The panel offers **Recruit +2 armies here**
  (3 gold) and **Improve** (3 gold, +1 gold per round, once per tile).
- **Then click a neighbouring tile** to target it (white outline and arrow):
  - your tile: **Move** armies there; pick how many with - / +;
  - enemy tile: **Attack** with the chosen armies; the button shows your chance
    and the panel shows what happens if you win or lose;
  - unclaimed land: **Claim** it (3 gold; it starts with no armies).
  Click a target a second time to select it instead.
- Each army has **2 steps** per turn: move twice, move then attack, or just
  attack (attacking ends its turn). The panel shows how many armies can act
  and how many steps they have. A bright dot on the tag means armies there
  can still act. Recruiting uses one of the recruits' steps, so they can move
  or attack once right away. Gold actions are unlimited while you have gold.
- **Recruiting requires established land:** you must have owned the tile at
  the start of your current turn. Newly claimed, captured or recaptured land
  waits until your next turn.
- **Fort:** 6 gold, +5 defense (stacks with the capital's +2). Maintenance
  consumes the tile's normal income, so it earns **0 gold per round**.
  A fort can replace a farm for the full 6 gold, but cannot be converted back.
  It survives capture and does not increase casualty damage.
  Implemented under [issue #7](https://github.com/mrorange2222/tinyempires/issues/7).
- **Battle:** armies sent + a 0-2 roll against defenders (+2 on a capital,
  +5 in a fort)
  + a 0-2 roll; ties go to the defender. Each side loses half the other
  side's armies, rounded up. Winners move in (at least 1). Defenders who
  survive losing a tile retreat to the friendly neighbour closest to their
  capital, or are lost if there is none. A tile with no armies or defense bonuses falls
  without a battle. Dice appear in Recent moves.
- The rival has a hidden **personality** each match (Conqueror, Builder,
  Raider or Guardian) and varying moods, revealed on the result screen.
- Press **End turn**. The rival plays the same rules with no bonuses, **one
  move at a time** (0.7 s apart): each move appears in Recent moves, its tiles
  get a coral dot, and the latest gets a bold ring. Then income:
  **2 + 1 per ordinary tile + 2 per farm tile**; fort tiles contribute zero.
- **Victory:** capture the rival capital, or hold more land when the last
  round ends (equal land is a draw). **Rules** in the header explains everything.
  The result dialog offers **Play another match** or **Main Menu**.
- The game opens on the **title screen**: an animated island at dusk (waving
  banners, turning windmill, drifting clouds) with **New Game**, **How to
  Play** (the rules), **Options** and **Exit Game**. **Resume** appears when
  an unfinished match is available in this running session.
- **Options** (saved): rival speed (Fast / Normal / Slow: 0.4 / 0.7 / 1 s
  between its moves), Windowed or Fullscreen, and map hints On / Off.
- **New Game** opens the match screen: pick the **difficulty** (Easy, Normal,
  Hard, Expert) and **map size**, both remembered for next time; Back returns
  to the title. In a match, **Menu** returns immediately to the title screen,
  without a dialog; choose **New Game** there to start another match.
  The match stays intact and the rival pauses until **Resume**. Starting a
  new match replaces it; exiting the app loses it (no disk saves).
  See [issue #6](https://github.com/mrorange2222/tinyempires/issues/6).
  The current difficulty and map size are shown next to
  the round counter:

  | Map | Land tiles | Rounds |
  |---|---:|---:|
  | Minuscule | ~22 | 15 |
  | Tiny | ~35 | 20 |
  | Small | ~55 | 25 |

  Difficulty: **Easy** (gentle, careful), **Normal** (varied personalities),
  **Hard** (plans coordinated strikes), **Expert** (claim-and-strike combos, a
  guarded capital, all-out last round). Claim-and-strike uses existing rested
  armies, not instant recruits on new land. No level gets bonuses; harder levels
  only play better. See [doc/ai.md](doc/ai.md).

  Each match gets a new island. Islands are mirror-symmetric (turned 180
  degrees they are identical), so both kingdoms start with equal land; you
  start at the bottom, the rival at the top.

Trees, hills, grass and flowers on the land are **decoration only**; all land
plays the same. Capitals show a castle. Improved tiles show one of four farm
designs (wheat field, windmill, orchard, pasture); they all give the same
+1 gold. The top bar uses icons: coin = gold (income next round),
shield = armies, hex = land.
Forts are low stone bastions with battlements, visually distinct from capitals.

The layout fills the window and keeps the information compact: one slim top
bar (title, both kingdoms' gold, armies and land, round, buttons) and a
one-line status bar (hover it for the map legend). In wide windows the info
cards sit in a narrow column on the right; in tall windows (such as a tiled
half screen) they move under the map as a row, so the island can use the full
width. Hexes grow to fill the map area and shrink only down to a minimum, below
which the map scrolls. Water is not clickable.
There are no saves, diplomacy, trade, research, or extra resources.

## Tools

- Godot **4.7.2 stable**, standard edition (GDScript, not .NET).
- Compatibility renderer for the 2D desktop interface.
- No third-party plugins or package-manager dependencies.
- Fonts (approved 2026-11-06): [Cinzel](https://github.com/NDISCOVER/Cinzel)
  for titles and [Nunito](https://github.com/googlefonts/nunito) for text,
  both under the SIL Open Font License 1.1. Licences are in `assets/fonts/`
  and must ship with any distributed build.

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
Close the window to exit. Progress is not saved; Menu > New Game starts a fresh match.

## Smoke checks

```sh
# Import and validate the project without a desktop window.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --quit

# Load the main scene and run ten frames without a desktop window.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 10

# Test exact economy, legal/illegal actions, combat, AI, complete wins/losses.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/game_rules.gd

# Test gameplay buttons, battle confirmation, result screens, and restart.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/game_ui.gd

# Test difficulty levels: setup, signature skills, legal play, and their order.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/ai_levels.gd

# Test generated islands: symmetry, connectivity, starts, sizes, playability.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/map_gen.gd

# Test map data, connectivity, scrolling, tilted hex/shore selection, and resizing.
./.tools/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/map_smoke.gd
```

Headless checks do not verify rendering. Also launch the game normally and check
the terrain, selection highlight, information readout, and resizing behavior.
Run the UI and map smoke scripts without `--headless` to exercise graphical startup.
These checks validate implementation, not game balance or fun.

## Structure and next steps

- `project.godot`: engine configuration and main-scene selection.
- `scenes/main.tscn`: the desktop map layout.
- `map/island_map.gd`: map sizes, the symmetric island generator, the classic
  island (used by tests), and hex-neighbour directions.
- `ui/hex_board.gd`: hex rendering, decorative terrain, soldier army tokens, and pointer selection.
- `ui/water.gdshader`: static water depth colors, surface detail, and shoreline.
- `ui/icon.gd`: small vector icons (coin, shield, hex, crown).
- `ui/tile_art.gd`: shared drawing for map pieces (soldiers, castle, farms,
  trees, hills) in one flat style; reuse it for new pieces.
- `ui/title_screen.gd`: the animated title scene, main menu, and Options.
- `assets/fonts/`: Cinzel and Nunito fonts with their OFL licences.
- `game/empire_game.gd`: match rules (tile armies, seeded dice).
- `game/ai/`: the computer player: shared planner, board analysis, and
  personalities as data files. See [doc/ai.md](doc/ai.md).
- `ui/main.gd`: match presentation, action wiring, battle confirmation, and restart.
- `tests/game_rules.gd`: rule checks with forced dice, AI-vs-AI full matches.
- `tests/ai_levels.gd`: difficulty checks; `tests/ai_tournament.gd`: long
  tournament for tuning (pass a map size after `--`).
- `tests/game_ui.gd`: viewport-driven gameplay and result screen checks.
- `tests/map_smoke.gd`: executable map and interface checks.
- [Design specification](doc/the-tiny-empire-game-design-spec-v0.1.md): product
  concept and unresolved gameplay decisions.

Playtest the current rules before adding systems. Record what choices feel
interesting, whether repeated attacks stall, and how long matches take. See the
[approved rules and known balance risks](doc/the-tiny-empire-game-design-spec-v0.1.md).

## Desktop exports

Export templates and export presets are not installed/configured yet. Those
belong to a follow-up desktop-build milestone. Validate a Windows export on
Windows early; running this project on Linux is not Windows verification.

When distributing builds, include the required Godot and applicable bundled
third-party license notices. See
[Godot license compliance](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html).
