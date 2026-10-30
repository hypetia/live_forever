class_name DistrictSystem
extends RefCounted
## A persistent relationship between field noise, district control and night labor.
const POINTS := {"street":3,"clinic":2,"works":1,"residential":2,"market":2,"waterworks":3,"depot":2,"broadcast":4,"evac":3}
const YIELDS := {
	"street":{"raw_food":2,"water":1},"clinic":{"medicine":1,"materials":1},
	"works":{"materials":4,"fuel":1},"residential":{"raw_food":2,"materials":2},
	"market":{"raw_food":3,"water":1},"waterworks":{"water":5},
	"depot":{"fuel":3,"materials":1},"broadcast":{"tools":1,"materials":2},"evac":{"water":2,"medicine":1}
}
const COSTS := {"build":{"materials":5,"tools":1},"repair":{"materials":2},"suppress":{"materials":1,"fuel":1}}
const SECONDS := {"build":9.0,"repair":5.0,"suppress":7.0}
const ACTION_NAMES := {"build":"建立补给前哨","repair":"修整前哨","suppress":"整治前哨周边"}
var regions: Dictionary = {}
var target := "street"
var work: Dictionary = {}
var shift: Dictionary = {}
var last_day := 0
var trip_map := ""
var trip_dead := 0
var alert := 0.0

func _init() -> void:
	for id in LocationCatalog.ALL_IDS: regions[id] = {"heat":0.0,"built":false,"condition":0.0,"secured_until":0,"shifts":0}

func sync(game: Node2D) -> void:
	for id in LocationCatalog.ALL_IDS:
		var field: ExpeditionState = game.regions[id]
		if not field.special_sites.has(POINTS[id]): field.special_sites.append(POINTS[id])

func begin_trip(game: Node2D) -> void:
	var field: ExpeditionState = game.expedition
	trip_map = field.location_id
	trip_dead = field.enemies.filter(func(e): return e["hp"] <= 0).size()
	work.clear()
	var region: Dictionary = regions[trip_map]
	# Population composition changes only before departure, never materializes
	# around the player mid-fight and never scales to their equipment.
	if field.persistent_loot:return # Persistent wounds and deaths are not replaced by a fresh difficulty preset.
	if float(region["heat"]) >= 45:
		for index in range(mini(2,field.enemies.size())):
			var e: Dictionary = field.enemies[index]
			if e["hp"] <= 0: continue
			e["kind"] = "brute" if region["heat"] >= 75 and index == 1 else "runner"
			e["hp"] = EnemyCatalog.stats(e["kind"])["health"]
	elif region["built"] and region["condition"] > 30 and region["secured_until"] >= game.cycle.night_day:
		var e: Dictionary = field.enemies.back()
		e["hp"] = 0;e["mode"] = "dead";e["climb_target"] = -1;e["climb_progress"] = 0
	trip_dead = field.enemies.filter(func(e): return e["hp"] <= 0).size()

func gunfire(game: Node2D,kind: String) -> void:
	if game.expedition.active and kind in ["shot","shot_miss","blocked_shot"]:
		var r: Dictionary = regions[game.expedition.location_id]
		r["heat"] = minf(100,float(r["heat"])+4)

func tick(game: Node2D,delta: float) -> void:
	var f: ExpeditionState = game.expedition
	if not f.active or trip_map != f.location_id: return
	if not work.is_empty() and (not f.site_in_range(POINTS[f.location_id]) or game.survivors[f.actor_id].health < float(work["health"])-.01 or not area_clear(f)):
		work.clear()
	var r: Dictionary = regions[f.location_id]
	r["heat"] = clampf(float(r["heat"])+maxf(0,f.noise-35)*delta*.0015+f.decoys.size()*delta*.025,0,100)
	var dead := f.enemies.filter(func(e): return e["hp"] <= 0).size()
	if dead > trip_dead: r["heat"] = maxf(0,float(r["heat"])-(dead-trip_dead)*3)
	trip_dead = dead

