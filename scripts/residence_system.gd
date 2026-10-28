class_name ResidenceSystem
extends RefCounted
## One occupied home. Survey papers travel with the scout; convoys consume an entire night.
const HOMES := {
	"shelter": {"name": "旧城避难屋", "map": "street", "site": 0, "day": 1, "warmth": 8, "risk": 0, "defense": 0.0, "hint": "初始住处；适中的保温和暴露程度。"},
	"row": {"name": "内巷排屋", "map": "residential", "site": 3, "day": 5, "warmth": 12, "risk": -10, "defense": 0.15, "hint": "较暖、隐蔽；需深入居民区勘察并清理。"},
	"depot": {"name": "货场值守楼", "map": "depot", "site": 3, "day": 12, "warmth": 4, "risk": 10, "defense": 0.5, "hint": "结实但寒冷，尸群更密集；原有围墙提供防守。"},
}
const PROJECTS := {
	"gate": {"name": "加固入口门", "cost": {"materials": 5, "tools": 1}, "seconds": 34.0, "hint": "两级，每级防守+0.35；受安防耐久影响。"},
	"mesh": {"name": "封护窗网", "cost": {"materials": 4, "tools": 1}, "seconds": 30.0, "hint": "两级，每级防守+0.25，减少突破时的伤害。"},
	"alarm": {"name": "拉线预警铃", "cost": {"materials": 2, "tools": 1}, "seconds": 22.0, "hint": "放大守夜者的防守贡献30%；不能代替守夜。"},
	"stakes": {"name": "外围拒马", "cost": {"materials": 5}, "seconds": 36.0, "hint": "防守+0.45，每次袭击额外磨损；需维护。"},
	"maintain": {"name": "维护门窗与拒马", "cost": {"materials": 2}, "seconds": 18.0, "hint": "恢复45安防耐久，不能恢复房屋结构。"},
	"guitar": {"name": "修好旧吉他", "cost": {"materials": 3, "tools": 1}, "seconds": 28.0, "hint": "可安排演奏；纲手安抚效果更好，会制造少量噪声。"},
	"music": {"name": "为同伴弹奏", "cost": {}, "seconds": 20.0, "hint": "每人每天一次；在场同伴恢复心境、减轻压力，不代替睡眠。"},
	"clear_row": {"name": "准备内巷清理工具", "cost": {"materials": 5, "tools": 2}, "seconds": 48.0, "hint": "勘察返回后准备工具，再赴新址清除附近感染者并确认清理。"},
	"clear_depot": {"name": "准备货场清理工具", "cost": {"materials": 7, "tools": 2}, "seconds": 54.0, "hint": "勘察返回后准备工具，再赴新址清除附近感染者并确认清理。"},
	"pack_shelter": {"name": "打包返回旧屋", "cost": {"meals": 5, "water": 10, "fuel": 2, "tools": 1}, "seconds": 48.0, "hint": "预付最多5人的运输补给；转移占用整夜，不能搜刮和睡眠。"},
	"pack_row": {"name": "打包迁往内巷", "cost": {"meals": 5, "water": 10, "fuel": 2, "tools": 1}, "seconds": 48.0, "hint": "预付最多5人的运输补给；转移占用整夜，不能搜刮和睡眠。"},
	"pack_depot": {"name": "打包迁往货场", "cost": {"meals": 5, "water": 10, "fuel": 2, "tools": 1}, "seconds": 48.0, "hint": "预付最多5人的运输补给；转移占用整夜，不能搜刮和睡眠。"},
}
var current := "shelter"
var surveyed: Array[String] = ["shelter"]
var prepared: Array[String] = []
var carried_clear := false
var cleared: Array[String] = ["shelter"]
var carried := ""
var convoy := ""
var last_move_day := 0
var moves: Array[Dictionary] = []
var security := {"gate": 0, "mesh": 0, "alarm": 0, "stakes": 0}
var condition := 100.0
var noise := 0.0
var guitar := false
var music_days: Dictionary = {}

func title() -> String:
	return HOMES[current]["name"]

func indoor_bonus() -> float:
	return HOMES[current]["warmth"]

func sync(game: Node2D) -> void:
	for id in HOMES:
		if cleared.has(id): continue
		var field: ExpeditionState = game.regions[HOMES[id]["map"]]
		var site: int = HOMES[id]["site"]
		if not field.special_sites.has(site): field.special_sites.append(site)

func survey_target(field: ExpeditionState) -> String:
	for id in HOMES:
		if id != "shelter" and not cleared.has(id) and field.location_id == HOMES[id]["map"] and field.loot_site == HOMES[id]["site"]: return id
	return ""

