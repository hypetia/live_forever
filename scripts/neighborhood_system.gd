class_name NeighborhoodSystem
extends RefCounted
## The first persistent district: finite salvage, physical projects and sourced production.
## Off-screen changes happen only at the ordinary dawn boundary, never in wall-clock time.
const MAPS := ["clinic", "waterworks"]
const NODES := {
	"generator": {"map":"clinic", "x":1370.0, "floor":0, "name":"冷链发电机", "icon":"fuel"},
	"coldstore": {"map":"clinic", "x":1910.0, "floor":1, "name":"冷藏药品与处置台", "icon":"medicine"},
	"patient": {"map":"clinic", "x":2440.0, "floor":0, "name":"被困的同伴", "icon":"people"},
	"pump": {"map":"waterworks", "x":1850.0, "floor":0, "name":"重力供水阀组", "icon":"water"},
	"valve": {"map":"waterworks", "x":2460.0, "floor":1, "name":"街区分水控制台", "icon":"tools"},
}
const ACTIONS := {
	"restore_cold": {"node":"generator", "name":"恢复冷链", "cost":{"materials":4,"tools":1,"fuel":2}, "seconds":12.0, "hint":"燃料存入现场。每个运行的夜晚耗燃料1，抢救药品2；冷藏原药总共8份，不会再生。发电声缓慢增加当地压力。"},
	"strip_cold": {"node":"generator", "name":"拆走发电设备", "cost":{}, "yield":{"materials":6,"tools":1,"fuel":2}, "seconds":10.0, "permanent":true, "hint":"永久失去这台发电机与剩余冷藏原药；回收物必须装进背包并带回家。已抢救的药品保留。未修复设备可拆出残余油料2；运行后仅回收实际剩余燃料。"},
	"refuel": {"node":"generator", "name":"补充现场燃料", "cost":{"fuel":3}, "seconds":4.0, "hint":"背包燃料3存入现场，最多储存6份；原药耗尽后不会继续烧燃料。"},
	"take_med": {"node":"coldstore", "name":"取走已抢救药品", "cost":{}, "seconds":2.0, "hint":"按背包余量取走现场药品，尚未运回的物资不会出现在基地。"},
	"sterilize": {"node":"coldstore", "name":"配制护理用品", "cost":{"water":2,"materials":1,"fuel":1}, "yield":{"medicine":1}, "seconds":8.0, "hint":"恢复处置台且水厂向诊所供水后开放。使用背包原料配制护理用品，补充有限的药品来源。"},
	"rescue": {"node":"patient", "name":"包扎并背负救援", "cost":{"medicine":1,"water":2}, "seconds":8.0, "hint":"需要额外2格；背负时行走慢20%。活着到出口才加入队伍，途中死亡救援也失败。不会自动授权新成员消耗药品。"},
	"restore_water": {"node":"pump", "name":"修复重力供水", "cost":{"materials":5,"tools":1}, "seconds":14.0, "hint":"修复高位水池与过滤阀，每夜产清水6，现场最多储存18。无需持续燃料；普通箱子仍保持空。"},
	"strip_water": {"node":"pump", "name":"拆取阀组零件", "cost":{}, "yield":{"materials":8,"tools":2}, "seconds":12.0, "permanent":true, "hint":"永久失去此处的持续供水；零件需要占用背包带回。"},
	"take_water": {"node":"pump", "name":"装取现场清水", "cost":{}, "seconds":3.0, "hint":"只取水池中已经生产的清水，按背包容量装入。"},
	"connect": {"node":"valve", "name":"接通街区管线", "cost":{"materials":4,"tools":1}, "seconds":10.0, "hint":"之后可将部分每日产水送往基地或诊所；同一时刻只能选择一种分流方向。"},
	"route_store": {"node":"valve", "name":"全部留在水厂", "cost":{}, "seconds":2.0, "hint":"每日清水6留在现场，适合一次集中运输。"},
	"route_home": {"node":"valve", "name":"分流到基地", "cost":{}, "seconds":2.0, "hint":"正常每日清水3到基地、3留现场。管线泄漏时基地只得1。真正减少找水的重复劳动。"},
	"route_clinic": {"node":"valve", "name":"分流到诊所", "cost":{}, "seconds":2.0, "hint":"每日清水2供诊所、余量留水厂。恢复的处置台可配制护理用品；基地不再收到这条管线的水。"},
	"repair_leak": {"node":"valve", "name":"更换老化接头", "cost":{"materials":2}, "seconds":7.0, "hint":"振动预警后可提前更换；修好后这次老化隐患永久消除，不会周期性重复收费。"},
}
var enabled := true
var last_day := 0
var clinic := {"seen":false,"first_day":0,"mode":"sealed","fuel":0,"cold":8,"spoiled":0,"stock":0,"migration_day":0}
var water := {"mode":"broken","stock":0,"connected":false,"target":"store","run_days":0,"leak":0,"migration_day":0}
var rescue := {"id":"gu","state":"waiting","carrier":"","day":0}
var work: Dictionary = {}
var memories: Array[Dictionary] = []
var network_completed := false

