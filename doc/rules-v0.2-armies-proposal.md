# Rules v0.2: armies on tiles ("Risk-lite")

**Status:** Approved 2026-11-06. Implementation tracked in [issue #2](https://github.com/mrorange2222/tinyempires/issues/2).
Replaces the kingdom-wide army of [Rules v0.1](the-tiny-empire-game-design-spec-v0.1.md).

Decided in conversation on 2026-11-06:

- Armies live on tiles, like Risk. Attacks are limited by armies, not by a cap.
- Each army can capture at most one tile per turn.
- Combat uses a little dice.

Everything else below is a proposal with suggested starting numbers.

## 1. What stays the same

- Same island, one player vs one rival, full map visible.
- Gold is the only resource. Income after each round: 2 + owned tiles + improvements.
- Claim land: 3 gold, unclaimed land next to your territory.
- Improve: 3 gold, +1 gold per round, once per tile; it survives capture.
- Gold actions are unlimited each turn, limited only by gold.
- Capture the rival capital to win at once. Otherwise, after round 20 the
  kingdom with more land wins; equal land is a draw.

## 2. Armies

- Every owned tile shows an **army count**. Unclaimed land has none.
- Start: **capital 3 armies**, each of the two other starting tiles **1 army**.
- **Recruit:** 3 gold places **+2 armies on one owned tile you choose**.
  *Changed 2026-11-07:* recruiting uses one of the recruits' two steps, so
  they can still **move once or attack** this turn.
- Newly claimed land starts with **0 armies**. An undefended tile (no armies
  and not a capital) falls to any attack without a battle or dice.
- There is no army upkeep and no limit per tile.

## 3. Moving

*Changed 2026-11-07 (approved in conversation): armies have two steps.*

- Each army has **2 steps per turn**. Moving to an adjacent tile you own uses
  1 step. **Attacking uses all remaining steps.** So an army can move twice,
  move then attack, or just attack. One capture per army per turn still holds:
  winners stop on the captured tile.
- When moving, armies with 2 steps go first (they arrive with 1 step left);
  when attacking, armies that already moved go first, keeping rested armies
  free. Recruits still act only from the next turn.
- Tiles may be left empty. That is allowed, but it is risky.

## 4. Attacking with a little dice

Attack from one of your tiles into an **adjacent enemy tile**, choosing how
many ready armies to send.

- **Attack total** = armies sent + attacker roll.
- **Defense total** = armies on the tile + 2 for a capital + defender roll.
- Each roll is a die that shows **0, 1 or 2** with equal chance.
- **Attacker wins if attack total is greater than defense total**; ties go
  to the defender.

Typical chances (no capital bonus):

| Armies sent vs defenders | Attacker wins |
|---|---:|
| 2 fewer or worse | 0% (not allowed) |
| 1 fewer | 11% |
| equal | 33% |
| 1 more | 67% |
| 2 more | 89% |
| 3 or more | 100% |

**Losses** do not depend on the dice, only on who wins:

- Each side loses armies equal to **half the other side's armies, rounded
  up**, but never more than it had.
- **If the attacker wins:** the tile changes owner and the surviving attackers
  move in (a winning attack always keeps at least 1 army). *Changed
  2026-11-07:* the defenders lose half the attackers, rounded up, as in a
  repelled attack; the **survivors retreat** to the adjacent friendly tile
  closest to their capital (ties: the one with more armies). With no friendly
  neighbour they are lost. The preview shows how many would retreat. They are spent and cannot
  attack again this turn (one capture per army per turn).
- **If the attacker loses:** surviving attackers stay on their starting tile
  and are spent for this turn.

Example: 6 armies attack 3 defenders with a 100% chance. The attacker loses 2,
and 4 armies move in. Example: 3 armies attack 4 defenders with an 11% chance.
If the attack fails, the attacker loses 2 (1 remains) and the defender loses 2
(2 remain).

Attacks with a **0% chance are not allowed**. Before confirming, the battle
preview shows the win chance and the result for both outcomes.

## 5. Interface

- A number badge in the kingdom colour on each owned tile shows its armies.
- **Click your tile** to select it. The panel shows armies (ready / total),
  plus **Recruit +2 here** and **Improve**.
- With your tile selected, **click an adjacent tile**:
  - your own tile: **Move** with a "how many" control, defaulting to all ready
    armies;
  - an enemy tile: **Attack** with "how many", win chance and both outcomes;
  - unclaimed land: **Claim** (3 gold).
- Clicking the current target again selects it instead; clicking from a tile
  whose armies have all acted also starts a new selection. Hints mark legal
  targets from the selected tile.
- A short dice line in the recent moves, e.g. "6+1 vs 3+2: captured".

## 6. Rival behaviour

*Added 2026-11-07 (requested in conversation):* each match the rival gets a
hidden **personality**, revealed on the result screen. How it is built and
how to tweak it: [doc/ai.md](ai.md). All follow the same
rules with no bonuses; they only weigh choices differently.

| Personality | Plays like |
|---|---|
| Conqueror | Attacks at about 67% chance, strongly prefers the capital |
| Builder | Claims land near home and improves every round; attacks from round 6 unless sure to win |
| Raider | Attacks at 60%+, prefers weakly held tiles, mostly ignores the capital |
| Guardian | Keeps 4 armies home, defends early, attacks only at 85%+ from round 4 |

Each turn also has a **mood** (20% bolder, 20% more hesitant), and choices
include a little randomness, so the same position is not always played the
same way. In the last two rounds every personality grabs land and may try a
long-shot capital attack. The rival uses its own random generator, separate
from the dice.

In tests against the same opponent: the Conqueror won 8 of 10 (all by capital,
around round 9), the Raider 5 of 10, the Builder 1 and the Guardian 0, with
longer matches. In AI-vs-AI over 20 seeds the first mover now wins 12, the
second 7, with 1 draw.

The common base plan below still applies, with the numbers set by the
personality.

### Base plan

Same rules and information as the player, no bonuses. Each turn it:

1. Attacks wherever its chance is at least 67%, capital first, keeping at
   least 1 army behind on tiles that border the player. It always keeps 2
   armies on its own capital.
2. Spends gold: an improvement every third round, then recruits on the
   border tile under the most pressure, then claims land toward the player.
3. Moves idle inner armies toward the nearest border (up to two steps), and
   re-plans after every move, so it can move and then attack.
4. Counts enemy stacks up to two tiles away as threats.

The rival plays **one move at a time, 0.7 s apart** (approved 2026-11-07),
so each move can be followed in Recent moves and on the map (coral dots, with
a bold ring on its latest move). Animations will build on this later.

Difficulty levels (Easy, Normal, Hard) come after v0.2 is playable.

## 7. Implementation notes

- In AI-vs-AI test matches (20 seeds) with two steps, the side that moves
  first won all 20, mostly by round 9: it gets ahead on land and income early.
  The human always moves first, so this mainly makes the rival easier.
  Human playtesting decides whether to compensate the second mover.

## 8. Approved decisions (2026-11-06)

1. Starting armies: capital 3, the two other starting tiles 1 each.
2. Newly claimed land starts with 0 armies.
3. Capital defense bonus +2, with the 0-1-2 dice.
4. Recruited armies defend at once but act only from the next turn.
   *Replaced 2026-11-07: recruits have one step left.*
5. Defenders left on a captured tile are destroyed. *Replaced 2026-11-07 by
   retreat (section 4).*
6. The 20-round limit and land victory are unchanged.
7. One capture per army per turn; no other attack limit.
