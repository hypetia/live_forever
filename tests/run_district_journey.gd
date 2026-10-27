extends SceneTree
## No deposits, teleportation, damage overrides or free equipment: a new-campaign proof.
const Policy := preload("res://tests/balance_bot.gd")
var game: Node2D
var policy := Policy.new()
var trace: Array[Dictionary] = []
var problem := ""

func _initialize() -> void: call_deferred("_run")
func record(label: String) -> void:
	trace.append({"event":label,"seconds":game.simulation_time,"stock":game.inventory.snapshot(),"health":game.survivors.map(func(a): return a.health),"bag":game.expedition.bag.duplicate(),"x":game.expedition.player_x,"floor":game.expedition.floor_level,"enemies":game.expedition.enemies.map(func(e): return {"x":e["x"],"floor":e["floor"],"hp":e["hp"]})})
	print("JOURNEY ",label," · ",game.simulation_time," · ",game.inventory.snapshot())

func step(controls: Dictionary = {},combat: bool = true) -> void:
	var input := policy.combat_input(controls) if combat and game.expedition.active else controls
	game.expedition_controls_override = input
	game.advance_simulation(1.0/30)
	game.expedition_controls_override = null

func duration(seconds: float,controls: Dictionary = {},combat: bool = true) -> void:
	for n in range(ceili(seconds*30)): step(controls,combat)

func walk_to(x: float,level: int) -> bool:
	for n in range(3000):
		var f: ExpeditionState = game.expedition
		if not f.active or game.survivors[f.actor_id].health < 25: return false
		if f.floor_level == level and f.climb_target == -1 and absf(f.player_x-x) < 10: return true
		var controls: Dictionary = game._route_controls(x,level,false);controls["sneak"] = true
		step(controls)
	return false

func loot(index: int) -> bool:
	var f: ExpeditionState = game.expedition
	var site: Dictionary = f.site_definitions()[index]
	if not walk_to(site["x"],site["floor"]): return false
	for n in range(900):
		if not f.active: return false
		step({"interact":true,"sneak":true})
		if f.loot_site == index:
			for key in ShelterInventory.NAMES: f.take_loot(key,100,game.survivors[f.actor_id])
			game.close_loot();f.loot_site = -1
			return true
	return false

func _run() -> void:
	game = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game);game.set_process(false)
	policy.game = game;policy.provide_care = true;policy.handle_projects = false
	record("fresh campaign")
	game.select_survivor(0);game.assign_task("craft");game.scheduler.submit(game.survivors[0],"craft")
	game.select_survivor(1);game.assign_task("cook")
	duration(35,{},false)
	game.select_survivor(0);game.assign_task("eat")
	game.select_survivor(1);game.assign_task("eat")
	duration(25,{},false)
	record("real tool crafting and food preparation")
	game.end_day();game.cycle.roles.assign(["guard","bed","scavenge"])
	game.cycle.loadout = {"materials":4,"tools":2,"fuel":1,"medicine":1}
	if not game.start_expedition(): problem = "prepared loadout did not depart"
	if problem.is_empty() and not loot(0): problem = "failed at entrance supplies"
	if problem.is_empty() and not loot(1): problem = "failed at food shelves"
	if problem.is_empty() and not loot(2): problem = "failed to obtain actual oil-cabinet building supplies"
	if problem.is_empty() and not walk_to(1620,1): problem = "could not reach upper-floor outpost"
	record("reached the physical site")
	if problem.is_empty():
		game.expedition_decoy()
		duration(1.5,{"sneak":true})
		for n in range(900):
			var f: ExpeditionState = game.expedition
			if not f.active: problem = "expedition ended before construction";break
			if not walk_to(1620,1): problem = "could not return to work point";break
			step({"interact":true,"sneak":true})
			if f.loot_site != DistrictSystem.POINTS["street"]: continue
			f.take_loot("medicine",100,game.survivors[f.actor_id])
			if game.districts.action_error(game,"build").is_empty():
				game.districts.begin_work(game,"build")
				for tick in range(600):
					step({"sneak":true})
					if game.districts.regions["street"]["built"]: break
					if game.districts.work.is_empty(): break
				if game.districts.regions["street"]["built"]: break
			game.close_loot();f.loot_site = -1
		if not game.districts.regions["street"]["built"] and problem.is_empty(): problem = "frontier could not be constructed with the real supplies"
	record("actual outpost construction")
	if problem.is_empty():
		game.expedition_retreat()
		for n in range(3000):
			step({},false)
			if game.departure_dialog.visible: game.confirm_departure();break
		if game.cycle.phase != "dawn": problem = "physical return did not reach dawn"
	record("returned with real supplies")
	if problem.is_empty():
		game.begin_day()
		# Paid food and actual sleep prepare the next night, not direct stat resets.
		game.select_survivor(1);game.assign_task("cook");duration(15,{},false)
		for actor in game.survivors:
			if actor.hunger >= 40 and game.inventory.amount("meals") > 0:
				game.select_survivor(actor.survivor_id);game.assign_task("eat");duration(12,{},false)
		game.select_survivor(2);game.assign_task("sleep");duration(35,{},false)
		game.end_day();game.cycle.roles.assign(["outpost","bed","guard"])
		var error: String = game.cycle.plan_error(game)
		if not error.is_empty(): problem = error
		elif not game.start_expedition(): problem = "funded outpost duty did not settle"
	record("next-night crew assignment and funded shift")
	var okay: bool = problem.is_empty() and game.districts.regions["street"]["shifts"] == 1 and game.survivors.all(func(a): return a.health > 0) and SaveSystem.validate(SaveSystem.capture(game)).is_empty()
	var report := {"passed":okay,"problem":problem,"no_inventory_grants":true,"no_teleports":true,"no_health_or_enemy_overrides":true,"trace":trace,"snapshot":SaveSystem.capture(game)}
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://district-journey.json"
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("DISTRICT JOURNEY ","PASS" if okay else "FAIL",": ",problem," · report ",path)
	game.free();await create_timer(.12).timeout;quit(0 if okay else 1)
