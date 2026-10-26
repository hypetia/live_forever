class_name Vitals
extends RefCounted
## Presentation only. Existing deficit values remain compatible with all saves.
const KEYS := ["health", "fullness", "hydration", "vigor"]
const NAMES := {"health": "生命", "fullness": "饱腹", "hydration": "水分", "vigor": "精神"}
const COLORS := {"health": Color("b2c1a2"), "fullness": Color("c4a676"), "hydration": Color("88abb3"), "vigor": Color("c2bbd2")}

static func value(actor: Survivor, key: String) -> int:
	match key:
		"health": return roundi(clampf(actor.health, 0, 100))
		"fullness": return roundi(100 - clampf(actor.hunger, 0, 100))
		"hydration": return roundi(100 - clampf(actor.person.thirst, 0, 100))
		"vigor": return roundi(100 - clampf(actor.fatigue, 0, 100))
	return 0

static func summary(actor: Survivor) -> String:
	var lines: Array[String] = []
	for key in KEYS: lines.append("%s  %d / 100" % [NAMES[key], value(actor, key)])
	lines.append("四项越满越好")
	for entry in [["伤势", actor.injury], ["感染", actor.infection], ["疾病", actor.illness], ["寒冷", actor.cold_exposure]]:
		if entry[1] > 0: lines.append("%s · %s" % [entry[0], "严重" if entry[1] >= 60 else "中度" if entry[1] >= 30 else "轻度"])
	return "\n".join(lines)
