class_name SurvivalExpansion
extends RefCounted
## Equipment ownership, physical workshop jobs, cold and a finite campaign.
const STAGES := ["修复电台", "寒潮准备", "恢复净水", "组装信标", "抵达撤离点", "已撤离"]
var epoch := 1
var stage := 0
var outcome := ""
var endless := false
var warm_nights := 0
var gear: Array[Dictionary] = []
var next_id := 1
var ammo := 0
var ammo_loadout := 0
var parts: Array[String] = []
var collected: Array[String] = []
var carried: Array[String] = []
var jobs: Array[Dictionary] = []
var heater_remaining := 0.0
var night_heat := 0.0
var use_night_heat := false
var pump_on := false

func day(game: Node2D) -> int:
	return maxi(1, ExpeditionState.day_at(game.simulation_time) - epoch + 1)

func outside(game: Node2D) -> float:
	return temperature_at(day(game))+float(ChronicleCatalog.SCENARIOS[game.chronicle.scenario]["cold"]) if game.has_method("chronicle_snapshot") else temperature_at(day(game))

static func temperature_at(day_number: int) -> float:
	var d := (day_number - 1) % 35 + 1
	if d < 6: return 10.0
	if d < 13: return 3.0
	if d < 20: return -7.0
	if d < 28: return -12.0
	return -3.0

func sync(game: Node2D) -> void:
	for field: ExpeditionState in game.regions.values():
		field.special_sites.clear()
		for key in GearCatalog.PARTS:
			if GearCatalog.PARTS[key]["map"] == field.location_id and not collected.has(key): field.special_sites.append(int(GearCatalog.PARTS[key]["site"]))
		if game.has_method("director_snapshot") and game.director.status == "active":
			var mission: Dictionary = CampaignDirector.CONTRACTS[game.director.contract]
			if mission["type"] == "survey" and mission["map"] == field.location_id and not field.special_sites.has(int(mission["site"])): field.special_sites.append(int(mission["site"]))
	if game.has_method("residence_snapshot"): game.residence.sync(game)
	for actor in game.survivors:
		actor.weapon_item = {}
		actor.armor_item = {}
		actor.coat_item = {}
		for item in gear:
			if item["owner"] == actor.person.persona:
				actor.set(str(GearCatalog.ITEMS[item["kind"]]["slot"]) + "_item", item)

	if game.has_method("districts_snapshot"): game.districts.sync(game)

func grant(kind: String, owner: String = "") -> void:
	gear.append({"id": next_id, "kind": kind, "durability": GearCatalog.ITEMS[kind]["durability"], "owner": owner})
	next_id += 1

func equip(game: Node2D, id: int, actor_id: int) -> bool:
	if not game.cycle.phase in ["day", "planning"] or actor_id < 0 or actor_id >= game.survivors.size() or game.survivors[actor_id].health <= 0: return false
	for item in gear:
		if item["id"] != id: continue
		var owner: String = game.survivors[actor_id].person.persona
		var slot: String = GearCatalog.ITEMS[item["kind"]]["slot"]
		var unequip: bool = item["owner"] == owner
		for other in gear:
			if other["owner"] == owner and GearCatalog.ITEMS[other["kind"]]["slot"] == slot: other["owner"] = ""
		item["owner"] = "" if unequip else owner
		sync(game)
		return true
	return false

func equipped_slots(actor: Survivor) -> int:
	return (0 if actor.weapon_item.is_empty() else 1) + (0 if actor.armor_item.is_empty() else 1)

func reserved_slots(game: Node2D) -> int:
	var id: int = game.cycle.scavenger()
	return equipped_slots(game.survivors[id]) + ceili(ammo_loadout / 8.0) if id >= 0 else 0

func refresh_slots(field: ExpeditionState, actor: Survivor) -> void:
	field.extra_slots = equipped_slots(actor) + ceili((field.reserve_ammo + field.magazine) / 8.0) + carried.size() + (2 if field.carrying_person else 0)

func unlocked(game: Node2D, id: String) -> bool:
	match id:
		"street", "clinic", "works": return true
		"residential": return day(game) >= 2
		"market": return stage >= 1
		"waterworks": return stage >= 2
		"depot": return stage >= 3
		"broadcast": return stage >= 3 and day(game) >= 12
		"evac": return stage >= 4 and day(game) >= 28
	return false

