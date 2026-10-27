class_name SaveSystem
extends RefCounted
## Validated snapshots, checksummed JSON, atomic replacement and one backup.
## Only data is loaded: no resource paths, scripts or executable expressions.

const VERSION := 16
const MAX_BYTES := 2 * 1024 * 1024
const STATIONS := ["workbench", "stove", "table", "bed"]
const FLOAT_FIELDS := ["work_elapsed", "work_duration", "hunger", "fatigue", "health", "injury", "infection", "illness", "cold_exposure", "movement_clock", "facing"]
var path := "user://shelter_v1.json"


static func capture(game: Node2D) -> Dictionary:
	var actors: Array = []
	for actor: Survivor in game.survivors:
		var entry := {
			"id": actor.survivor_id, "position": [actor.position.x, actor.position.y],
			"state": actor.state, "orders": actor.orders.duplicate(), "route": [],
			"held_cost": actor.held_cost.duplicate(), "completed_jobs": actor.completed_jobs,
			"completed_by_task": actor.completed_by_task.duplicate(), "feedback": actor.feedback,
			"warned": actor.warned.duplicate(), "legacy_repair": actor.legacy_repair, "person": actor.person.snapshot(),
		}
		for field in FLOAT_FIELDS:
			entry[field] = actor.get(field)
		for point in actor.route:
			entry["route"].append([point.x, point.y])
		actors.append(entry)
	var stations := {}
	for station: Workstation in game.scheduler.facilities.values():
		stations[station.facility_id] = {"occupant": station.occupant_id, "waiters": station.waiting_ids.duplicate(), "completed": station.completed_jobs}
	var other_regions := {}
	for id in game.regions:
		if id != game.expedition.location_id: other_regions[id] = game.regions[id].snapshot()
	return {
		"districts": game.districts_snapshot() if game.has_method("districts_snapshot") else {},
		"director": game.director_snapshot() if game.has_method("director_snapshot") else {},
		"facilities": game.facilities_snapshot() if game.has_method("facilities_snapshot") else {},
		"residence": game.residence_snapshot() if game.has_method("residence_snapshot") else {},
		"expansion": game.expansion_snapshot() if game.has_method("expansion_snapshot") else {},
		"campaign": game.campaign_snapshot() if game.has_method("campaign_snapshot") else {},
		"destination": game.expedition.location_id, "other_regions": other_regions, "upkeep": game.upkeep.snapshot(), "people": game.people.snapshot(), "story": game.story.snapshot(), "goals": game.goals.snapshot(),
		"simulation_time": game.simulation_time, "paused": game.paused, "speed": game.speed,
		"selected_id": game.selected_id, "selected_task": game.selected_task,
		"stock": game.inventory.snapshot(), "history": game.inventory.history.duplicate(true),
		"stairs_open": game.scheduler.navigation.stairs_open, "actors": actors,
		"stations": stations, "logs": game.logs.duplicate(),
		"expedition": game.expedition.snapshot(),
	}


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))


static func _exact_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _items(value: Variant, exact: bool = false) -> bool:
	if not value is Dictionary or (exact and not _exact_keys(value, ShelterInventory.NAMES.keys())):
		return false
	for resource in value:
		if not ShelterInventory.NAMES.has(resource) or not _integer(value[resource], 0, 1000000):
			return false
	return true


static func _same_items(value: Dictionary, recipe: Dictionary) -> bool:
	if not _exact_keys(value, recipe.keys()):
		return false
	for key in recipe:
		if value[key] != recipe[key]:
			return false
	return true


static func _point(value: Variant) -> bool:
	if not value is Array or value.size() != 2 or not _number(value[0], 113, 975) or not _number(value[1], 430, 640):
		return false
	if absf(float(value[1]) - 430) < 0.001 or absf(float(value[1]) - 640) < 0.001:
		return true
	return _on_stairs(value)


static func _on_stairs(point: Array) -> bool:
	return absf(float(point[0]) - (690.0 + (float(point[1]) - 430.0) * 120.0 / 210.0)) < 0.01


static func _segment(a: Array, b: Array) -> bool:
	return (absf(float(a[1]) - float(b[1])) < 0.001 and (absf(float(a[1]) - 430) < 0.001 or absf(float(a[1]) - 640) < 0.001)) or (_on_stairs(a) and _on_stairs(b))


