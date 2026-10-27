class_name ExpeditionState
extends RefCounted
## Real-time expedition simulation. Rendering and physical input are separate.
## Loot is removed from persistent containers, never granted on a timer.

signal event_reported(message: String)
signal returned(survivor_id: int, cargo: Dictionary, survived: bool)
signal site_searched(index: int)
signal combat_resolved(kind: String, point: Vector2, damage: int)
signal exit_requested(side: int)
signal enemy_damaged(index: int, point: Vector2, direction: float, damage: int, lethal: bool)
signal player_hurt(point: Vector2, direction: float, damage: int)

const CAPACITY := 10
const WIDTH := 2600.0
const LADDER_X := 1480.0
const FLOOR_Y := [620.0, 400.0]
const SITE_DEFS := LocationCatalog.STREET_SITES

const MODES := ["patrol", "investigate", "chase", "windup", "stunned", "dead"]

var environment_active := false # Derived by the campaign, not trusted from disk.
var condition := 0
var route_open := false
var route_progress := 0.0
var route_tool := false

var capacity := CAPACITY
var stacked := false # The legacy shelter fixture retains its original unit capacity. Campaigns use stacks.
var extra_slots := 0
var reserve_ammo := 0
var magazine := 0
var reload_remaining := 0.0
var manual_loot := false
var confirm_exits := false # Campaign UI policy, derived again after loading.
var _exit_interact_held := false
var loot_site := -1
var discovered: Array[int] = []
var special_sites: Array[int] = [] # Derived from campaign parts after loading; never trusted from disk.
var location_id := "street"
var active := false
var actor_id := -1
var attempts := 0
var last_refresh_day := 1
var return_speed := 1.0
var player_x := 110.0
var player_y := 620.0
var floor_level := 0
var facing := 1.0
var sneaking := false
var sprinting := false
var moving := false
var noise := 0.0
var noise_burst := 0.0
var elapsed := 0.0
var invulnerable := 0.0
var attack_cooldown := 0.0
var attack_windup := 0.0
var medicine_cooldown := 0.0
var climb_target := -1
var climb_progress := 0.0
var search_index := -1
var search_progress := 0.0
var search_duration := 0.0
var search_tool := false
var feedback := "A/D 移动，按住 E 搜索；回到左侧入口撤退。"
var bag: Dictionary = {}
var sites: Array[Dictionary] = []
var enemies: Array[Dictionary] = []


func _init(id: String = "street") -> void:
	location_id = id
	_clear_bag()
	for definition in site_definitions():
		sites.append({"contents": definition["items"].duplicate(), "locked": definition["locked"]})
	_spawn_enemies(1)


func _clear_bag() -> void:
	bag.clear()
	for resource in ShelterInventory.NAMES:
		bag[resource] = 0


static func day_at(seconds: float) -> int:
	return 1 + (480 + int(seconds * SurvivalRules.MINUTES_PER_SECOND)) / 1440


func refresh_for_day(day: int) -> void:
	if active or day <= last_refresh_day:
		return
	# Migration/restocking is announced before departure, never spawned on a
	# player mid-fight. Only two locations refresh; others stay depleted.
	for index in [(day * 2) % site_definitions().size(), (day * 2 + 1) % site_definitions().size()]:
		sites[index] = {"contents": site_definitions()[index]["items"].duplicate(), "locked": site_definitions()[index]["locked"]}
		discovered.erase(index)
	last_refresh_day = day
	condition = (day - 1) % 2
	_spawn_enemies(day)
	event_reported.emit("%s：两处容器补充，感染者迁入；%s。已打通的通路保留。" % [area()["name"],condition_name()])


func _spawn_enemies(day: int) -> void:
	enemies.clear()
	var definitions: Array = area()["guards"].duplicate(true)
	if day % 3 == 0:
		definitions.append(area()["extra"].duplicate())
	for index in range(definitions.size()):
		var data: Array = definitions[index]
		enemies.append({"x": data[0], "floor": data[1], "home_floor": data[1], "target_floor": data[1], "memory": 0.0, "climb_target": -1, "climb_progress": 0.0, "min": data[2], "max": data[3], "direction": -1.0 if (day + index) % 2 else 1.0, "mode": "patrol", "suspicion": 0.0, "target": data[0], "timer": 0.0, "cooldown": 0.0, "brace": 0.0, "hp": EnemyCatalog.stats(str(data[4]) if data.size() > 4 else "walker")["health"], "kind": data[4] if data.size() > 4 else "walker"})


func begin(id: int, loadout: Dictionary, previous_speed: float) -> void:
	_exit_interact_held = false
	_reset_route()
	active = true
	loot_site = -1
	actor_id = id
	attempts += 1
	return_speed = previous_speed
	player_x = 110
	player_y = FLOOR_Y[0]
	floor_level = 0
	facing = 1
	sneaking = false
	sprinting = false
	moving = false
	noise = 0
	noise_burst = 0
	elapsed = 0
	invulnerable = 0
	attack_cooldown = 0
	attack_windup = 0
	medicine_cooldown = 0
	climb_target = -1
	climb_progress = 0
	_reset_search()
	_clear_bag()
	for resource in loadout:
		bag[resource] = int(loadout[resource])
	for enemy in enemies:
		if enemy["hp"] > 0:
			enemy["mode"] = "patrol"
			enemy["suspicion"] = 0.0
			enemy["timer"] = 0.0
			enemy["cooldown"] = 0.0
			enemy["memory"] = 0.0
			enemy["target_floor"] = enemy["floor"]
			enemy["target"] = enemy["x"]
	feedback = "%s · %s。%s" % [area()["name"],condition_name(),LocationEnvironment.route_hint(location_id)]


func used_capacity() -> int:
	return extra_slots+BackpackStacks.slots(bag,stacked)


func room_for(resource: String) -> int:
	return BackpackStacks.room(bag,resource,capacity,extra_slots,stacked)


