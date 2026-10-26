extends RefCounted
## Reproducible management policy. All supplies come from actual world searches,
## recipes or paid events. Movement/climbing/combat use the real expedition API.

var game: Node2D
var recruit_members := false
var supply_runs := true
var provide_care := true
var trips := 0
var swings := 0
var first_aid := 0
var retreat_now := false
var peak_people := 3
var started := 0.0
var duration := 0.0
var complete_daily: Array[Dictionary] = []
var handle_stories := true
var handle_projects := true
var project_attempt_day := 0


func run(scene: Node2D, days: int, recruiting: bool = false, explore: bool = true, care: bool = true) -> Dictionary:
	game = scene
	recruit_members = recruiting
	supply_runs = explore
	provide_care = care
	duration = game.simulation_time + days * 720.0
	started = Time.get_ticks_msec()
	for actor: Survivor in game.survivors: actor.person.routine = care and actor.health > 0
	var reported_day := 0
	var iterations := 0
	while game.simulation_time + 0.0001 < duration and not game.game_over:
		iterations += 1
		assert(iterations < 15000, "Balance policy stopped advancing time")
		var day := ExpeditionState.day_at(game.simulation_time)
		if day != reported_day:
			reported_day = day
			if not game.people.daily.is_empty(): complete_daily.append(game.people.daily.back().duplicate(true))
			print("BALANCE DAY %d · time %.2f · alive %d · trips %d · stock %s" % [day, game.simulation_time, game.survivors.filter(func(a): return a.health > 0).size(), trips, game.inventory.snapshot()])
		if game.paused: game.toggle_pause()
		_manage()
		var selected := _supply_target() if supply_runs else {}
		var traveler := _traveler()
		if not selected.is_empty() and traveler >= 0:
			game.select_survivor(traveler)
			game.choose_destination(selected["region"])
			if game.start_expedition(game.inventory.amount("tools") > 0, game.inventory.amount("medicine") > 0):
				_trip(int(selected["site"]))
				trips += 1
			else: _advance(1)
		else:
			_advance(minf(5, duration - game.simulation_time))
	var crew: Array = []
	for actor: Survivor in game.survivors:
		crew.append({"name": actor.display_name, "persona": actor.person.persona, "alive": actor.health > 0, "health": actor.health, "hunger": actor.hunger, "fatigue": actor.fatigue, "morale": actor.person.morale, "stress": actor.person.stress, "thirst": actor.person.thirst, "injury": actor.injury, "infection": actor.infection, "experience": actor.person.experience.duplicate(), "jobs": actor.completed_by_task.duplicate()})
	if not game.people.daily.is_empty() and (complete_daily.is_empty() or complete_daily.back()["day"] != game.people.daily.back()["day"]): complete_daily.append(game.people.daily.back().duplicate(true))
	return {"simulated_seconds": game.simulation_time, "days_elapsed": game.simulation_time / 720.0, "alive": game.survivors.filter(func(a): return a.health > 0).size(), "peak_people": peak_people, "drinks": game.people.drinks, "trips": trips, "swings": swings, "first_aid": first_aid, "stock": game.inventory.snapshot(), "integrity": game.upkeep.integrity, "level": game.upkeep.level, "repairs": game.upkeep.repairs, "spoiled": game.people.spoiled.duplicate(), "recovered": game.upkeep.recovered.duplicate(), "daily": complete_daily.duplicate(true), "crew": crew, "stories": game.story.history.duplicate(true), "goals": game.goals.snapshot(), "game_over": game.game_over, "save_error": SaveSystem.validate(SaveSystem.capture(game)), "wall_seconds": (Time.get_ticks_msec() - started) / 1000.0}


func _advance(seconds: float, controls: Dictionary = {}) -> void:
	game.expedition_controls_override = controls
	game.advance_simulation(seconds)
	game.expedition_controls_override = null