func trip_return(game: Node2D,survived: bool) -> void:
	if trip_map.is_empty(): return
	var f: ExpeditionState = game.expedition
	if survived:
		var different_exit := f.player_x >= f.right_edge(0)-55
		alert = clampf(alert+maxf(0,float(regions[trip_map]["heat"])-35)*.15*(.45 if different_exit else 1.0),0,12)
	work.clear();trip_map = "";trip_dead = 0

func action_error(game: Node2D,action: String) -> String:
	if not COSTS.has(action): return "未知前哨行动。"
	var f: ExpeditionState = game.expedition
	if not f.active or game.cycle.phase != "scavenge" or game.paused or game.game_over: return "需要夜间在现场行动；暂停时不能施工。"
	if not work.is_empty(): return "当前施工尚未结束。"
	if f.loot_site != POINTS[f.location_id] or not f.site_in_range(POINTS[f.location_id]): return "先靠近前哨位置并打开现场容器。"
	var r: Dictionary = regions[f.location_id]
	if action == "build" and r["built"]: return "这个前哨已经建成。"
	if action == "repair" and (not r["built"] or r["condition"] >= 100): return "需要已建成且有损耗的前哨。"
	if action == "suppress" and r["heat"] < 10: return "街区压力较低，无需处理。"
	if not area_clear(f): return "附近仍有活动感染者；可击倒它们，也可用诱饵引开。"
	for key in COSTS[action]:
		if int(f.bag[key]) < int(COSTS[action][key]): return "背包缺少："+ShelterInventory.describe(COSTS[action])
	return ""

func area_clear(f: ExpeditionState) -> bool:
	var point: Dictionary = f.site_definitions()[POINTS[f.location_id]]
	for e: Dictionary in f.enemies:
		if e["hp"] <= 0: continue
		var ladder := f.route_ladder(float(e["x"]),float(point["x"]))
		var distance := absf(float(e["x"])-float(point["x"])) if int(e["floor"]) == int(point["floor"]) else absf(float(e["x"])-ladder)+absf(float(point["x"])-ladder)+absf(f.enemy_y(e)-ExpeditionState.FLOOR_Y[int(point["floor"])])*.45
		if distance < 200: return false
	return true

func begin_work(game: Node2D,action: String) -> bool:
	var error := action_error(game,action)
	if not error.is_empty(): game._log(error);return false
	var f: ExpeditionState = game.expedition
	work = {"map":f.location_id,"actor":f.actor_id,"action":action,"elapsed":0.0,"health":game.survivors[f.actor_id].health}
	game.close_loot();f.loot_site = -1;game.expedition_view.search_held = false;game.interface.has_move_target = false
	f._reset_search();f._reset_route()
	return true

func tick_work(game: Node2D,delta: float,controls: Dictionary) -> void:
	if work.is_empty(): return
	var f: ExpeditionState = game.expedition
	if not f.active or f.location_id != work["map"] or f.actor_id != work["actor"]:
		work.clear();return
	var actor: Survivor = game.survivors[f.actor_id]
	var interrupted: bool = game.cycle.phase != "scavenge" or absf(float(controls.get("axis",0))) > .01 or int(controls.get("climb",0)) != 0 or f.climb_target != -1 or f.attack_windup > 0 or actor.health < float(work["health"])-.01 or not f.site_in_range(POINTS[f.location_id]) or not area_clear(f)
	for key in COSTS[work["action"]]:
		if int(f.bag[key]) < int(COSTS[work["action"]][key]): interrupted = true
	if interrupted:
		work.clear();game._log("前哨行动中止；未完成不扣施工物资。")
		return
	work["elapsed"] = float(work["elapsed"])+delta*(1.2 if actor.person.persona == "lin" else 1.0)*actor.person.bonus("craft")*(1.25 if work["action"] in ["build","repair"] and FieldTools.can_use(actor,work["action"]) else 1.0)
	f.noise_burst = maxf(f.noise_burst,48 if work["action"] == "suppress" else 28)
	if work["elapsed"] + .000001 < float(SECONDS[work["action"]]): return
	var action: String = work["action"]
	for key in COSTS[action]: f.bag[key] -= int(COSTS[action][key])
	var r: Dictionary = regions[f.location_id]
	match action:
		"build": r["built"] = true;r["condition"] = 100.0
		"repair": r["condition"] = minf(100,float(r["condition"])+55)
		"suppress": r["heat"] = maxf(0,float(r["heat"])-25)
	if action in ["build","repair"]:FieldTools.spend(actor,action)
	work.clear();actor.person.gain("craft",10)
	game._log(ACTION_NAMES[action]+"完成；现场状态已保留。")
	game.expansion.sync(game)

