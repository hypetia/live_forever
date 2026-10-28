class_name SelfCareSystem
extends RefCounted
signal cooperation_completed(kind: String,actor_id: int,target_id: int)
## Campaign-only basic autonomy. Uses the same walking, queues and paid tasks
## as player commands; it never runs during night settlement or offline time.
const MANUAL_GRACE := 8.0
const NEEDS := {"drink": 65.0, "eat": 65.0, "sleep": 70.0}
var members: Dictionary = {}
var notices: Dictionary = {}
var suspended := false

func sync(game: Node2D) -> void:
	for actor: Survivor in game.survivors:
		var id := actor.person.persona
		if not members.has(id): members[id] = {"enabled": actor.health > 0, "manual_until": 0.0, "action": "", "resting": false,"shared_cooking":false,"medical":false,"aid":{}}
		for key in ["shared_cooking","medical"]:
			if not members[id].has(key): members[id][key] = false
		if not members[id].has("aid"): members[id]["aid"] = {}
		if actor.health <= 0:
			members[id]["enabled"] = false;members[id]["action"] = "";members[id]["resting"] = false;members[id]["aid"].clear()
		actor.self_care_kind = str(members[id]["action"])
		if not members[id]["enabled"]: actor.self_care_wait = ""

func enabled(actor: Survivor) -> bool:
	return members.get(actor.person.persona,{}).get("enabled",true) and actor.health > 0

func set_enabled(game: Node2D, actor: Survivor, value: bool) -> void:
	sync(game)
	if not value and not members[actor.person.persona]["action"].is_empty():
		game._cancel_external(actor.survivor_id)
		game.scheduler.cancel(actor)
	members[actor.person.persona]["enabled"] = value and actor.health > 0
	if not value: members[actor.person.persona]["resting"] = false
	actor.self_care_wait = ""

func manual(game: Node2D, id: int) -> void:
	sync(game)
	var actor: Survivor = game.survivors[id]
	var record: Dictionary = members[actor.person.persona]
	if not record["aid"].is_empty(): _stop_aid(game,actor,record)
	record["action"] = "";record["resting"] = false
	record["manual_until"] = game.simulation_time + MANUAL_GRACE
	actor.self_care_kind = "";actor.self_care_wait = ""
	notices.erase(actor.person.persona)

func finished(game: Node2D, id: int, task: String) -> void:
	var actor: Survivor = game.survivors[id]
	if not members.has(actor.person.persona): return
	var record: Dictionary = members[actor.person.persona]
	if task == "cook" and record["action"] == "cook_shared":
		cooperation_completed.emit("cook",id,-1)
		record["action"] = "";actor.self_care_kind = "";return
	if task == "cook" and record["action"] == "cook_eat": return
	if (task == "eat" and record["action"] in ["eat","cook_eat"]) or task == record["action"]:
		if task == "sleep": record["resting"] = actor.fatigue > 15
		record["action"] = "";actor.self_care_kind = ""

func failed(game: Node2D, id: int) -> void:
	var actor: Survivor = game.survivors[id]
	if members.get(actor.person.persona,{}).get("action","").is_empty(): return
	game.scheduler.cancel(actor)
	manual(game,id)

func maintain(game: Node2D) -> void:
	sync(game)
	for actor: Survivor in game.survivors:
		var record: Dictionary = members[actor.person.persona]
		if record["action"] in ["cook_shared","aid"] or (record["action"] == "cook_eat" and actor.person.thirst >= 95):
			if actor.person.thirst >= 90 or (record["action"] == "aid" and actor.hunger >= 90):
				game._cancel_external(actor.survivor_id);game.scheduler.cancel(actor);record["manual_until"] = 0.0
			continue
		if record["action"] != "sleep": continue
		if actor.hunger >= 90 or actor.person.thirst >= 90:
			game._cancel_external(actor.survivor_id)
			game.scheduler.cancel(actor)
			record["manual_until"] = 0.0
			record["resting"] = actor.fatigue > 15
		elif actor.fatigue <= 15 and actor.state == Survivor.TaskState.WORKING and actor.orders == ["sleep"]:
			# Stop a self-chosen nap once rested; manual sleep keeps its duration.
			game.scheduler._finish(actor)