func _manage() -> void:
	if handle_stories and not game.story.pending.is_empty() and not game.expedition.active:
		var cost: Dictionary = StoryCatalog.DATA[game.story.pending["id"]]["cost"]
		var surplus := true
		for resource in cost:
			if game.inventory.amount(resource) < int(cost[resource]) + 3: surplus = false
		game.story.resolve(game, surplus)
	if provide_care:
		for actor: Survivor in game.survivors:
			if actor.health > 0 and actor.orders.is_empty() and (actor.health < 80 or actor.infection > 5 or actor.injury > 25) and game.inventory.amount("medicine") > 0:
				game.scheduler.submit(actor, "heal")
	var materials: int = game.inventory.amount("materials")
	if not game.survivors.any(func(a): return a.orders.has("repair")) and game.upkeep.integrity < 60 and materials > 0:
		_order("repair")
	if not game.survivors.any(func(a): return a.orders.has("craft")) and game.inventory.amount("tools") < 2 and materials >= 3:
		_order("craft")
	if game.upkeep.pending_event >= 0:
		var cost: Dictionary = ShelterProgress.EVENT_COSTS[game.upkeep.pending_event]
		var accept: bool = game.inventory.can_take(cost)
		if game.upkeep.pending_event == 2: accept = accept and game.inventory.amount("materials") >= 4
		if game.upkeep.pending_event == 3: accept = accept and game.inventory.amount("medicine") >= 3
		game.upkeep.resolve_event(accept, game.inventory)
	if game.upkeep.level < 3:
		var cost: Dictionary = ShelterProgress.UPGRADE_COSTS[game.upkeep.level]
		var afford := true
		for resource in cost:
			var reserve := 3 if resource == "materials" else 1 if resource in ["tools", "medicine"] else 2
			if game.inventory.amount(resource) < int(cost[resource]) + reserve: afford = false
		if afford: game.upkeep.upgrade(game.inventory)
	if recruit_members and game.upkeep.level > 0 and game.inventory.amount("raw_food") >= 4 and game.inventory.amount("water") >= 4 and game.inventory.amount("medicine") >= 2:
		for id in game.people.offers(game):
			if game.people.recruit(game, id):
				game.survivors.back().person.routine = provide_care
				peak_people = maxi(peak_people, game.survivors.filter(func(a): return a.health > 0).size())
				break
	if handle_projects:
		for id in GoalCatalog.IDS:
			if not game.goals.progress_error(game, id).is_empty(): continue
			var cost: Dictionary = GoalCatalog.STAGES[id][int(game.goals.stages[id])]["cost"]
			var reserve := true
			for resource in cost:
				if game.inventory.amount(resource) < int(cost[resource]) + (8 if resource == "materials" else 3): reserve = false
			if reserve: game.goals.advance(game, id)
		var trade := "medicine" if game.inventory.amount("medicine") > 7 else "materials" if game.inventory.amount("materials") > 14 else ""
		if not trade.is_empty(): game.goals.trade(game, trade)


func _order(task: String) -> void:
	for actor: Survivor in game.survivors:
		if actor.health > 0 and actor.state == Survivor.TaskState.IDLE and actor.orders.is_empty() and actor.hunger < 65 and actor.fatigue < 65:
			game.scheduler.submit(actor, task)
			return


func _traveler() -> int:
	var chosen := -1
	var best := -1000.0
	for actor: Survivor in game.survivors:
		if actor.health < 60 or actor.hunger >= 65 or actor.fatigue >= 65 or actor.injury >= 50 or actor.infection >= 30: continue
		if not actor.orders.is_empty() and actor.orders[0] in ["eat", "sleep", "heal", "cook"]: continue
		var score: float = actor.health - actor.hunger * 0.25 - actor.fatigue * 0.5 + (20 if actor.speciality == "搜寻者" else 0)
		if score > best: best = score; chosen = actor.survivor_id
	return chosen


func _needs(bag: Dictionary = {}) -> Dictionary:
	var population: int = game.survivors.filter(func(a): return a.health > 0).size()
	var stock: Dictionary = game.inventory.snapshot()
	for resource in bag: stock[resource] += maxi(0, int(bag[resource]) - int(game.upkeep.trip_loadout.get(resource, 0)))
	return {"raw_food": maxf(0, population * 1.7 - stock["raw_food"] - stock["meals"] * 0.5), "water": maxf(0, population * 1.5 - stock["water"]), "fuel": maxf(0, population * 1.2 - stock["fuel"]), "materials": maxf(0, 9 - stock["materials"]), "tools": maxf(0, 2 - stock["tools"]), "medicine": maxf(0, 2 - stock["medicine"]), "meals": 0.0}


func _value(contents: Dictionary, needs: Dictionary) -> float:
	var score := 0.0
	for resource in contents:
		var weight := 4.0 if resource in ["raw_food", "fuel", "water"] else 2.0 if resource == "medicine" else 1.0
		score += minf(float(contents[resource]), float(needs[resource])) * weight
	return score


func _supply_target() -> Dictionary:
	var needs := _needs()
	var best := 0.0
	var target := {}
	for id in LocationCatalog.IDS:
		game.choose_destination(id) # Same preparation path, including announced day refresh.
		var state: ExpeditionState = game.expedition
		for index in range(state.sites.size()):
			var definition: Dictionary = state.site_definitions()[index]
			var score: float = _value(state.sites[index]["contents"], needs) / (1.0 + float(definition["x"]) / 700 + int(definition["floor"]) * 0.6 + (0.5 if state.sites[index]["locked"] else 0))
			if score > best: best = score; target = {"region": id, "site": index}
	var day := ExpeditionState.day_at(game.simulation_time)
	if handle_projects and day >= 6 and day != project_attempt_day and best < 2 and game.inventory.amount("medicine") >= 2 and game.inventory.amount("tools") >= 2:
		for note in GoalCatalog.NOTE_IDS:
			if game.goals.notes.has(note): continue
			var id: String = note.get_slice(":", 0)
			var index := int(note.get_slice(":", 1))
			var world: ExpeditionState = game.regions[id]
			if world.sites[index]["contents"].values().all(func(n): return n == 0): continue
			project_attempt_day = day
			return {"region": id, "site": index}
	return target


