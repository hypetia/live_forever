class_name PeopleSystem
extends RefCounted
## Small persistent roster, explicit care policy, relationships and daily ledger.

signal event_reported(message: String)
var drinks := 0
var next_routine := 0.0
var last_day := 1
var bonds: Dictionary = {}
var deaths: Array[String] = []
var daily: Array[Dictionary] = []
var spoiled := {"raw_food": 0, "meals": 0}


func sync_members(actors: Array[Survivor]) -> void:
	for left in range(actors.size()):
		for right in range(left + 1, actors.size()):
			var pair := "%d:%d" % [left, right]
			if not bonds.has(pair): bonds[pair] = 25 if right < 3 else 15


func tick(game: Node2D, delta: float) -> void:
	var day := ExpeditionState.day_at(game.simulation_time)
	if day > last_day:
		_record_day(game)
		last_day = day
		_age_surplus(game)
	for actor: Survivor in game.survivors:
		if actor.health <= 0: continue
		var person := actor.person
		person.thirst = minf(100, person.thirst + delta * 0.045 * actor.metabolism)
		if person.thirst >= 95: actor.health = maxf(0, actor.health - delta * 0.06)
		var asleep := actor.state == Survivor.TaskState.WORKING and actor.orders[0] == "sleep"
		var pressure := (1.0 if actor.hunger >= 80 else 0.0) + (0.5 if actor.fatigue >= 85 else 0.0) + (0.5 if actor.infection >= 30 or actor.injury >= 50 else 0.0)
		if person.persona == "lin" and actor.fatigue >= 85: pressure += 0.3
		if person.persona == "tang" and actor.injury > 0: pressure += 0.3
		if person.persona == "xu" and game.survivors.any(func(a): return a.health > 0 and a.health < 40): pressure += 0.2
		if actor.state == Survivor.TaskState.AWAY and game.expedition.elapsed > 120: pressure += 0.4 if person.persona == "chen" else 0.2
		if person.thirst >= 80: pressure += 0.5
		if person.trauma >= 40: pressure += 0.25 if person.trauma < 70 else 0.5
		if pressure > 0:
			person.stress = minf(100, person.stress + delta * 0.025 * pressure)
			person.morale = maxf(0, person.morale - delta * 0.01 * pressure)
		elif actor.state != Survivor.TaskState.AWAY:
			person.stress = maxf(0, person.stress - delta * (0.08 if asleep else 0.025))
			if asleep: person.morale = minf(75, person.morale + delta * 0.015)
			elif actor.hunger < 60 and actor.fatigue < 65: person.morale = move_toward(person.morale, 60, delta * 0.005)
			if actor.hunger < 70 and actor.fatigue < 75: person.trauma = maxf(0, person.trauma - delta * 0.005)
		if (person.morale < 25 or person.stress >= 80) and not person.warned:
			person.warned = true
			event_reported.emit("%s情绪吃紧：检查饮水、进食、休息或共餐安慰，低心境与高压力会影响效率。" % actor.display_name)
		elif person.morale >= 35 and person.stress < 65: person.warned = false
		if person.thirst >= 80 and not person.warned_thirst:
			person.warned_thirst = true
			event_reported.emit("%s水分不足：20以下降效，低至5缓慢损害生命。基地人物页饮水，外出用背包水按B。" % actor.display_name)
		elif person.thirst < 70: person.warned_thirst = false
	if game.simulation_time + 0.000001 >= next_routine:
		next_routine = game.simulation_time + 1.0
		_routines(game)


func _routines(game: Node2D) -> void:
	if game.has_method("plan_self_care"):
		game.plan_self_care()
		return
	for actor: Survivor in game.survivors:
		if not actor.person.routine or actor.health <= 0 or actor.state == Survivor.TaskState.AWAY: continue
		if actor.person.thirst >= 60: drink(game, actor.survivor_id)
		if actor.state != Survivor.TaskState.IDLE or not actor.orders.is_empty(): continue
		if actor.hunger >= 60:
			if game.inventory.amount("meals") > 0: game.scheduler.submit(actor, "eat")
			elif game.inventory.can_take(TaskCatalog.TASKS["cook"]["cost"]):
				game.scheduler.submit(actor, "cook")
				game.scheduler.submit(actor, "eat")
			elif actor.fatigue >= 65: game.scheduler.submit(actor, "sleep")
			else: actor.feedback = "照料等待补给：食物、水或燃料不足"
		elif actor.fatigue >= 65:
			game.scheduler.submit(actor, "sleep")