func plan(game: Node2D) -> void:
	sync(game)
	if suspended or game._settling or game.cycle.phase != "day" or game.paused or game.game_over: return
	var actors: Array = game.survivors.duplicate()
	actors.sort_custom(func(a: Survivor,b: Survivor): return urgency(a) > urgency(b) if not is_equal_approx(urgency(a),urgency(b)) else a.survivor_id < b.survivor_id)
	for actor: Survivor in actors:
		var record: Dictionary = members[actor.person.persona]
		if not enabled(actor) or game.simulation_time < record["manual_until"] or not record["action"].is_empty(): continue
		if actor.state != Survivor.TaskState.IDLE or not actor.orders.is_empty() or not actor.route.is_empty() or actor.manual_walking or game._external_busy(actor.survivor_id): continue
		var needs: Array[String] = []
		for kind: String in NEEDS:
			if deficit(actor,kind) >= NEEDS[kind] or (kind == "sleep" and record["resting"] and actor.fatigue > 15): needs.append(kind)
		needs.sort_custom(func(a: String,b: String): return NEEDS.keys().find(a) < NEEDS.keys().find(b) if is_equal_approx(severity(actor,a),severity(actor,b)) else severity(actor,a) > severity(actor,b))
		actor.self_care_wait = ""
		var reason := ""
		for kind in needs:
			var result := _try_need(game,actor,kind)
			if result.is_empty():
				reason = "";notices.erase(actor.person.persona);break
			if reason.is_empty(): reason = result
		if not reason.is_empty():
			actor.self_care_wait = reason;actor.feedback = reason
			if notices.get(actor.person.persona,"") != reason:
				notices[actor.person.persona] = reason
				game._log("%s自理等待：%s。" % [actor.display_name,reason])
		elif needs.is_empty(): notices.erase(actor.person.persona)
	_plan_support(game)

func _try_need(game: Node2D, actor: Survivor, kind: String) -> String:
	var record: Dictionary = members[actor.person.persona]
	if kind == "drink":
		if available(game,"water") < 1: return "等待饮用水"
		if game.cycle.actions.any(func(a): return a["kind"] == "drink"): return "等待水桶空闲"
		if not game._start_action("drink",-1,game.water_store.position,actor.survivor_id,true): return "饮水路线不通"
	elif kind == "eat":
		if available(game,"meals") > 0:
			if game.scheduler.navigation.route_between(actor.position,game.dining_table.work_position()).is_empty(): return "餐桌路线不通"
			if not game.scheduler.submit(actor,"eat"): return "等待熟食"
		elif actor.person.routine:
			if game.survivors.any(func(a): return a.orders.has("cook")): return "等待饭菜出锅"
			for resource in TaskCatalog.TASKS["cook"]["cost"]:
				if available(game,resource) < TaskCatalog.TASKS["cook"]["cost"][resource]: return "做饭缺少"+ShelterInventory.NAMES[resource]
			if game.scheduler.navigation.route_between(actor.position,game.stove.work_position()).is_empty(): return "灶台路线不通"
			if not game.scheduler.submit(actor,"cook"): return "等待灶台"
			game.scheduler.submit(actor,"eat")
			kind = "cook_eat"
		else: return "等待熟食"
	else:
		# An emergency already interrupts a self-chosen nap. Do not start the
		# same nap again while the missing provision or busy bucket persists.
		if actor.person.thirst >= 90 or actor.hunger >= 90: return "先处理饥渴"
		var best_slot := -2
		var best_distance := INF
		var blocked := false
		var candidates: Array = [{"slot":-1,"point":game.bed.work_position()}]
		for build in game.cycle.builds:
			if build["type"] == "bed" and build["state"] == "complete": candidates.append({"slot":int(build["slot"]),"point":CampaignCycle.SLOTS[build["slot"]]})
		for candidate in candidates:
			var slot: int = candidate["slot"]
			if slot == -1 and (game.bed.occupant_id >= 0 or not game.bed.waiting_ids.is_empty()): continue
			if slot >= 0 and game.cycle.actions.any(func(a): return a["kind"] == "sleep" and a["slot"] == slot): continue
			var route: Array[Vector2] = game.scheduler.navigation.route_between(actor.position,candidate["point"])
			if route.is_empty(): blocked = true;continue
			var distance := 0.0;var previous := actor.position
			for point in route: distance += previous.distance_to(point);previous = point
			if distance < best_distance: best_distance = distance;best_slot = slot
		if best_slot == -2: return "床位路线不通" if blocked else "等待空床"
		if best_slot == -1:
			if not game.scheduler.submit(actor,"sleep"): return "等待空床"
		elif not game._start_action("sleep",best_slot,CampaignCycle.SLOTS[best_slot],actor.survivor_id,true): return "床位路线不通"
		record["resting"] = true
	record["action"] = kind;actor.self_care_kind = kind;actor.self_care_wait = ""
	return ""

