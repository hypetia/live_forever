class_name ShelterProgress
extends RefCounted
## Ongoing upkeep, bounded upgrades, optional milestones and explicit event trades.

signal event_reported(message: String)
const UPGRADE_COSTS := [{"materials": 4, "tools": 1}, {"materials": 6, "tools": 1, "fuel": 2}, {"materials": 8, "tools": 2, "medicine": 1}]
const EVENT_TITLES := ["雨水与容器", "路过的换物者", "风前的加固", "邻街的求助"]
const EVENT_TEXTS := [
	"有人找到了一段能接雨水的屋檐。用材料制作滤水容器，或者保留材料。",
	"换物者带来食物与燃料，只愿意交换能修好推车的材料。每次来访只交换一次。",
	"下一阵风会吹过北墙。可以提前加固，也可以接受可预见的结构损失。本次风害只影响结构，不会直接伤及成员。",
	"邻街的人缺少药品，愿意用工具和饮水交换。你也可以把药留给自己的队伍。",
]
const EVENT_COSTS := [{"materials": 2}, {"materials": 4}, {"materials": 2}, {"medicine": 1}]
const EVENT_OUTPUTS := [{"water": 6}, {"raw_food": 4, "fuel": 2}, {}, {"tools": 2, "water": 3}]
var integrity := 82.0
var level := 0
var last_day := 1
var pending_event := -1
var event_day := 0
var resolved_events := 0
var repairs := 0
var returns := {"street": 0, "clinic": 0, "works": 0}
var recovered: Dictionary = {}
var trip_loadout: Dictionary = {}
var journal: Array[String] = []


func _init() -> void:
	for resource in ShelterInventory.NAMES: recovered[resource] = 0


func tick(delta: float, seconds: float) -> void:
	var day := ExpeditionState.day_at(seconds)
	var weather := 1.5 if day % 4 == 0 else 1.0
	integrity = maxf(0, integrity - delta * 0.012 * weather * (1.0 - level * 0.12))
	if day > last_day:
		last_day = day
		if pending_event == -1:
			pending_event = (day - 2) % EVENT_TITLES.size()
			event_day = day
			_note("第%d天：%s，按M查看并选择。" % [day, EVENT_TITLES[pending_event]])


func efficiency() -> float:
	return (0.65 if integrity < 20 else 0.85 if integrity < 40 else 1.0) * (1.0 + level * 0.08)


func repair() -> void:
	integrity = minf(100, integrity + 18)
	repairs += 1
	_note("完成修缮：结构+18，当前%d；材料不是自动补充的。" % ceili(integrity))


func upgrade(inventory: ShelterInventory) -> bool:
	if level >= UPGRADE_COSTS.size(): return false
	if not inventory.try_take(UPGRADE_COSTS[level], "庇护所升级"):
		return false
	level += 1
	integrity = minf(100, integrity + 12)
	_note("据点升到%d级：生产速度增加，结构磨损降低；食物与药品仍需外出。" % level)
	return true


func resolve_event(accept: bool, inventory: ShelterInventory) -> bool:
	if pending_event == -1: return false
	var id := pending_event
	if accept and not inventory.try_take(EVENT_COSTS[id], "事件：" + EVENT_TITLES[id]): return false
	if accept:
		inventory.deposit(EVENT_OUTPUTS[id], "事件：" + EVENT_TITLES[id])
		if id == 2: integrity = minf(100, integrity + 8)
	elif id == 2:
		integrity = maxf(0, integrity - 8)
	pending_event = -1
	event_day = 0
	resolved_events += 1
	_note("%s：%s。" % [EVENT_TITLES[id], "已处理" if accept else "保留物资，继续生存"])
	return true


func begin_trip(loadout: Dictionary) -> void:
	trip_loadout = loadout.duplicate()


func finish_trip(id: String, cargo: Dictionary, survived: bool) -> void:
	if survived:
		var gained := 0
		for resource in recovered:
			var amount := maxi(0, int(cargo.get(resource, 0)) - int(trip_loadout.get(resource, 0)))
			recovered[resource] += amount
			gained += amount
		if gained > 0:
			returns[id] += 1
			_note("从%s带回%d份净补给。" % [LocationCatalog.area(id)["name"], gained])
	trip_loadout.clear()