func survey(game: Node2D) -> bool:
	var field: ExpeditionState = game.expedition
	if not field.active or game.paused: return false
	var id := survey_target(field)
	if id.is_empty() or not carried.is_empty(): return false
	var clearing := surveyed.has(id)
	if clearing and not prepared.has(id):
		game._log("已勘察；先回家准备清理工具，再来处理新址。")
		return false
	# Search and physical presence both matter; a stale open container is insufficient.
	var site: Dictionary = field.site_definitions()[int(HOMES[id]["site"])]
	if field.floor_level != site["floor"] or absf(field.player_x - float(site["x"])) > 80 or field.climb_target != -1: return false
	if clearing and field.enemies.any(func(enemy): return enemy["hp"] > 0 and absf(float(enemy["x"]) - float(site["x"])) < 450):
		game._log("新址附近仍有感染者：清除附近上下两层的威胁再确认。")
		return false
	carried_clear = clearing
	carried = id
	game._log("已记录" + HOMES[id]["name"] + "的入口与隐患，活着返回才能用于迁居。")
	return true

func trip_return(game: Node2D, survived: bool) -> void:
	if survived and not carried.is_empty():
		if carried_clear:
			cleared.append(carried)
			prepared.erase(carried)
			game._log(HOMES[carried]["name"] + "已确认清理，可在H页打包迁居。")
		elif not surveyed.has(carried):
			surveyed.append(carried)
			game._log(HOMES[carried]["name"] + "勘察入库；H准备清理工具，再赴新址处理感染者。")
	carried = ""
	carried_clear = false


func job_error(game: Node2D, kind: String) -> String:
	if game.game_over or game.cycle.phase != "day": return "白天才能准备。"
	if not PROJECTS.has(kind): return "未知家园项目。"
	if not convoy.is_empty(): return "已有待出发的搬家队伍；可取消打包后再准备。"
	if security.has(kind) and security[kind] >= (2 if kind in ["gate", "mesh"] else 1): return "已经完成此项加固。"
	if kind == "maintain" and (condition >= 100 or security.values().all(func(n): return n == 0)): return "安防设施无需维护。"
	if kind == "guitar" and guitar: return "吉他已经修好。"
	if kind == "music":
		if not guitar: return "先修好吉他。"
		if int(music_days.get(game.survivors[game.selected_id].person.persona, 0)) >= ExpeditionState.day_at(game.simulation_time): return "这位成员今天已经演奏过。"
	if kind.begins_with("clear_"):
		var id := kind.trim_prefix("clear_")
		if not surveyed.has(id): return "先深入对应地图勘察，再从入口带回记录。"
		if cleared.has(id) or prepared.has(id): return "已清理或已备好工具；去新址清除附近感染者并确认。"
	if kind.begins_with("pack_"):
		var id := kind.trim_prefix("pack_")
		if id == current: return "已经住在这里。"
		if not cleared.has(id): return "先勘察并完成清理。"
		var day := ExpeditionState.day_at(game.simulation_time)
		if day < maxi(5, int(HOMES[id]["day"])): return "至少第%d天才能迁居。" % maxi(5, int(HOMES[id]["day"]))
		if last_move_day > 0 and day - last_move_day < 5: return "上次迁居后至少休整5天。"
		for actor in game.survivors:
			if actor.health > 0 and (actor.health < 25 or actor.fatigue > 70 or actor.illness >= 75): return "全员需要生命至少25、精神至少30、疾病低于75。"
	if game.expansion.jobs.any(func(job): return PROJECTS.has(job["kind"])): return "家园项目一次准备一项。"
	return ""

func finish(game: Node2D, kind: String, actor: Survivor) -> void:
	if security.has(kind): security[kind] += 1
	elif kind == "maintain": condition = minf(100, condition + 45)
	elif kind == "guitar": guitar = true
	elif kind == "music":
		music_days[actor.person.persona] = ExpeditionState.day_at(game.simulation_time)
		var strength := CharacterAbilities.factor(actor, "music")
		for member in game.survivors:
			if member.health <= 0: continue
			member.person.morale = minf(100, member.person.morale + 5 * strength)
			member.person.stress = maxf(0, member.person.stress - 9 * strength)
		noise = minf(100, noise + 5)
	elif kind.begins_with("clear_"): prepared.append(kind.trim_prefix("clear_"))
	elif kind.begins_with("pack_"): convoy = kind.trim_prefix("pack_")
	if kind != "music": noise = minf(100, noise + 9)
	game.queue_redraw()

