# Computer player

How the rival thinks, and how to tweak or extend it. Rules are in
[Rules v0.2](rules-v0.2-armies-proposal.md).

## Files

| File | Role |
|---|---|
| `game/ai/ai_player.gd` | The planner shared by every personality |
| `game/ai/ai_board.gd` | Shared board analysis (threats, front distance, staging) |
| `game/ai/ai_personality.gd` | The personality settings (weights), with blending |
| `game/ai/personalities/*.tres` | The built-in personalities as data |
| `game/ai/ai_personalities.gd` | List of built-in personalities |

`game/empire_game.gd` only asks the planner for the next action and executes
it through the same rules as the player (`ai_step()`), so the computer can
never make an illegal move or get a bonus.

## How a turn is planned

The planner returns **one action at a time** and re-plans after every action,
so armies can move and then attack. Each time, it tries these stages in order
and takes the first that has something to do:

1. **Attack:** every own tile with ready armies × every adjacent enemy tile.
   Candidates below the attack threshold are skipped. The rest are scored:
   win chance, closeness to the enemy capital, how much it outnumbers the
   target (`weak_target_bias`), a capital bonus (`capital_bonus`), and some
   random spread (`noise`). Highest score wins.
2. **Move:** idle armies that do not border the enemy step toward the front;
   the capital keeps `capital_garrison` armies.
3. **Spend gold** (while it has 3+ gold), first match wins:
   1. Top up the capital garrison.
   2. Improve a safe tile every `improve_every` rounds.
   3. Reinforce the most threatened tile (`defend_slack` makes it cautious).
   4. Claim land while not ahead by more than `land_margin` (toward its own
      capital if `claim_near_home`, else toward yours).
   5. Recruit where an attack is cheapest to set up (`capital_staging`
      favours tiles next to your capital).
   6. Otherwise claim land, else recruit at home.

At the start of each turn it rolls a **mood** that shifts the attack
threshold: 20% bolder (-0.10), 20% more hesitant (+0.12). In the last two
rounds every personality grabs land and may try a long shot at the capital.

## Personality settings

| Setting | Meaning |
|---|---|
| `min_chance` | Lowest win chance it attacks at |
| `attack_from_round` | Before this round it only attacks sure wins |
| `capital_bonus` | Extra score for attacking the enemy capital |
| `weak_target_bias` | Preference for targets it outnumbers by more |
| `capital_garrison` | Armies always kept on its capital |
| `defend_slack` | Reinforces even when this much stronger than the threat |
| `improve_every` | Improves once every this many rounds |
| `land_margin` | Keeps claiming while its land <= yours + this |
| `claim_near_home` | Claims near its own capital instead of toward yours |
| `capital_staging` | How strongly it gathers armies next to your capital |
| `noise` | Random spread added to scores |

## Common changes

- **Tweak a personality:** edit its `.tres` file in
  `game/ai/personalities/`, in Godot's Inspector or as text.
- **Add a personality:** copy a `.tres` file, give it a new `display_name`
  and `description`, and add it to `ALL` in `ai_personalities.gd`. Each
  match picks one at random.
- **Blend two:** `raider.blended_with(builder, 0.3)` returns a new
  personality 30% of the way from Raider to Builder. Numbers are
  interpolated (whole numbers rounded); on/off settings follow the heavier
  side. Use `game.set_ai_personality(side, blend)` to play against it.
- **Add a setting:** declare an `@export` field in `ai_personality.gd`, use it
  in the planner, and set it in the `.tres` files. Blending picks up new
  fields automatically.
- **React to a new rule:** put board analysis in `ai_board.gd` (all
  personalities benefit), then add a consideration to the relevant stage, or a
  new stage in `next_action()`, in `ai_player.gd`.

## Randomness and testing

The planner uses its own random generator (`ai_rng`), separate from the dice,
so seeded games are reproducible and forced dice in tests are not consumed by
the AI. `tests/game_rules.gd` checks that every personality plays legally,
that personalities really behave differently, that blends work, and that
AI-vs-AI matches always finish by round 20.