static func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "存档内容不是对象"
	var required := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs", "expedition", "destination", "other_regions", "upkeep", "people", "story", "goals", "campaign", "expansion", "residence", "facilities"]
	required.append("director")
	required.append("districts")
	if not _exact_keys(data, required):
		return "存档缺少字段或包含未知字段"
	var region_ids: Array = LocationCatalog.IDS if data["expansion"] is Dictionary and data["expansion"].is_empty() else LocationCatalog.ALL_IDS
	if not data["destination"] is String or not region_ids.has(data["destination"]): return "未知目的地"
	if not _number(data["simulation_time"], 0, 1000000000) or not data["paused"] is bool or not data["stairs_open"] is bool or not data["speed"] in [1.0, 3.0]:
		return "时间或运行设置无效"
	if not data["actors"] is Array or data["actors"].size() < 3 or data["actors"].size() > PeopleCatalog.MAX_HISTORY: return "队伍数量无效"
	if not _integer(data["selected_id"], 0, data["actors"].size() - 1) or not data["selected_task"] is String or not TaskCatalog.TASKS.has(data["selected_task"]):
		return "角色或任务选择无效"
	if not _items(data["stock"], true):
		return "库存无效或含有负数"
	if not data["history"] is Array or data["history"].size() > 32:
		return "交易记录无效"
	for transaction in data["history"]:
		if not _exact_keys(transaction, ["kind", "items", "reason"]) or not transaction["kind"] in ["credit", "debit"] or not _items(transaction["items"]) or not transaction["reason"] is String or transaction["reason"].length() > 1000:
			return "交易记录内容无效"
	if not data["logs"] is Array or data["logs"].size() > 4:
		return "操作记录无效"
	for line in data["logs"]:
		if not line is String or line.length() > 1000:
			return "操作记录内容无效"
	if not _exact_keys(data["stations"], STATIONS):
		return "角色或设施数量不符"
	var totals := {"workbench": 0, "stove": 0, "table": 0, "bed": 0}
	var identities: Array = []
	var living := 0
	for index in range(data["actors"].size()):
		var actor: Variant = data["actors"][index]
		var fields := ["id", "position", "state", "orders", "route", "held_cost", "completed_jobs", "completed_by_task", "feedback", "warned", "legacy_repair", "person"]
		fields.append_array(FLOAT_FIELDS)
		if not _exact_keys(actor, fields) or not _integer(actor["id"], index, index) or not _integer(actor["state"], 0, Survivor.TaskState.AWAY):
			return "角色身份或状态无效"
		var character_error := CharacterState.validate(actor["person"], ExpeditionState.day_at(data["simulation_time"]), float(data["simulation_time"]))
		if not character_error.is_empty(): return character_error
		var persona: String = actor["person"]["persona"]
		if identities.has(persona) or (index < 3 and persona != PeopleCatalog.ORIGINALS[index]) or (index >= 3 and not PeopleCatalog.CANDIDATES.has(persona)): return "队伍身份顺序或唯一性无效"
		identities.append(persona)
		if actor.get("health", 0) is float or actor.get("health", 0) is int:
			if actor["health"] > 0: living += 1
		if not _point(actor["position"]) or not actor["route"] is Array or actor["route"].size() > 6:
			return "角色位置或路径无效"
		var previous: Array = actor["position"]
		for point in actor["route"]:
			if not _point(point) or not _segment(previous, point):
				return "角色路径穿过不可行走区域"
			previous = point
		if not actor["orders"] is Array or actor["orders"].size() > TaskScheduler.MAX_ORDERS:
			return "任务队列无效"
		for task in actor["orders"]:
			if not task is String or not TaskCatalog.TASKS.has(task):
				return "存档含未知任务"
		for field in ["hunger", "fatigue", "health", "injury", "infection", "illness", "cold_exposure"]:
			if not _number(actor[field], 0, 100):
				return "生存状态超出范围"
		if not _number(actor["work_duration"], 0.1, 60) or not _number(actor["work_elapsed"], 0, actor["work_duration"]) or not _number(actor["movement_clock"], 0, 1000000000000) or not actor["facing"] in [-1.0, 1.0]:
			return "角色进度无效"
		if not actor["feedback"] is String or actor["feedback"].length() > 1000 or not _exact_keys(actor["warned"], ["hunger", "fatigue", "health", "infection"]):
			return "角色反馈无效"
		for flag in actor["warned"].values():
			if not flag is bool:
				return "预警标记无效"
		if not _items(actor["held_cost"]) or not _exact_keys(actor["completed_by_task"], TaskCatalog.TASKS.keys()) or not _integer(actor["completed_jobs"], 0, 1000000000):
			return "角色用料或完成记录无效"
		var jobs := 0
		for task in TaskCatalog.TASKS:
			if not _integer(actor["completed_by_task"][task], 0, 1000000000):
				return "完成记录不是有效整数"
			jobs += int(actor["completed_by_task"][task])
			totals[TaskCatalog.TASKS[task]["facility"]] += int(actor["completed_by_task"][task])
		if jobs != actor["completed_jobs"]:
			return "角色完成总数不符"
		if actor["health"] == 0 and actor["person"]["routine"]: return "已故成员不能保留自动照料授权"
		var state := int(actor["state"])
		if not actor["legacy_repair"] is bool or (actor["legacy_repair"] and (state != Survivor.TaskState.WORKING or (actor["orders"].is_empty() or actor["orders"][0] != "repair") or not actor["held_cost"].is_empty())): return "旧版修整标记无效"
		var active := state in [Survivor.TaskState.MOVING, Survivor.TaskState.WAITING, Survivor.TaskState.WORKING, Survivor.TaskState.BLOCKED]
		if active == actor["orders"].is_empty() or (state == Survivor.TaskState.DEAD) != (actor["health"] == 0):
			return "角色任务与生命状态不一致"
		if (state in [Survivor.TaskState.MOVING, Survivor.TaskState.RETURNING]) == actor["route"].is_empty():
			return "角色移动状态与路径不一致"
		if active:
			var task: String = actor["orders"][0]
			var duration := TaskCatalog.duration_for_persona(task, persona)
			if not is_equal_approx(actor["work_duration"], duration):
				return "任务预计耗时与定义不符"
		if state == Survivor.TaskState.WORKING:
			var recipe: Dictionary = TaskCatalog.TASKS[actor["orders"][0]]["cost"]
			var task: String = actor["orders"][0]
			var duration := TaskCatalog.duration_for_persona(task, persona)
			if (not actor["legacy_repair"] and not _same_items(actor["held_cost"], recipe)) or not is_equal_approx(actor["work_duration"], duration) or actor["work_elapsed"] >= duration:
				return "进行中任务的用料或耗时不符"
		elif not actor["held_cost"].is_empty() or actor["work_elapsed"] != 0:
			return "未开工角色却持有用料或进度"
	if living > PeopleCatalog.MAX_LIVING: return "在队人数超过五人"
	var people_error := PeopleSystem.validate(data["people"], data["actors"], float(data["simulation_time"]))
	if not people_error.is_empty(): return people_error
	var story_error := StorySystem.validate(data["story"], data["actors"], float(data["simulation_time"]))
	if not story_error.is_empty(): return story_error
	var queued: Array[int] = []
	var occupied: Array[int] = []
	for id in STATIONS:
		var station: Variant = data["stations"][id]
		if not _exact_keys(station, ["occupant", "waiters", "completed"]) or not _integer(station["occupant"], -1, data["actors"].size() - 1) or not _integer(station["completed"], 0, 1000000000) or station["completed"] != totals[id]:
			return "设施占用或完成记录不符"
		if not station["waiters"] is Array or station["waiters"].size() > data["actors"].size():
			return "设施等待队列无效"
		var occupant := int(station["occupant"])
		if occupant >= 0:
			var actor: Dictionary = data["actors"][occupant]
			if occupied.has(occupant) or actor["state"] != Survivor.TaskState.WORKING or actor["orders"].is_empty() or TaskCatalog.TASKS[actor["orders"][0]]["facility"] != id:
				return "设施使用者与任务不符"
			if Vector2(actor["position"][0], actor["position"][1]).distance_to(_station_position(id)) > 0.01:
				return "工作者不在设施交互位置"
			occupied.append(occupant)
		for waiter in station["waiters"]:
			if not _integer(waiter, 0, data["actors"].size() - 1) or queued.has(int(waiter)):
				return "等待者重复或身份无效"
			var actor: Dictionary = data["actors"][int(waiter)]
			if not int(actor["state"]) in [Survivor.TaskState.MOVING, Survivor.TaskState.WAITING] or actor["orders"].is_empty() or TaskCatalog.TASKS[actor["orders"][0]]["facility"] != id:
				return "等待者与设施任务不符"
			queued.append(int(waiter))
	for actor in data["actors"]:
		if (int(actor["state"]) == Survivor.TaskState.WORKING) != occupied.has(int(actor["id"])) or (int(actor["state"]) in [Survivor.TaskState.MOVING, Survivor.TaskState.WAITING]) != queued.has(int(actor["id"])):
			return "角色与设施登记缺失"
	var expedition_error := ExpeditionState.validate_snapshot(data["expedition"], data["actors"], data["destination"])
	if not expedition_error.is_empty():
		return expedition_error
	var goal_error := GoalSystem.validate(data["goals"], float(data["simulation_time"]), data["expedition"], data["destination"])
	if not goal_error.is_empty(): return goal_error
	if data["expedition"]["last_refresh_day"] > ExpeditionState.day_at(data["simulation_time"]):
		return "探索地点日期超过世界时间"
	if data["expedition"]["active"] and (data["selected_id"] != data["expedition"]["actor_id"] or data["speed"] != 1.0):
		return "外出控制角色或速度不符"
	var inactive_ids := region_ids.duplicate()
	inactive_ids.erase(data["destination"])
	if not _exact_keys(data["other_regions"], inactive_ids): return "地点存档不完整"
	for id in inactive_ids:
		var world: Variant = data["other_regions"][id]
		var error := ExpeditionState.validate_snapshot(world, [], id)
		if not error.is_empty(): return error
		if world["active"] or world["last_refresh_day"] > ExpeditionState.day_at(data["simulation_time"]): return "非当前地点不能活动或超前刷新"
	var campaign_error := CampaignCycle.validate(data["campaign"], data)
	if not campaign_error.is_empty(): return campaign_error
	var expansion_error := SurvivalExpansion.validate(data["expansion"], data)
	if not expansion_error.is_empty(): return expansion_error
	var facilities_error := FacilitySystem.validate(data["facilities"],data)
	if not facilities_error.is_empty(): return facilities_error
	var district_error := DistrictSystem.validate(data["districts"],data)
	if not district_error.is_empty(): return district_error
	var director_error := CampaignDirector.validate(data["director"],data)
	if not director_error.is_empty(): return director_error
	if data["residence"] is Dictionary and data["residence"].is_empty() and not data["campaign"].is_empty(): return "昼夜战役缺少家园记录"
	var residence_error := ResidenceSystem.validate(data["residence"], data)
	if not residence_error.is_empty(): return residence_error
	return ShelterProgress.validate(data["upkeep"], float(data["simulation_time"]), bool(data["expedition"]["active"]))