func lock_reason(id: String) -> String:
	return {"residential": "第2天开放", "market": "修复电台后开放", "waterworks": "度过两次温暖寒夜后开放", "depot": "修复净水泵后开放", "broadcast": "净水泵修好且第12天开放", "evac": "信标完成且第28天开放"}.get(id, "")

func objective(game: Node2D) -> String:
	if outcome == "victory": return "撤离成功！可以继续无尽生存。"
	if outcome == "missed": return "35日撤离窗口已关闭；可以继续无尽生存。"
	match stage:
		0: return "机修厂二楼工具台取回继电器，回基地工作台修复电台。"
		1: return "建设取暖炉；第6天起，留守者度过两次足够温暖的夜晚（%d/2）。" % warm_nights
		2: return "水厂二楼取回滤芯，在工作台修复净水泵。"
		3: return "货运站取电池、广播塔取信标组件，回工作台组装信标。"
		_: return "第28天开放撤离码头：带回航路记录，再备齐每位活人的熟食1、水2及燃料2。"

func take_part(game: Node2D) -> bool:
	var field: ExpeditionState = game.expedition
	if not field.active or field.loot_site < 0: return false
	for key in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[key]
		if part["map"] == field.location_id and part["site"] == field.loot_site and not collected.has(key):
			if carried.has(key):
				carried.erase(key)
				refresh_slots(field, game.survivors[field.actor_id])
				return true
			if field.used_capacity() >= field.capacity: return false
			carried.append(key)
			refresh_slots(field, game.survivors[field.actor_id])
			game._log("装入%s：占1格，回到入口后才计入战役。" % part["name"])
			return true
	return false

func trip_return(game: Node2D, id: int, survived: bool) -> void:
	if survived:
		ammo += game.expedition.reserve_ammo + game.expedition.magazine
		for key in carried:
			parts.append(key)
			collected.append(key)
			game._log("战役物资入库：" + GearCatalog.PARTS[key]["name"])
	else:
		var owner: String = game.survivors[id].person.persona
		for item in gear.duplicate():
			if item["owner"] == owner: gear.erase(item)
	carried.clear()
	game.expedition.reserve_ammo = 0
	game.expedition.magazine = 0
	game.expedition.extra_slots = 0
	game.expedition.reload_remaining = 0
	sync(game)

func climate(actor: Survivor, seconds: float, temperature: float, resting: bool = false) -> void:
	var remaining := seconds
	while remaining > 0 and actor.health > 0:
		var step := minf(remaining, 0.5)
		var effective := temperature + actor.warmth()
		if effective < 6: actor.cold_exposure = minf(100, actor.cold_exposure + (6 - effective) * step * 0.018)
		else: actor.cold_exposure = maxf(0, actor.cold_exposure - step * 0.22)
		if actor.cold_exposure >= 35: actor.illness = minf(100, actor.illness + step * 0.026)
		elif effective >= 8 and actor.hunger < 75 and resting: actor.illness = maxf(0, actor.illness - step * 0.035)
		if actor.illness >= 75: actor.health = maxf(0, actor.health - step * 0.012)
		remaining -= step

