extends RefCounted
## Difficulty levels for the computer player.
##
## A level never gives bonuses: it only changes which personalities the rival
## may have and which planning skills the shared planner (ai_player.gd) uses.
## Every level keeps the basics: defend the capital, no hopeless attacks, keep
## claiming land.

const LEVELS := {
	"Easy": {
		"description": "A gentle rival: careful, attacks only when it is safe and never builds up big strikes.",
		"personalities": ["Builder", "Guardian"],
		"threshold_shift": 0.1,   # needs a better chance before attacking
		"staging": false,         # recruits to defend and to grow, not to build up attacks
		"noise_scale": 1.5,       # more varied, less sharp choices
		"mood_scale": 1.0,
		"strikes": false,         # no coordinated attacks
		"smart_targets": false,   # values all enemy tiles alike
		"recruit_threat": false,  # ignores that you can recruit and strike
		"risk_check": false,      # does not weigh counter-attacks
		"capital_guard": false,   # fixed capital garrison
		"early_improve": false,   # improves on its personality's schedule
		"endgame_rush": false,    # plays the last round like any other
		"claim_strikes": false,   # strikes only from tiles it already owns
		"capital_buffer": false,  # does not secure the tiles around its capital
	},
	"Normal": {
		"description": "A fair fight with varied rival personalities.",
		"personalities": [],      # empty means all personalities
		"threshold_shift": 0.0,
		"noise_scale": 1.0,
		"mood_scale": 1.0,
		"strikes": false,
		"smart_targets": false,
		"recruit_threat": false,
		"risk_check": false,
		"capital_guard": false,
		"early_improve": false,
		"endgame_rush": false,
		"claim_strikes": false,
		"capital_buffer": false,
	},
	"Hard": {
		"description": "Plans strikes: gathers armies and recruits to take weak spots.",
		"personalities": [],
		"threshold_shift": 0.0,
		"noise_scale": 0.5,
		"mood_scale": 0.5,
		"strikes": true,          # gathers armies and recruits to make an attack work
		"smart_targets": true,    # prefers improved tiles and the capital
		"recruit_threat": true,   # expects you to recruit next to its border
		"risk_check": false,
		"capital_guard": false,
		"early_improve": false,
		"endgame_rush": false,
		"claim_strikes": false,
		"capital_buffer": false,
	},
	"Expert": {
		"description": "Plays its best: claim-and-strike combos, a guarded capital, and an all-out last round.",
		"personalities": [],
		"threshold_shift": 0.0,
		"noise_scale": 0.2,
		"mood_scale": 0.0,
		"strikes": true,
		"smart_targets": true,
		"recruit_threat": true,
		"risk_check": false,      # (tested: avoiding captures it might lose back made it weaker)
		"capital_guard": true,    # keeps enough armies home to hold against the threat
		"early_improve": true,    # invests in improvements early when safe
		"endgame_rush": true,     # throws everything at grabbing land in the last round
		"claim_strikes": true,    # claims a staging tile, then moves existing rested armies there
		"capital_buffer": true,   # claims and retakes the tiles around its capital
	},
}
const NAMES: Array[String] = ["Easy", "Normal", "Hard", "Expert"]


static func get_level(level: String) -> Dictionary:
	return LEVELS.get(level, LEVELS["Normal"])
