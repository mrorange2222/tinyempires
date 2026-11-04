# The Tiny Empire — Game Design Specification

**Status:** Draft v0.1  
**Purpose:** Initial concept and scope definition

## 1. Game concept

**The Tiny Empire** is a small, turn-based strategy game in which the player starts with a tiny kingdom and competes against rival kingdoms to expand territory, gather resources, build structures, recruit armies, and conquer land.

The game is intentionally simple. It should offer meaningful strategic decisions without the complexity of traditional 4X games. A complete game should take approximately **5–10 minutes**.

**Core gameplay loop:** Gather resources → expand territory → build → recruit → fight rival kingdoms → repeat until victory or defeat.

## 2. Design principles

- **Simple rules:** A player should understand the basic mechanics within minutes.
- **Meaningful decisions:** Each turn should involve a trade-off.
- **Short sessions:** A complete game should last around 10 minutes.
- **Small map:** The entire game should fit comfortably on one screen.
- **Minimal management:** No complicated production chains, inventories, or technology trees.
- **Active opponents:** Rival kingdoms should expand and fight independently.
- **Replayability:** Different maps and rival behavior should create different challenges.

## 3. The game world

The game takes place on a small hexagonal grid with six neighbors per tile.
Hex tiles and a fixed irregular island were approved on 2026-11-04.

Map preview scope ([MAP-001](tickets/MAP-001.md)):
- A fixed irregular island with 35 connected land tiles, comparable in area
  to the original 7x7 board proposal.
- A 9x9 offset-row envelope includes surrounding non-playable water.
- Plains, forest, and mountains use simple colors and letter markers.
- Selecting a tile displays its terrain and axial hex coordinates.
- Water can be inspected but cannot be used for expansion; no naval systems.
- Terrain placement is illustrative, not yet balanced for gameplay.
- No procedural generation in the initial map.

Presentation update ([MAP-002](tickets/MAP-002.md)), approved on 2026-11-04:
- Tilted 2D hex surfaces with raised land edges and subtle coastline shadows.
- No actual 3D scene or camera; map coordinates and adjacency are unchanged.
- Selection follows projected surfaces and visible coastline faces.
- Upright terrain artwork is deferred.

Water and scale update ([MAP-003](tickets/MAP-003.md)), approved on 2026-11-04:
- Same island and tile counts, with larger fixed-size hexes (76-pixel radius).
- A scrollable map viewport replaces fit-to-window scaling; both axes can scroll.
- Still water with natural depth colors, subtle surface detail, and shoreline accents.
- Water tile grid lines and markers are hidden; inspection remains available.
- No water animation, external assets, or new dependencies.

Empty land update ([MAP-004](tickets/MAP-004.md)), approved on 2026-11-04:
- Supersedes the preview terrain mix: all 35 land tiles start as empty plains.
- Default land has textured grass, subtle edge lighting, and earthy coastal sides.
- No terrain letter markers, props, forests, mountains, or buildings in this pass.
- Water is non-clickable; water clicks leave selection and readout unchanged.
- Island shape, scroll controls, projection, and land/coastline selection are unchanged.
- Forest and mountain terrain remain future design options, not implemented gameplay.

Future gameplay proposal:
- The player starts with a small settlement and a few owned tiles.
- One or two rival kingdoms occupy other parts of the map.
- Unclaimed territory is available for expansion.

### Terrain types

| Terrain | Potential benefit |
|---|---|
| Plains | Food production |
| Forest | Wood production |
| Mountains | Stone or defensive advantage |
| Water | Blocks movement or expansion |

Terrain should be visually recognizable and have straightforward gameplay effects.

## 4. Resources

The initial resource system should be small.

| Resource | Primary use |
|---|---|
| Food | Population upkeep |
| Wood | Buildings and expansion |
| Stone | Defensive structures and stronger buildings |
| Gold | Special purchases and military recruitment |

The exact resource list is not final. Three resources could be sufficient for the first prototype, with stone added only if it creates meaningful decisions.

Resources are collected from owned territory or through a dedicated gathering action. Avoid complicated resource conversion and production chains.

## 5. Player actions

Each turn, the player chooses one action.

