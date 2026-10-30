class_name WorkshopProduction
extends RefCounted
## Production plans dispatch one paid physical job at a time. Manual orders win.
const KINDS := ["craft","toolkit","lockpick"]
const NAMES := {"craft":"机械零件","toolkit":"工具包","lockpick":"简易开锁器"}
const CACHES := {
	"works_tools":{"map":"works","site":1,"durability":70},
	"depot_tools":{"map":"depot","site":3,"durability":55},
	"waterworks_tools":{"map":"waterworks","site":2,"durability":65},
}
var condition := 100
var orders: Array[Dictionary] = []
var recovered: Array[String] = []
var carried: Array[String] = []
var dispatching := false
var ending_day := false

func rate() -> float:
	return .65 if condition==0 else .85 if condition<=20 else 1.0

func wear(kind: String) -> void:
	if kind=="service_tools":condition=mini(100,condition+60);return
	condition=maxi(0,condition-(2 if kind in ["craft","ammo","repair"] else 4))

func plan(game: Node2D,kind: String,mode: String,amount: int,actor_id: int) -> bool:
	if not kind in KINDS or not mode in ["batch","stock"] or amount<1 or amount>20 or game.cycle.phase!="day" or game.game_over or actor_id<0 or actor_id>=game.survivors.size() or game.survivors[actor_id].health<=0:return false
	remove(game,kind)
	orders.append({"kind":kind,"mode":mode,"amount":amount,"actor":game.survivors[actor_id].person.persona,"active":false,"paused":false})
	return true

func actor_for(game: Node2D,row: Dictionary) -> Survivor:
	for actor:Survivor in game.survivors:
		if actor.person.persona==row["actor"]:return actor
	return null

func stock(game: Node2D,kind: String) -> int:
	if kind=="craft":return game.inventory.amount("tools")
	return game.expansion.gear.filter(func(item):return item["kind"]==kind and item["owner"]=="" and item["durability"]>0).size()

func in_flight(game: Node2D,kind: String) -> int:
	if kind=="craft":return game.survivors.filter(func(actor):return actor.orders.has("craft")).size()
	return game.expansion.jobs.filter(func(job):return job["kind"]==kind).size()

func status(game: Node2D,row: Dictionary) -> String:
	var actor:=actor_for(game,row)
	if actor==null or actor.health<=0:return "工人无法工作"
	if row["paused"]:return "完成本件后暂停" if row["active"] else "已暂停"
	if row["active"]:return "正在生产"
	if game.cycle.phase!="day":return "等待白天"
	if row["mode"]=="stock" and stock(game,row["kind"])+in_flight(game,row["kind"])>=row["amount"]:return "库存充足"
	if actor.hunger>=65 or actor.person.thirst>=65 or actor.fatigue>=70 or actor.health<=30:return "等待工人恢复"
	if actor.state!=Survivor.TaskState.IDLE or not actor.orders.is_empty() or not actor.route.is_empty() or actor.manual_walking or game._external_busy(actor.survivor_id):return "等待工人空闲"
	var cost:Dictionary=TaskCatalog.TASKS["craft"]["cost"] if row["kind"]=="craft" else GearCatalog.ITEMS[row["kind"]]["cost"]
	if not game.inventory.can_take(cost):return "缺料："+game.inventory.missing_text(cost)
	if row["kind"]!="craft" and game.expansion.gear.size()>=300:return "装备仓库已满"
	return "等待开工"

func tick(game: Node2D) -> void:
	if game.cycle.phase!="day" or game.game_over:return
	for row in orders.duplicate():
		if row["active"] or status(game,row)!="等待开工":continue
		var actor:=actor_for(game,row)
		# Let urgent self care and other work finish, and never hold materials
		# while another user of this station is still working or approaching it.
		if game.facility.occupant_id>=0 or not game.facility.waiting_ids.is_empty() or game.expansion.jobs.any(func(job):return FacilitySystem.station_for(job["kind"])=="workbench") or game.camp.reserves("workbench"):continue
		dispatching=true
		var accepted:bool=game.scheduler.submit(actor,"craft") if row["kind"]=="craft" else game.expansion.start_job(game,row["kind"],-1,actor.survivor_id)
		dispatching=false
		row["active"]=accepted
		if accepted:break

func finished(game: Node2D,actor_id: int,kind: String) -> void:
	if kind in ["craft","repair"] or (not TaskCatalog.TASKS.has(kind) and FacilitySystem.station_for(kind)=="workbench"):wear(kind)
	for row in orders.duplicate():
		if row["active"] and row["kind"]==kind and row["actor"]==game.survivors[actor_id].person.persona:
			row["active"]=false
			if row["mode"]=="batch":
				row["amount"]-=1
				if row["amount"]==0:orders.erase(row)

func interrupt(game: Node2D,actor_id: int,preserve_current: bool=false) -> void:
	if dispatching:return
	for row in orders:
		if row["actor"]!=game.survivors[actor_id].person.persona:continue
		if not (preserve_current and row["kind"]=="craft" and not game.survivors[actor_id].orders.is_empty() and game.survivors[actor_id].orders[0]=="craft"):row["active"]=false
		if not ending_day:row["paused"]=true

func stop_active(game: Node2D,row: Dictionary) -> void:
	if not row["active"]:return
	var actor:=actor_for(game,row)
	row["active"]=false
	if actor==null:return
	var followups:Array=actor.orders.slice(1) if row["kind"]=="craft" and not actor.orders.is_empty() and actor.orders[0]=="craft" else []
	dispatching=true
	game.expansion.cancel(game,actor.survivor_id)
	game.scheduler.cancel(actor)
	for task in followups:game.scheduler.submit(actor,task)
	dispatching=false