func select_target(game: Node2D,id: String) -> bool:
	if not game.cycle.phase in ["day","planning"] or not regions.has(id) or not regions[id]["built"]: return false
	target = id
	return true

func operator(game: Node2D) -> int:
	return game.cycle.roles.find("outpost")

func plan_error(game: Node2D) -> String:
	if game.cycle.roles.count("outpost") > 1: return "每晚最多一人负责前哨轮值。"
	var id := operator(game)
	if id < 0: return ""
	if not game.residence.convoy.is_empty(): return "迁居当晚不能安排前哨轮值。"
	if not regions[target]["built"] or regions[target]["condition"] < 20: return "先建立并修整轮值目标；Y打开街区图。"
	var actor: Survivor = game.survivors[id]
	if actor.health < 40 or actor.fatigue >= 85: return "轮值者需要生命至少40、精神高于15。"
	if game.inventory.amount("fuel") < int(game.cycle.loadout.get("fuel",0))+1: return "轮值需额外预留燃料1，不能使用归来后的补给。"
	if game.expansion.use_night_heat and game.cycle.has_build("heater"):
		var heating := ceili(maxf(0,game.cycle.night_end-game.cycle.night_start-game.expansion.heater_remaining)/240.0)
		if game.inventory.amount("fuel") < int(game.cycle.loadout.get("fuel",0))+1+heating: return "轮值燃料1与夜间取暖预留不足；请调整携带物资或取暖计划。"
	var rounds := 2 if actor.weapon().has("magazine") else 0
	var field_rounds: int = game.expansion.ammo_loadout if game.cycle.scavenger() >= 0 else 0
	if game.expansion.ammo < rounds+field_rounds: return "轮值枪械需额外预留弹药2；改用近战武器或调整携带弹药。"
	return ""

func reserve_shift(game: Node2D) -> bool:
	var id := operator(game)
	if id < 0: return true
	var rounds := 2 if game.survivors[id].weapon().has("magazine") else 0
	if not shift.is_empty() or game.expansion.ammo < rounds or not game.inventory.try_take({"fuel":1},"前哨轮值预留燃料"): return false
	game.expansion.ammo -= rounds
	shift = {"map":target,"actor":id,"day":game.cycle.night_day,"fuel":1,"ammo":rounds}
	return true

func shift_risk(actor: Survivor,id: String,settled: bool = false) -> int:
	var r: Dictionary = regions[id]
	var fatigue := maxf(0,actor.fatigue-45) if settled else minf(100,actor.fatigue+45)-45
	var burden := maxf(0,fatigue-30)*.25+(100-actor.health)*.2+actor.injury*.15+actor.illness*.1
	return clampi(roundi(float(r["heat"])*.55+(100-float(r["condition"]))*.45+burden-actor.person.level("scout")*4-(22 if actor.weapon().has("magazine") else 12 if not actor.weapon().is_empty() else 0)),0,90)

func shift_yield(actor: Survivor,id: String) -> Dictionary:
	var result: Dictionary = YIELDS[id].duplicate()
	var persona := actor.person.persona
	if persona in ["xu","gu"] and id == "clinic": result["medicine"] += 1
	if persona == "lin" and id in ["works","depot"]: result["materials"] += 1
	if persona == "he" and id in ["street","market","residential"]: result["raw_food"] += 1
	if persona == "tang": result["water"] = int(result.get("water",0))+1
	return result