func tick_day(game: Node2D, delta: float) -> void:
	var heat := minf(delta, heater_remaining)
	heater_remaining = maxf(0, heater_remaining - delta)
	var temperature: float = outside(game) + game.residence.indoor_bonus() + (18 * heat / delta if delta > 0 else 0)
	for actor in game.survivors:
		climate(actor, delta, temperature, actor.orders.has("sleep") or game.cycle.actions.any(func(action): return action["actor"] == actor.survivor_id and action["kind"] == "sleep"))
		if actor.health <= 0 and actor.state != Survivor.TaskState.DEAD:
			game._cancel_external(actor.survivor_id, false)
			game.scheduler.mark_dead(actor, "严重疾病")
	var used_stations: Array[String] = []
	for job in jobs.duplicate():
		var actor: Survivor = game.survivors[int(job["actor"])]
		if actor.health <= 0:
			cancel(game, actor.survivor_id, false)
			continue
		if not actor.route.is_empty() or actor.position.distance_to(job_position(job["kind"])) > 10: continue
		var station := FacilitySystem.station_for(job["kind"])
		if not station.is_empty() and (used_stations.has(station) or job != jobs.filter(func(work): return FacilitySystem.station_for(work["kind"]) == station)[0] or game.scheduler.facilities[station].occupant_id >= 0):
			actor.feedback = "等待厨房空闲" if station == "stove" else "等待工作台空闲"
			continue
		if not station.is_empty(): used_stations.append(station)
		var rate: float = game.facilities.rate(station) if not station.is_empty() and not FacilitySystem.RECIPES.get(job["kind"],{}).has("from") else 1.0
		job["elapsed"] = minf(job["duration"], job["elapsed"] + delta * (1.0 if job["kind"] in ["music","picnic"] else CharacterAbilities.factor(actor,"work")) * actor.effort_factor() * actor.person.bonus("craft") * rate)
		actor.activity = {"kind": "music" if job["kind"] == "music" else "eat" if job["kind"] == "picnic" else "build", "label": job["label"], "progress": job["elapsed"] / job["duration"]}
		if job["elapsed"] >= job["duration"]:
			finish(game, job)
			jobs.erase(job)
			actor.activity.clear()

static func job_position(kind: String) -> Vector2:
	return Vector2(584,430) if kind in ["music","picnic"] else Vector2(900,430) if FacilitySystem.station_for(kind) == "stove" else Vector2(485,640)

func reserves_station(game: Node2D, station: String) -> bool:
	return jobs.any(func(job): return FacilitySystem.station_for(job["kind"]) == station and game.survivors[int(job["actor"])].route.is_empty() and game.survivors[int(job["actor"])].position.distance_to(job_position(job["kind"])) <= 10)

func start_job(game: Node2D, kind: String, item_id: int = -1) -> bool:
	if game.cycle.phase != "day" or game.survivors[game.selected_id].health <= 0: return false
	var recipe := GearCatalog.recipe(kind)
	if kind == "repair": recipe = {"name": "修理装备", "cost": {"materials": 2}, "seconds": 18.0}
	if recipe.is_empty(): return false
	var facility_error: String = game.facilities.job_error(game,kind)
	if not facility_error.is_empty():
		game._log(facility_error)
		return false
	if ResidenceSystem.PROJECTS.has(kind):
		var error: String = game.residence.job_error(game, kind)
		if not error.is_empty():
			game._log(error)
			return false
	if GearCatalog.ITEMS.has(kind) and gear.size() >= 300:
		game._log("装备仓库已满，请优先修理现有装备。")
		return false
	if kind == "ammo" and ammo > 99992: return false
	if kind == "repair" and not gear.any(func(item): return item["id"] == item_id and item["durability"] < GearCatalog.ITEMS[item["kind"]]["durability"]): return false
	if kind == "radio" and (stage != 0 or not parts.has("relay")): return false
	if kind == "pump" and (stage != 2 or not parts.has("filter_core")): return false
	if kind == "beacon" and (stage != 3 or not parts.has("beacon_core") or not parts.has("power_cell")): return false
	if jobs.any(func(job): return (kind in ["radio", "pump", "beacon"] and job["kind"] == kind) or (kind == "repair" and job["item"] == item_id)): return false
	if not game.inventory.can_take(recipe["cost"]):
		game._log("物资不足：" + ShelterInventory.describe(recipe["cost"]))
		return false
	var actor: Survivor = game.survivors[game.selected_id]
	var route: Array[Vector2] = game.scheduler.navigation.route_between(actor.position, job_position(kind))
	if route.is_empty(): return false
	game._cancel_external(actor.survivor_id)
	game.scheduler.cancel(actor)
	if not game.inventory.try_take(recipe["cost"], recipe["name"]): return false
	jobs.append({"actor": actor.survivor_id, "kind": kind, "item": item_id, "elapsed": 0.0, "duration": recipe["seconds"], "cost": recipe["cost"].duplicate(), "label": recipe["name"]})
	actor.route = route
	actor.state = Survivor.TaskState.RETURNING
	game._log(actor.display_name + ("前往餐桌：" if kind == "picnic" else "前往厨房：" if FacilitySystem.station_for(kind) == "stove" else "前往工作台：") + recipe["name"] + "。取消或日落退还未完成用料。")
	return true

