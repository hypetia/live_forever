class_name CampaignCycle
extends RefCounted
## Persistent daily decisions. The scene advances time; this class validates
## transitions and owns night roles, construction and the morning ledger.

const PHASES := ["day", "planning", "scavenge", "returning", "dawn"]
const ROLES := ["scavenge", "guard", "bed", "floor", "dead"]
const ROLE_NAMES := ["外出搜刮", "留守警戒", "床上睡眠", "地铺睡眠", "已故"]
const BAGS := {"lin": 12, "xu": 10, "chen": 14, "he": 12, "gu": 10, "tang": 14}
const SLOTS := [Vector2(330, 640), Vector2(650, 640), Vector2(190, 430), Vector2(755, 430), Vector2(905, 640)]
const RECIPES := {
	"heater": {"name": "取暖炉", "cost": {"materials": 5, "tools": 1}, "seconds": 40.0, "hint": "点燃消耗燃料1，室内升温18℃持续8小时；夜间可提前预留燃料。"},
	"bed": {"name": "简易床", "cost": {"materials": 4}, "seconds": 36.0, "hint": "夜间增加一个床上睡眠名额；白天也可直接躺下休息。"},
	"filter": {"name": "雨水收集器", "cost": {"materials": 3, "tools": 1}, "seconds": 30.0, "hint": "细雨天气的清晨收集水2；晴天不会凭空产水。"},
	"barricade": {"name": "加固隔断", "cost": {"materials": 4, "tools": 1}, "seconds": 42.0, "hint": "夜间防守强度+0.9，仍需安排健康且有精神的守夜者。"},
}
var phase := "day"
var night_day := 1
var night_start := 0.0
var night_end := 0.0
var roles: Array[String] = []
var loadout: Dictionary = {}
var report: Array[String] = []
var late_warned := false
var builds: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var seed := 71413
var last_resolved_day := 0


static func minute(seconds: float) -> float:
	return fposmod(480.0 + seconds * 2.0, 1440.0)


static func next_dawn(seconds: float) -> float:
	var now := minute(seconds)
	return seconds + ((360.0 - now) if now < 360 else (1800.0 - now)) / 2.0


func bed_count() -> int:
	var count := 1
	for build in builds:
		if build["type"] == "bed" and build["state"] == "complete": count += 1
	return count


func has_build(type: String) -> bool:
	return builds.any(func(build): return build["type"] == type and build["state"] == "complete")


func scavenger() -> int:
	return roles.find("scavenge")


func capacity(game: Node2D) -> int:
	var id := scavenger()
	return int(BAGS[game.survivors[id].person.persona]) if id >= 0 else 0


func plan_error(game: Node2D) -> String:
	if phase != "planning": return "现在不是夜间分工阶段。"
	if roles.size() != game.survivors.size(): return "请为所有成员选择夜间岗位。"
	if roles.count("scavenge") > 1: return "每晚只能有一名搜刮者。"
	if roles.count("bed") > bed_count(): return "床位不足：改为地铺或白天建造简易床。"
	var total := 0
	for amount in loadout.values(): total += int(amount)
	if game.has_method("expansion_snapshot"): total += game.expansion.reserved_slots(game)
	if game.has_method("expansion_snapshot") and game.expansion.ammo_loadout > game.expansion.ammo: return "携带弹药超过库存。"
	if total > capacity(game): return "随身物资超过这位角色的背包容量。"
	if not game.inventory.can_take(loadout): return "据点库存已变化，请重新调整携带物资。"
	for index in range(roles.size()):
		if game.survivors[index].health <= 0 and roles[index] != "dead": return "已故成员不能承担夜间岗位。"
	return ""


func snapshot() -> Dictionary:
	return {"phase": phase, "night_day": night_day, "night_start": night_start, "night_end": night_end, "roles": roles.duplicate(), "loadout": loadout.duplicate(), "report": report.duplicate(), "late_warned": late_warned, "builds": builds.duplicate(true), "actions": actions.duplicate(true), "seed": seed, "last_resolved_day": last_resolved_day}


func restore(data: Dictionary) -> void:
	phase = data["phase"]
	night_day = int(data["night_day"])
	night_start = float(data["night_start"])
	night_end = float(data["night_end"])
	roles.clear()
	for value: String in data["roles"]: roles.append(value)
	loadout.clear()
	for key in data["loadout"]: loadout[key] = int(data["loadout"][key])
	report.clear()
	for line: String in data["report"]: report.append(line)
	late_warned = data["late_warned"]
	builds.clear()
	for entry: Dictionary in data["builds"]: builds.append(entry.duplicate(true))
	actions.clear()
	for entry: Dictionary in data["actions"]: actions.append(entry.duplicate(true))
	seed = int(data["seed"])
	last_resolved_day = int(data["last_resolved_day"])