func dawn(game: Node2D,report: Array[String]) -> void:
	if last_day >= game.cycle.night_day: return
	last_day = game.cycle.night_day
	if not shift.is_empty():
		var id: String = shift["map"]
		var r: Dictionary = regions[id]
		var actor: Survivor = game.survivors[int(shift["actor"])]
		var risk := shift_risk(actor,id,true)
		var roll: int = (game.cycle.seed+game.cycle.night_day*73+LocationCatalog.ALL_IDS.find(id)*37)%100
		var success: bool = actor.health > 0 and r["built"] and r["condition"] >= 20 and roll >= risk
		if success:
			var supplies := shift_yield(actor,id)
			game.inventory.deposit(supplies,"前哨轮值回收："+LocationCatalog.area(id)["name"])
			r["secured_until"] = game.cycle.night_day+2;r["shifts"] += 1
			actor.person.gain("scout",10)
			report.append("【前哨】%s在%s完成轮值，回收%s；随后两夜保留巡查清理效果。" % [actor.display_name,LocationCatalog.area(id)["name"],ShelterInventory.describe(supplies)])
		else:
			var damage := minf(actor.health,8*(1-actor.protection()))
			actor.health = maxf(0,actor.health-damage);actor.injury = minf(100,actor.injury+6)
			if not actor.armor_item.is_empty(): actor.armor_item["durability"] = maxi(0,int(actor.armor_item["durability"])-5)
			r["condition"] = maxf(0,float(r["condition"])-8)
			if actor.health <= 0:
				var persona := actor.person.persona
				game.expansion.gear = game.expansion.gear.filter(func(item): return item["owner"] != persona)
				game.expansion.sync(game)
				report.append("【前哨】%s未能归来，本夜未回收物资；随身装备遗失，预留燃料已消耗。" % actor.display_name)
			else:
				report.append("【前哨】%s在%s遭遇尸群，生命−%.1f，本夜未回收物资；预留燃料已消耗。" % [actor.display_name,LocationCatalog.area(id)["name"],damage])
		if not actor.weapon_item.is_empty(): actor.weapon_item["durability"] = maxi(0,int(actor.weapon_item["durability"])-(1 if int(shift["ammo"]) > 0 else 2))
		if int(shift["ammo"]) > 0: report.append("【前哨】轮值预留弹药2已消耗；枪械磨损1，枪声增加街区压力。")
		actor.person.stress = minf(100,actor.person.stress+(3 if success else 8))
		r["condition"] = maxf(0,float(r["condition"])-14)
		r["heat"] = minf(100,float(r["heat"])+(5 if actor.person.persona == "chen" else 9)+(4 if int(shift["ammo"]) > 0 else 0))
		shift.clear()
	for id in regions:
		var r: Dictionary = regions[id]
		r["heat"] = maxf(0,float(r["heat"])-2)
		if r["built"]: r["condition"] = maxf(0,float(r["condition"])-2)

func snapshot() -> Dictionary:
	return {"regions":regions.duplicate(true),"target":target,"work":work.duplicate(),"shift":shift.duplicate(),"last_day":last_day,"trip_map":trip_map,"trip_dead":trip_dead,"alert":alert}

func restore(data: Dictionary,game: Node2D) -> void:
	var source := DistrictSystem.new().snapshot() if data.is_empty() else data
	regions = source["regions"].duplicate(true);target = source["target"]
	work = source["work"].duplicate();shift = source["shift"].duplicate()
	last_day = int(source["last_day"]);trip_map = source["trip_map"];trip_dead = int(source["trip_dead"]);alert = float(source["alert"])
	if data.is_empty() and game.expedition.active:
		trip_map = game.expedition.location_id;trip_dead = game.expedition.enemies.filter(func(e): return e["hp"] <= 0).size()
	sync(game)