func in_cover() -> bool:
	if not sneaking or climb_target != -1:
		return false
	for cover in area()["covers"]:
		if floor_level == cover[2] and player_x >= cover[0] and player_x <= cover[1]: return true
	return false


const INTERACTION_RADIUS := 58.0


func site_hit_rect(index: int) -> Rect2:
	var definition: Dictionary = site_definitions()[index]
	return Rect2(Vector2(float(definition["x"])-76,FLOOR_Y[int(definition["floor"])]-106),Vector2(116,116))


func site_in_range(index: int) -> bool:
	if index < 0 or index >= sites.size() or climb_target != -1: return false
	var site: Dictionary = site_definitions()[index]
	return floor_level == int(site["floor"]) and absf(player_x - float(site["x"])) < INTERACTION_RADIUS


func site_has_supplies(index: int) -> bool:
	return sites[index]["contents"].values().any(func(amount): return int(amount) > 0)


func nearby_site() -> int:
	if climb_target != -1:
		return -1
	var nearest := -1
	var distance := INTERACTION_RADIUS
	for index in range(site_definitions().size()):
		if site_in_range(index) and absf(player_x - site_definitions()[index]["x"]) < distance:
			nearest = index
			distance = absf(player_x - site_definitions()[index]["x"])
	return nearest


func reload(actor: Survivor) -> bool:
	if not active or reload_remaining > 0 or not actor.weapon().has("magazine") or magazine >= 6 or reserve_ammo <= 0 or attack_windup > 0: return false
	reload_remaining = 1.4
	feedback = "换弹中 · 1.4秒，仍可移动。"
	return true


