extends Resource
## Tunable weights for one computer personality.
##
## Every personality uses the same planner (ai_player.gd); these numbers only
## change how it weighs its options. Add a field here, use it in the planner,
## and set it in the personality files. Blending picks it up automatically.

@export var display_name := "Custom"
## One line shown on the result screen.
@export var description := ""

@export_group("Attacking")
## Lowest win chance it will attack at (the turn's mood shifts this a little).
@export_range(0.0, 1.0, 0.01) var min_chance := 0.66
## Before this round it only attacks when sure to win.
@export var attack_from_round := 1
## Extra score for attacking the enemy capital.
@export var capital_bonus := 60.0
## Preference for targets it outnumbers by more.
@export var weak_target_bias := 0.3

@export_group("Defending")
## Armies it always keeps on its own capital.
@export var capital_garrison := 2
## Recruits to defend even when this much stronger than the nearest threat.
@export var defend_slack := 0

@export_group("Growing")
## Improves one tile every this many rounds.
@export var improve_every := 4
## Keeps claiming land while its land <= enemy land + this.
@export var land_margin := 0
## Claims land near its own capital instead of toward the enemy.
@export var claim_near_home := false
## How strongly it gathers armies next to the enemy capital.
@export var capital_staging := 3

@export_group("Variety")
## Random spread added to scores, so equal positions are not always played the same way.
@export var noise := 2.0


## Returns a new personality that is `weight` of the way from this one to `other`.
## Numbers are interpolated (whole numbers rounded); on/off settings follow
## whichever side has more weight.
func blended_with(other: Resource, weight: float, blend_name: String = "") -> Resource:
	var mix: Resource = duplicate()
	for property in get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var key: String = property["name"]
		match typeof(get(key)):
			TYPE_FLOAT:
				mix.set(key, lerpf(get(key), other.get(key), weight))
			TYPE_INT:
				mix.set(key, roundi(lerpf(get(key), other.get(key), weight)))
			TYPE_BOOL:
				mix.set(key, other.get(key) if weight >= 0.5 else get(key))
	mix.display_name = blend_name if not blend_name.is_empty() else "%s-%s" % [display_name, other.display_name]
	mix.description = "a blend of %s and %s" % [display_name, other.display_name]
	return mix
