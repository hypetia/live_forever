class_name FacilitySystem
extends RefCounted
## Facility tiers are separate from shelter condition and the shelter-wide level.
const NAMES := {"workbench":["基础工作台","改良工作台","精密武器台"],"stove":["简易灶台","改良厨房","高效厨房"]}
const REQUIREMENTS := {"spear":2,"vest":2,"coat":2,"pistol":3,"ammo":3}
const RECIPES := {
	"workbench_2":{"name":"升级改良工作台","cost":{"materials":6,"tools":1},"seconds":36.0,"station":"workbench","from":1,"to":2,"hint":"解锁铁矛、防咬背心、厚冬衣；制作速度+10%。"},
	"workbench_3":{"name":"升级精密武器台","cost":{"materials":10,"tools":2},"seconds":56.0,"station":"workbench","from":2,"to":3,"hint":"解锁修复手枪、弹药；制作速度+20%。"},
	"stove_2":{"name":"升级改良厨房","cost":{"materials":5,"tools":1},"seconds":32.0,"station":"stove","from":1,"to":2,"hint":"解锁节燃料合炊、节水炖煮；烹饪速度+15%。"},
	"stove_3":{"name":"升级高效厨房","cost":{"materials":8,"tools":1},"seconds":46.0,"station":"stove","from":2,"to":3,"hint":"解锁大锅烩饭；烹饪速度+30%。"},
	"cook_batch":{"name":"节燃料合炊","cost":{"raw_food":2,"water":2,"fuel":1},"seconds":10.0,"station":"stove","minimum":2,"output":{"meals":4},"chef_bonus":2,"hint":"两份生食合做，燃料比两次普通做饭少1。"},
	"cook_stew":{"name":"节水炖煮","cost":{"raw_food":2,"water":1,"fuel":1},"seconds":9.0,"station":"stove","minimum":2,"output":{"meals":3},"chef_bonus":1,"hint":"少用水，熟食产量比合炊低，适合缺水时。"},
	"cook_pot":{"name":"大锅烩饭","cost":{"raw_food":3,"water":2,"fuel":1},"seconds":14.0,"station":"stove","minimum":3,"output":{"meals":6},"chef_bonus":2,"hint":"适合多人备餐；仍受熟食保鲜容量限制。"},
}
var levels := {"workbench":1,"stove":1}

func snapshot() -> Dictionary:
	return levels.duplicate()

func restore(data: Dictionary, game: Node2D) -> void:
	levels = {"workbench":1,"stove":1} if data.is_empty() else data.duplicate()
	sync(game)

func title(station: String) -> String:
	return "%s · Lv.%d" % [NAMES[station][int(levels[station])-1],levels[station]]

func rate(station: String) -> float:
	return 1.0 + (int(levels.get(station,1))-1)*(0.15 if station == "stove" else 0.1)

func next_upgrade(station: String) -> String:
	return station+"_"+str(int(levels[station])+1) if int(levels[station]) < 3 else ""

static func station_for(kind: String) -> String:
	if kind == "music": return ""
	return RECIPES.get(kind,{}).get("station","workbench")

static func cooking_output(kind: String, actor: Survivor) -> Dictionary:
	var recipe: Dictionary = RECIPES[kind]
	return {"meals":int(recipe["output"]["meals"])+(int(recipe["chef_bonus"]) if actor.person.persona == "he" else 0)}

func job_error(game: Node2D, kind: String) -> String:
	var station := station_for(kind)
	if station.is_empty(): return ""
	var recipe: Dictionary = RECIPES.get(kind,{})
	if recipe.has("from"):
		if levels[station] != recipe["from"]: return "设施等级不符，请依次升级。"
		if game.expansion.jobs.any(func(job): return RECIPES.get(job["kind"],{}).has("from") and station_for(job["kind"]) == station): return "该设施已有升级施工，不能重复安排。"
	elif int(levels[station]) < int(recipe.get("minimum",REQUIREMENTS.get(kind,1))):
		return "需要%sLv.%d。" % ["厨房" if station == "stove" else "工作台",recipe.get("minimum",REQUIREMENTS.get(kind,1))]
	return ""

func complete(game: Node2D, kind: String, actor: Survivor) -> void:
	var recipe: Dictionary = RECIPES[kind]
	if recipe.has("to"):
		levels[recipe["station"]] = int(recipe["to"])
		sync(game)
	else:
		game.inventory.deposit(cooking_output(kind,actor),recipe["name"])
		game.director.food_cooked(game,kind,cooking_output(kind,actor)["meals"])
		actor.person.gain("craft",4)

func sync(game: Node2D) -> void:
	for station: Workstation in [game.facility,game.stove]:
		station.tier = int(levels[station.facility_id])
		station.display_name = NAMES[station.facility_id][station.tier-1]
		station.queue_redraw()

func move_home(game: Node2D) -> int:
	var salvage := 0
	for station in levels:
		for tier in range(2,int(levels[station])+1): salvage += int(RECIPES[station+"_"+str(tier)]["cost"]["materials"])/2
		levels[station] = 1
	sync(game)
	return salvage

static func validate(data: Variant, world: Dictionary) -> String:
	if data is Dictionary and data.is_empty(): return "" if world["campaign"].is_empty() else "缺少设施等级"
	if world["campaign"].is_empty(): return "非战役存档不能持有设施等级"
	if not CharacterState.keys(data,["workbench","stove"]): return "设施等级字段无效"
	for station in data:
		if not CharacterState.integer(data[station],1,3): return "设施等级超出范围"
	var upgrades: Array = []
	for job in world["expansion"].get("jobs",[]):
		var recipe: Dictionary = RECIPES.get(job["kind"],{})
		if recipe.has("from"):
			var station: String = recipe["station"]
			if int(data[station]) != recipe["from"] or upgrades.has(station): return "设施升级重复或等级不符"
			upgrades.append(station)
		elif recipe.has("minimum") and int(data[recipe["station"]]) < recipe["minimum"]: return "烹饪配方尚未解锁"
	return ""
