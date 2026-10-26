extends RefCounted
## Test-only policy. Uses campaign actions, real navigation and exact inventory.
const Policy := preload("res://tests/balance_bot.gd")
var game: Node2D
var policy := Policy.new()
var trips := 0
var target := -1
var returning := false
var visited: Array[int] = []
var day_started := -1.0
var current_day := 0
var planning_time := 0.0
var desired := {"raw_food": 10, "water": 12, "fuel": 7, "materials": 8, "medicine": 5, "tools": 3, "meals": 0}
var weights := {"raw_food": 1.5, "water": 1.3, "fuel": 2.0, "materials": 0.8, "medicine": 1.8, "tools": 2.0, "meals": 1.5}


func setup(scene: Node2D) -> void:
	game = scene
	policy.game = scene
	policy.provide_care = true
	policy.handle_projects = false
	for actor: Survivor in game.survivors: actor.person.routine = true


func tick(delta: float) -> void:
	if game.departure_dialog.visible:
		game.confirm_departure()
		trips += 1
		return
	if game.game_over: return
	if game.cycle.phase == "dawn":
		game.begin_day()
		return
	if game.cycle.phase == "planning":
		_select_night()
		return
	if game.paused: game.toggle_pause()
	if game.cycle.phase == "day":
		var day := ExpeditionState.day_at(game.simulation_time)
		if day != current_day:
			current_day = day
			day_started = game.simulation_time
		planning_time -= delta
		if planning_time <= 0:
			planning_time = 0.5
			# Food takes priority over elective repairs and non-urgent medicine.
			for actor: Survivor in game.survivors:
				if actor.health <= 0 or not actor.orders.is_empty(): continue
				if actor.hunger >= 60:
					if game.inventory.amount("meals") > 0: game.scheduler.submit(actor, "eat")
					elif game.inventory.can_take(TaskCatalog.TASKS["cook"]["cost"]):
						game.scheduler.submit(actor, "cook")
						game.scheduler.submit(actor, "eat")
			policy._manage()
		# Give a sleeper time to physically arrive and rest before skipping.
		var urgent: bool = game.survivors.any(func(actor): return actor.health > 0 and (actor.hunger >= 80 or actor.fatigue >= 90))
		if game.simulation_time - day_started >= (100 if urgent else 35):
			game.end_day()
			return
		game.advance_simulation(delta)
	else:
		var field: ExpeditionState = game.expedition
		if field.loot_site >= 0:
			var site: int = field.loot_site
			for key in desired:
				var need := maxi(0, int(desired[key]) - game.inventory.amount(key) - int(field.bag[key]))
				field.take_loot(key, need, game.survivors[field.actor_id])
			visited.append(site)
			game.close_loot()
			field.loot_site = -1
			target = -1
		if target < 0 and not returning:
			target = _next_site(field)
			if target < 0: returning = true
		if field.used_capacity() >= field.capacity or field.elapsed > 235 or game.survivors[field.actor_id].health < 35: returning = true
		if returning and field.floor_level == 0 and field.player_x <= 145:
			game.expedition_retreat()
			game.confirm_departure()
			trips += 1
			return
		var x: float = 110 if returning else field.site_definitions()[target]["x"]
		var level: int = 0 if returning else field.site_definitions()[target]["floor"]
		var input: Dictionary = game._route_controls(x, level, returning)
		if not returning and field.climb_target == -1 and field.floor_level == level and absf(field.player_x - x) <= 10: input = {"interact": true}
		input = policy.combat_input(input)
		game.expedition_controls_override = input
		game.advance_simulation(delta)
		game.expedition_controls_override = null
	game._process(0)


func _select_night() -> void:
	var best := -1.0
	var destination := "street"
	for id in LocationCatalog.IDS:
		var field: ExpeditionState = game.regions[id]
		field.refresh_for_day(game.cycle.night_day)
		var value := 0.0
		for site in field.sites:
			for key in site["contents"]:
				value += minf(float(site["contents"][key]), maxf(0, float(desired[key]) - game.inventory.amount(key))) * weights[key]
		if value > best:
			best = value
			destination = id
	game.choose_destination(destination)
	game.cycle.loadout.clear()
	if game.inventory.amount("tools") > 0: game.cycle.loadout["tools"] = 1
	if game.inventory.amount("medicine") > 0: game.cycle.loadout["medicine"] = 1
	if game.start_expedition():
		target = -1
		returning = false
		visited.clear()
		policy.retreat_now = false


func _next_site(field: ExpeditionState) -> int:
	var best := 0.0
	var selected := -1
	for index in range(field.sites.size()):
		if visited.has(index): continue
		var value := 0.0
		for key in field.sites[index]["contents"]:
			var need := maxi(0, int(desired[key]) - game.inventory.amount(key) - int(field.bag[key]))
			value += mini(int(field.sites[index]["contents"][key]), need) * weights[key]
		value /= 1.0 + absf(float(field.site_definitions()[index]["x"]) - field.player_x) / 500
		if value > best:
			best = value
			selected = index
	return selected