func tick(delta: float, actor: Survivor, controls: Dictionary) -> void:
	if not active:
		return
	if actor.health <= 0:
		_finish(false)
		return
	if reload_remaining > 0:
		reload_remaining = maxf(0, reload_remaining - delta)
		if reload_remaining == 0:
			var rounds := mini(6 - magazine, reserve_ammo)
			magazine += rounds
			reserve_ammo -= rounds
			feedback = "换弹完成 · 弹匣%d / 备用%d" % [magazine, reserve_ammo]
	elapsed += delta
	invulnerable = maxf(0, invulnerable - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	medicine_cooldown = maxf(0, medicine_cooldown - delta)
	noise_burst = maxf(0, noise_burst - delta * 45)
	sneaking = bool(controls.get("sneak", false))
	sprinting = bool(controls.get("sprint", false)) and not sneaking
	var axis := clampf(float(controls.get("axis", 0)), -1, 1)
	var exit_interact := bool(controls.get("interact",false)) and (not _exit_interact_held or bool(controls.get("force_exit",false)))
	_exit_interact_held = bool(controls.get("interact",false))
	moving = absf(axis) > 0.01
	if climb_target != -1:
		climb_progress = minf(1, climb_progress + delta / 2.0)
		player_y = lerpf(FLOOR_Y[floor_level], FLOOR_Y[climb_target], climb_progress)
		moving = true
		noise = maxf(30, noise_burst)
		if climb_progress >= 1:
			floor_level = climb_target
			climb_target = -1
			climb_progress = 0
			player_y = FLOOR_Y[floor_level]
	else:
		var climb := int(controls.get("climb", 0))
		var access := nearest_ladder(player_x)
		if absf(player_x - access) < 48 and ((climb > 0 and floor_level == 0) or (climb < 0 and floor_level == 1)):
			climb_target = 1 - floor_level
			climb_progress = 0
			player_x = access
			_reset_search()
			_reset_route()
		elif moving:
			facing = signf(axis)
			var pace := 95.0 if sneaking else 275.0 if sprinting else 190.0
			var surface := current_surface()
			player_x = clampf(player_x + axis * pace * float(surface["pace"]) * actor.effort_factor() * delta, 90 if floor_level == 0 else upper_left(), right_edge(floor_level))
			actor.fatigue = minf(100, actor.fatigue + delta * (0.10 if sprinting else 0.04))
			_reset_route()
		var movement_noise := (8.0 if sneaking else 75.0 if sprinting else 30.0) if moving else 0.0
		movement_noise *= float(current_surface()["quiet" if sneaking else "noise"])
		movement_noise *= (0.8 if actor.speciality == "搜寻者" else 1.0) * (1.0 - actor.person.level("scout") * 0.05)
		noise = minf(100, maxf(noise_burst, movement_noise))
		if bool(controls.get("interact", false)) and not moving and climb_target == -1:
			if exit_side() != 0:
				if exit_interact: request_retreat()
				return
			if route_in_range() and nearby_site() == -1:
				_clear_route(delta)
			else:
				_search(delta * (1.2 if actor.speciality == "搜寻者" else 1.0) * actor.person.bonus("scout"), actor)
	if attack_windup > 0:
		attack_windup = maxf(0, attack_windup - delta)
		if attack_windup == 0:
			_resolve_attack(actor)
	for enemy in enemies:
		_tick_enemy(enemy, actor, delta)
	if actor.health <= 0:
		_finish(false)


func _reset_search() -> void:
	search_index = -1
	search_progress = 0
	search_duration = 0
	search_tool = false


func _search(delta: float, actor: Survivor) -> void:
	var index := nearby_site()
	if index == -1:
		feedback = "靠近箱柜，按住 E 搜索。W/S 在梯子旁上下楼。"
		return
	if used_capacity() >= capacity and not manual_loot:
		feedback = "背包已满；可丢弃一份物资腾出空间，或回入口撤退。"
		return
	var site := sites[index]
	if manual_loot and discovered.has(index):
		loot_site = index
		return
	if site["contents"].values().all(func(amount: int): return amount == 0) and not special_sites.has(index):
		feedback = "这个容器已空。同一天反复进出不会刷新物资。"
		return
	if search_index != index:
		search_index = index
		search_progress = 0
		search_tool = site["locked"] and bag["tools"] > 0
		search_duration = 3.0 if search_tool else float(site_definitions()[index]["seconds"]) + (4.0 if site["locked"] else 0.0)
	noise_burst = maxf(noise_burst, 70 if site["locked"] else 42)
	search_progress += delta * (0.8 if sneaking else 1.0)
	feedback = "搜索 %s · %d%%（移动或松开 E 会暂停）" % [site_definitions()[index]["name"], int(search_progress / search_duration * 100)]
	if search_progress + 0.000001 < search_duration:
		return
	if manual_loot:
		if site["locked"]:
			if search_tool: bag["tools"] -= 1
			site["locked"] = false
		discovered.append(index)
		loot_site = index
		feedback = "已打开%s，选择要拿走的物资；没有自动装包。" % site_definitions()[index]["name"]
		_reset_search()
		return
	var taken := {}
	for resource in ShelterInventory.NAMES:
		var quantity := mini(int(site["contents"].get(resource, 0)), room_for(resource))
		if quantity > 0:
			bag[resource] += quantity
			site["contents"][resource] -= quantity
			taken[resource] = quantity
	if not taken.is_empty() and site["locked"]:
		if search_tool:
			bag["tools"] -= 1
			event_reported.emit("使用了一件工具破锁。")
		site["locked"] = false
	var gained := 0
	for amount in taken.values(): gained += int(amount)
	if gained > 0 and actor.person.gain("scout", gained * 2): event_reported.emit("%s的探索技能提升至%d级。" % [actor.display_name, actor.person.level("scout")])
	if gained > 0: site_searched.emit(index)
	feedback = "搜获%s；未装下的物资仍留在容器。" % ShelterInventory.describe(taken)
	event_reported.emit(feedback)
	_reset_search()


func attack(actor: Survivor) -> bool:
	if not active or actor.health <= 0 or attack_cooldown > 0 or climb_target != -1 or reload_remaining > 0:
		return false
	var weapon := actor.weapon()
	if weapon.has("magazine"):
		if magazine <= 0:
			feedback = "弹匣已空：L换弹；没有备用弹药时请撤离。"
			return false
		var old_slots := ceili((reserve_ammo + magazine) / 8.0)
		magazine -= 1
		extra_slots = maxi(0, extra_slots - old_slots + ceili((reserve_ammo + magazine) / 8.0))
	_reset_route()
	actor.fatigue = minf(100, actor.fatigue + (0.6 if not weapon.is_empty() or bag["tools"] > 0 else 1.2))
	attack_cooldown = float(weapon.get("cooldown", 1.1))
	attack_windup = float(weapon.get("windup", 0.2))
	noise_burst = 100 if weapon.has("magazine") or weapon.is_empty() else 8 if sneaking else 65
	feedback = "准备%s · 距离%d" % [weapon.get("name", "徒手推搡"), weapon.get("reach", 75)]
	return true


func attack_obstruction(enemy: Dictionary, actor: Survivor) -> Dictionary:
	var ranged := actor.weapon().has("magazine")
	var origin := Vector2(player_x,player_y-((38 if sneaking else 58) if ranged else 35))
	var end := Vector2(enemy["x"],enemy_y(enemy)-(60*float(EnemyCatalog.stats(enemy["kind"])["scale"]) if ranged else 35))
	return CombatGeometry.obstruction(area()["covers"],origin,end,floor_level)


func _resolve_attack(actor: Survivor) -> void:
	var target: Dictionary = {}
	var target_index := -1
	var weapon := actor.weapon()
	if not weapon.is_empty() and not weapon.has("magazine"): noise_burst = maxf(noise_burst,65)
	var closest := float(weapon.get("reach", 75.0))
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		var distance := absf(float(enemy["x"]) - player_x)
		if enemy["hp"] > 0 and absf(enemy_y(enemy) - player_y) < 30 and climb_target == -1 and distance < closest and (float(enemy["x"]) - player_x) * facing >= -10:
			target = enemy
			target_index = index
			closest = distance
	if target.is_empty():
		if weapon.has("magazine"):
			actor.weapon_item["durability"] = maxi(0,int(actor.weapon_item["durability"])-1)
			var origin := Vector2(player_x,player_y-(38 if sneaking else 58))
			var end := origin+Vector2(facing*float(weapon["reach"]),0)
			var obstruction := CombatGeometry.obstruction(area()["covers"],origin,end,floor_level)
			combat_resolved.emit("shot_miss" if obstruction.is_empty() else "blocked_shot",end if obstruction.is_empty() else obstruction["point"],0)
		else:
			combat_resolved.emit("miss",Vector2(player_x+facing*55,player_y-50),0)
		feedback = "前方没有命中目标；射击仍消耗弹药。" if weapon.has("magazine") else "挥空：前方有效距离内没有同层敌人。"
		event_reported.emit(feedback)
		return
	var ranged := weapon.has("magazine")
	var ray := attack_obstruction(target,actor)
	if not ray.is_empty():
		if ranged: actor.weapon_item["durability"] = maxi(0,int(actor.weapon_item["durability"])-1)
		feedback = "弹道被家具挡住。站起或调整位置。" if ranged else "家具挡住了这次攻击，绕近再出手。"
		combat_resolved.emit("blocked_shot" if ranged else "obstructed",ray["point"],0)
		event_reported.emit(feedback)
		return
	var unaware: bool = target["suspicion"] < 40 and not target["mode"] in ["windup","chase","stunned"]
	# A hit reveals the attacker's last known position; it does not grant wall vision.
	target["suspicion"] = 100.0
	target["target"] = player_x
	target["target_floor"] = floor_level
	target["memory"] = memory_duration(target)
	if not weapon.is_empty():
		var ambush: bool = not weapon.has("magazine") and sneaking and unaware and (player_x - float(target["x"])) * float(target["direction"]) < -10
		var strength := int(weapon["damage"]) if weapon.has("magazine") else CharacterAbilities.melee_damage(actor, int(weapon["damage"]), ambush)
		var damage := mini(int(target["hp"]), strength)
		target["hp"] -= damage
		if target["hp"] <= 0 and int(target["climb_target"]) != -1:
			target["floor"] = floor_level
			target["climb_target"] = -1
			target["climb_progress"] = 0.0
		actor.weapon_item["durability"] = maxi(0, int(actor.weapon_item["durability"]) - int(weapon["wear"]))
		target["mode"] = "dead" if target["hp"] <= 0 else "stunned"
		target["timer"] = 0.0 if target["hp"] <= 0 else 0.35
		target["cooldown"] = 0.0
		enemy_damaged.emit(target_index,Vector2(target["x"],enemy_y(target)),facing,damage,target["hp"] <= 0)
		combat_resolved.emit("shot" if weapon.has("magazine") else "hit", Vector2(target["x"], enemy_y(target) - (60*float(EnemyCatalog.stats(target["kind"])["scale"]) if ranged else 50)), damage)
		feedback = "%s%s −%d！敌人剩余生命%d，武器耐久%d。" % [weapon["name"], "背后突袭" if ambush else "命中", damage, target["hp"], actor.weapon_item["durability"]]
	elif actor.metabolism >= 1 and bag["tools"] > 0:
		bag["tools"] -= 1
		var damage: int = target["hp"]
		target["hp"] = 0
		target["floor"] = floor_level
		target["climb_target"] = -1
		target["climb_progress"] = 0.0
		combat_resolved.emit("hit", Vector2(target["x"], enemy_y(target) - 50), damage)
		target["mode"] = "dead"
		target["suspicion"] = 0.0
		target["timer"] = 0.0
		target["cooldown"] = 0.0
		target["brace"] = 0.0
		enemy_damaged.emit(target_index,Vector2(target["x"],enemy_y(target)),facing,damage,true)
		feedback = "命中 −40！消耗工具1，感染者已击倒。动静可能引来其他敌人。"
	else:
		if target["brace"] > 0:
			feedback = "推搡被挡：感染者正在稳身，不扣生命；拉开距离或使用工具。"
			combat_resolved.emit("blocked", Vector2(target["x"], player_y - 50), 0)
			event_reported.emit(feedback)
			return
		actor.fatigue = minf(100, actor.fatigue + 2.8)
		target["brace"] = 3.6
		target["mode"] = "stunned"
		target["timer"] = 1.6
		if int(target["climb_target"]) == -1: target["x"] = clampf(float(target["x"]) + facing * 42, 90 if floor_level == 0 else upper_left(), right_edge(floor_level))
		feedback = "推开成功 · 不造成伤害！趁失衡后退，敌人生命仍为%d。" % target["hp"]
		combat_resolved.emit("push", Vector2(target["x"], player_y - 50), 0)
	_reset_search()
	event_reported.emit(feedback)


func use_medicine(actor: Survivor) -> bool:
	if not active or actor.health <= 0 or bag["medicine"] <= 0 or medicine_cooldown > 0:
		feedback = "背包没有可用药品，或急救仍在冷却。"
		return false
	if actor.metabolism < 1 and actor.hunger >= 80 and actor.injury <= 0 and actor.infection <= 0 and actor.illness <= 0:
		feedback = "需要先吃饭，药品不能代替食物。没有消耗药品。"
		return false
	bag["medicine"] -= 1
	medicine_cooldown = 3
	var recovered := 25 if actor.metabolism >= 1 or actor.hunger < 80 else 0
	actor.health = minf(100, actor.health + recovered)
	actor.injury = maxf(0, actor.injury - 40)
	actor.infection = maxf(0, actor.infection - 35)
	actor.illness = maxf(0, actor.illness - 35)
	feedback = "使用药品：生命+%d，伤势-40，感染-35。%s" % [recovered, "先恢复饱腹才能恢复生命。" if recovered == 0 else ""]
	event_reported.emit(feedback)
	return true


func drop(resource: String) -> bool:
	if not active or not bag.has(resource) or bag[resource] <= 0:
		return false
	bag[resource] -= 1
	_reset_search()
	_reset_route()
	feedback = "丢弃了%s×1，无法拾回。" % ShelterInventory.NAMES[resource]
	event_reported.emit(feedback)
	return true


func request_retreat() -> bool:
	if not active:
		return false
	var side := exit_side()
	if side == 0:
		var distance := minf(maxf(0,player_x-145),maxf(0,right_edge(0)-55-player_x))
		if floor_level != 0 or climb_target != -1:
			var access := route_ladder(player_x,minf(player_x,right_edge(0)-55))
			distance = absf(player_x-access)+minf(access-145,right_edge(0)-55-access)
		feedback = "回到地面左侧或右侧出口再离开，距出口约%d步。%s" % [ceili(distance/10),"先回梯子下楼。" if floor_level != 0 or climb_target != -1 else ""]
		return false
	if confirm_exits:
		exit_requested.emit(side)
		return true
	return confirm_retreat(side)


func exit_side() -> int:
	if not active or floor_level != 0 or climb_target != -1: return 0
	if player_x <= 145: return -1
	if player_x >= right_edge(0) - 55: return 1
	return 0


func confirm_retreat(side: int) -> bool:
	# Revalidate on confirmation: stale dialogs cannot credit cargo remotely.
	if side == 0 or exit_side() != side: return false
	_finish(true)
	return true


func _finish(survived: bool) -> void:
	if not active:
		return
	var id := actor_id
	var cargo := bag.duplicate()
	active = false
	loot_site = -1
	actor_id = -1
	_clear_bag()
	_reset_search()
	_reset_route()
	climb_target = -1
	climb_progress = 0
	player_y = FLOOR_Y[floor_level]
	attack_windup = 0
	returned.emit(id, cargo, survived)


func enemy_y(enemy: Dictionary) -> float:
	return FLOOR_Y[int(enemy["floor"])] if int(enemy["climb_target"]) == -1 else lerpf(FLOOR_Y[int(enemy["floor"])],FLOOR_Y[int(enemy["climb_target"])],float(enemy["climb_progress"]))


func memory_duration(enemy: Dictionary) -> float:
	return 8.0 if enemy["kind"] == "runner" else 5.0 if enemy["kind"] == "brute" else 6.0


func enemy_can_reach(enemy: Dictionary) -> bool:
	return climb_target == -1 and absf(enemy_y(enemy)-player_y) < 30


func _enemy_route(enemy: Dictionary, destination: float, level: int, speed: float, delta: float) -> void:
	var access := route_ladder(float(enemy["x"]),destination)
	var x := access if int(enemy["floor"]) != level else destination
	var difference := x-float(enemy["x"])
	if absf(difference) > 0.01:
		enemy["direction"] = signf(difference)
		enemy["x"] = move_toward(float(enemy["x"]),x,speed*delta)
	if int(enemy["floor"]) != level and absf(float(enemy["x"])-access) < 0.01:
		enemy["climb_target"] = level
		enemy["climb_progress"] = 0.0


func _tick_enemy(enemy: Dictionary, actor: Survivor, delta: float) -> void:
	if enemy["hp"] <= 0: return
	enemy["brace"] = maxf(0,float(enemy["brace"])-delta)
	enemy["cooldown"] = maxf(0,float(enemy["cooldown"])-delta)
	enemy["memory"] = maxf(0,float(enemy["memory"])-delta)
	var distance := absf(float(enemy["x"])-player_x)
	var kind: String = enemy["kind"]
	var same_floor: bool = enemy["floor"] == floor_level and climb_target == -1 and int(enemy["climb_target"]) == -1
	if enemy["mode"] == "stunned":
		enemy["timer"] = maxf(0,float(enemy["timer"])-delta)
		if enemy["timer"] == 0: enemy["mode"] = "chase" if enemy["memory"] > 0 else "patrol"
		return
	if int(enemy["climb_target"]) != -1:
		var duration := 1.4 if kind == "runner" else 3.2 if kind == "brute" else 2.2
		enemy["climb_progress"] = minf(1,float(enemy["climb_progress"])+delta/duration)
		if enemy["climb_progress"] >= 1:
			enemy["floor"] = int(enemy["climb_target"])
			enemy["climb_target"] = -1
			enemy["climb_progress"] = 0.0
		return
	var bite_clear := same_floor and CombatGeometry.obstruction(area()["covers"],Vector2(enemy["x"],enemy_y(enemy)-35),Vector2(player_x,player_y-35),floor_level).is_empty()
	if enemy["mode"] == "windup":
		enemy["timer"] = maxf(0,float(enemy["timer"])-delta)
		if enemy["timer"] == 0:
			if bite_clear and distance < 62 and (player_x-float(enemy["x"]))*float(enemy["direction"]) >= -10 and invulnerable <= 0:
				var reduction := 1 - actor.protection()
				var damage := roundi(float(EnemyCatalog.stats(kind)["damage"])*reduction)
				actor.health = maxf(0, actor.health - damage)
				actor.injury = minf(100, actor.injury + 12 * reduction)
				actor.infection = minf(100, actor.infection + 8 * reduction)
				if not actor.armor_item.is_empty(): actor.armor_item["durability"] = maxi(0, int(actor.armor_item["durability"]) - 8)
				actor.person.stress = minf(100, actor.person.stress + 8)
				actor.person.trauma = minf(100, actor.person.trauma + 2)
				actor.person.morale = maxf(0, actor.person.morale - 2)
				invulnerable = 1.6
				_reset_route()
				player_hurt.emit(Vector2(player_x,player_y),1.0 if player_x >= enemy["x"] else -1.0,damage)
				player_x = clampf(player_x + (1 if player_x >= enemy["x"] else -1) * 42, 90 if floor_level == 0 else upper_left(), right_edge(floor_level))
				feedback = "被扑咬！生命-%d（护甲已计入），伤势与感染上升；R用药。" % damage
				event_reported.emit(feedback)
			enemy["mode"] = "chase"
			enemy["cooldown"] = 1.8
		return
	var facing_player: bool = (player_x-float(enemy["x"]))*float(enemy["direction"]) >= 0
	var vision := 115.0 if sneaking else 290.0
	if in_cover(): vision = 52.0
	vision = maxf(55,vision*float(weather()["vision"]))
	var sight_clear := same_floor and CombatGeometry.obstruction(area()["covers"],Vector2(enemy["x"],enemy_y(enemy)-60*float(EnemyCatalog.stats(kind)["scale"])),Vector2(player_x,player_y-(40 if sneaking else 65)),floor_level).is_empty()
	var sees := sight_clear and distance < vision and (facing_player or distance < 55)
	var sound_access := route_ladder(float(enemy["x"]),player_x)
	var hearing_distance := distance if same_floor else absf(float(enemy["x"])-sound_access)+absf(player_x-sound_access)+absf(enemy_y(enemy)-player_y)*0.45
	var hears: bool = noise >= 15 and hearing_distance < noise*4*float(weather()["hearing"])*(1 if same_floor else 0.75)
	if sees or hears:
		enemy["suspicion"] = minf(100,float(enemy["suspicion"])+delta*((90 if distance < 100 else 55) if sees else 35))
		enemy["target"] = player_x
		enemy["target_floor"] = floor_level if climb_target == -1 else climb_target
		enemy["memory"] = memory_duration(enemy)
		if enemy["mode"] == "patrol": enemy["mode"] = "investigate"
	else:
		enemy["suspicion"] = maxf(0,float(enemy["suspicion"])-delta*18)
	if enemy["suspicion"] >= 100:
		if enemy["mode"] != "chase": event_reported.emit("感染者发现了你！留意蓄力，后退或打断。")
		enemy["mode"] = "chase"
	if enemy["mode"] == "chase" and sees and bite_clear and distance < 48 and enemy["cooldown"] <= 0:
		enemy["mode"] = "windup"
		if distance > 0.01: enemy["direction"] = signf(player_x-float(enemy["x"]))
		enemy["timer"] = EnemyCatalog.stats(kind)["windup"]
		return
	if enemy["mode"] in ["chase","investigate"]:
		if enemy["memory"] <= 0:
			enemy["mode"] = "patrol"
			enemy["suspicion"] = 0.0
		else:
			_enemy_route(enemy,float(enemy["target"]),int(enemy["target_floor"]),float(EnemyCatalog.stats(kind)["chase_speed"]) if enemy["mode"] == "chase" else 48,delta)
			return
	# Return to the original floor and patrol by walking, never by teleporting.
	if int(enemy["floor"]) != int(enemy["home_floor"]):
		_enemy_route(enemy,float(enemy["min"]),int(enemy["home_floor"]),36,delta)
		return
	if enemy["x"] <= enemy["min"]: enemy["direction"] = 1.0
	if enemy["x"] >= enemy["max"]: enemy["direction"] = -1.0
	enemy["x"] = clampf(float(enemy["x"])+float(enemy["direction"])*36*delta,90 if int(enemy["floor"]) == 0 else upper_left(),right_edge(int(enemy["floor"])))


func snapshot() -> Dictionary:
	return {
		"condition":condition,"route_open":route_open,"route_progress":route_progress,"route_tool":route_tool,
		"stacked": stacked, "extra_slots": extra_slots, "reserve_ammo": reserve_ammo, "magazine": magazine, "reload_remaining": reload_remaining, "discovered": discovered.duplicate(), "capacity": capacity, "manual_loot": manual_loot, "loot_site": loot_site,
		"active": active, "actor_id": actor_id, "attempts": attempts, "last_refresh_day": last_refresh_day,
		"return_speed": return_speed, "player_x": player_x, "player_y": player_y, "floor": floor_level,
		"facing": facing, "sneaking": sneaking, "sprinting": sprinting, "moving": moving,
		"noise": noise, "noise_burst": noise_burst, "elapsed": elapsed, "invulnerable": invulnerable,
		"attack_cooldown": attack_cooldown, "attack_windup": attack_windup, "medicine_cooldown": medicine_cooldown,
		"climb_target": climb_target, "climb_progress": climb_progress, "search_index": search_index,
		"search_progress": search_progress, "search_duration": search_duration, "search_tool": search_tool,
		"feedback": feedback, "bag": bag.duplicate(), "sites": sites.duplicate(true), "enemies": enemies.duplicate(true),
	}


func restore_validated(data: Dictionary) -> void:
	_exit_interact_held = false
	for property in ["condition", "route_open", "route_progress", "route_tool", "stacked", "extra_slots", "reserve_ammo", "magazine", "reload_remaining", "capacity", "manual_loot", "loot_site", "active", "facing", "sneaking", "sprinting", "moving", "return_speed", "player_x", "player_y", "noise", "noise_burst", "elapsed", "invulnerable", "attack_cooldown", "attack_windup", "medicine_cooldown", "climb_progress", "search_progress", "search_duration", "search_tool", "feedback"]:
		set(property, data[property])
	discovered.clear()
	for index in data["discovered"]: discovered.append(int(index))
	actor_id = int(data["actor_id"])
	attempts = int(data["attempts"])
	last_refresh_day = int(data["last_refresh_day"])
	floor_level = int(data["floor"])
	climb_target = int(data["climb_target"])
	search_index = int(data["search_index"])
	_clear_bag()
	for resource in bag: bag[resource] = int(data["bag"][resource])
	sites.clear()
	for site: Dictionary in data["sites"]:
		var contents := {}
		for resource in site["contents"]: contents[resource] = int(site["contents"][resource])
		sites.append({"contents": contents, "locked": site["locked"]})
	enemies.clear()
	for enemy: Dictionary in data["enemies"]:
		var restored := enemy.duplicate()
		restored["floor"] = int(restored["floor"])
		restored["hp"] = int(restored["hp"])
		enemies.append(restored)


static func _n(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _i(value: Variant, low: int, high: int) -> bool:
	return _n(value, low, high) and float(value) == floorf(float(value))


static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true


static func validate_snapshot(data: Variant, actors: Array, id: String = "street") -> String:
	if not LocationCatalog.ALL_IDS.has(id): return "未知探索地点"
	var definition := LocationCatalog.area(id)
	var site_defs: Array = definition["sites"]
	var upper: float = definition["upper_left"]
	var width: float = definition["width"]
	var fields := ["condition", "route_open", "route_progress", "route_tool", "stacked", "extra_slots", "reserve_ammo", "magazine", "reload_remaining", "discovered", "capacity", "manual_loot", "loot_site", "active", "actor_id", "attempts", "last_refresh_day", "return_speed", "player_x", "player_y", "floor", "facing", "sneaking", "sprinting", "moving", "noise", "noise_burst", "elapsed", "invulnerable", "attack_cooldown", "attack_windup", "medicine_cooldown", "climb_target", "climb_progress", "search_index", "search_progress", "search_duration", "search_tool", "feedback", "bag", "sites", "enemies"]
	if not _keys(data, fields): return "探索字段不完整"
	if not _keys(data["bag"], ShelterInventory.NAMES.keys()): return "探索背包种类无效"
	if not _i(data["condition"],0,1) or not data["route_open"] is bool or not data["route_tool"] is bool: return "地图状态无效"
	var route_seconds := LocationEnvironment.route_seconds(id,data["route_tool"])
	if not _n(data["route_progress"],0,route_seconds) or data["route_progress"] >= route_seconds: return "清障进度无效"
	if data["route_progress"] > 0:
		if not data["active"] or data["route_open"] or data["floor"] != 0 or data["climb_target"] != -1 or absf(float(data["player_x"])-float(LocationEnvironment.profile(id)["route"])) >= INTERACTION_RADIUS or data["search_index"] != -1: return "清障位置无效"
		if data["route_tool"] and int(data.get("bag",{}).get("tools",0)) < 1: return "清障工具缺失"
	elif data["route_tool"]: return "空清障保留工具状态"
	if not _i(data["extra_slots"], 0, 16) or not _i(data["reserve_ammo"], 0, 120) or not _i(data["magazine"], 0, 6) or not _n(data["reload_remaining"], 0, 1.4): return "弹药或装备负重无效"
	if not _i(data["capacity"], 10, 16) or not data["manual_loot"] is bool or not _i(data["loot_site"], -1, site_defs.size() - 1): return "背包容量或物资窗口无效"
	if not data["discovered"] is Array or data["discovered"].size() > site_defs.size(): return "已搜索容器记录无效"
	var unique: Array = []
	for index in data["discovered"]:
		if not _i(index, 0, site_defs.size() - 1) or unique.has(int(index)): return "已搜索容器重复或越界"
		unique.append(int(index))
	for field in ["stacked", "active", "sneaking", "sprinting", "moving", "search_tool"]:
		if not data[field] is bool: return "探索开关无效"
	if not _i(data["actor_id"], -1, PeopleCatalog.MAX_HISTORY - 1) or not _i(data["attempts"], 0, 10000000) or not _i(data["last_refresh_day"], 1, 10000000): return "探索人员或地点日期无效"
	if not data["return_speed"] in [1.0, 3.0] or not data["facing"] in [-1.0, 1.0] or not _i(data["floor"], 0, 1): return "探索方向与楼层无效"
	for field in ["noise", "noise_burst"]:
		if not _n(data[field], 0, 100): return "探索噪声无效"
	for field in ["invulnerable", "attack_cooldown", "attack_windup", "medicine_cooldown"]:
		if not _n(data[field], 0, 3): return "探索动作冷却无效"
	if not _n(data["elapsed"], 0, 1000000000) or not data["feedback"] is String or data["feedback"].length() > 1000: return "探索时间或反馈无效"
	if not _n(data["player_x"], 90 if data["floor"] == 0 else upper, width - 100 if data["floor"] == 0 else width - 150) or not _n(data["player_y"], 400, 620): return "探索位置越界"
	if not _i(data["climb_target"], -1, 1) or not _n(data["climb_progress"], 0, 1): return "攀爬状态无效"
	var level := int(data["floor"])
	var target := int(data["climb_target"])
	if target == -1:
		if absf(data["player_y"] - FLOOR_Y[level]) > 0.01 or data["climb_progress"] != 0: return "探索角色不在走道上"
	else:
		if not data["active"] or target == level or not valid_ladder(id,float(data["player_x"]),data["route_open"]) or data["climb_progress"] >= 1 or absf(data["player_y"] - lerpf(FLOOR_Y[level], FLOOR_Y[target], data["climb_progress"])) > 0.01: return "探索攀爬路径不一致"
	if not _keys(data["bag"], ShelterInventory.NAMES.keys()): return "探索背包种类无效"
	var used := int(data["extra_slots"])
	for resource in data["bag"]:
		if not _i(data["bag"][resource], 0, int(data["capacity"])*BackpackStacks.limit(resource,data["stacked"])): return "探索背包数量无效"
		used += ceili(int(data["bag"][resource])/float(BackpackStacks.limit(resource,data["stacked"])))
	if used > int(data["capacity"]): return "探索背包超重"
	var away: Array[int] = []
	for index in range(actors.size()):
		if int(actors[index]["state"]) == Survivor.TaskState.AWAY: away.append(index)
	if data["active"]:
		if data["actor_id"] < 0 or data["attempts"] == 0 or away != [int(data["actor_id"])]: return "外出角色与探索场景不符"
	elif data["actor_id"] != -1 or used != 0 or not away.is_empty() or target != -1:
		return "未外出却保留背包或人员占用"
	if not data["sites"] is Array or data["sites"].size() != site_defs.size(): return "探索容器数量不符"
	for index in range(site_defs.size()):
		var site: Variant = data["sites"][index]
		if not _keys(site, ["contents", "locked"]) or not site["locked"] is bool or not _keys(site["contents"], site_defs[index]["items"].keys()): return "探索容器数据无效"
		for resource in site["contents"]:
			if not _i(site["contents"][resource], 0, int(site_defs[index]["items"][resource])): return "探索容器物资超限"
		if site["locked"] and not site_defs[index]["locked"]: return "容器锁状态无效"
	if data["loot_site"] >= 0 and (not data["manual_loot"] or not data["active"] or data["sites"][int(data["loot_site"])]["locked"]): return "物资窗口与地点不一致"
	if not _i(data["search_index"], -1, site_defs.size() - 1) or not _n(data["search_duration"], 0, 15) or not _n(data["search_progress"], 0, data["search_duration"]): return "搜索进度无效"
	var search := int(data["search_index"])
	if search == -1:
		if data["search_progress"] != 0 or data["search_duration"] != 0 or data["search_tool"]: return "空搜索保留了进度"
	else:
		var site: Dictionary = data["sites"][search]
		var duration := 3.0 if data["search_tool"] else float(site_defs[search]["seconds"]) + (4.0 if site["locked"] else 0.0)
		if not data["active"] or target != -1 or site_defs[search]["floor"] != level or data["search_progress"] >= duration or not is_equal_approx(data["search_duration"], duration): return "搜索动作与容器不符"
		if data["search_tool"] and (not site["locked"] or data["bag"]["tools"] < 1): return "破锁没有实际工具"
	if not data["enemies"] is Array or data["enemies"].size() != (definition["guards"].size() + (1 if int(data["last_refresh_day"]) % 3 == 0 else 0)): return "感染者数量与迁入日期不符"
	for enemy in data["enemies"]:
		if not _keys(enemy, ["x", "floor", "min", "max", "direction", "mode", "suspicion", "target", "timer", "cooldown", "brace", "hp", "kind", "home_floor", "target_floor", "memory", "climb_target", "climb_progress"]): return "感染者字段无效"
		if not _i(enemy["floor"], 0, 1) or not enemy["mode"] in MODES or not enemy["kind"] in ["walker", "runner", "brute"] or not _i(enemy["hp"], 0, EnemyCatalog.stats(enemy["kind"])["health"]) or not enemy["direction"] in [-1.0, 1.0]: return "感染者状态无效"
		var low := 90.0 if enemy["floor"] == 0 else upper
		var high := width - 100 if enemy["floor"] == 0 else width - 150
		if not _i(enemy["home_floor"],0,1) or not _i(enemy["target_floor"],0,1) or not _n(enemy["memory"],0,8) or not _i(enemy["climb_target"],-1,1) or not _n(enemy["climb_progress"],0,1): return "感染者记忆或路径无效"
		var home_low := 90.0 if enemy["home_floor"] == 0 else upper
		var home_high := width-100 if enemy["home_floor"] == 0 else width-150
		var target_low := 90.0 if enemy["target_floor"] == 0 else upper
		var target_high := width-100 if enemy["target_floor"] == 0 else width-150
		if not _n(enemy["x"],low,high) or not _n(enemy["min"],home_low,home_high) or not _n(enemy["max"],enemy["min"],home_high) or not _n(enemy["target"],target_low,target_high): return "感染者位置越界"
		if enemy["climb_target"] == -1:
			if enemy["climb_progress"] != 0: return "感染者攀爬进度无效"
		elif enemy["hp"] <= 0 or enemy["mode"] == "windup" or enemy["climb_target"] == enemy["floor"] or enemy["climb_progress"] >= 1 or not valid_ladder(id,float(enemy["x"]),data["route_open"]):
			return "感染者攀爬路径不一致"
		if not _n(enemy["brace"], 0, 3.6) or not _n(enemy["suspicion"], 0, 100) or not _n(enemy["timer"], 0, 2) or not _n(enemy["cooldown"], 0, 2) or (enemy["hp"] == 0) != (enemy["mode"] == "dead"): return "感染者警觉或动作无效"
	return ""


func area() -> Dictionary:
	return LocationCatalog.area(location_id)


func site_definitions() -> Array:
	return area()["sites"]


func ladder_x() -> float:
	return float(area()["ladder"])


func upper_left() -> float:
	return float(area()["upper_left"])


func right_edge(level: int) -> float:
	return float(area()["width"]) - (100 if level == 0 else 150)


func weather() -> Dictionary:
	return LocationCatalog.weather(last_refresh_day)


func take_loot(resource: String, count: int, actor: Survivor) -> int:
	if not active or loot_site < 0 or not ShelterInventory.NAMES.has(resource) or count <= 0: return 0
	var site: Dictionary = sites[loot_site]
	var gained := mini(count, mini(int(site["contents"].get(resource, 0)), room_for(resource)))
	if gained <= 0: return 0
	site["contents"][resource] -= gained
	bag[resource] += gained
	site_searched.emit(loot_site)
	return gained


func put_loot(resource: String, count: int) -> int:
	if not active or loot_site < 0 or not ShelterInventory.NAMES.has(resource) or count <= 0: return 0
	# Containers keep their own item types and original bounds.
	var contents: Dictionary = sites[loot_site]["contents"]
	if not contents.has(resource): return 0
	var room := int(site_definitions()[loot_site]["items"][resource]) - int(contents[resource])
	var amount := mini(count, mini(int(bag[resource]), room))
	if amount > 0:
		bag[resource] -= amount
		contents[resource] += amount
	return amount


func condition_name() -> String:
	return LocationEnvironment.profile(location_id)["conditions"][condition]


func current_surface() -> Dictionary:
	if not environment_active: return {"pace":1.0,"noise":1.0,"quiet":1.0}
	return LocationEnvironment.surface(location_id,condition,player_x,floor_level)


func route_x() -> float:
	return float(LocationEnvironment.profile(location_id)["route"])


func ladders() -> Array[float]:
	var result: Array[float] = [ladder_x()]
	if route_open: result.append(route_x())
	return result


func nearest_ladder(x: float) -> float:
	return route_x() if route_open and absf(x-route_x()) < absf(x-ladder_x()) else ladder_x()


func route_ladder(from_x: float, to_x: float) -> float:
	if not route_open: return ladder_x()
	var original := absf(from_x-ladder_x())+absf(to_x-ladder_x())
	var alternate := absf(from_x-route_x())+absf(to_x-route_x())
	# Equal horizontal distances are common when returning left. Prefer the
	# closer landing so opening a local escape also affects real T return.
	if alternate < original or (is_equal_approx(alternate,original) and absf(from_x-route_x()) < absf(from_x-ladder_x())): return route_x()
	return ladder_x()


static func valid_ladder(id: String, x: float, opened: bool) -> bool:
	return absf(x-float(LocationCatalog.area(id)["ladder"])) < 0.01 or (opened and absf(x-float(LocationEnvironment.profile(id)["route"])) < 0.01)


func route_hit_rect() -> Rect2:
	return Rect2(route_x()-36,488,72,142)


func route_in_range() -> bool:
	return environment_active and not route_open and floor_level == 0 and climb_target == -1 and absf(player_x-route_x()) < INTERACTION_RADIUS


func _reset_route() -> void:
	route_progress = 0
	route_tool = false


func _clear_route(delta: float) -> void:
	if not route_in_range(): return
	_reset_search()
	if route_progress == 0: route_tool = int(bag["tools"]) > 0
	if route_tool and int(bag["tools"]) < 1:
		_reset_route()
		return
	route_progress += delta
	noise_burst = maxf(noise_burst,36 if route_tool else 95)
	feedback = LocationEnvironment.route_hint(location_id)
	if route_progress + 0.000001 < LocationEnvironment.route_seconds(location_id,route_tool): return
	if route_tool: bag["tools"] -= 1
	route_open = true
	_reset_route()
	feedback = "%s已打通；感染者也能使用这条通路。" % LocationEnvironment.profile(location_id)["route_name"]
	event_reported.emit(feedback)