func cancel_convoy(game: Node2D) -> bool:
	if convoy.is_empty() or not game.cycle.phase in ["day", "planning"]: return false
	var cost: Dictionary = PROJECTS["pack_" + convoy]["cost"]
	convoy = ""
	game.inventory.deposit(cost, "取消尚未出发的搬家，退回运输补给")
	return true

func plan_error(game: Node2D) -> String:
	if convoy.is_empty(): return ""
	if game.cycle.scavenger() >= 0: return "搬家占用整夜，请将所有人改为留守警戒。"
	if not game.cycle.loadout.is_empty() or game.expansion.ammo_loadout > 0: return "搬家不使用搜刮背包，请清空携带物资与弹药。"
	for actor in game.survivors:
		if actor.health > 0 and (actor.health < 25 or actor.fatigue > 80 or actor.illness >= 75): return "有人无法赶路：先取消搬家、治疗和休息。"
	return ""

func defense() -> float:
	return float(HOMES[current]["defense"]) + (security["gate"] * 0.35 + security["mesh"] * 0.25 + security["stakes"] * 0.45) * condition / 100

func guard_multiplier() -> float:
	return 1.0 + (0.3 * condition / 100 if security["alarm"] > 0 else 0.0)

func attack_chance(base: int) -> int:
	return clampi(base + int(HOMES[current]["risk"]) + int(noise / 5), 10, 95)

func wear(threat: float) -> void:
	if security.values().any(func(n): return n > 0): condition = maxf(0, condition - threat * 4 - (6 if security["stakes"] > 0 else 0))

func finish_move(game: Node2D, report: Array[String]) -> void:
	if convoy.is_empty() or game.survivors.all(func(a): return a.health <= 0): return
	var old := current
	var salvage := 0
	if game.has_method("facilities_snapshot"): salvage += game.facilities.move_home(game)
	for build in game.cycle.builds:
		if build["state"] == "complete": salvage += int(CampaignCycle.RECIPES[build["type"]]["cost"].get("materials",0)) / 2
	for kind in security:
		salvage += int(PROJECTS[kind]["cost"].get("materials",0) * security[kind] * condition / 200)
		security[kind] = 0
	game.cycle.builds.clear()
	game.inventory.deposit({"materials": salvage}, "拆解旧址固定设施回收半数材料，工具不返还")
	current = convoy
	convoy = ""
	last_move_day = ExpeditionState.day_at(game.simulation_time)
	moves.append({"day": last_move_day, "from": old, "to": current})
	if moves.size() > 20: moves.pop_front()
	condition = 100
	noise = 0
	game.upkeep.level = 0
	game.upkeep.integrity = 85 if current == "depot" else 75
	game.expansion.heater_remaining = 0
	game.expansion.pump_on = false
	for actor in game.survivors:
		if actor.health <= 0: continue
		actor.fatigue = minf(100, actor.fatigue + 12)
		actor.position = Vector2(190 + actor.survivor_id * 42, 640)
		actor.route.clear()
		actor.state = Survivor.TaskState.IDLE
	game._props_signature = ""
	game._sync_props()
	game.queue_redraw()
	report.append("全员迁入%s：固定设施拆解回收材料%d；据点等级与安防重建。库存、装备、吉他和战役设备随队转移。" % [title(), salvage])

func snapshot() -> Dictionary:
	return {"current": current, "surveyed": surveyed.duplicate(), "cleared": cleared.duplicate(), "prepared": prepared.duplicate(), "carried_clear": carried_clear, "carried": carried, "convoy": convoy, "last_move_day": last_move_day, "moves": moves.duplicate(true), "security": security.duplicate(), "condition": condition, "noise": noise, "guitar": guitar, "music_days": music_days.duplicate()}

func restore(data: Dictionary, game: Node2D) -> void:
	var source := ResidenceSystem.new().snapshot() if data.is_empty() else data
	for key in source:
		if key in ["surveyed", "cleared", "prepared"]:
			var list: Array[String] = []
			for id in source[key]: list.append(id)
			set(key, list)
		elif key == "moves":
			moves.clear()
			for move in source[key]: moves.append(move.duplicate(true))
		elif source[key] is Dictionary: set(key, source[key].duplicate(true))
		else: set(key, source[key])
	sync(game)