func sync(game: Node2D) -> void:
	for id in MAPS:
		game.regions[id].persistent_loot = enabled
	for field: ExpeditionState in game.regions.values():
		field.carrying_person = enabled and rescue["state"] == "carried" and field.active
	if rescue["state"] == "waiting" and game.survivors.any(func(a):return a.person.persona==rescue["id"]):
		rescue["id"] = "tang" if rescue["id"]=="gu" and not game.survivors.any(func(a):return a.person.persona=="tang") else ""
		if rescue["id"].is_empty():rescue["state"]="safe"

func node_visible(game: Node2D, id: String) -> bool:
	if not enabled or not NODES.has(id):return false
	if id=="patient":return rescue["state"]=="waiting" and not rescue["id"].is_empty() and ExpeditionState.day_at(game.simulation_time)>=int(PeopleCatalog.DATA[rescue["id"]]["day"])
	return true

static func point(id: String) -> Vector2:
	return Vector2(float(NODES[id]["x"]),ExpeditionState.FLOOR_Y[int(NODES[id]["floor"])])

func near(game: Node2D,id: String) -> bool:
	var f: ExpeditionState=game.expedition
	return node_visible(game,id) and f.active and f.location_id==NODES[id]["map"] and f.climb_target==-1 and f.floor_level==NODES[id]["floor"] and absf(f.player_x-float(NODES[id]["x"]))<=62 and f.interior.clear_sight(f.location_id,f.player_x,float(NODES[id]["x"]),f.floor_level)

func nearby(game: Node2D) -> String:
	for id in NODES:
		if near(game,id):return id
	return ""

func hit(game: Node2D,p: Vector2) -> String:
	for id in NODES:
		if NODES[id]["map"]==game.expedition.location_id and node_visible(game,id) and Rect2(point(id)+Vector2(-35,-99),Vector2(70,108)).has_point(p) and game.expedition.interior.visible(game.expedition,float(NODES[id]["x"]),int(NODES[id]["floor"])):return id
	return ""

func begin_trip(game: Node2D) -> void:
	if not enabled:return
	sync(game)
	var f: ExpeditionState=game.expedition
	var day:=ExpeditionState.day_at(game.simulation_time)
	if f.location_id=="clinic" and not clinic["seen"]:
		clinic["seen"]=true;clinic["first_day"]=day
		game._log("诊所冷藏电源已停：从今晚起有3夜抢救期。发电机在楼下，药品在楼上；普通箱子不会补货。")
	if f.location_id in MAPS:
		var record: Dictionary=clinic if f.location_id=="clinic" else water
		if game.districts.regions[f.location_id]["heat"]>=35 and day-int(record["migration_day"])>=3:
			for index in range(f.enemies.size()):
				if f.enemies[index]["hp"]>0:continue
				var enemy: Dictionary=f.enemies[index]
				enemy["hp"]=EnemyCatalog.stats(enemy["kind"])["health"];enemy["x"]=f.right_edge(0)-12
				enemy["floor"]=0;enemy["home_floor"]=0;enemy["target_floor"]=0;enemy["target"]=enemy["x"];enemy["climb_target"]=-1;enemy["climb_progress"]=0
				enemy["min"]=float(f.area()["width"])-550;enemy["max"]=f.right_edge(0);enemy["mode"]="patrol";enemy["direction"]=-1.0;enemy["suspicion"]=0;enemy["memory"]=0;enemy["timer"]=0;enemy["cooldown"]=0;enemy["brace"]=0
				f.minds[index]=EnemyMind.make(f.location_id,index);record["migration_day"]=day
				game._log("此前的动静引来一只感染者，从街区远端迁入；已清空的物资与其他伤亡保留。")
				break

