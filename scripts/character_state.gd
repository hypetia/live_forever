class_name CharacterState
extends RefCounted
## Capped growth and predictable emotional effects; never random refusal/death.

const SKILLS := ["craft", "care", "scout"]
const LEVELS := [0.0, 30.0, 90.0, 180.0]
var persona := "lin"
var morale := 60.0
var stress := 0.0
var trauma := 0.0
var thirst := 20.0
var experience := {"craft": 0.0, "care": 0.0, "scout": 0.0}
var joined_day := 1
var routine := false
var last_support := -180.0
var last_aid := -180.0
var warned := false
var warned_thirst := false


func level(skill: String) -> int:
	var rank := 0
	for index in range(1, LEVELS.size()):
		if float(experience[skill]) >= LEVELS[index]: rank = index
	return rank


func gain(skill: String, amount: float) -> bool:
	var old := level(skill)
	var bonus := 1.2 if (persona == "lin" and skill == "craft") or (persona == "gu" and skill == "care") else 1.0
	experience[skill] = minf(180, float(experience[skill]) + amount * bonus)
	return level(skill) > old


func bonus(skill: String) -> float:
	return 1.0 + 0.05 * level(skill)


func emotional_effort() -> float:
	return (0.9 if morale < 25 else 1.0) * (0.9 if stress >= 80 else 1.0) * (0.9 if thirst >= 80 else 1.0)


func snapshot() -> Dictionary:
	return {"persona": persona, "morale": morale, "stress": stress, "trauma": trauma, "thirst": thirst, "experience": experience.duplicate(), "joined_day": joined_day, "routine": routine, "last_support": last_support, "last_aid": last_aid, "warned": warned, "warned_thirst": warned_thirst}


func restore_validated(data: Dictionary) -> void:
	persona = data["persona"]
	for field in ["morale", "stress", "trauma", "thirst", "last_support", "last_aid"]: set(field, float(data[field]))
	joined_day = int(data["joined_day"])
	routine = data["routine"]
	warned = data["warned"]
	warned_thirst = data["warned_thirst"]
	for skill in SKILLS: experience[skill] = float(data["experience"][skill])


static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func integer(value: Variant, low: int, high: int) -> bool:
	return number(value, low, high) and float(value) == floorf(float(value))


static func keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key in expected:
		if not value.has(key): return false
	return true


static func validate(data: Variant, day: int, seconds: float) -> String:
	if not keys(data, ["persona", "morale", "stress", "trauma", "thirst", "experience", "joined_day", "routine", "last_support", "last_aid", "warned", "warned_thirst"]): return "人物档案字段无效"
	if not data["persona"] is String or not PeopleCatalog.DATA.has(data["persona"]): return "人物身份无效"
	for field in ["morale", "stress", "trauma", "thirst"]:
		if not number(data[field], 0, 100): return "情绪状态超出范围"
	if not keys(data["experience"], SKILLS): return "技能种类无效"
	for amount in data["experience"].values():
		if not number(amount, 0, 180): return "技能经验无效"
	if not integer(data["joined_day"], 1, day) or not data["routine"] is bool or not data["warned"] is bool or not data["warned_thirst"] is bool or not number(data["last_support"], -180, seconds) or not number(data["last_aid"], -180, seconds): return "人物日期或照料设置无效"
	if PeopleCatalog.CANDIDATES.has(data["persona"]) and data["joined_day"] < PeopleCatalog.DATA[data["persona"]]["day"]: return "来访者加入日期早于出现日期"
	return ""
