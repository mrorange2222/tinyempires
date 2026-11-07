# The Tiny Empire — Game Design Specification

**Status:** Playable prototype rules v0.1 (approved 2026-11-04)

**Purpose:** Initial concept and scope definition

## 1. Game concept

**The Tiny Empire** is a small, turn-based strategy game in which the player starts with a tiny kingdom and competes against rival kingdoms to expand territory, gather resources, build structures, recruit armies, and conquer land.

The game is intentionally simple. It should offer meaningful strategic decisions without the complexity of traditional 4X games. A complete game should take approximately **5–10 minutes**.

**Core gameplay loop:** Expand territory → invest in income or recruit → attack rival territory → collect income → repeat until a capital falls.

## 2. Design principles

- **Simple rules:** A player should understand the basic mechanics within minutes.
- **Meaningful decisions:** Each turn should involve a trade-off.
- **Short sessions:** A complete game should last around 10 minutes.
- **Small map:** Keep a compact island; larger hexes may scroll within the map viewport.
- **Minimal management:** No complicated production chains, inventories, or technology trees.
- **Active opponents:** Rival kingdoms should expand and fight independently.
- **Replayability:** Different maps and rival behavior should create different challenges.

## 3. The game world

The game takes place on a small hexagonal grid with six neighbors per tile.
Hex tiles and a fixed irregular island were approved on 2026-11-04.

Historical map preview scope ([MAP-001](tickets/MAP-001.md)):
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

## 4. Rules v0.1: starting state and resources