static func validate(data: Variant, world: Dictionary) -> String:
	# Empty means a legacy/core snapshot; the campaign scene imports it once.
	if data is Dictionary and data.is_empty(): return ""
	if not CharacterState.keys(data, ["phase", "night_day", "night_start", "night_end", "roles", "loadout", "report", "late_warned", "builds", "actions", "seed", "last_resolved_day"]): return "昼夜记录字段无效"
	if not data["phase"] in PHASES or not data["late_warned"] is bool: return "昼夜阶段无效"
	var day := ExpeditionState.day_at(float(world["simulation_time"]))
	if not CharacterState.integer(data["night_day"], 1, day) or not CharacterState.integer(data["last_resolved_day"], 0, day) or not CharacterState.integer(data["seed"], 1, 2147483647): return "夜晚日期或种子无效"
	if not CharacterState.number(data["night_start"], 0, world["simulation_time"]) or not CharacterState.number(data["night_end"], 0, world["simulation_time"] + 720): return "夜晚时钟无效"
	var active: bool = world["expedition"]["active"]
	if active != (data["phase"] in ["scavenge", "returning"]): return "昼夜阶段与外出现场不符"
	if not data["roles"] is Array or data["roles"].size() > world["actors"].size(): return "夜间人员数量无效"
	if data["phase"] != "day" and data["roles"].size() != world["actors"].size(): return "夜间分工缺少人员"
	for role in data["roles"]:
		if not role in ROLES: return "未知夜间岗位"
	if data["phase"] != "planning" and data["roles"].count("scavenge") > 1: return "每晚只能派出一人"
	if active and data["roles"].find("scavenge") != world["expedition"]["actor_id"]: return "搜刮岗位与外出者不一致"
	if not data["loadout"] is Dictionary: return "携带物资无效"
	var total := 0
	for key in data["loadout"]:
		if not ShelterInventory.NAMES.has(key) or not CharacterState.integer(data["loadout"][key], 0, 16): return "携带物资种类或数量无效"
		total += int(data["loadout"][key])
	if total > 16: return "携带物资超出最大背包"
	if not data["report"] is Array or data["report"].size() > 32: return "清晨记录容量无效"
	for line in data["report"]:
		if not line is String or line.length() > 1000: return "清晨记录文字无效"
	if data["phase"] == "dawn" and data["last_resolved_day"] != data["night_day"]: return "清晨结算标记缺失"
	if not data["builds"] is Array or data["builds"].size() > SLOTS.size() or not data["actions"] is Array or data["actions"].size() > 5: return "建设或行动容量无效"
	var slots: Array = []
	var types: Array = []
	var occupied: Array = []
	for build in data["builds"]:
		if not CharacterState.keys(build, ["slot", "type", "state", "actor", "elapsed"]): return "建设字段无效"
		if not CharacterState.integer(build["slot"], 0, SLOTS.size() - 1) or slots.has(int(build["slot"])) or not RECIPES.has(build["type"]) or not build["state"] in ["blueprint", "complete"]: return "建设位置或类型无效"
		if (build["type"] != "bed" and types.has(build["type"])) or (build["type"] == "bed" and types.count("bed") >= 2): return "设施数量超出上限"
		types.append(build["type"])
		slots.append(int(build["slot"]))
		if not CharacterState.integer(build["actor"], -1, world["actors"].size() - 1) or not CharacterState.number(build["elapsed"], 0, RECIPES[build["type"]]["seconds"]): return "建设工时无效"
		if build["state"] == "complete":
			if build["actor"] != -1 or not is_equal_approx(build["elapsed"], RECIPES[build["type"]]["seconds"]): return "已建成设施状态无效"
		else:
			var actor := int(build["actor"])
			if data["phase"] != "day" or actor < 0 or occupied.has(actor) or not world["actors"][actor]["orders"].is_empty() or not world["actors"][actor]["state"] in [Survivor.TaskState.IDLE, Survivor.TaskState.RETURNING]: return "建设者与岗位不符"
			occupied.append(actor)
	var beds_used: Array = []
	for action in data["actions"]:
		if not CharacterState.keys(action, ["actor", "kind", "slot", "elapsed"]): return "场景行动字段无效"
		if not CharacterState.integer(action["actor"], 0, world["actors"].size() - 1) or occupied.has(int(action["actor"])) or not action["kind"] in ["drink", "sleep"] or not CharacterState.integer(action["slot"], -1, SLOTS.size() - 1): return "场景行动人员或类型无效"
		var actor := int(action["actor"])
		if data["phase"] != "day" or not world["actors"][actor]["orders"].is_empty() or not world["actors"][actor]["state"] in [Survivor.TaskState.IDLE, Survivor.TaskState.RETURNING]: return "行动者正在承担其他岗位"
		if not CharacterState.number(action["elapsed"], 0, 20.0 if action["kind"] == "sleep" else 2.0): return "场景行动进度无效"
		if action["kind"] == "sleep":
			if beds_used.has(action["slot"]) or not data["builds"].any(func(build): return build["slot"] == action["slot"] and build["type"] == "bed" and build["state"] == "complete"): return "休息床位无效或重复占用"
			beds_used.append(action["slot"])
		elif action["slot"] != -1: return "饮水位置无效"
		occupied.append(actor)
	return ""