static func validate(data: Variant,world: Dictionary) -> String:
	if data is Dictionary and data.is_empty(): return "" if world["campaign"].is_empty() else "缺少街区经营记录"
	if world["campaign"].is_empty() or not CharacterState.keys(data,DistrictSystem.new().snapshot().keys()): return "街区经营字段无效"
	if not CharacterState.keys(data["regions"],LocationCatalog.ALL_IDS) or not data["target"] in LocationCatalog.ALL_IDS: return "街区记录或轮值目标无效"
	var day := ExpeditionState.day_at(float(world["simulation_time"]))
	for id in LocationCatalog.ALL_IDS:
		var r: Variant = data["regions"][id]
		if not CharacterState.keys(r,["heat","built","condition","secured_until","shifts"]) or not r["built"] is bool: return "前哨字段无效"
		if not CharacterState.number(r["heat"],0,100) or not CharacterState.number(r["condition"],0,100) or not CharacterState.integer(r["secured_until"],0,day+2) or not CharacterState.integer(r["shifts"],0,day): return "前哨数值无效"
		if not r["built"] and (r["condition"] != 0 or r["secured_until"] != 0 or r["shifts"] != 0): return "未建成前哨保留经营效果"
	if not CharacterState.integer(data["last_day"],0,day) or not CharacterState.number(data["alert"],0,12) or not CharacterState.integer(data["trip_dead"],0,6): return "街区时钟或压力无效"
	if not data["trip_map"] is String: return "街区外出编号无效"
	var f: Dictionary = world["expedition"]
	if f["active"]:
		if data["trip_map"] != world["destination"] or data["trip_dead"] > f["enemies"].size(): return "街区外出记录不匹配"
	elif data["trip_map"] != "" or data["trip_dead"] != 0: return "未外出保留街区随身记录"
	if not data["work"] is Dictionary or not data["shift"] is Dictionary: return "前哨工作记录无效"
	var w: Dictionary = data["work"]
	if not w.is_empty():
		if not CharacterState.keys(w,["map","actor","action","elapsed","health"]) or not w["action"] in COSTS: return "前哨施工字段无效"
		if not f["active"] or world["campaign"]["phase"] != "scavenge" or w["map"] != world["destination"] or w["actor"] != f["actor_id"] or f["climb_target"] != -1: return "前哨施工不在活动现场"
		if not CharacterState.number(w["elapsed"],0,SECONDS[w["action"]]) or w["elapsed"] >= SECONDS[w["action"]] or not CharacterState.number(w["health"],0,100): return "前哨施工进度无效"
		var point: Dictionary = LocationCatalog.area(w["map"])["sites"][POINTS[w["map"]]]
		if point["floor"] != f["floor"] or absf(float(point["x"])-float(f["player_x"])) >= ExpeditionState.INTERACTION_RADIUS: return "前哨施工距离无效"
		for key in COSTS[w["action"]]:
			if f["bag"][key] < COSTS[w["action"]][key]: return "前哨施工缺少实物"
		var r: Dictionary = data["regions"][w["map"]]
		if (w["action"] == "build" and r["built"]) or (w["action"] == "repair" and not r["built"]): return "前哨施工与状态不符"
	var s: Dictionary = data["shift"]
	if not s.is_empty():
		if not CharacterState.keys(s,["map","actor","day","fuel","ammo"]) or not s["map"] in LocationCatalog.ALL_IDS or not CharacterState.integer(s["actor"],0,world["actors"].size()-1) or s["fuel"] != 1: return "前哨轮值字段无效"
		if not CharacterState.integer(s["ammo"],0,2) or not int(s["ammo"]) in [0,2]: return "轮值预留弹药无效"
		var expected_rounds := 0
		var persona: String = world["actors"][int(s["actor"])]["person"]["persona"]
		for item: Dictionary in world["expansion"]["gear"]:
			if item["owner"] == persona and item["durability"] > 0 and GearCatalog.ITEMS[item["kind"]].has("magazine"): expected_rounds = 2
		if s["ammo"] != expected_rounds or s["map"] != data["target"]: return "轮值装备或目的地与预留不符"
		if not world["campaign"]["phase"] in ["scavenge","returning"] or s["day"] != world["campaign"]["night_day"] or world["campaign"]["roles"][int(s["actor"])] != "outpost" or not data["regions"][s["map"]]["built"]: return "前哨轮值与岗位不符"
	elif world["campaign"]["phase"] in ["scavenge","returning"] and world["campaign"]["roles"].has("outpost"): return "前哨轮值未预留燃料"
	return ""