func job_completed(game: Node2D, actor_id: int, task: String) -> void:
	var actor: Survivor = game.survivors[actor_id]
	var skill := "care" if task == "heal" else "craft"
	var amount := 8.0 if task in ["craft", "heal"] else 6.0 if task == "repair" else 4.0 if task == "cook" else 0.0
	if amount > 0 and actor.person.gain(skill, amount):
		event_reported.emit("%s的%s提升至%d级。" % [actor.display_name, "照护" if skill == "care" else "工艺", actor.person.level(skill)])
	if task == "eat":
		actor.person.morale = minf(100, actor.person.morale + 2)
		actor.person.stress = maxf(0, actor.person.stress - 3)
	elif task == "heal":
		actor.person.stress = maxf(0, actor.person.stress - 10)
		actor.person.trauma = maxf(0, actor.person.trauma - 5)


func survivor_lost(game: Node2D, actor_id: int) -> void:
	var lost: Survivor = game.survivors[actor_id]
	if deaths.has(lost.person.persona): return
	deaths.append(lost.person.persona)
	lost.person.routine = false
	for actor: Survivor in game.survivors:
		if actor.health <= 0: continue
		var relation := relationship(actor_id, actor.survivor_id)
		actor.person.morale = maxf(0, actor.person.morale - 18 - (5 if relation >= 60 else 0))
		actor.person.stress = minf(100, actor.person.stress + (15 if actor.person.persona == "xu" else 25))
		actor.person.trauma = minf(100, actor.person.trauma + 10)
	event_reported.emit("队伍失去了%s。同伴需要时间、休息与照顾；这位成员不会被补员复活。" % lost.display_name)


func returned(game: Node2D, actor: Survivor, cargo: Dictionary, loadout: Dictionary, survived: bool) -> void:
	if not survived: return
	var gained := 0
	for resource in cargo: gained += maxi(0, int(cargo[resource]) - int(loadout.get(resource, 0)))
	if gained <= 0: return
	game.story.note("supplies")
	actor.person.gain("scout", 4)
	actor.person.morale = minf(100, actor.person.morale + 3)
	for other: Survivor in game.survivors:
		if other.health > 0 and other != actor:
			other.person.morale = minf(100, other.person.morale + 1)


func relationship(left: int, right: int) -> int:
	return int(bonds.get("%d:%d" % [mini(left, right), maxi(left, right)], 0))


func support(game: Node2D, target_id: int) -> bool:
	if game.expedition.active or game.game_over or target_id < 0 or target_id >= game.survivors.size() or target_id == game.selected_id: return false
	var actor: Survivor = game.survivors[game.selected_id]
	var target: Survivor = game.survivors[target_id]
	if actor.health <= 0 or target.health <= 0 or game.simulation_time - actor.person.last_support < 180 or game.simulation_time - target.person.last_support < 180: return false
	if not game.inventory.try_take({"meals": 1}, "与同伴共餐安慰"): return false
	var close := relationship(actor.survivor_id, target_id) >= 60
	for member in [actor, target]:
		member.person.morale = minf(100, member.person.morale + (15 if close else 10))
		member.person.stress = maxf(0, member.person.stress - 20)
		member.person.trauma = maxf(0, member.person.trauma - 8)
		member.person.last_support = game.simulation_time
	var pair := "%d:%d" % [mini(actor.survivor_id, target_id), maxi(actor.survivor_id, target_id)]
	bonds[pair] = mini(100, int(bonds[pair]) + 10)
	event_reported.emit("%s与%s分享了一份热食，彼此更信任了。这次安慰不代替日常进食。" % [actor.display_name, target.display_name])
	return true


func offers(game: Node2D) -> Array[String]:
	var available: Array[String] = []
	var known: Array = game.survivors.map(func(a): return a.person.persona)
	var day := ExpeditionState.day_at(game.simulation_time)
	for id in (PeopleCatalog.DATA.keys() if game.has_method("chronicle_snapshot") else PeopleCatalog.CANDIDATES):
		if not known.has(id) and day >= maxi(3,int(PeopleCatalog.DATA[id]["day"])): available.append(id)
	return available