func remove(game: Node2D,kind: String) -> void:
	for row in orders.duplicate():
		if row["kind"]==kind:stop_active(game,row);orders.erase(row)

func toggle(game: Node2D,kind: String) -> void:
	for row in orders:
		if row["kind"]!=kind:continue
		if not row["paused"]:stop_active(game,row)
		row["paused"]=not row["paused"]

func sync(game: Node2D) -> void:
	for field:ExpeditionState in game.regions.values():field.tool_sites.clear()
	for key in CACHES:
		var cache:Dictionary=CACHES[key]
		if not recovered.has(key) and not carried.has(key):
			game.regions[cache["map"]].tool_sites.append(int(cache["site"]))
			if not game.regions[cache["map"]].special_sites.has(int(cache["site"])):game.regions[cache["map"]].special_sites.append(int(cache["site"]))

func cache_entries(game: Node2D) -> Array[Dictionary]:
	var entries:Array[Dictionary]=[]
	for key in CACHES:
		var cache:Dictionary=CACHES[key]
		if cache["map"]==game.expedition.location_id and cache["site"]==game.expedition.loot_site and not recovered.has(key) and not carried.has(key):entries.append(cache_entry(key))
	return entries

func cargo_entries() -> Array[Dictionary]:
	var entries:Array[Dictionary]=[]
	for key in carried:entries.append(cache_entry(key))
	return entries

static func cache_entry(key: String) -> Dictionary:
	return {"kind":"tool_cache","key":"toolkit","cache":key,"count":1,"limit":1,"durability":CACHES[key]["durability"]}

func transfer(game: Node2D,key: String,put: bool=false) -> bool:
	var field:ExpeditionState=game.expedition
	if not CACHES.has(key) or not field.active or game.departure_dialog.visible or field.loot_site<0 or not field.discovered.has(field.loot_site) or field.nearby_site()!=field.loot_site:return false
	var cache:Dictionary=CACHES[key]
	if cache["map"]!=field.location_id or cache["site"]!=field.loot_site or recovered.has(key):return false
	if put:
		if not carried.has(key):return false
		carried.erase(key)
	else:
		if carried.has(key) or field.used_capacity()>=field.capacity or game.expansion.gear.size()+carried.size()>=300:return false
		carried.append(key)
	game.expansion.sync(game)
	game.expansion.refresh_slots(field,game.survivors[field.actor_id])
	return true

func returned(game: Node2D,survived: bool) -> void:
	for key in carried:
		# A lost pack cannot duplicate a cache on the next expedition.
		recovered.append(key)
		if survived and game.expansion.gear.size()<300:
			game.expansion.grant("toolkit")
			game.expansion.gear[-1]["durability"]=int(CACHES[key]["durability"])
	carried.clear()

func snapshot() -> Dictionary:
	return {"condition":condition,"orders":orders.duplicate(true),"recovered":recovered.duplicate(),"carried":carried.duplicate()}

func restore(data: Dictionary) -> void:
	condition=int(data.get("condition",100));orders.clear();recovered.clear();carried.clear()
	for row in data.get("orders",[]):orders.append(row.duplicate(true))
	for key in data.get("recovered",[]):recovered.append(key)
	for key in data.get("carried",[]):carried.append(key)

static func validate(data: Variant,world: Dictionary) -> String:
	if data is Dictionary and data.is_empty():return "" if world["campaign"].is_empty() else "缺少生产计划记录"
	if world["campaign"].is_empty() or not CharacterState.keys(data,["condition","orders","recovered","carried"]) or not CharacterState.integer(data["condition"],0,100) or not data["orders"] is Array or data["orders"].size()>3:return "生产计划或工具状态无效"
	for name in ["recovered","carried"]:
		if not data[name] is Array or data[name].size()>CACHES.size():return "回收工具记录无效"
		var seen:Array=[]
		for key in data[name]:
			if not CACHES.has(key) or seen.has(key):return "回收工具重复或未知"
			seen.append(key)
	for key in data["carried"]:
		if data["recovered"].has(key) or not world["expedition"]["active"] or CACHES[key]["map"]!=world["destination"] or not world["expedition"]["discovered"].has(int(CACHES[key]["site"])):return "随身工具来源无效"
	if data["carried"].size()+world["expansion"]["gear"].size()>300:return "携带工具超出装备仓库上限"
	var kinds:Array=[]
	var active_actors:Array=[]
	for row in data["orders"]:
		if not CharacterState.keys(row,["kind","mode","amount","actor","active","paused"]) or not row["kind"] in KINDS or kinds.has(row["kind"]) or not row["mode"] in ["batch","stock"] or not CharacterState.integer(row["amount"],1,20) or not row["active"] is bool or not row["paused"] is bool:return "生产订单字段无效"
		kinds.append(row["kind"])
		var index:int=world["actors"].find_custom(func(actor):return actor["person"]["persona"]==row["actor"])
		if index<0:return "生产工人无效"
		if row["active"]:
			if (row["paused"] and row["kind"]!="craft") or active_actors.has(index) or world["campaign"]["phase"]!="day" or world["actors"][index]["health"]<=0:return "生产工人重复或状态不符"
			active_actors.append(index)
			if row["kind"]=="craft":
				if world["actors"][index]["orders"].is_empty() or world["actors"][index]["orders"][0]!="craft":return "零件订单缺少实际任务"
			elif not world["expansion"]["jobs"].any(func(job):return job["actor"]==index and job["kind"]==row["kind"]):return "装备订单缺少实际任务"
	return ""

static func cargo_slots(data: Variant) -> int:
	return data["carried"].size() if data is Dictionary and data.get("carried") is Array else 0