static func _station_position(id: String) -> Vector2:
	match id:
		"workbench": return Vector2(455, 640)
		"stove": return Vector2(900, 430)
		"table": return Vector2(525, 430)
		_: return Vector2(345, 430)


static func apply_state(game: Node2D, data: Dictionary) -> String:
	var error := validate(data)
	if not error.is_empty():
		return error
	game.ensure_roster(data["actors"].map(func(actor): return actor["person"]["persona"]))
	game.people.restore_validated(data["people"])
	game.story.restore_validated(data["story"])
	game.goals.restore_validated(data["goals"])
	game.inventory.restore_validated(data["stock"], data["history"])
	game.expedition = game.regions[data["destination"]]
	game.expedition.restore_validated(data["expedition"])
	for id in game.regions:
		if id == data["destination"]: continue
		game.regions[id].restore_validated(data["other_regions"][id] if data["other_regions"].has(id) else ExpeditionState.new(id).snapshot())
	game.upkeep.restore_validated(data["upkeep"])
	game.simulation_time = float(data["simulation_time"])
	game.paused = data["paused"]
	game.speed = float(data["speed"])
	game.scheduler.navigation.stairs_open = data["stairs_open"]
	for index in range(data["actors"].size()):
		var actor: Survivor = game.survivors[index]
		var saved: Dictionary = data["actors"][index]
		actor.person.restore_validated(saved["person"])
		actor.position = Vector2(saved["position"][0], saved["position"][1])
		actor.state = int(saved["state"])
		actor.orders.clear()
		for task: String in saved["orders"]:
			actor.orders.append(task)
		actor.route.clear()
		for point in saved["route"]:
			actor.route.append(Vector2(point[0], point[1]))
		actor.legacy_repair = saved["legacy_repair"]
		actor.held_cost.clear()
		for resource in saved["held_cost"]:
			actor.held_cost[resource] = int(saved["held_cost"][resource])
		actor.completed_jobs = int(saved["completed_jobs"])
		for task in TaskCatalog.TASKS:
			actor.completed_by_task[task] = int(saved["completed_by_task"][task])
		for field in FLOAT_FIELDS:
			actor.set(field, float(saved[field]))
		actor.feedback = saved["feedback"]
		actor.warned = saved["warned"].duplicate()
		if not actor.orders.is_empty():
			actor.task_label = TaskCatalog.label_for(actor.orders[0])
			actor.target_label = game.scheduler.facilities[TaskCatalog.TASKS[actor.orders[0]]["facility"]].display_name
		actor.queue_redraw()
	for id in STATIONS:
		var station: Workstation = game.scheduler.facilities[id]
		var saved: Dictionary = data["stations"][id]
		station.occupant_id = int(saved["occupant"])
		station.completed_jobs = int(saved["completed"])
		station.waiting_ids.clear()
		for waiter in saved["waiters"]:
			station.waiting_ids.append(int(waiter))
		station.queue_redraw()
	game.logs.clear()
	for line: String in data["logs"]:
		game.logs.append(line)
	game.game_over = game.survivors.all(func(actor: Survivor): return actor.health <= 0)
	game.selected_task = data["selected_task"]
	if game.has_method("restore_campaign"): game.restore_campaign(data["campaign"])
	if game.has_method("restore_facilities"): game.restore_facilities(data["facilities"])
	if game.has_method("restore_expansion"): game.restore_expansion(data["expansion"])
	if game.has_method("restore_residence"): game.restore_residence(data["residence"])
	if game.has_method("restore_director"): game.restore_director(data["director"])
	if game.has_method("restore_districts"): game.restore_districts(data["districts"])
	game.expedition_view.reset_feedback()
	game.select_survivor(int(data["selected_id"]))
	game._refresh_log()
	game.queue_redraw()
	return ""