func offers(node: String) -> Array[String]:
	var out: Array[String]=[]
	for id in ACTIONS:
		if ACTIONS[id]["node"]==node:out.append(id)
	return out

func _output(game: Node2D,id: String) -> Dictionary:
	if id=="take_med":return {"medicine":mini(int(clinic["stock"]),game.expedition.room_for("medicine"))}
	if id=="take_water":return {"water":mini(int(water["stock"]),game.expedition.room_for("water"))}
	var output:Dictionary=ACTIONS[id].get("yield",{}).duplicate()
	if id=="strip_cold":output["fuel"]=2 if clinic["mode"]=="sealed" else int(clinic["fuel"])
	return output

func error(game: Node2D,id: String, continuing: bool=false) -> String:
	if not enabled or not ACTIONS.has(id):return "无此行动"
	var f: ExpeditionState=game.expedition
	if game.cycle.phase!="scavenge" or not f.active or game.game_over:return "需要在夜间亲自到场"
	if not continuing and not work.is_empty():return "当前行动尚未结束"
	if not near(game,ACTIONS[id]["node"]):return "尚未进入操作范围"
	if f.attack_windup>0 or not f.interior.action.is_empty():return "先结束当前动作"
	if id=="restore_cold" and (clinic["mode"]!="sealed" or clinic["cold"]==0):return "设备已处理，或冷藏原药已失效"
	if id=="strip_cold" and clinic["mode"]=="stripped":return "设备已拆除"
	if id=="refuel" and (clinic["mode"]!="running" or clinic["cold"]==0 or clinic["fuel"]>3):return "需要运行中的冷链、剩余原药和空油箱"
	if id=="take_med" and clinic["stock"]<=0:return "尚无已抢救的药品"
	if id=="sterilize" and (clinic["mode"]!="running" or water["mode"]!="running" or not water["connected"] or water["target"]!="clinic" or water["leak"]==2):return "需要恢复处置台及通往诊所的完好供水管线"
	if id=="rescue":
		if rescue["state"]!="waiting" or rescue["id"].is_empty():return "救援已处理"
		if game.survivors.any(func(a):return a.person.persona==rescue["id"]):return "这位成员已经在队伍中"
		if game.survivors.filter(func(a):return a.health>0).size()>=PeopleCatalog.MAX_LIVING:return "基地没有新成员名额"
	if id=="restore_water" and water["mode"]!="broken":return "阀组已处理"
	if id=="strip_water" and water["mode"]=="stripped":return "阀组已拆除"
	if id=="take_water" and water["stock"]<=0:return "水池尚无清水"
	if id=="connect" and (water["mode"]!="running" or water["connected"]):return "需要已修复且尚未接管的水厂"
	if id.begins_with("route_"):
		if water["mode"]!="running" or not water["connected"]:return "先修复水厂并接通管线"
		if water["target"]==id.trim_prefix("route_"):return "当前已经采用这一分流"
	if id=="repair_leak" and (water["mode"]!="running" or not water["leak"] in [1,2]):return "管线目前没有这项老化隐患"
	var projected: Dictionary=f.bag.duplicate()
	for key in ACTIONS[id]["cost"]:
		if int(projected[key])<int(ACTIONS[id]["cost"][key]):return "背包缺少："+ShelterInventory.describe(ACTIONS[id]["cost"])
		projected[key]-=int(ACTIONS[id]["cost"][key])
	var output:=_output(game,id)
	if id in ["take_med","take_water"] and output.values()[0]<=0:return "背包已满"
	for key in output:projected[key]+=int(output[key])
	if BackpackStacks.slots(projected)+f.extra_slots+(2 if id=="rescue" else 0)>f.capacity:return "背包空间不足，请先取舍物资"
	return ""

func start(game: Node2D,id: String) -> bool:
	var issue:=error(game,id)
	if not issue.is_empty():game.expedition.feedback=issue;return false
	game.expedition._reset_search();game.expedition._reset_route()
	game.interface.has_move_target=false;game.expedition_view.search_held=false;game.cycle.return_requested=false
	work={"id":id,"elapsed":0.0,"health":game.survivors[game.expedition.actor_id].health}
	return true