static func available(game: Node2D, resource: String) -> int:
	var amount: int = game.inventory.amount(resource)
	for actor: Survivor in game.survivors:
		for index in range(actor.orders.size()):
			if index == 0 and actor.state == Survivor.TaskState.WORKING: continue
			amount -= int(TaskCatalog.TASKS[actor.orders[index]]["cost"].get(resource,0))
	if resource == "water": amount -= game.cycle.actions.filter(func(a): return a["kind"] == "drink").size()
	return maxi(0,amount)

static func deficit(actor: Survivor, kind: String) -> float:
	return actor.person.thirst if kind == "drink" else actor.hunger if kind == "eat" else actor.fatigue

static func severity(actor: Survivor, kind: String) -> float:
	return (deficit(actor,kind)-NEEDS[kind])/(100.0-NEEDS[kind])

static func urgency(actor: Survivor) -> float:
	return maxf(severity(actor,"drink"),maxf(severity(actor,"eat"),severity(actor,"sleep")))

func summary(actor: Survivor) -> String:
	return "基本自理%s · 缺饭自动做饭%s\n%s" % ["开启" if enabled(actor) else "关闭","开启" if actor.person.routine else "关闭",actor.status_text() if not actor.self_care_kind.is_empty() else actor.self_care_wait if not actor.self_care_wait.is_empty() else "空闲时自行满足需要；手动任务优先"]

func snapshot(game: Node2D) -> Dictionary:
	sync(game)
	return {"members":members.duplicate(true)}

func restore(data: Dictionary, game: Node2D) -> void:
	members = data["members"].duplicate(true) if not data.is_empty() else {}
	suspended = false
	notices.clear()
	for actor: Survivor in game.survivors: actor.self_care_wait = ""
	sync(game)