func _field_step(controls: Dictionary) -> void:
	var input := combat_input(controls)
	_advance(1.0 / 30, input)


func combat_input(controls: Dictionary) -> Dictionary:
	var state: ExpeditionState = game.expedition
	if not state.active: return controls
	var actor: Survivor = game.survivors[state.actor_id]
	if actor.health < 85 or actor.infection > 5 or actor.injury > 20:
		if state.bag["medicine"] > 0 and state.medicine_cooldown <= 0:
			game.expedition_medicine(); first_aid += 1
	if actor.health < 55 or actor.infection > 40: retreat_now = true
	var input := controls.duplicate()
	if state.attack_windup > 0: input["axis"] = 0.0
	elif state.attack_cooldown <= 0 and state.climb_target == -1:
		var nearest: Dictionary = {}
		var distance := 70.0
		for enemy in state.enemies:
			if enemy["hp"] > 0 and state.enemy_can_reach(enemy) and absf(float(enemy["x"]) - state.player_x) < distance:
				nearest = enemy; distance = absf(float(enemy["x"]) - state.player_x)
		if not nearest.is_empty() and state.attack_obstruction(nearest,actor).is_empty() and (state.bag["tools"] > 0 or nearest["brace"] <= 0) and (not bool(controls.get("interact", false)) or state.search_progress < 0.1 or state.bag["tools"] > 0):
			var direction := signf(float(nearest["x"]) - state.player_x)
			if state.facing != direction:
				_advance(1.0 / 30, {"axis": direction})
			game.expedition_attack(); swings += 1
			input["axis"] = 0.0
	# Dodge a visible late windup rather than assuming perpetual barehand control.
	for enemy in state.enemies:
		if enemy["hp"] > 0 and enemy["floor"] == state.floor_level and enemy["mode"] == "windup" and enemy["timer"] < 0.5 and absf(float(enemy["x"]) - state.player_x) < 68:
			input["axis"] = -signf(float(enemy["x"]) - state.player_x)
			input["sprint"] = true
			input["interact"] = false
	if actor.person.thirst >= 65 and state.bag["water"] > 0: game.people.drink(game, state.actor_id)
	return input


func _walk(x: float, escaping: bool = false) -> void:
	var timeout := 0.0
	while game.expedition.active and absf(game.expedition.player_x - x) > 9 and timeout < 60:
		if retreat_now and not escaping: return
		_field_step({"axis": signf(x - game.expedition.player_x), "sprint": true})
		timeout += 1.0 / 30


func _go(x: float, floor: int, escaping: bool = false) -> void:
	var state: ExpeditionState = game.expedition
	if state.floor_level != floor:
		_walk(state.ladder_x(), escaping)
		if not state.active or (retreat_now and not escaping): return
		var timeout := 0.0
		while state.active and (state.floor_level != floor or state.climb_target != -1) and timeout < 4:
			_field_step({"climb": 1 if floor == 1 else -1})
			timeout += 1.0 / 30
	_walk(x, escaping)


func _trip(first: int) -> void:
	retreat_now = false
	var state: ExpeditionState = game.expedition
	var index := first
	for stop in range(2):
		var definition: Dictionary = state.site_definitions()[index]
		_go(float(definition["x"]), int(definition["floor"]))
		if not state.active or retreat_now: break
		var timeout := 0.0
		while state.active and not retreat_now and state.used_capacity() < 10 and state.sites[index]["contents"].values().any(func(n): return n > 0) and timeout < 20:
			if absf(state.player_x - float(definition["x"])) > 45: _go(float(definition["x"]), int(definition["floor"]))
			_field_step({"interact": true})
			timeout += 1.0 / 30
		if not state.active or state.used_capacity() >= 9 or retreat_now: break
		var best := 0.0
		var next := -1
		var needs := _needs(state.bag)
		for candidate in range(state.sites.size()):
			if candidate == index: continue
			var site: Dictionary = state.site_definitions()[candidate]
			var score: float = _value(state.sites[candidate]["contents"], needs) / (1.0 + absf(float(site["x"]) - state.player_x) / 500 + (0.8 if int(site["floor"]) != state.floor_level else 0))
			if score > best: best = score; next = candidate
		if next == -1: break
		index = next
	if state.active:
		_go(100, 0, true)
		game.expedition_retreat()