func cancel() -> void:
	work.clear()

func tick(game: Node2D,delta: float,input: Dictionary) -> Dictionary:
	if work.is_empty():return input
	var id: String=work["id"]
	var f: ExpeditionState=game.expedition
	if not error(game,id,true).is_empty() or game.survivors[f.actor_id].health<float(work["health"])-.01 or absf(float(input.get("axis",0)))>0 or int(input.get("climb",0))!=0 or bool(input.get("attack",false)):
		cancel();return input
	work["elapsed"]=float(work["elapsed"])+delta*game.survivors[f.actor_id].person.bonus("craft")
	f.noise_burst=maxf(f.noise_burst,55 if id.begins_with("strip_") else 28)
	if float(work["elapsed"])+.000001>=float(ACTIONS[id]["seconds"]):
		_complete(game,id);work.clear()
	return {"axis":0.0,"climb":0,"interact":false}

func remember(game: Node2D,kind: String,actor: String,other: String="") -> void:
	memories.append({"day":ExpeditionState.day_at(game.simulation_time),"kind":kind,"actor":actor,"other":other})
	if memories.size()>24:memories.pop_front()

func _complete(game: Node2D,id: String) -> void:
	var f: ExpeditionState=game.expedition
	var output:=_output(game,id)
	for key in ACTIONS[id]["cost"]:f.bag[key]-=int(ACTIONS[id]["cost"][key])
	for key in output:f.bag[key]+=int(output[key])
	match id:
		"restore_cold":clinic["mode"]="running";clinic["fuel"]=2
		"strip_cold":clinic["mode"]="stripped";clinic["spoiled"]+=int(clinic["cold"]);clinic["cold"]=0;clinic["fuel"]=0
		"refuel":clinic["fuel"]+=3
		"take_med":clinic["stock"]-=int(output["medicine"])
		"rescue":rescue["state"]="carried";rescue["carrier"]=game.survivors[f.actor_id].person.persona;f.carrying_person=true
		"restore_water":water["mode"]="running"
		"strip_water":water["mode"]="stripped";water["connected"]=false;water["target"]="store"
		"take_water":water["stock"]-=int(output["water"])
		"connect":water["connected"]=true
		"repair_leak":water["leak"]=3
	if id.begins_with("route_"):water["target"]=id.trim_prefix("route_")
	if id=="rescue":game.expansion.refresh_slots(f,game.survivors[f.actor_id])
	remember(game,id,game.survivors[f.actor_id].person.persona)
	game._log(ACTIONS[id]["name"]+"完成；现场变化已保留。")

func trip_return(game: Node2D,survived: bool) -> void:
	cancel()
	if rescue["state"]!="carried":return
	game.expedition.carrying_person=false
	if not survived:
		rescue["state"]="lost";remember(game,"rescue_lost",rescue["carrier"],rescue["id"]);return
	var newcomer: Survivor=game.add_survivor(rescue["id"])
	newcomer.hunger=60;newcomer.fatigue=65;newcomer.injury=25;newcomer.health=75;newcomer.person.joined_day=ExpeditionState.day_at(game.simulation_time)
	rescue["state"]="safe";rescue["day"]=ExpeditionState.day_at(game.simulation_time)
	game.cycle.roles.append("floor")
	game.people.sync_members(game.survivors);game.self_care.sync(game);game.chronicle.sync(game);game.sync_roster_cards()
	for a: Survivor in game.survivors:
		if a.person.persona==rescue["carrier"]:
			var pair:="%d:%d" % [mini(a.survivor_id,newcomer.survivor_id),maxi(a.survivor_id,newcomer.survivor_id)]
			game.people.bonds[pair]=55
	remember(game,"rescued",rescue["carrier"],rescue["id"])
	game._log(newcomer.display_name+"被背回基地；记住了救援者。需额外食物与休息，F4可授权其照护同伴。")

func prefers(actor: Survivor,target: Survivor) -> bool:
	return enabled and rescue["state"]=="safe" and actor.person.persona==rescue["id"] and target.person.persona==rescue["carrier"]