Approved in conversation on 2026-11-04 and implemented under
[issue #1](https://github.com/mrorange2222/tinyempires/issues/1).
These experimental rules supersede the earlier resource/building proposals.

- One player (blue) and one rival (coral) on the current fixed island.
- Each starts with a capital and two adjacent owned tiles, 6 gold, and 3 army strength.
- Player capital: axial (3, 1); rival capital: (2, 7). The view is turned
  180 degrees (2026-11-07) so the player starts at the bottom of the screen.
- The entire map is visible. All land is plains with identical gameplay effects.
- Gold is the only resource. No food, wood, stone, population, or upkeep.
- Army strength is kingdom-wide and applies at every border; no individual units.

## 5. Rounds and actions

The player takes any number of gold-funded actions, then explicitly ends their
turn. The rival does the same under identical rules. **Claim, Improve and
Recruit are limited only by gold; Attack is limited to 2 per turn** (attacks
cost no gold, so an uncapped army could sweep the map in one turn). Income is
paid to both kingdoms only after the rival finishes:
**2 + owned tiles + improved owned tiles** gold. No income before round 1.

*Changed 2026-11-06 (approved in conversation): previously a shared limit of
two actions per turn, and Improve cost 4. The shared limit made large
treasuries feel pointless.*

| Action | Gold cost | Effect |
|---|---:|---|
| Expand | 3 | Claim an unowned land tile adjacent to any owned tile |
| Improve | 3 | Add +1 income per round to an owned tile; once per tile |
| Recruit | 3 | Add 2 kingdom-wide army strength; no selected tile needed |
| Attack | 0 (max 2 per turn) | Capture adjacent enemy land when army strength exceeds defense |

Successful attacks use one of the turn's two attacks. Illegal actions change
nothing and return an explicit reason. A player may end their turn early,
including when unable to afford an action. Water is never selectable/playable.

## 6. Improvements and ownership

An improvement is represented by a small gold field symbol. Capitals can also
be improved. There are no building types or production queues yet. Improvements
survive capture, with their income going to the new owner at the next payout.
Territory is marked by blue/coral borders and a subtle color tint; gold dots
indicate adjacent unclaimed land. Crowns identify capitals.

Captured or disconnected owned land remains productive; no supply rules exist.

## 7. Rival behavior

The rival uses the same costs, income, adjacency, combat, and two-action limit.
Its deterministic policy is intentionally simple:

1. Capture a capital if legal, otherwise attack legal enemy land nearest the capital.
2. If bordering enemy territory and unable to attack, recruit when affordable,
   unless its army is already stronger and open land is available to claim.
3. Away from the border, improve once at the start of every third round when possible.
4. Expand toward the player capital, then recruit or improve if expansion is unavailable.
5. End its turn when nothing legal is affordable (it spends all its gold).

Recent actions and payouts appear in the sidebar. Both kingdoms' gold, strength,
land counts, and projected income are public. No hidden AI bonuses.

## 8. Combat

Combat is deterministic, with an explicit preview and confirmation:

- Defense = defending kingdom's army strength, plus **2** on its capital.
- Attack requires army strength **strictly greater** than defense.
- Defender loses **ceil(pre-battle defending army strength / 2)** strength.
- Attacker loses the same amount, with a **minimum loss of 1**.
- Capital defense bonus does not increase casualties.
- The attacker captures the tile and preserves its improvement.
- Example: 7 attacking 4 ends at 5 versus 2, capturing the tile.
- At zero defending strength, the defender loses 0 and the attacker loses 1.

There are no moving armies, random rolls, terrain bonuses, or separate battles.

## 9. Victory, defeat, and pacing

Capturing the rival capital wins immediately; losing the player capital loses
immediately. No subsequent income or actions occur after either outcome.
A result screen offers a completely fresh match. No saves in this prototype.

**Round limit (approved 2026-11-06):** a match lasts at most **20 rounds**.
If no capital has fallen when the rival finishes round 20, the kingdom holding
more land wins; equal land is a draw. No income is paid after the final round.
This replaced "no turn limit" after simulations showed mirrored recruiting
could trade border tiles forever without either capital falling.

The 5-10 minute session length is still a target to measure with real play.
Deterministic smoke matches end by round 20 at the latest; a recruitment-first
strategy captures the rival capital in round 4 (after the 2026-11-06 change to
unlimited spending; it was round 11 under the two-action limit).

Remaining playtest risks: economic investment may be too slow compared with
recruitment, and armies can still grow large late in the match.

## 9a. Interface rules for the prototype

- Selecting a tile shows only the action for that tile type (claim, improve,
  or attack); Recruit is a separate kingdom action that needs no tile.
- Unavailable actions are disabled and the panel states the reason.
- Map hints appear only for legal actions: gold dot = claimable land,
  coral X = enemy tile attackable now. Hover shows a white outline.
- Selection clears after a successful tile action and at the end of the turn.
- Tiles the rival changed in its latest turn are outlined in coral.
- The layout fills the window; hexes fit the map area between 50 and 76 px
  radius, and the map scrolls only below the minimum.

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

The setup milestone [BOOT-001](tickets/BOOT-001.md) established the canvas.
The current playable match is tracked in
[issue #1](https://github.com/mrorange2222/tinyempires/issues/1).

The game engine should be independent of the UI so that rules and combat can be tested without rendering the game.

## 12. Playtest questions

- Is there a useful choice between expansion, improvement, and recruitment?
- Does capital defense give enough time to react to aggression?
- How often do matches stall or repeat the same territory exchanges?
- Can a player recover after an early mistake?
- Does unlimited spending with a 2-attack cap feel good, and are the costs clear?
- How long do actual human matches take?

Change the numbers or rules based on play, not to grow the feature list.

## 12a. Visual style (approved 2026-11-06, [issue #3](https://github.com/mrorange2222/tinyempires/issues/3))

- Simple and elegant, not realistic. Flat vector shapes drawn in code.
- Fonts: Cinzel (titles), Nunito (text), SIL OFL 1.1.
- Decorative terrain (groves, hills, meadows) is cosmetic and must never imply
  a rule. It is drawn under soldiers, tags, crowns and hints so it never hides them.
- Armies: stylised helmeted soldiers (one per army, at most three) with a number tag.
- Top bar: kingdom cards with coin, shield and hex icons.
- Sidebar: cards for the selection, your kingdom, and recent moves.

## 13. Current development goal

Next ruleset (approved, in progress): [Rules v0.2: armies on tiles](rules-v0.2-armies-proposal.md).

Play a complete match against one rival using Rules v0.1. Presentation should
be simple and elegant, not realistic: restrained colors, readable counters,
simple vector markers, and no new asset dependencies.

The prototype should prioritize testing one question:

**Is it fun to make a handful of strategic decisions while competing against rival kingdoms in a tiny world?**

Everything else is secondary.
