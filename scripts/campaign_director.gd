class_name CampaignDirector
extends RefCounted
## Optional three-day opportunities. Enemy stats never scale to player equipment.
signal event_reported(message: String)
const CONTRACTS := {
	"survey_street":{"name":"旧街巡查回执","type":"survey","map":"street","site":3,"goal":1,"risk":"中 · 需要登上二楼并返回","reward":{"materials":2,"medicine":1},"cost":{},"hint":"打开旧街楼梯间药箱记录现场，活着带回回执。空容器也可重新查看。"},
	"survey_clinic":{"name":"诊所物资核查","type":"survey","map":"clinic","site":1,"goal":1,"risk":"中 · 留意楼梯与巡逻","reward":{"fuel":2,"medicine":1},"cost":{},"hint":"前往指定容器，打开并记录现场，活着返回。"},
	"survey_works":{"name":"机修厂路线勘查","type":"survey","map":"works","site":1,"goal":1,"risk":"中高 · 需要穿过工厂","reward":{"materials":3,"tools":1},"cost":{},"hint":"打开机修厂二楼工具台记录路线，回到避难所交回回执。"},
	"clear_street":{"name":"清理旧街入口","type":"combat","map":"street","goal":1,"risk":"中 · 需要近身战斗","reward":{"materials":3,"fuel":1},"cost":{},"hint":"在旧街击倒1只僵尸并活着返回。已经死亡的敌人不计入。"},
	"clear_works":{"name":"工厂安全通道","type":"combat","map":"works","goal":2,"risk":"高 · 建议携带长武器与护甲","reward":{"materials":4,"tools":1},"cost":{},"hint":"在机修厂击倒2只僵尸并返回，可分两晚完成。"},
	"ranged_works":{"name":"火力掩护演练","type":"ranged","map":"works","goal":3,"risk":"高 · 枪声会吸引尸群","reward":{"materials":5,"medicine":1},"cost":{},"hint":"在机修厂用手枪实际命中3次并活着返回；挥空与空枪不计。"},
	"meal_basic":{"name":"邻里应急餐食","type":"food","recipes":["cook","cook_batch","cook_stew","cook_pot"],"goal":4,"risk":"低 · 要交付自己的熟食","reward":{"water":3,"fuel":1},"cost":{"meals":4},"hint":"接取后实际做出4份熟食，再交付4份；仅持有旧库存不能完成。"},
	"meal_batch":{"name":"互助点集体热餐","type":"food","recipes":["cook_batch","cook_stew","cook_pot"],"goal":4,"risk":"低 · 使用二级厨房新配方","reward":{"tools":1,"water":3},"cost":{"meals":4},"hint":"接取后用高级配方做出4份熟食，再交付4份换取工具和饮水。"},
	"meal_pot":{"name":"集中备餐接应","type":"food","recipes":["cook_pot"],"goal":6,"risk":"低 · 使用三级厨房大锅饭","reward":{"medicine":1,"fuel":2,"materials":2},"cost":{"meals":6},"hint":"接取后用大锅烩饭做出6份熟食，再交付6份。注意给队伍留饭。"},
}
var contract := ""
var status := ""
var accepted_window := -1
var deadline := 0
var progress := 0
var trip_progress := 0
var trip_start_dead := 0
var rewards_received := 0

func window(game: Node2D) -> int:
	return (game.expansion.day(game)-1)/3

func offers(game: Node2D) -> Array[String]:
	var bench: int = game.facilities.levels["workbench"]
	var kitchen: int = game.facilities.levels["stove"]
	return [["survey_street","survey_clinic","survey_works"][window(game)%3],"ranged_works" if bench >= 3 else "clear_works" if bench >= 2 else "clear_street","meal_pot" if kitchen >= 3 else "meal_batch" if kitchen >= 2 else "meal_basic"]

func sync_day(game: Node2D) -> void:
	if status == "active" and game.expansion.day(game) > deadline and not game.expedition.active:
		status = "expired"
		trip_progress = 0
		trip_start_dead = 0
		game.expansion.sync(game)
		event_reported.emit("本轮委托已到期，未领取补给；新的街区动态已更新。")

func accept(game: Node2D, id: String) -> bool:
	sync_day(game)
	if not accept_error(game,id).is_empty(): return false
	contract = id
	status = "active"
	accepted_window = window(game)
	deadline = (accepted_window+1)*3
	progress = 0
	trip_progress = 0
	trip_start_dead = 0
	game.expansion.sync(game)
	event_reported.emit("已接取：%s；战役第%d夜结束前完成。" % [CONTRACTS[id]["name"],deadline])
	return true

func accept_error(game: Node2D, id: String) -> String:
	if not game.cycle.phase in ["day","planning"] or game.game_over: return "外出时可查看，回到营地后接取。"
	if status in ["active","ready"]: return "先完成或放弃当前委托。"
	if accepted_window == window(game): return "本轮已接取过一项，下一轮再来。"
	if not offers(game).has(id): return "本轮没有这项委托。"
	if game.cycle.phase == "planning" and CONTRACTS[id]["type"] == "food" and game.expansion.day(game) >= (window(game)+1)*3: return "已是本轮最后一夜，来不及烹饪；可选择外出委托。"
	if game.cycle.phase == "planning" and not game.residence.convoy.is_empty() and game.expansion.day(game) >= (window(game)+1)*3: return "最后一夜已安排迁居，不能同时外出；可先调整迁居计划。"
	return ""