func dawn(game: Node2D,report: Array[String]) -> void:
	if not enabled or game.cycle.night_day<=last_day:return
	last_day=game.cycle.night_day
	if clinic["mode"]=="running" and clinic["fuel"]>0 and clinic["cold"]>0:
		var recovered:=mini(2,int(clinic["cold"]))
		clinic["cold"]-=recovered;clinic["stock"]+=recovered;clinic["fuel"]-=1
		game.districts.regions["clinic"]["heat"]=minf(100,float(game.districts.regions["clinic"]["heat"])+2)
		report.append("诊所消耗现场燃料1，保全药品%d，仍在楼上冷藏柜；剩余原药%d。" % [recovered,clinic["cold"]])
	elif clinic["seen"] and clinic["cold"]>0 and last_day>=int(clinic["first_day"])+2:
		clinic["spoiled"]+=int(clinic["cold"]);clinic["cold"]=0
		report.append("诊所停电超过抢救期，未保全的冷藏原药失效；普通药柜不受影响。")
	if water["mode"]=="running":
		water["run_days"]+=1
		if water["leak"]==0 and water["run_days"]>=3:
			water["leak"]=1;report.append("水厂旧接头出现振动：下一夜会开始泄漏，可先去楼上更换接头。")
		elif water["leak"]==1:
			water["leak"]=2;report.append("预警的水厂接头开始泄漏，日产水由6降至3；更换一次即可永久解决这项隐患。")
		var produced:=3 if water["leak"]==2 else 6
		if game.camp.enabled:produced=game.camp.situation.water_output(last_day,produced,true)
		var delivered:=0
		if water["connected"] and water["target"]=="home":
			delivered=mini(produced,1 if water["leak"]==2 else 3)
			game.inventory.deposit({"water":delivered},"水厂经已接通管线供水")
		elif water["connected"] and water["target"]=="clinic":delivered=mini(2,produced)
		water["stock"]=mini(18,int(water["stock"])+produced-delivered)
		report.append("水厂产水%d，%s；现场余水%d/18。" % [produced,"基地收到%d" % delivered if water["target"]=="home" and water["connected"] else "诊所收到%d" % delivered if delivered>0 else "全部留在现场",water["stock"]])
	if not network_completed and clinic["mode"]=="running" and water["mode"]=="running" and water["connected"] and water["leak"]==3:
		network_completed=true;remember(game,"network","lin");report.append("街区长期目标完成：诊所处置台与稳定供水均已恢复。可以维持生活，也可继续撤离。")

func summary(id: String) -> String:
	if not enabled or not id in MAPS:return ""
	if id=="clinic":return "冷链：%s · 原药%d / 已保全%d\n现场燃料%d · 救援：%s\n普通容器搜空后保持空；发电声会积累压力。" % [{"sealed":"停电","running":"已修复","stripped":"已拆走"}[clinic["mode"]],clinic["cold"],clinic["stock"],clinic["fuel"],{"waiting":"待现场确认","carried":"返程中","safe":"已安顿","lost":"失败"}[rescue["state"]]]
	return "供水：%s · 现场%d/18\n管线：%s · %s\n%s" % [{"broken":"待修复","running":"运行中","stripped":"已拆取"}[water["mode"]],water["stock"],{"store":"留存水厂","home":"分流基地","clinic":"分流诊所"}[water["target"]],"已接通" if water["connected"] else "未接通",{0:"修复后持续供水，降低找水负担。",1:"旧接头振动：下一夜开始泄漏。",2:"接头泄漏：更换后恢复产水。",3:"接头已更换，这项隐患已消除。"}[int(water["leak"])]]

func snapshot() -> Dictionary:
	return {"enabled":enabled,"last_day":last_day,"clinic":clinic.duplicate(),"water":water.duplicate(),"rescue":rescue.duplicate(),"work":work.duplicate(),"memories":memories.duplicate(true),"network_completed":network_completed}

func restore(data: Dictionary,game: Node2D) -> void:
	if data.is_empty():data=NeighborhoodSystem.new().snapshot()
	enabled=data["enabled"];last_day=int(data["last_day"]);clinic=data["clinic"].duplicate();water=data["water"].duplicate();rescue=data["rescue"].duplicate();work=data["work"].duplicate();network_completed=data["network_completed"]
	memories.clear()
	for m in data["memories"]:memories.append(m.duplicate())
	sync(game)