func has_save() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func _read_file(filename: String) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return {"ok": false, "message": "文件不存在"}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "message": "文件无法读取或过大"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "message": "JSON格式损坏：" + parser.get_error_message()}
	var envelope: Variant = parser.data
	if not _exact_keys(envelope, ["version", "data_json", "sha256"]) or not _integer(envelope["version"], 1, VERSION):
		return {"ok": false, "message": "存档版本不支持或格式损坏"}
	if not envelope.get("data_json") is String or not envelope.get("sha256") is String or envelope["data_json"].sha256_text() != envelope["sha256"]:
		return {"ok": false, "message": "存档校验失败"}
	if parser.parse(envelope["data_json"]) != OK:
		return {"ok": false, "message": "存档数据格式损坏"}
	var data: Variant = parser.data
	var migrated := int(envelope["version"]) < VERSION
	if int(envelope["version"]) == 1:
		data = migrate_v1(data)
	if int(envelope["version"]) <= 2:
		data = migrate_v2(data)
	if int(envelope["version"]) <= 3:
		data = migrate_v3(data)
	if int(envelope["version"]) <= 4:
		data = migrate_v4(data)
	if int(envelope["version"]) <= 5:
		data = migrate_v5(data)
	if int(envelope["version"]) <= 6:
		data = migrate_v6(data)
	if int(envelope["version"]) <= 7:
		data = migrate_v7(data)
	if int(envelope["version"]) <= 8:
		data = migrate_v8(data)
	if int(envelope["version"]) <= 9:
		data = migrate_v9(data)
	if int(envelope["version"]) <= 10:
		data = migrate_v10(data)
	if int(envelope["version"]) <= 11:
		data = migrate_v11(data)
	if int(envelope["version"]) <= 12:
		data = migrate_v12(data)
	if int(envelope["version"]) <= 13:
		data = migrate_v13(data)
	if int(envelope["version"]) <= 14:
		data = migrate_v14(data)
	if int(envelope["version"]) <= 15:
		data = migrate_v15(data)
	var error := validate(data)
	if not error.is_empty():
		return {"ok": false, "message": error}
	return {"ok": true, "data": data, "migrated": migrated}


