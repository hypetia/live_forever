extends "res://tests/expansion_pilot.gd"
## Uses ordinary movement, work, combat and returns. No supplies, HP, sites or progress injection.
var home_trip := false

func setup(scene: Node2D) -> void:
	super.setup(scene)
	desired["materials"] = 22
	desired["tools"] = 6
	desired["water"] = 22

func tick(delta: float) -> void:
	if game.expedition.active and game.expedition.loot_site == 3 and game.expedition.location_id == "residential":
		game.residence.survey(game)
	super.tick(delta)

func _select_night() -> void:
	if not game.residence.convoy.is_empty():
		game.start_expedition()
		return
	home_trip = game.expansion.day(game) >= 2 and (not game.residence.surveyed.has("row") or game.residence.prepared.has("row")) and game.expansion.gear.any(func(item): return item["kind"] == "spear" and item["durability"] >= 30)
	if not home_trip:
		super._select_night()
		return
	part_target = ""
	game.choose_destination("residential")
	var scout: int = game.cycle.scavenger()
	for item in game.expansion.gear:
		if item["kind"] == "spear" and item["owner"] != game.survivors[scout].person.persona: game.expansion.equip(game,int(item["id"]),scout)
	game.cycle.loadout.clear()
	if game.inventory.amount("medicine") > 0: game.cycle.loadout["medicine"] = 1
	if game.start_expedition():
		target = 3
		returning = false
		visited.clear()

func _next_site(field: ExpeditionState) -> int:
	if home_trip and not visited.has(3): return 3
	return super._next_site(field)

func _combat(controls: Dictionary) -> Dictionary:
	if home_trip and game.residence.prepared.has("row") and game.residence.carried.is_empty() and not returning:
		var field: ExpeditionState = game.expedition
		for enemy in field.enemies:
			if enemy["hp"] <= 0 or absf(float(enemy["x"])-1600) >= 450: continue
			var approach: Dictionary = game._route_controls(float(enemy["x"]),int(enemy["floor"]),false)
			return super._combat(approach)
	return super._combat(controls)

func _manage_expansion() -> void:
	var builder: Survivor = game.survivors[0]
	var ready: bool = builder.health > 0 and builder.hunger < 65 and builder.fatigue < 70 and not game._external_busy(0) and builder.orders.is_empty()
	if ready:
		game.select_survivor(0)
		if game.residence.surveyed.has("row") and not game.residence.prepared.has("row") and not game.residence.cleared.has("row") and game.inventory.amount("materials") >= 8 and game.inventory.amount("tools") >= 3:
			if game.expansion.start_job(game,"clear_row"): return
		if game.residence.cleared.has("row") and game.residence.current == "shelter" and game.expansion.day(game) >= 5 and game.residence.convoy.is_empty():
			if game.inventory.amount("meals") < 8 and game.inventory.can_take(TaskCatalog.TASKS["cook"]["cost"]):
				game.scheduler.submit(builder,"cook")
				return
			if game.residence.job_error(game,"pack_row").is_empty() and game.inventory.can_take(ResidenceSystem.PROJECTS["pack_row"]["cost"]):
				if game.expansion.start_job(game,"pack_row"): return
		if game.residence.current == "row" and game.residence.security["gate"] == 0 and game.inventory.amount("materials") >= 8 and game.inventory.amount("tools") >= 2:
			if game.expansion.start_job(game,"gate"): return
	super._manage_expansion()
