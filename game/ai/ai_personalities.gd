extends RefCounted
## The built-in rival personalities. To add one, create a .tres file with the
## ai_personality.gd script (copy an existing one) and list it here.

const ALL: Array[Resource] = [
	preload("res://game/ai/personalities/conqueror.tres"),
	preload("res://game/ai/personalities/builder.tres"),
	preload("res://game/ai/personalities/raider.tres"),
	preload("res://game/ai/personalities/guardian.tres"),
]


static func names() -> Array[String]:
	var result: Array[String] = []
	for personality in ALL:
		result.append(personality.display_name)
	return result


static func by_name(personality_name: String) -> Resource:
	for personality in ALL:
		if personality.display_name == personality_name:
			return personality
	return null