static func migrate_v1(data: Variant) -> Variant:
	var fields := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs"]
	if not _exact_keys(data, fields) or not data["stock"] is Dictionary or not data["actors"] is Array or data["actors"].size() != 3:
		return null
	var old_resources := ["raw_food", "water", "fuel", "meals", "materials", "tools"]
	var old_tasks := ["repair", "cook", "eat", "sleep", "craft"]
	if not _exact_keys(data["stock"], old_resources): return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["stock"]["medicine"] = 0 # Migration must not grant free supplies.
	for actor in upgraded["actors"]:
		if not actor is Dictionary or not actor.has("completed_by_task") or not actor.has("warned") or not _exact_keys(actor["completed_by_task"], old_tasks) or not _exact_keys(actor["warned"], ["hunger", "fatigue", "health"]): return null
		if actor.has("injury") or actor.has("infection"): return null
		actor["injury"] = 0.0
		actor["infection"] = 0.0
		actor["completed_by_task"]["heal"] = 0
		actor["warned"]["infection"] = false
	upgraded["expedition"] = ExpeditionState.new().snapshot()
	return upgraded


static func migrate_v2(data: Variant) -> Variant:
	var fields := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs", "expedition"]
	if not _exact_keys(data, fields) or not data["actors"] is Array or data["actors"].size() != 3 or not _number(data["simulation_time"], 0, 1000000000): return null
	var upgraded: Dictionary = data.duplicate(true)
	for actor in upgraded["actors"]:
		if not actor is Dictionary or actor.has("legacy_repair") or not actor.has_all(["state", "orders", "held_cost"]): return null
		if not _integer(actor["state"], 0, Survivor.TaskState.AWAY) or not actor["orders"] is Array or not actor["held_cost"] is Dictionary: return null
		actor["legacy_repair"] = actor["state"] == Survivor.TaskState.WORKING and (not actor["orders"].is_empty() and actor["orders"][0] == "repair") and actor["held_cost"] == {}
	upgraded["destination"] = "street"
	upgraded["other_regions"] = {}
	for id in ["clinic", "works"]: upgraded["other_regions"][id] = ExpeditionState.new(id).snapshot()
	var progress := ShelterProgress.new()
	progress.last_day = ExpeditionState.day_at(float(upgraded["simulation_time"]))
	var world: Variant = upgraded["expedition"]
	if world is Dictionary and world.get("active", false) == true and world.get("bag") is Dictionary:
		for resource in ["tools", "medicine"]:
			if _integer(world["bag"].get(resource, 0), 1, ExpeditionState.CAPACITY): progress.trip_loadout[resource] = 1
	upgraded["upkeep"] = progress.snapshot()
	return upgraded