func cancel(game: Node2D, id: int, refund: bool = true) -> void:
	for job in jobs.duplicate():
		if job["actor"] != id: continue
		if refund: game.inventory.deposit(job["cost"], "取消工作台制作，退料")
		jobs.erase(job)

func finish(game: Node2D, job: Dictionary) -> void:
	var kind: String = job["kind"]
	if not ResidenceSystem.PROJECTS.has(kind): game.residence.noise = minf(100, game.residence.noise + 6)
	if FacilitySystem.RECIPES.has(kind): game.facilities.complete(game,kind,game.survivors[int(job["actor"])])
	elif GearCatalog.ITEMS.has(kind): grant(kind)
	elif kind == "ammo": ammo += 8
	elif ResidenceSystem.PROJECTS.has(kind): game.residence.finish(game, kind, game.survivors[int(job["actor"])])
	elif kind == "repair":
		for item in gear:
			if item["id"] == job["item"]: item["durability"] = mini(GearCatalog.ITEMS[item["kind"]]["durability"], int(item["durability"]) + 60)
	else:
		parts.erase(GearCatalog.PROJECTS[kind]["part"])
		if kind == "beacon": parts.erase("power_cell")
		stage += 1
	sync(game)
	game._log(job["label"] + "完成。")

func ignite(game: Node2D) -> bool:
	if game.cycle.phase != "day" or not game.cycle.has_build("heater") or heater_remaining > 0: return false
	if not game.inventory.try_take({"fuel": 1}, "取暖炉燃烧8小时"): return false
	heater_remaining = 240
	game._log("取暖炉点燃：消耗燃料1，室内+18℃，持续游戏8小时。")
	return true

func reserve_heat(game: Node2D) -> void:
	if not game.residence.convoy.is_empty(): return
	night_heat = minf(heater_remaining, maxf(0, game.cycle.night_end - game.cycle.night_start))
	heater_remaining = 0
	if not use_night_heat or not game.cycle.has_build("heater"): return
	var duration: float = game.cycle.night_end - game.cycle.night_start
	while night_heat < duration and game.inventory.amount("fuel") > 0:
		game.inventory.try_take({"fuel": 1}, "夜间取暖预留燃料")
		night_heat += 240

func dawn(game: Node2D, duration: float, report: Array[String]) -> void:
	var night_day: int = game.cycle.night_day - epoch + 1
	var night_temperature := temperature_at(night_day)+(float(ChronicleCatalog.SCENARIOS[game.chronicle.scenario]["cold"]) if game.has_method("chronicle_snapshot") else 0.0)
	var heat_time := minf(duration, night_heat)
	var all_warm := true
	var home := 0
	for actor in game.survivors:
		if actor.health <= 0: continue
		var role: String = game.cycle.roles[actor.survivor_id]
		var absence := minf(duration, game.expedition.elapsed) if role == "scavenge" else 0.0
		if role not in ["scavenge","outpost"] and game.residence.convoy.is_empty(): home += 1
		var temperature: float = night_temperature + (game.residence.indoor_bonus() if game.residence.convoy.is_empty() and role != "outpost" else 0)
		var actor_heat := maxf(0, heat_time - absence) if role != "outpost" else 0.0
		climate(actor, actor_heat, temperature + 18, role == "bed")
		climate(actor, maxf(0, duration - absence - actor_heat), temperature, role == "bed")
		if role not in ["scavenge","outpost"] and temperature + actor.warmth() + (18 if heat_time >= duration else 0) < 6: all_warm = false
		if not actor.coat_item.is_empty(): actor.coat_item["durability"] = maxi(0, int(actor.coat_item["durability"]) - 1)
		report.append("%s · 疾病%d，寒冷%d，衣物保暖+%d℃。" % [actor.display_name, roundi(actor.illness), roundi(actor.cold_exposure), actor.warmth()])
	heater_remaining = maxf(0, night_heat - duration)
	night_heat = 0
	if stage == 1 and night_day >= 6 and game.cycle.has_build("heater") and all_warm and home > 0:
		warm_nights = mini(2, warm_nights + 1)
		if warm_nights >= 2:
			stage = 2
			report.append("寒潮准备完成：水厂路线已开放。")
	if pump_on and stage >= 3 and game.residence.convoy.is_empty() and game.inventory.try_take({"fuel": 1}, "净水泵每日运行"):
		game.inventory.deposit({"water": 3}, "净水泵产水")
		report.append("净水泵消耗燃料1，获得水3。")
	if outcome.is_empty() and stage >= 4 and parts.has("route") and day(game) >= 28:
		var alive: int = game.survivors.filter(func(actor): return actor.health > 0).size()
		var cost := {"meals": alive, "water": alive * 2, "fuel": 2}
		if alive > 0 and game.inventory.try_take(cost, "完成全员撤离补给"):
			outcome = "victory"
			stage = 5
			report.append("撤离成功！%d位幸存者带着补给抵达接应点。可继续无尽生存或新开战役。" % alive)
	if outcome.is_empty() and day(game) > 35:
		outcome = "missed"
		report.append("35日撤离窗口已关闭。幸存者仍在，可选择继续无尽生存。")
	report.append("战役第%d/35天 · %s：%s" % [day(game), STAGES[stage], objective(game)])