static func validate(data: Variant, world: Dictionary) -> String:
	if world["campaign"].is_empty(): return "" if data is Dictionary and data.is_empty() else "基础场景不含自主记录"
	if not CharacterState.keys(data,["members"]) or not data["members"] is Dictionary or data["members"].size() != world["actors"].size(): return "自主角色数量无效"
	var patients: Array = []
	for actor in world["actors"]:
		var id: String = actor["person"]["persona"]
		if not data["members"].has(id): return "缺少自主角色记录"
		var record: Variant = data["members"][id]
		if not CharacterState.keys(record,["enabled","manual_until","action","resting","shared_cooking","medical","aid"]) or not record["enabled"] is bool or not record["resting"] is bool or not record["action"] in ["","eat","drink","sleep","cook_eat","cook_shared","aid"]: return "自主记录字段无效"
		if not record["shared_cooking"] is bool or not record["medical"] is bool or not record["aid"] is Dictionary: return "同伴协作设置无效"
		if not CharacterState.number(record["manual_until"],0,world["simulation_time"]+MANUAL_GRACE+.001): return "自主让行时间无效"
		if actor["health"] <= 0 and (record["enabled"] or not record["action"].is_empty() or record["resting"]): return "已故角色仍在自理"
		if (record["action"] == "aid") != (not record["aid"].is_empty()): return "医护行动归属无效"
		if record["action"].is_empty(): continue
		if not record["enabled"] or world["campaign"]["phase"] != "day": return "自主行动与阶段不符"
		if record["action"] == "aid":
			var job: Dictionary = record["aid"]
			if not record["medical"] or PeopleCatalog.DATA[id]["role"] != "医护" or not CharacterState.keys(job,["target","elapsed","health"]) or not CharacterState.integer(job["target"],0,world["actors"].size()-1) or int(job["target"]) == actor["id"] or not CharacterState.number(job["elapsed"],0,4-.00000001) or not CharacterState.number(job["health"],0,100) or not actor["orders"].is_empty() or not int(actor["state"]) in [Survivor.TaskState.IDLE,Survivor.TaskState.RETURNING] or world["actors"][int(job["target"])]["health"]<=0: return "医护现场计划无效"
			if patients.has(int(job["target"])): return "同一伤员被重复安排护理"
			patients.append(int(job["target"]))
		elif record["action"] == "cook_shared":
			if not record["shared_cooking"] or actor["orders"] != ["cook"]: return "共享备餐计划无效"
		elif record["action"] == "drink":
			if not world["campaign"]["actions"].any(func(a): return a["actor"] == actor["id"] and a["kind"] == "drink"): return "自主饮水缺少现场行动"
		elif record["action"] == "sleep":
			if actor["orders"] != ["sleep"] and not world["campaign"]["actions"].any(func(a): return a["actor"] == actor["id"] and a["kind"] == "sleep"): return "自主休息缺少床位"
		elif not (actor["orders"] == ["eat"] or (record["action"] == "cook_eat" and actor["orders"] == ["cook","eat"])): return "自主进食与任务不符"
	return ""

func busy(game: Node2D,id: int) -> bool:
	return not members.get(game.survivors[id].person.persona,{}).get("aid",{}).is_empty()

func set_cooperation(game: Node2D,actor: Survivor,key: String,value: bool) -> void:
	if not key in ["shared_cooking","medical"] or game.cycle.phase != "day": return
	sync(game)
	var record: Dictionary = members[actor.person.persona]
	record[key] = value and actor.health>0 and (key!="medical" or actor.speciality=="医护")
	if not value and ((key=="medical" and record["action"]=="aid") or (key=="shared_cooking" and record["action"]=="cook_shared")):
		game._cancel_external(actor.survivor_id);game.scheduler.cancel(actor)

func _idle(game: Node2D,actor: Survivor) -> bool:
	var record: Dictionary = members[actor.person.persona]
	return enabled(actor) and game.simulation_time>=record["manual_until"] and record["action"].is_empty() and actor.state==Survivor.TaskState.IDLE and actor.orders.is_empty() and actor.route.is_empty() and not actor.manual_walking and not game._external_busy(actor.survivor_id)