func recruit(game: Node2D, id: String) -> bool:
	if game.expedition.active or game.game_over or game.upkeep.level < 1 or not offers(game).has(id): return false
	if game.survivors.filter(func(a): return a.health > 0).size() >= PeopleCatalog.MAX_LIVING: return false
	if not game.inventory.try_take(PeopleCatalog.RECRUIT_COST, "接纳" + PeopleCatalog.DATA[id]["name"]): return false
	var actor: Survivor = game.add_survivor(id)
	actor.hunger = 60
	actor.fatigue = 55
	actor.person.joined_day = ExpeditionState.day_at(game.simulation_time)
	sync_members(game.survivors)
	game.sync_roster_cards()
	event_reported.emit("%s加入了队伍。需要额外食物与床位时间，%s。" % [actor.display_name,"基本自理默认开启" if game.has_method("plan_self_care") else "自动照料默认关闭"])
	return true


func protected_food(game: Node2D) -> Dictionary:
	return {"raw_food": 12 + game.upkeep.level * 4, "meals": 6 + game.upkeep.level * 2}


func _age_surplus(game: Node2D) -> void:
	var protected := protected_food(game)
	for resource in ["raw_food", "meals"]:
		var extra := maxi(0, game.inventory.amount(resource) - int(protected[resource]))
		var loss := ceili(extra * (0.15 if resource == "raw_food" else 0.25))
		if loss > 0:
			game.inventory.try_take({resource: loss}, "超出保鲜容量的食物损耗")
			spoiled[resource] += loss
			event_reported.emit("清晨检查：%s超出保鲜容量，损耗%d份。M人物页可查看容量，少量现做更稳妥。" % [ShelterInventory.NAMES[resource], loss])


func _record_day(game: Node2D) -> void:
	var living: Array = game.survivors.filter(func(a): return a.health > 0)
	var hunger := 0.0
	var morale := 0.0
	for actor: Survivor in living:
		hunger += actor.hunger
		morale += actor.person.morale
	daily.append({"day": last_day, "alive": living.size(), "stock": game.inventory.snapshot(), "hunger": hunger / max(1, living.size()), "morale": morale / max(1, living.size()), "integrity": game.upkeep.integrity})
	if daily.size() > 30: daily.pop_front()


func snapshot() -> Dictionary:
	return {"drinks": drinks, "next_routine": next_routine, "last_day": last_day, "bonds": bonds.duplicate(), "deaths": deaths.duplicate(), "daily": daily.duplicate(true), "spoiled": spoiled.duplicate()}


func restore_validated(data: Dictionary) -> void:
	drinks = int(data["drinks"])
	next_routine = float(data["next_routine"])
	last_day = int(data["last_day"])
	bonds.clear()
	for pair in data["bonds"]: bonds[pair] = int(data["bonds"][pair])
	deaths.clear()
	for id in data["deaths"]: deaths.append(id)
	daily.clear()
	for entry in data["daily"]: daily.append(entry.duplicate(true))
	for resource in spoiled: spoiled[resource] = int(data["spoiled"][resource])


static func validate(data: Variant, actors: Array, seconds: float) -> String:
	if not CharacterState.keys(data, ["drinks", "next_routine", "last_day", "bonds", "deaths", "daily", "spoiled"]): return "队伍记录字段无效"
	if not CharacterState.integer(data["drinks"], 0, 100000000): return "饮水账目无效"
	var day := ExpeditionState.day_at(seconds)
	if not CharacterState.number(data["next_routine"], 0, seconds + 1.001) or not CharacterState.integer(data["last_day"], 1, day): return "照料时钟或队伍日期无效"
	var expected: Array = []
	for left in range(actors.size()):
		for right in range(left + 1, actors.size()): expected.append("%d:%d" % [left, right])
	if not CharacterState.keys(data["bonds"], expected): return "队友关系不完整"
	for amount in data["bonds"].values():
		if not CharacterState.integer(amount, 0, 100): return "队友信任数值无效"
	var lost: Array = []
	for actor in actors:
		if actor["health"] == 0: lost.append(actor["person"]["persona"])
	if not data["deaths"] is Array or data["deaths"].size() != lost.size(): return "伤亡记录不一致"
	var checked: Array = []
	for id in data["deaths"]:
		if not lost.has(id) or checked.has(id): return "伤亡记录重复或身份无效"
		checked.append(id)
	if not CharacterState.keys(data["spoiled"], ["raw_food", "meals"]): return "食物损耗账目无效"
	for amount in data["spoiled"].values():
		if not CharacterState.integer(amount, 0, 100000000): return "食物损耗数量无效"
	if not data["daily"] is Array or data["daily"].size() > 30: return "每日记录容量无效"
	var previous := 0
	for entry in data["daily"]:
		if not CharacterState.keys(entry, ["day", "alive", "stock", "hunger", "morale", "integrity"]): return "每日记录字段无效"
		if not CharacterState.integer(entry["day"], previous + 1, data["last_day"] - 1) or not CharacterState.integer(entry["alive"], 0, 5): return "每日记录日期或人数无效"
		previous = int(entry["day"])
		if not CharacterState.keys(entry["stock"], ShelterInventory.NAMES.keys()): return "每日库存种类无效"
		for amount in entry["stock"].values():
			if not CharacterState.integer(amount, 0, 1000000): return "每日库存数量无效"
		for field in ["hunger", "morale", "integrity"]:
			if not CharacterState.number(entry[field], 0, 100): return "每日状态数值无效"
	return ""