func snapshot() -> Dictionary:
	return {"epoch": epoch, "stage": stage, "outcome": outcome, "endless": endless, "warm_nights": warm_nights, "gear": gear.duplicate(true), "next_id": next_id, "ammo": ammo, "ammo_loadout": ammo_loadout, "parts": parts.duplicate(), "collected": collected.duplicate(), "carried": carried.duplicate(), "jobs": jobs.duplicate(true), "heater_remaining": heater_remaining, "night_heat": night_heat, "use_night_heat": use_night_heat, "pump_on": pump_on}

func restore(data: Dictionary, game: Node2D) -> void:
	var source := data
	if data.is_empty():
		var fresh := SurvivalExpansion.new()
		fresh.epoch = ExpeditionState.day_at(game.simulation_time)
		source = fresh.snapshot()
	for key in source:
		if key in ["gear", "jobs"]:
			var target: Array[Dictionary] = []
			for entry in source[key]: target.append(entry.duplicate(true))
			set(key, target)
		elif key in ["parts", "collected", "carried"]:
			var target: Array[String] = []
			for value in source[key]: target.append(value)
			set(key, target)
		else: set(key, source[key])
	sync(game)

static func validate(data: Variant, world: Dictionary) -> String:
	if data is Dictionary and data.is_empty(): return ""
	var defaults := SurvivalExpansion.new().snapshot()
	if not CharacterState.keys(data, defaults.keys()): return "生存扩展字段无效"
	if not CharacterState.integer(data["epoch"], 1, ExpeditionState.day_at(world["simulation_time"])) or not CharacterState.integer(data["stage"], 0, 5) or not CharacterState.integer(data["warm_nights"], 0, 2): return "战役进度无效"
	if not data["outcome"] in ["", "victory", "missed"] or not data["endless"] is bool or not data["pump_on"] is bool or not data["use_night_heat"] is bool: return "战役开关无效"
	for checkpoint in [[1, "relay"], [3, "filter_core"], [4, "power_cell"], [4, "beacon_core"], [5, "route"]]:
		if data["stage"] >= checkpoint[0] and (not data.get("collected") is Array or not data["collected"].has(checkpoint[1])): return "战役推进缺少真实入库凭据"
	if (data["stage"] == 5) != (data["outcome"] == "victory"): return "撤离结局与进度不符"
	for key in ["ammo", "ammo_loadout"]:
		if not CharacterState.integer(data[key], 0, 100000): return "弹药库存无效"
	if data["ammo_loadout"] > 120: return "携带弹药过量"
	for key in ["heater_remaining", "night_heat"]:
		if not CharacterState.number(data[key], 0, 540): return "取暖工时无效"
	var personas: Array = world["actors"].map(func(actor): return actor["person"]["persona"])
	var ids: Array = []
	var owners: Array = []
	if not data["gear"] is Array or data["gear"].size() > 300 or not CharacterState.integer(data["next_id"], 1, 1000000): return "装备容量无效"
	for item in data["gear"]:
		if not CharacterState.keys(item, ["id", "kind", "durability", "owner"]) or not GearCatalog.ITEMS.has(item["kind"]): return "装备种类无效"
		if not CharacterState.integer(item["id"], 1, int(data["next_id"]) - 1) or ids.has(int(item["id"])) or not CharacterState.integer(item["durability"], 0, GearCatalog.ITEMS[item["kind"]]["durability"]): return "装备耐久或编号无效"
		ids.append(int(item["id"]))
		if not item["owner"] is String or (item["owner"] != "" and not personas.has(item["owner"])): return "装备归属无效"
		if item["owner"] != "":
			var pair: String = item["owner"] + "/" + GearCatalog.ITEMS[item["kind"]]["slot"]
			if owners.has(pair): return "同一装备位置重复占用"
			owners.append(pair)
	for key in ["parts", "collected", "carried"]:
		if not data[key] is Array or data[key].size() > GearCatalog.PARTS.size(): return "战役物资容量无效"
		var unique: Array = []
		for part in data[key]:
			if not GearCatalog.PARTS.has(part) or unique.has(part): return "战役物资重复或未知"
			unique.append(part)
	for part in data["parts"]:
		if not data["collected"].has(part): return "战役入库记录缺失"
	for part in data["carried"]:
		if data["collected"].has(part) or GearCatalog.PARTS[part]["map"] != world["destination"]: return "随身零件来源无效"
	var field: Dictionary = world["expedition"]
	if field["active"]:
		var owner: String = world["actors"][int(field["actor_id"])]["person"]["persona"]
		var equipped := 0
		for item in data["gear"]:
			if item["owner"] == owner and GearCatalog.ITEMS[item["kind"]]["slot"] != "coat": equipped += 1
		var expected: int = equipped + ceili((field["reserve_ammo"] + field["magazine"]) / 8.0) + data["carried"].size()
		if world.get("neighborhood",{}).get("rescue",{}).get("state","")=="carried": expected+=2
		if expected != field["extra_slots"]: return "装备弹药与背包负重不符"
	elif not data["carried"].is_empty() or field["reserve_ammo"] != 0 or field["magazine"] != 0 or field["reload_remaining"] != 0:
		return "未外出却保留随身装备物资"
	if not data["jobs"] is Array or data["jobs"].size() > 5: return "工作台制作容量无效"
	var busy: Array = []
	for job in data["jobs"]:
		if not CharacterState.keys(job, ["actor", "kind", "item", "elapsed", "duration", "cost", "label"]): return "工作台制作字段无效"
		if not CharacterState.integer(job["actor"], 0, world["actors"].size() - 1) or busy.has(int(job["actor"])): return "制作人员无效"
		busy.append(int(job["actor"]))
		if not job["kind"] is String: return "制作种类无效"
		var recipe := GearCatalog.recipe(job["kind"])
		if job["kind"] == "repair": recipe = {"name": "修理装备", "cost": {"materials": 2}, "seconds": 18.0}
		if recipe.is_empty() or not job["cost"] is Dictionary or not SaveSystem._same_items(job["cost"], recipe["cost"]) or job["duration"] != recipe["seconds"] or job["label"] != recipe["name"] or not CharacterState.number(job["elapsed"], 0, recipe["seconds"]): return "制作配方或工时无效"
		if not CharacterState.integer(job["item"], -1, 1000000) or (job["kind"] == "repair" and not ids.has(int(job["item"]))) or (job["kind"] != "repair" and job["item"] != -1): return "维修目标无效"
		if job["kind"] in ["radio", "pump", "beacon"]:
			var required_stage: int = {"radio": 0, "pump": 2, "beacon": 3}[job["kind"]]
			if data["stage"] != required_stage or not data["parts"].has(GearCatalog.PROJECTS[job["kind"]]["part"]) or (job["kind"] == "beacon" and not data["parts"].has("power_cell")): return "制作战役项目缺少零件或阶段不符"
		var actor: Dictionary = world["actors"][int(job["actor"])]
		if world["campaign"].is_empty() or world["campaign"]["phase"] != "day" or not actor["orders"].is_empty() or not int(actor["state"]) in [Survivor.TaskState.IDLE, Survivor.TaskState.RETURNING] or actor["health"] <= 0: return "制作行动与昼夜或角色不符"
		if world["campaign"]["actions"].any(func(action): return action["actor"] == job["actor"]) or world["campaign"]["builds"].any(func(build): return build["state"] == "blueprint" and build["actor"] == job["actor"]): return "制作人员重复占用"
	return ""