static func migrate_v3(data: Variant) -> Variant:
	var fields := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs", "expedition", "destination", "other_regions", "upkeep"]
	if not _exact_keys(data, fields) or not data["actors"] is Array or data["actors"].size() != 3 or not _number(data["simulation_time"], 0, 1000000000): return null
	var upgraded: Dictionary = data.duplicate(true)
	var party := PeopleSystem.new()
	party.last_day = ExpeditionState.day_at(float(data["simulation_time"]))
	party.next_routine = float(data["simulation_time"])
	for index in range(3):
		var actor: Variant = upgraded["actors"][index]
		if not actor is Dictionary or actor.has("person") or not actor.has_all(["completed_by_task", "health"]) or not actor["completed_by_task"] is Dictionary or not _number(actor["health"], 0, 100): return null
		var person := CharacterState.new()
		person.persona = PeopleCatalog.ORIGINALS[index]
		for task in ["repair", "craft", "cook", "heal"]:
			var count: Variant = actor["completed_by_task"].get(task)
			if not _integer(count, 0, 1000000000): return null
			person.gain("care" if task == "heal" else "craft", float(count) * (8 if task in ["craft", "heal"] else 6 if task == "repair" else 4))
		actor["person"] = person.snapshot()
		if actor["health"] == 0: party.deaths.append(person.persona)
	party.bonds = {"0:1": 25, "0:2": 25, "1:2": 25}
	if not upgraded["other_regions"] is Dictionary: return null
	var worlds: Array = upgraded["other_regions"].values()
	worlds.append(upgraded["expedition"])
	for world in worlds:
		if not world is Dictionary or not world.get("enemies") is Array: return null
		for enemy in world["enemies"]:
			if not enemy is Dictionary: return null
			if not enemy.has("brace"): enemy["brace"] = 0.0
	upgraded["people"] = party.snapshot()
	return upgraded