func _plan_support(game: Node2D) -> void:
	var helpers: Array = game.survivors.duplicate()
	helpers.sort_custom(func(a: Survivor,b: Survivor):return int(CharacterAbilities.cooking_output(a)["meals"])>int(CharacterAbilities.cooking_output(b)["meals"]) if CharacterAbilities.cooking_output(a)["meals"]!=CharacterAbilities.cooking_output(b)["meals"] else a.survivor_id<b.survivor_id)
	for actor: Survivor in helpers:
		if not _idle(game,actor) or actor.person.thirst>=65: continue
		var record: Dictionary = members[actor.person.persona]
		if record["medical"] and actor.speciality=="医护" and actor.hunger<65 and actor.fatigue<70 and available(game,"medicine")>0:
			var target: Survivor = null;var worst:=0.0
			for patient: Survivor in game.survivors:
				if patient==actor or patient.health<=0 or not patient.route.is_empty() or patient.manual_walking or not patient.position.y in [430.0,640.0]: continue
				if not patient.orders.is_empty() and patient.orders!=["sleep"]: continue
				if game._external_busy(patient.survivor_id) and patient.activity.get("kind","")!="sleep": continue
				if members.values().any(func(m):return not m["aid"].is_empty() and int(m["aid"]["target"])==patient.survivor_id): continue
				if game.simulation_time-actor.person.last_aid<180 or game.simulation_time-patient.person.last_aid<180: continue
				if patient.health>70 and patient.injury<35 and patient.infection<25 and patient.illness<35: continue
				if patient.hunger>=80 and patient.injury<=0 and patient.infection<=0 and patient.illness<=0: continue
				var need: float = 100-patient.health+patient.infection+patient.illness+patient.injury*.5
				if patient.health<=25:need+=1000
				elif game.neighborhood.prefers(actor,patient):need+=5
				if need>worst: target=patient;worst=need
			if target!=null:
				var path: Array[Vector2] = game.scheduler.navigation.route_between(actor.position,target.position)
				if not path.is_empty():
					actor.route=path;actor.state=Survivor.TaskState.RETURNING
					record["aid"]={"target":target.survivor_id,"elapsed":0.0,"health":actor.health};record["action"]="aid";actor.self_care_kind="aid";actor.feedback="前往照护同伴"
					continue
		if not record["shared_cooking"] or available(game,"meals")>0 or game.survivors.any(func(a):return a.orders.has("cook")): continue
		if not game.survivors.any(func(a):return a.health>0 and a.hunger>=65): continue
		var enough:=true
		for key in TaskCatalog.TASKS["cook"]["cost"]:
			if available(game,key)<int(TaskCatalog.TASKS["cook"]["cost"][key]):enough=false
		if enough and not game.scheduler.navigation.route_between(actor.position,game.stove.work_position()).is_empty() and game.scheduler.submit(actor,"cook"):
			record["action"]="cook_shared";actor.self_care_kind="cook_shared";actor.feedback="为同伴备餐"

func _stop_aid(game: Node2D,actor: Survivor,record: Dictionary) -> void:
	record["aid"].clear();actor.activity.clear()
	if actor.state==Survivor.TaskState.RETURNING and actor.orders.is_empty():
		if actor.position.y in [430.0,640.0]:actor.route.clear();actor.state=Survivor.TaskState.IDLE
		else:
			var landing:=ShelterNavigation.TOP_STAIR if game.scheduler.navigation.floor_at(actor.position)==1 else ShelterNavigation.BOTTOM_STAIR
			actor.route=game.scheduler.navigation.route_between(actor.position,landing)

func tick_support(game: Node2D,delta: float) -> void:
	for actor: Survivor in game.survivors:
		var record: Dictionary = members[actor.person.persona]
		if record["aid"].is_empty():continue
		var job: Dictionary = record["aid"];var target: Survivor = game.survivors[int(job["target"])]
		if actor.health<float(job["health"]) or target.health<=0 or not target.route.is_empty() or target.manual_walking or available(game,"medicine")<1:
			_stop_aid(game,actor,record);record["action"]="";actor.self_care_kind="";record["manual_until"]=game.simulation_time+MANUAL_GRACE;continue
		if not actor.route.is_empty():continue
		if actor.position.distance_to(target.position)>56:
			_stop_aid(game,actor,record);record["action"]="";actor.self_care_kind="";record["manual_until"]=game.simulation_time+MANUAL_GRACE;continue
		job["elapsed"]=minf(4,float(job["elapsed"])+delta*actor.person.bonus("care"))
		actor.facing=1.0 if target.position.x>=actor.position.x else -1.0
		actor.activity={"kind":"aid","label":"照护同伴","progress":float(job["elapsed"])/4}
		if job["elapsed"]>=4:
			if game.people.aid_by(game,actor.survivor_id,target.survivor_id): cooperation_completed.emit("aid",actor.survivor_id,target.survivor_id)
			_stop_aid(game,actor,record);record["action"]="";actor.self_care_kind=""