| Action | Description |
|---|---|
| Expand | Claim an adjacent unowned tile by paying its cost |
| Gather | Collect resources |
| Build | Construct a building on an owned tile |
| Recruit | Spend resources to increase army strength |
| Attack | Attack an adjacent enemy tile |

The player should not have to manage individual citizens, workers, or soldiers.

## 6. Buildings

Initial proposed building types:

| Building | Purpose |
|---|---|
| Farm | Produces food |
| Lumber mill | Produces wood |
| Mine | Produces stone |
| Fort | Improves defensive strength |

Buildings should be inexpensive to understand and have one clear purpose.

## 7. Rival kingdoms

Rival kingdoms are an important part of the game. They should operate automatically, using simple rules rather than sophisticated AI.

Each rival should be able to:
- Expand into neighboring territory.
- Acquire resources.
- Build structures.
- Recruit soldiers.
- Attack the player or other rivals.

Rivals should follow the same basic rules as the player, although their decision-making can be simplified.

The objective is to create competition over territory and resources, not simulate a complicated political world. No diplomacy, trading, alliances, or negotiations.

## 8. Combat

Combat should be simple and quick.

Proposed mechanics:
- Each army has a numerical strength.
- Terrain can provide defensive bonuses.
- Fortifications can increase defensive strength.
- The stronger side generally wins.
- The losing side suffers casualties.
- Winning an attack can capture the contested tile.

Combat should not involve individual units, formations, tactical movement, or a separate battle interface. The exact combat formula remains undecided.

## 9. Game duration and victory

Initial proposal:
- 10–12 turns per game.
- Approximately 5–10 minutes per session.
- One or two rival kingdoms.

Possible victory conditions:
1. **Conquest:** Defeat all rival kingdoms.
2. **Territorial dominance:** Control the most territory when the game ends.

A defeat condition should also exist, such as losing the player's original settlement. The final victory conditions need further design.

## 10. Explicitly excluded features

To preserve the simplicity of the game, the following are outside the initial scope:
- Trading between kingdoms.
- Diplomacy and alliances.
- Technology trees.
- Research systems.
- Complex population management.
- Individual soldiers or unit types.
- Tactical battles.
- Detailed economic simulations.
- Multiple resource conversion chains.
- Multiplayer.
- Online accounts or backend services.

These features should not be added unless the basic game proves fun and there is a compelling reason.

## 11. Technical direction

Desktop technical direction approved on 2026-11-04:
- Godot 4.7.2 stable, standard edition, with GDScript.
- Linux development environment; Linux and Windows desktop targets.
- Compatibility renderer and Godot controls for the 2D interface.
- Game rules kept separate from scenes and UI code.
- Local saves through Godot's user-data paths when saving is implemented.
- Offline single-player; no backend required initially.
- Mobile adaptation deferred and outside the first desktop release scope.

The first setup milestone is [BOOT-001](tickets/BOOT-001.md): a runnable
desktop canvas with no gameplay. Gameplay questions below remain unresolved.

The game engine should be independent of the UI so that rules and combat can be tested without rendering the game.

## 12. Open design questions

These decisions remain unresolved and should be settled before implementation.

1. **Turns:** Does each kingdom take one action per round, or do rivals get multiple actions?
2. **Resources:** Start with three resources or four?
3. **Production:** Are resources generated automatically every turn, or does the player need to use Gather?
4. **Population:** Is population a resource, a simple upkeep requirement, or unnecessary?
5. **Combat:** What is the exact strength and casualty formula?
6. **Rival AI:** Should rivals prioritize expansion, resource acquisition, or attacking nearby enemies?
7. **Victory:** Conquer all rivals, control the most territory after a fixed number of turns, or both?
8. **Map variety:** Start with the approved fixed island; revisit additional
   maps or procedural generation only after gameplay is tested.

## 13. Initial development goal

Build a playable prototype with:
- One small map.
- One player kingdom.
- Two rival kingdoms.
- Basic resource collection.
- Territory expansion.
- A few building types.
- Recruitment.
- Basic combat.
- Simple rival AI.
- A clear win/loss condition.

The prototype should prioritize testing one question:

**Is it fun to make a handful of strategic decisions while competing against rival kingdoms in a tiny world?**

Everything else is secondary.