func milestones(game: Node2D) -> Array:
	var cook := 0
	var eat := 0
	var sleep := 0
	for actor: Survivor in game.survivors:
		cook += int(actor.completed_by_task["cook"])
		eat += int(actor.completed_by_task["eat"])
		sleep += int(actor.completed_by_task["sleep"])
	var all_places := returns.values().all(func(n): return n > 0)
	return [
		["第一批补给", returns.values().any(func(n): return n > 0), "亲自搜到物资并从入口带回"],
		["照顾彼此", cook >= 1 and eat >= 1 and sleep >= 1, "完成做饭、吃饭与睡眠"],
		["走遍街区", all_places, "从所有已开放区域分别带回净补给"],
		["修补漏风的墙", repairs > 0, "消耗材料，真正完成一次修缮"],
		["留住这束光", level == 3, "把据点升到三级，仍需维护和补给"],
		["第七个清晨", ExpeditionState.day_at(game.simulation_time) >= 7 and game.survivors.any(func(a): return a.health > 0), "带着至少一位幸存者抵达第七天；之后可继续"],
	]


func _note(message: String) -> void:
	journal.push_front(message)
	if journal.size() > 16: journal.pop_back()
	event_reported.emit(message)


func snapshot() -> Dictionary:
	return {"integrity": integrity, "level": level, "last_day": last_day, "pending_event": pending_event, "event_day": event_day, "resolved_events": resolved_events, "repairs": repairs, "returns": returns.duplicate(), "recovered": recovered.duplicate(), "trip_loadout": trip_loadout.duplicate(), "journal": journal.duplicate()}


func restore_validated(data: Dictionary) -> void:
	integrity = float(data["integrity"])
	for field in ["level", "last_day", "pending_event", "event_day", "resolved_events", "repairs"]: set(field, int(data[field]))
	for field in ["returns", "recovered", "trip_loadout"]:
		var values := {}
		for key in data[field]: values[key] = int(data[field][key])
		set(field, values)
	journal.clear()
	for line in data["journal"]: journal.append(line)


static func validate(data: Variant, seconds: float, away: bool) -> String:
	if not ExpeditionState._keys(data, ["integrity", "level", "last_day", "pending_event", "event_day", "resolved_events", "repairs", "returns", "recovered", "trip_loadout", "journal"]): return "据点记录字段无效"
	if not ExpeditionState._n(data["integrity"], 0, 100) or not ExpeditionState._i(data["level"], 0, 3) or not ExpeditionState._i(data["last_day"], 1, ExpeditionState.day_at(seconds)): return "据点结构或日期无效"
	if not ExpeditionState._i(data["pending_event"], -1, 3) or not ExpeditionState._i(data["event_day"], 0, data["last_day"]): return "事件编号或日期无效"
	if (data["pending_event"] == -1) != (data["event_day"] == 0) or (data["pending_event"] != -1 and data["event_day"] < 2): return "事件状态不一致"
	for key in ["resolved_events", "repairs"]:
		if not ExpeditionState._i(data[key], 0, 100000000): return "据点计数无效"
	if (not ExpeditionState._keys(data["returns"], LocationCatalog.IDS) and not ExpeditionState._keys(data["returns"], LocationCatalog.ALL_IDS)) or not ExpeditionState._keys(data["recovered"], ShelterInventory.NAMES.keys()) or not data["trip_loadout"] is Dictionary: return "探索日志种类无效"
	for field in ["returns", "recovered"]:
		for amount in data[field].values():
			if not ExpeditionState._i(amount, 0, 100000000): return "探索统计数量无效"
	if not away and not data["trip_loadout"].is_empty(): return "未外出却保留携带账目"
	for key in data["trip_loadout"]:
		if not key in ShelterInventory.NAMES or not ExpeditionState._i(data["trip_loadout"][key], 1, 16): return "携带账目无效"
	if not data["journal"] is Array or data["journal"].size() > 16: return "日志容量无效"
	for line in data["journal"]:
		if not line is String or line.length() > 300: return "日志内容无效"
	return ""