static func migrate_v4(data: Variant) -> Variant:
	var fields := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs", "expedition", "destination", "other_regions", "upkeep", "people"]
	if not _exact_keys(data, fields) or not data["actors"] is Array or not _number(data["simulation_time"], 0, 1000000000): return null
	var upgraded: Dictionary = data.duplicate(true)
	var narrative := StorySystem.new()
	narrative.next_poll = float(data["simulation_time"])
	narrative.next_offer_day = maxi(2, ExpeditionState.day_at(float(data["simulation_time"])))
	for actor in data["actors"]:
		if not actor is Dictionary or not actor.get("completed_by_task") is Dictionary: return null
		for task in ["eat", "sleep", "repair"]:
			if not _integer(actor["completed_by_task"].get(task), 0, 1000000000): return null
			if actor["completed_by_task"][task] > 0: narrative.job_completed(task)
	if not data["people"] is Dictionary or not _integer(data["people"].get("drinks"), 0, 100000000): return null
	if data["people"]["drinks"] > 0: narrative.note("drink")
	if not data["upkeep"] is Dictionary or not data["upkeep"].get("returns") is Dictionary: return null
	if data["upkeep"]["returns"].values().any(func(n): return (n is int or n is float) and n > 0):
		# Only actual net recovered cargo proves the supply tutorial step.
		if data["upkeep"].get("recovered") is Dictionary and data["upkeep"]["recovered"].values().any(func(n): return (n is int or n is float) and n > 0): narrative.note("supplies")
	upgraded["story"] = narrative.snapshot()
	return upgraded


static func migrate_v5(data: Variant) -> Variant:
	var fields := ["simulation_time", "paused", "speed", "selected_id", "selected_task", "stock", "history", "stairs_open", "actors", "stations", "logs", "expedition", "destination", "other_regions", "upkeep", "people", "story"]
	if not _exact_keys(data, fields): return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["goals"] = GoalSystem.new().snapshot()
	return upgraded


func read_state() -> Dictionary:
	var primary := _read_file(path)
	if primary["ok"]:
		primary["backup"] = false
		return primary
	var backup := _read_file(path + ".bak")
	if backup["ok"]:
		backup["backup"] = true
		return backup
	return {"ok": false, "message": "主存档：%s；备份：%s" % [primary["message"], backup["message"]]}