func abandon(game: Node2D) -> bool:
	if not game.cycle.phase in ["day","planning"] or not status in ["active","ready"]: return false
	status = "abandoned"
	trip_progress = 0
	trip_start_dead = 0
	game.expansion.sync(game)
	return true

func food_cooked(game: Node2D, kind: String, count: int) -> void:
	sync_day(game)
	if status != "active": return
	var definition: Dictionary = CONTRACTS[contract]
	if definition["type"] != "food" or not definition["recipes"].has(kind): return
	progress = mini(definition["goal"],progress+count)
	_check_ready()

func begin_trip(game: Node2D) -> void:
	trip_progress = 0
	trip_start_dead = 0
	if status != "active": return
	var definition: Dictionary = CONTRACTS[contract]
	if definition["type"] == "combat" and definition["map"] == game.expedition.location_id: trip_start_dead = game.expedition.enemies.filter(func(enemy): return enemy["hp"] <= 0).size()

func observe_trip(game: Node2D) -> void:
	if status != "active" or not game.expedition.active: return
	var definition: Dictionary = CONTRACTS[contract]
	if definition.get("map","") != game.expedition.location_id: return
	if definition["type"] == "survey" and game.expedition.loot_site == definition["site"] and game.expedition.site_in_range(definition["site"]): trip_progress = 1
	elif definition["type"] == "combat": trip_progress = mini(definition["goal"],maxi(0,game.expedition.enemies.filter(func(enemy): return enemy["hp"] <= 0).size()-trip_start_dead))

func shot(game: Node2D, kind: String, damage: int) -> void:
	if status == "active" and CONTRACTS[contract]["type"] == "ranged" and game.expedition.active and game.expedition.location_id == CONTRACTS[contract]["map"] and kind == "shot" and damage > 0: trip_progress = mini(CONTRACTS[contract]["goal"],trip_progress+1)

func trip_return(game: Node2D, survived: bool) -> void:
	if status == "active" and survived and maxi(1,game.cycle.night_day-game.expansion.epoch+1) <= deadline:
		progress = mini(CONTRACTS[contract]["goal"],progress+trip_progress)
		_check_ready()
	trip_progress = 0
	trip_start_dead = 0

func _check_ready() -> void:
	if progress >= CONTRACTS[contract]["goal"]:
		status = "ready"
		event_reported.emit("委托达成：%s；按U接收补给。" % CONTRACTS[contract]["name"])

func claim(game: Node2D) -> bool:
	if status != "ready" or not game.cycle.phase in ["day","planning"] or game.game_over: return false
	var definition: Dictionary = CONTRACTS[contract]
	if not game.inventory.try_take(definition["cost"],"委托交付："+definition["name"]): return false
	status = "claimed"
	game.expansion.sync(game)
	rewards_received += 1
	game.inventory.deposit(definition["reward"],"委托接应："+definition["name"])
	event_reported.emit("收到接应补给："+ShelterInventory.describe(definition["reward"]))
	return true

func snapshot() -> Dictionary:
	return {"contract":contract,"status":status,"accepted_window":accepted_window,"deadline":deadline,"progress":progress,"trip_progress":trip_progress,"trip_start_dead":trip_start_dead,"rewards_received":rewards_received}

func restore(data: Dictionary) -> void:
	var source := CampaignDirector.new().snapshot() if data.is_empty() else data
	for key in source: set(key,int(source[key]) if key not in ["contract","status"] else source[key])

static func validate(data: Variant, world: Dictionary) -> String:
	if data is Dictionary and data.is_empty(): return "" if world["campaign"].is_empty() else "缺少街区动态记录"
	if world["campaign"].is_empty() or not CharacterState.keys(data,CampaignDirector.new().snapshot().keys()): return "街区动态字段无效"
	if not data["status"] in ["","active","ready","claimed","expired","abandoned"] or not data["contract"] is String: return "委托状态无效"
	for key in ["accepted_window","deadline","progress","trip_progress","trip_start_dead","rewards_received"]:
		if not CharacterState.integer(data[key],-1 if key == "accepted_window" else 0,10000000): return "委托进度无效"
	if data["status"] == "":
		var empty := CampaignDirector.new().snapshot()
		for key in empty:
			if data[key] != empty[key]: return "空委托保留了进度"
		return ""
	if not CONTRACTS.has(data["contract"]) or data["accepted_window"] < 0 or data["deadline"] != (data["accepted_window"]+1)*3: return "委托编号或时限无效"
	var day: int = maxi(1,ExpeditionState.day_at(world["simulation_time"])-int(world["expansion"]["epoch"])+1)
	if int(data["accepted_window"]) > (day-1)/3 or data["rewards_received"] > data["accepted_window"]+1: return "委托超出当前日期"
	var definition: Dictionary = CONTRACTS[data["contract"]]
	if data["progress"] > definition["goal"] or data["trip_progress"] > definition["goal"] or data["trip_start_dead"] > world["expedition"]["enemies"].size(): return "委托数量超出目标"
	if data["status"] in ["ready","claimed"] and data["progress"] != definition["goal"]: return "未完成委托不能领奖"
	if data["status"] == "active" and data["progress"] >= definition["goal"]: return "委托完成状态不符"
	if not world["expedition"]["active"] and (data["trip_progress"] != 0 or data["trip_start_dead"] != 0): return "未外出却保留随身回执"
	return ""