func drink(game: Node2D, actor_id: int) -> bool:
	if game.game_over or actor_id < 0 or actor_id >= game.survivors.size(): return false
	var actor: Survivor = game.survivors[actor_id]
	if actor.health <= 0 or actor.person.thirst <= 0: return false
	if game.expedition.active:
		if actor_id != game.expedition.actor_id or game.paused or game.expedition.bag["water"] <= 0: return false
		game.expedition.bag["water"] -= 1
	else:
		if not game.inventory.try_take({"water": 1}, actor.display_name + "饮水"): return false
	actor.person.thirst = maxf(0, actor.person.thirst - 60)
	drinks += 1
	game.story.note("drink")
	return true


func aid(game: Node2D, target_id: int) -> bool:
	return aid_by(game,game.selected_id,target_id)


func aid_by(game: Node2D, medic_id: int, target_id: int) -> bool:
	if game.expedition.active or game.game_over or target_id < 0 or target_id >= game.survivors.size() or medic_id < 0 or medic_id >= game.survivors.size() or target_id == medic_id: return false
	var medic: Survivor = game.survivors[medic_id]
	var target: Survivor = game.survivors[target_id]
	if medic.health <= 0 or target.health <= 0 or medic.speciality != "医护": return false
	if target.metabolism < 1 and target.hunger >= 80 and target.injury <= 0 and target.infection <= 0 and target.illness <= 0: return false
	if game.simulation_time - medic.person.last_aid < 180 or game.simulation_time - target.person.last_aid < 180: return false
	if target.health >= 100 and target.injury <= 0 and target.infection <= 0 and target.illness <= 0: return false
	if not game.inventory.try_take({"medicine": 1}, medic.display_name + "医疗援助" + target.display_name): return false
	if target.metabolism >= 1 or target.hunger < 80: target.health = minf(100, target.health + (20 + medic.person.level("care") * 2 + (10 if medic.metabolism < 1 and medic.person.persona == "xu" else 0))*CharacterAbilities.factor(medic,"aid"))
	target.injury = maxf(0, target.injury - 40)
	target.infection = maxf(0, target.infection - 35)
	target.illness = maxf(0, target.illness - 35)
	if medic.metabolism < 1 and medic.person.persona == "gu":
		target.injury = maxf(0, target.injury - 15)
		target.illness = maxf(0, target.illness - 10)
	target.person.stress = maxf(0, target.person.stress - 10)
	target.person.trauma = maxf(0, target.person.trauma - 5)
	medic.person.last_aid = game.simulation_time
	target.person.last_aid = game.simulation_time
	medic.person.gain("care", 8)
	medic.person.morale = minf(100, medic.person.morale + 2)
	var pair := "%d:%d" % [mini(medic.survivor_id, target_id), maxi(medic.survivor_id, target_id)]
	bonds[pair] = mini(100, int(bonds[pair]) + 5)
	if game.has_method("chronicle_snapshot"): game.chronicle.aid(game,medic)
	event_reported.emit("%s用一份药品为%s提供了医疗援助；后续仍要安排休息与照料。" % [medic.display_name, target.display_name])
	return true