func write_state(game: Node2D) -> Dictionary:
	var state := capture(game)
	var error := validate(state)
	if not error.is_empty():
		return {"ok": false, "message": "当前状态不能保存：" + error}
	var destination := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "message": "无法创建存档目录"}
	var text := JSON.stringify(state, "", true, true)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "无法写入临时存档"}
	file.store_string(JSON.stringify({"version": VERSION, "data_json": text, "sha256": text.sha256_text()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	var verification := _read_file(path + ".tmp")
	if write_error != OK or not verification["ok"]:
		return {"ok": false, "message": "临时存档写入校验失败：" + verification.get("message", "写入错误")}
	# Never replace a good backup with a damaged primary.
	if _read_file(path)["ok"]:
		if DirAccess.copy_absolute(destination, destination + ".bak.tmp") != OK or DirAccess.rename_absolute(destination + ".bak.tmp", destination + ".bak") != OK:
			return {"ok": false, "message": "备份写入失败，原存档保留"}
	if DirAccess.rename_absolute(destination + ".tmp", destination) != OK:
		return {"ok": false, "message": "存档替换失败，原存档保留"}
	return {"ok": true, "message": "已保存"}


static func migrate_v6(data: Variant) -> Variant:
	if not data is Dictionary or data.has("campaign") or not data.has_all(["expedition", "other_regions"]): return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["campaign"] = {}
	if not upgraded["other_regions"] is Dictionary or not upgraded["expedition"] is Dictionary: return null
	var worlds: Array = upgraded["other_regions"].values()
	worlds.append(upgraded["expedition"])
	for world in worlds:
		if not world is Dictionary: return null
		if not world.has("discovered"): world["discovered"] = []
		if not world.has("capacity"): world["capacity"] = 10
		if not world.has("manual_loot"): world["manual_loot"] = false
		if not world.has("loot_site"): world["loot_site"] = -1
	return upgraded


static func migrate_v7(data: Variant) -> Variant:
	if not data is Dictionary or data.has("expansion") or not data.has_all(["actors", "campaign", "expedition", "other_regions"]): return null
	var upgraded: Dictionary = data.duplicate(true)
	if not upgraded["actors"] is Array or not upgraded["campaign"] is Dictionary or not upgraded["other_regions"] is Dictionary or not upgraded["expedition"] is Dictionary: return null
	upgraded["expansion"] = {}
	if not upgraded["campaign"].is_empty():
		var expansion := SurvivalExpansion.new()
		expansion.epoch = ExpeditionState.day_at(float(upgraded.get("simulation_time", 0)))
		upgraded["expansion"] = expansion.snapshot()
	for actor in upgraded["actors"]:
		if not actor is Dictionary: return null
		actor["illness"] = 0.0
		actor["cold_exposure"] = 0.0
	var worlds: Array = upgraded["other_regions"].values()
	worlds.append(upgraded["expedition"])
	for world in worlds:
		if not world is Dictionary or not world.get("enemies") is Array: return null
		world["extra_slots"] = 0
		world["reserve_ammo"] = 0
		world["magazine"] = 0
		world["reload_remaining"] = 0.0
		for enemy in world["enemies"]:
			if not enemy is Dictionary: return null
			enemy["kind"] = "walker"
	if not upgraded["campaign"].is_empty():
		for id in LocationCatalog.ALL_IDS:
			if not LocationCatalog.IDS.has(id):
				upgraded["other_regions"][id] = ExpeditionState.new(id).snapshot()
				if upgraded.get("upkeep") is Dictionary and upgraded["upkeep"].get("returns") is Dictionary: upgraded["upkeep"]["returns"][id] = 0
	return upgraded


static func migrate_v8(data: Variant) -> Variant:
	if not data is Dictionary or data.has("residence") or not data.has_all(["campaign", "expansion"]): return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["residence"] = {} if upgraded["campaign"].is_empty() else ResidenceSystem.new().snapshot()
	return upgraded


static func migrate_v9(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("campaign") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	if not upgraded["campaign"].is_empty():
		if upgraded["campaign"].has("return_requested"): return null
		upgraded["campaign"]["return_requested"] = false
	return upgraded


static func migrate_v10(data: Variant) -> Variant:
	if not data is Dictionary or data.has("facilities") or not data.get("campaign") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	# Keep already paid jobs and owned gear. New crafting uses the tier gates.
	upgraded["facilities"] = {} if upgraded["campaign"].is_empty() else FacilitySystem.new().snapshot()
	return upgraded


static func migrate_v11(data: Variant) -> Variant:
	if not data is Dictionary or data.has("director") or not data.get("campaign") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["director"] = {} if upgraded["campaign"].is_empty() else CampaignDirector.new().snapshot()
	return upgraded


static func migrate_v12(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("other_regions") is Dictionary or not data.get("expedition") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	for region in [upgraded["expedition"]]+upgraded["other_regions"].values():
		if not region is Dictionary or not region.get("enemies") is Array: return null
		for enemy in region["enemies"]:
			if not enemy is Dictionary or not enemy.has("floor"): return null
			# Older migrations create fresh maps with the current constructor.
			if enemy.has("home_floor"):
				if not enemy.has_all(["target_floor","memory","climb_target","climb_progress"]): return null
				continue
			enemy["home_floor"] = enemy["floor"]
			enemy["target_floor"] = enemy["floor"]
			enemy["memory"] = 0.0
			enemy["climb_target"] = -1
			enemy["climb_progress"] = 0.0
	return upgraded


static func migrate_v13(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("campaign") is Dictionary or not data.get("expedition") is Dictionary or not data.get("other_regions") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	for field in [upgraded["expedition"]]+upgraded["other_regions"].values():
		if not field is Dictionary: return null
		# Earlier migrations create current-format fresh maps.
		field["stacked"] = not upgraded["campaign"].is_empty()
	return upgraded


static func migrate_v14(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("expedition") is Dictionary or not data.get("other_regions") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	for field in [upgraded["expedition"]]+upgraded["other_regions"].values():
		if not field is Dictionary: return null
		# Older migrations may create fresh maps using the current constructor.
		# Existing units, current coordinates, search and enemy memory are preserved.
		field["condition"] = 0
		field["route_open"] = false
		field["route_progress"] = 0.0
		field["route_tool"] = false
	return upgraded


static func migrate_v15(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("campaign") is Dictionary or not data.get("expedition") is Dictionary or not data.get("other_regions") is Dictionary: return null
	var upgraded: Dictionary = data.duplicate(true)
	upgraded["districts"] = {} if upgraded["campaign"].is_empty() else DistrictSystem.new().snapshot()
	for f in [upgraded["expedition"]]+upgraded["other_regions"].values():
		if not f is Dictionary: return null
		f["decoys"] = [];f["lure_cooldown"] = 0.0
	if not upgraded["campaign"].is_empty() and upgraded["expedition"].get("active",false):
		upgraded["districts"]["trip_map"] = upgraded["destination"]
		upgraded["districts"]["trip_dead"] = upgraded["expedition"]["enemies"].filter(func(e): return e["hp"] <= 0).size()
	return upgraded
