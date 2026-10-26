extends "res://tests/campaign_pilot.gd"
## Integration pilot: no inventory, health, position or progress injection.
var part_target := ""
var phase_started := 0.0

func setup(scene: Node2D) -> void:
	super.setup(scene)
	desired = {"raw_food": 12, "water": 16, "fuel": 12, "materials": 18, "medicine": 6, "tools": 4, "meals": 0}
	weights = {"raw_food": 2.5, "water": 2.0, "fuel": 2.2, "materials": 2.5, "medicine": 2.0, "tools": 2.0, "meals": 2.5}

func tick(delta: float) -> void:
	if game.departure_dialog.visible:
		game.confirm_departure()
		trips += 1
		return
	if game.game_over: return
	if game.cycle.phase == "dawn":
		if not game.expansion.outcome.is_empty(): return
		game.begin_day()
		phase_started = game.simulation_time
		return
	if game.cycle.phase == "planning":
		_select_night()
		return
	if game.paused: game.paused = false
	if game.cycle.phase == "day":
		if current_day != game.expansion.day(game):
			current_day = game.expansion.day(game)
			phase_started = game.simulation_time
		planning_time -= delta
		if planning_time <= 0:
			planning_time = 0.5
			_manage_expansion()
			_manage_needs()
			for actor: Survivor in game.survivors:
				if actor.health <= 0 or game._external_busy(actor.survivor_id) or not actor.orders.is_empty(): continue
				if actor.hunger >= 55 and game.inventory.amount("meals") > 0: game.scheduler.submit(actor, "eat")
				elif actor.illness >= 30 and game.inventory.amount("medicine") > 0: game.scheduler.submit(actor, "heal")
		if game.simulation_time - phase_started >= 190 and game.expansion.jobs.is_empty() and not game.cycle.builds.any(func(build): return build["state"] == "blueprint"):
			game.end_day()
			return
		game.advance_simulation(delta)

	else:
		var field: ExpeditionState = game.expedition
		if field.loot_site >= 0:
			game._process(0) # Open the same modal before invoking its close action.
			var site := field.loot_site
			game.expansion.take_part(game)
			for key in desired:
				var need := maxi(0, int(desired[key]) - game.inventory.amount(key) - int(field.bag[key]))
				# Keep one slot for the mission cache until its part is secured.
				if not part_target.is_empty() and not game.expansion.carried.has(part_target): need = mini(need, maxi(0, field.capacity - field.used_capacity() - 1))
				field.take_loot(key, need, game.survivors[field.actor_id])
			visited.append(site)
			game.close_loot()
			target = -1
		if not part_target.is_empty() and not game.expansion.carried.has(part_target) and not visited.has(int(GearCatalog.PARTS[part_target]["site"])):
			target = int(GearCatalog.PARTS[part_target]["site"])
		elif target < 0 and not returning:
			target = _next_site(field)
			if target < 0: returning = true
		if field.used_capacity() >= field.capacity or field.elapsed > 235 or game.survivors[field.actor_id].health < 40: returning = true
		if game.cycle.phase == "returning": returning = true
		if returning and field.floor_level == 0 and field.player_x <= 145:
			game.expedition_retreat()
			game.confirm_departure()
			trips += 1
			return
		var x: float = 110 if returning else field.site_definitions()[target]["x"]
		var level: int = 0 if returning else field.site_definitions()[target]["floor"]
		var input: Dictionary = game._route_controls(x, level, returning)
		if not returning and field.climb_target == -1 and field.floor_level == level and absf(field.player_x - x) < 10: input = {"interact": true}
		input = _combat(input)
		game.expedition_controls_override = input
		game.advance_simulation(delta)
		game.expedition_controls_override = null
	# Logic pilot does not redraw/layout the full HUD on every simulated step.
	# GUI input, layout and actual elapsed play have separate acceptance tests.

func _manage_expansion() -> void:
	var builder: Survivor = game.survivors[0]
	if builder.hunger >= 65 or builder.fatigue >= 80 or builder.health <= 0 or game._external_busy(0) or not builder.orders.is_empty(): return
	game.select_survivor(0)
	if game.facilities.levels["workbench"] < 2:
		if game.inventory.amount("tools") < 1 and game.inventory.amount("materials") >= 8: game.scheduler.submit(builder,"craft")
		elif game.inventory.can_take(FacilitySystem.RECIPES["workbench_2"]["cost"]): game.expansion.start_job(game,"workbench_2")
		return
	if not game.expansion.gear.any(func(item): return item["kind"] == "spear"):
		if game.inventory.amount("tools") == 0 and game.inventory.amount("materials") >= 6: game.scheduler.submit(builder, "craft")
		elif game.inventory.can_take(GearCatalog.ITEMS["spear"]["cost"]): game.expansion.start_job(game, "spear")
		return
	for item in game.expansion.gear:
		if item["kind"] == "spear" and item["durability"] < 30:
			game.expansion.start_job(game, "repair", int(item["id"]))
			return
	if game.expansion.stage == 0 and game.expansion.parts.has("relay"):
		game.expansion.start_job(game, "radio")
		return
	if not game.cycle.has_build("heater") and game.expansion.stage >= 1:
		game.place_build("heater", 4)
		return
	if game.expansion.stage == 2 and game.expansion.parts.has("filter_core"):
		game.expansion.start_job(game, "pump")
		return
	if game.expansion.stage == 3 and game.expansion.parts.has("power_cell") and game.expansion.parts.has("beacon_core"):
		game.expansion.start_job(game, "beacon")
		return
	if game.expansion.stage == 4 and game.expansion.day(game) >= 26 and game.inventory.amount("meals") < game.survivors.size() + 2:
		if game.inventory.can_take(TaskCatalog.TASKS["cook"]["cost"]): game.scheduler.submit(builder, "cook")
		return
	var coats: int = game.expansion.gear.filter(func(item): return item["kind"] == "coat").size()
	if coats < game.survivors.size() and game.expansion.day(game) >= 9: game.expansion.start_job(game, "coat")