static func validate(data: Variant,world: Dictionary) -> String:
	if data is Dictionary and data.is_empty():return "" if world["campaign"].is_empty() else "街区记录缺失"
	if not CharacterState.keys(data,["enabled","last_day","clinic","water","rescue","work","memories","network_completed"]) or not data["enabled"] is bool or not data["network_completed"] is bool:return "街区记录字段无效"
	var day:=ExpeditionState.day_at(float(world["simulation_time"]))
	if not CharacterState.integer(data["last_day"],0,day):return "街区结算日期无效"
	var c: Variant=data["clinic"];var w: Variant=data["water"];var r: Variant=data["rescue"]
	if not CharacterState.keys(c,["seen","first_day","mode","fuel","cold","spoiled","stock","migration_day"]) or not c["seen"] is bool or not c["mode"] in ["sealed","running","stripped"]:return "诊所记录无效"
	for key in ["first_day","migration_day"]:
		if not CharacterState.integer(c[key],0,day):return "诊所日期无效"
	if bool(c["seen"])!=(int(c["first_day"])>0):return "诊所勘察日期不符"
	if not CharacterState.integer(c["fuel"],0,6):return "冷链燃料无效"
	for key in ["cold","spoiled","stock"]:
		if not CharacterState.integer(c[key],0,8):return "冷藏原药数量无效"
	if int(c["cold"])+int(c["spoiled"])+int(c["stock"])>8 or (c["mode"]=="stripped" and (c["cold"]!=0 or c["fuel"]!=0)):return "冷链物资不守恒"
	if not CharacterState.keys(w,["mode","stock","connected","target","run_days","leak","migration_day"]) or not w["mode"] in ["broken","running","stripped"] or not w["connected"] is bool or not w["target"] in ["store","home","clinic"]:return "供水记录无效"
	if not CharacterState.integer(w["stock"],0,18) or not CharacterState.integer(w["run_days"],0,day) or not CharacterState.integer(w["leak"],0,3) or not CharacterState.integer(w["migration_day"],0,day):return "供水数量或日期无效"
	if (w["mode"]!="running" and w["connected"]) or (not w["connected"] and w["target"]!="store"):return "未接通的分流无效"
	if not CharacterState.keys(r,["id","state","carrier","day"]) or not r["id"] in ["gu","tang",""] or not r["state"] in ["waiting","carried","safe","lost"] or not r["carrier"] in PeopleCatalog.DATA.keys()+[""] or not CharacterState.integer(r["day"],0,day):return "救援记录无效"
	var f: Dictionary=world["expedition"]
	if r["state"]=="carried":
		if not data["enabled"] or not f["active"] or world["destination"]!="clinic" or r["id"].is_empty() or world["actors"].any(func(a):return a["person"]["persona"]==r["id"]) or world["actors"][int(f["actor_id"])]["person"]["persona"]!=r["carrier"]:return "在途救援与搜刮者不符"
	if not data["work"] is Dictionary:return "街区工作无效"
	var job: Dictionary=data["work"]
	if not job.is_empty():
		if not CharacterState.keys(job,["id","elapsed","health"]) or not ACTIONS.has(job["id"]):return "街区工作字段无效"
		var action: Dictionary=ACTIONS[job["id"]];var n: Dictionary=NODES[action["node"]]
		if not data["enabled"] or not f["active"] or world["campaign"]["phase"]!="scavenge" or world["destination"]!=n["map"] or f["floor"]!=n["floor"] or f["climb_target"]!=-1 or absf(float(f["player_x"])-float(n["x"]))>62 or not CharacterState.number(job["elapsed"],0,float(action["seconds"])-.00000001) or not CharacterState.number(job["health"],.001,100):return "街区工作位置或进度无效"
		for key in action["cost"]:
			if int(f["bag"][key])<int(action["cost"][key]):return "街区工作缺少实际用料"
	if not data["memories"] is Array or data["memories"].size()>24:return "街区经历容量无效"
	var previous:=0
	for m in data["memories"]:
		if not CharacterState.keys(m,["day","kind","actor","other"]) or not CharacterState.integer(m["day"],previous,day) or not m["kind"] in ACTIONS.keys()+["rescued","rescue_lost","network"] or not m["actor"] in PeopleCatalog.DATA or not m["other"] in PeopleCatalog.DATA.keys()+[""]:return "街区经历无效"
		previous=int(m["day"])
	return ""