static func validate(data: Variant, world: Dictionary) -> String:
	if data is Dictionary and data.is_empty(): return ""
	if not CharacterState.keys(data, ResidenceSystem.new().snapshot().keys()): return "家园字段无效"
	var day := ExpeditionState.day_at(world["simulation_time"])
	if not data["current"] is String or not HOMES.has(data["current"]) or not CharacterState.integer(data["last_move_day"], 0, day): return "家园地点或迁居日期无效"
	for key in ["surveyed", "cleared", "prepared"]:
		if not data[key] is Array or data[key].size() > 3 or (key != "prepared" and not data[key].has("shelter")): return "家园勘察记录无效"
		var unique: Array = []
		for id in data[key]:
			if not id is String or not HOMES.has(id) or unique.has(id): return "家园地点重复或未知"
			unique.append(id)
	for id in data["prepared"]:
		if id == "shelter" or not data["surveyed"].has(id) or data["cleared"].has(id): return "清理工具与勘察状态不符"
	if not data["carried_clear"] is bool or (data["carried"] == "" and data["carried_clear"]): return "清理确认状态无效"
	for id in data["cleared"]:
		if not data["surveyed"].has(id): return "清理缺少勘察"
	if not data["cleared"].has(data["current"]): return "入住缺少清理"
	for key in ["carried", "convoy"]:
		if not data[key] is String or (data[key] != "" and not HOMES.has(data[key])): return "勘察或车队目标无效"
	if data["carried"] != "":
		if data["carried"] == "shelter" or data["cleared"].has(data["carried"]) or (data["carried_clear"] != data["surveyed"].has(data["carried"])) or (data["carried_clear"] and not data["prepared"].has(data["carried"])) or not world["expedition"]["active"] or world["destination"] != HOMES[data["carried"]]["map"]: return "勘察记录未随实际搜刮者携带"
	if data["convoy"] != "" and (not data["cleared"].has(data["convoy"]) or data["convoy"] == data["current"] or world["expedition"]["active"] or day < maxi(5, HOMES[data["convoy"]]["day"]) or (data["last_move_day"] > 0 and day - data["last_move_day"] < 5)): return "车队准备状态无效"
	if not CharacterState.keys(data["security"], ["gate", "mesh", "alarm", "stakes"]): return "安防项目无效"
	for key in data["security"]:
		if not CharacterState.integer(data["security"][key], 0, 2 if key in ["gate", "mesh"] else 1): return "安防等级无效"
	if not CharacterState.number(data["condition"], 0, 100) or not CharacterState.number(data["noise"], 0, 100) or not data["guitar"] is bool: return "安防耐久或噪声无效"
	if not data["music_days"] is Dictionary or data["music_days"].size() > PeopleCatalog.MAX_HISTORY: return "演奏记录无效"
	for id in data["music_days"]:
		if not PeopleCatalog.DATA.has(id) or not CharacterState.integer(data["music_days"][id], 1, day) or not data["guitar"]: return "演奏者或日期无效"
	if not data["moves"] is Array or data["moves"].size() > 20: return "迁居历史无效"
	var previous := 0
	var last_home := ""
	for move in data["moves"]:
		if not CharacterState.keys(move, ["day", "from", "to"]) or not CharacterState.integer(move["day"], maxi(5, previous + 5), day) or not HOMES.has(move["from"]) or not HOMES.has(move["to"]) or move["from"] == move["to"]: return "迁居历史内容无效"
		if last_home != "" and move["from"] != last_home: return "迁居路线不连续"
		previous = move["day"]
		last_home = move["to"]
	if previous != data["last_move_day"] or (last_home != "" and last_home != data["current"]) or (data["last_move_day"] == 0 and data["current"] != "shelter"): return "迁居历史与现居地不符"
	var home_jobs := 0
	if world["expansion"] is Dictionary and world["expansion"].get("jobs") is Array:
		for job in world["expansion"]["jobs"]:
			var kind: String = job["kind"]
			if not PROJECTS.has(kind): continue
			home_jobs += 1
			if home_jobs > 1 or data["convoy"] != "": return "家园项目或车队重复占用"
			if data["security"].has(kind) and data["security"][kind] >= (2 if kind in ["gate", "mesh"] else 1): return "安防项目已达上限"
			if kind == "guitar" and data["guitar"]: return "重复修复吉他"
			if kind == "music":
				var persona: String = world["actors"][int(job["actor"])]["person"]["persona"]
				if not data["guitar"] or int(data["music_days"].get(persona,0)) >= day: return "演奏缺少吉他或仍在冷却"
			if kind.begins_with("clear_"):
				var id := kind.trim_prefix("clear_")
				if not data["surveyed"].has(id) or data["prepared"].has(id) or data["cleared"].has(id): return "清理项目与新址状态不符"
			if kind.begins_with("pack_"):
				var id := kind.trim_prefix("pack_")
				if not data["cleared"].has(id) or id == data["current"] or day < maxi(5,HOMES[id]["day"]) or (data["last_move_day"] > 0 and day-data["last_move_day"] < 5): return "打包项目缺少迁居条件"
	return ""