func _select_night() -> void:
	part_target = ""
	var destination := "street"
	for key in GearCatalog.PARTS:
		var id: String = GearCatalog.PARTS[key]["map"]
		if not game.expansion.collected.has(key) and game.expansion.unlocked(game, id):
			part_target = key
			destination = id
			break
	if part_target.is_empty():
		var best := -1.0
		for id in LocationCatalog.ALL_IDS:
			if not game.expansion.unlocked(game, id): continue
			var field: ExpeditionState = game.regions[id]
			field.refresh_for_day(game.cycle.night_day)
			var value := 0.0
			for site in field.sites:
				for key in site["contents"]: value += minf(site["contents"][key], maxi(0, desired[key] - game.inventory.amount(key))) * weights[key]
			if value > best: best = value; destination = id
	game.choose_destination(destination)
	var scout: int = game.cycle.scavenger()
	for item in game.expansion.gear:
		if item["kind"] == "spear" and item["durability"] > 0 and item["owner"] != game.survivors[scout].person.persona: game.expansion.equip(game, int(item["id"]), scout)
	var coats: Array = game.expansion.gear.filter(func(item): return item["kind"] == "coat")
	for index in range(coats.size()):
		var target_id: int = scout if index == 0 else (scout + index) % game.survivors.size()
		if coats[index]["owner"] != game.survivors[target_id].person.persona: game.expansion.equip(game, int(coats[index]["id"]), target_id)
	game.cycle.loadout.clear()
	if game.inventory.amount("medicine") > 0: game.cycle.loadout["medicine"] = 1
	game.expansion.use_night_heat = game.expansion.outside(game) < 0
	if game.start_expedition():
		target = -1
		returning = false
		visited.clear()

func _combat(controls: Dictionary) -> Dictionary:
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	if actor.health < 80 or actor.infection > 20:
		if field.bag["medicine"] > 0: game.expedition_medicine()
	var input := controls.duplicate()
	var nearest: Dictionary = {}
	var distance := 999.0
	for enemy in field.enemies:
		if enemy["hp"] > 0 and enemy["floor"] == field.floor_level and absf(enemy["x"] - field.player_x) < distance:
			distance = absf(enemy["x"] - field.player_x)
			nearest = enemy
	if nearest.is_empty(): return input
	var direction := signf(nearest["x"] - field.player_x)
	var reach: float = actor.weapon().get("reach", 75)
	if distance < reach - 5 and field.climb_target == -1:
		if field.facing != direction: return {"axis": direction}
		if field.attack_cooldown <= 0: game.expedition_attack()
		input["axis"] = 0.0
		input["interact"] = false
	if distance < 90 and nearest["mode"] in ["chase", "windup"]:
		input["axis"] = -direction
		input["sprint"] = true
		input["interact"] = false
	return input


func _manage_needs() -> void:
	for actor: Survivor in game.survivors:
		if actor.health <= 0 or game._external_busy(actor.survivor_id) or not actor.orders.is_empty(): continue
		if actor.hunger >= 55:
			if game.inventory.amount("meals") > 0: game.scheduler.submit(actor, "eat")
			elif game.inventory.can_take(TaskCatalog.TASKS["cook"]["cost"]):
				game.scheduler.submit(actor, "cook")
				game.scheduler.submit(actor, "eat")
		elif actor.health < 80 or actor.infection >= 20 or actor.illness >= 30:
			if game.inventory.amount("medicine") > 0: game.scheduler.submit(actor, "heal")
	if game.upkeep.pending_event >= 0:
		var cost: Dictionary = ShelterProgress.EVENT_COSTS[game.upkeep.pending_event]
		game.upkeep.resolve_event(game.inventory.can_take(cost) and game.inventory.amount("materials") >= 8, game.inventory)
	if game.upkeep.integrity < 30 and game.inventory.amount("materials") >= 4: policy._order("repair")
