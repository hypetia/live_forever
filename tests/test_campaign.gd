extends "res://tests/test_shelter.gd"


func campaign() -> Node2D:
	var scene: Node2D = load("res://scenes/campaign.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	return scene


func valid(scene: Node2D, message: String) -> void:
	var error := SaveSystem.validate(SaveSystem.capture(scene))
	expect(error.is_empty(), message + ": " + error)


func night(scene: Node2D) -> void:
	scene.end_day()
	expect(scene.cycle.phase == "planning" and scene.paused, "day ends in frozen role planning")


func _run() -> void:
	var scene := campaign()
	expect(scene.cycle.phase == "day" and not scene.expedition.active, "new campaign starts in the physical shelter")
	var stock: Dictionary = scene.inventory.snapshot()
	expect(not scene.start_expedition() and scene.inventory.snapshot() == stock, "daytime cannot directly enter scavenging or spend equipment")
	valid(scene, "initial campaign save")
	scene.request_expedition()
	expect(scene.end_day_dialog.visible and scene.paused, "end day first asks for a concrete action confirmation")
	scene.end_day_dialog.get_cancel_button().pressed.emit()
	expect(scene.cycle.phase == "day" and not scene.paused, "cancel day end retains the actual daytime")
	scene.free()

	scene = campaign()
	scene.select_survivor(2)
	scene.assign_task("craft")
	advance(scene, 1)
	var materials: int = scene.inventory.amount("materials")
	night(scene)
	expect(scene.inventory.amount("tools") == 0 and scene.inventory.amount("materials") >= materials, "skipping daylight cancels work and never grants free completion")
	expect(scene.survivors.all(func(actor): return actor.orders.is_empty() and actor.route.is_empty()), "all daytime jobs release their workers at sunset")
	expect(is_equal_approx(scene.simulation_time, 360), "first sunset is exactly 20:00")
	expect(scene.cycle.roles.size() == 3 and scene.cycle.scavenger() == 2, "night screen has a role for everyone and prefers a healthy scout")
	scene.cycle.loadout = {"medicine": 1}
	stock = scene.inventory.snapshot()
	valid(scene, "planning with draft loadout")
	expect(scene.inventory.snapshot() == stock, "draft equipment has no inventory side effects")
	expect(scene.start_expedition(), "valid night roles commit one departure")
	expect(scene.expedition.capacity == 14 and scene.expedition.bag["medicine"] == 1 and scene.inventory.amount("medicine") == 0, "scout capacity and exact paid equipment reach the field")
	expect(not scene.start_expedition(), "second confirmation cannot double-spend or begin another trip")
	valid(scene, "active night")
	var field: ExpeditionState = scene.expedition
	field.player_x = 300
	field._search(8, scene.survivors[2])
	expect(field.loot_site == 0 and field.bag["raw_food"] == 0 and field.sites[0]["contents"]["raw_food"] == 2, "search opens real container without silently taking its contents")
	var xp: float = scene.survivors[2].person.experience["scout"]
	for index in range(6):
		expect(field.take_loot("raw_food", 1, scene.survivors[2]) == 1, "manual transfer debits the container")
		expect(field.put_loot("raw_food", 1) == 1, "putting back conserves stock")
	expect(scene.survivors[2].person.experience["scout"] == xp, "take-put loops cannot farm experience")
	expect(field.take_loot("raw_food", 100, scene.survivors[2]) == 2 and field.take_loot("water", 100, scene.survivors[2]) == 1, "take all still respects actual contents")
	expect(scene.inventory.amount("raw_food") == 4, "field cargo never credits the shelter remotely")
	field.loot_site = -1
	field._search(0.01, scene.survivors[2])
	expect(field.loot_site == 0 and field.discovered.has(0), "already searched container remains open without another timed search")
	field.loot_site = -1
	field.player_x = 110
	var before_fatigue: float = scene.survivors[1].fatigue
	scene.expedition_retreat()
	scene.confirm_departure()
	expect(scene.cycle.phase == "dawn" and scene.paused and not field.active, "early physical return enters the morning ledger")
	expect(is_equal_approx(scene.simulation_time, 660) and CampaignCycle.minute(scene.simulation_time) == 360, "early return advances to next 06:00 rather than permitting repeated nights")
	expect(scene.inventory.amount("raw_food") == 6 and scene.inventory.amount("water") == 5 and scene.inventory.amount("medicine") == 1, "actual loot and unused equipment return exactly once")
	expect(scene.survivors[1].fatigue < before_fatigue, "assigned sleeper recovers in the night settlement")
	valid(scene, "morning summary")
	var snapshot: Dictionary = SaveSystem.capture(scene)
	scene._settle_night([])
	expect(SaveSystem.capture(scene) == snapshot, "repeating settlement cannot grant loot, rest or damage again")
	scene.begin_day()
	expect(scene.cycle.phase == "day" and not scene.paused, "acknowledging morning begins a new playable daytime")
	scene.begin_day()
	expect(scene.simulation_time == 660, "repeating morning acknowledgement cannot skip days")
	valid(scene, "new day after a genuine night")
	scene.free()

	scene = campaign()
	expect(scene.place_build("bed", 0), "construction reserves a valid physical slot")
	expect(scene.inventory.amount("materials") == 4 and scene.cycle.bed_count() == 1, "blueprint consumes actual material but does not activate a bed early")
	expect(scene.survivors[0].route.size() == 3, "builder routes downstairs instead of remote construction")
	valid(scene, "builder walking to a paid blueprint")
	advance(scene, 13)
	expect(scene.cycle.builds[0]["elapsed"] > 0 and scene.cycle.bed_count() == 1, "construction time begins after physical arrival")
	valid(scene, "construction progress")
	advance(scene, 40)
	expect(scene.cycle.bed_count() == 2 and scene.cycle.builds[0]["state"] == "complete", "completed construction creates usable bed capacity")
	scene.survivors[0].fatigue = 90
	expect(scene._start_action("sleep", 0, CampaignCycle.SLOTS[0]), "extra physical bed accepts a rest action")
	advance(scene, 23)
	expect(scene.survivors[0].fatigue < 35 and scene.survivors[0].completed_by_task["sleep"] == 1, "extra bed actually restores fatigue and records the same rest task")
	valid(scene, "secondary bed completion ledger")
	scene.free()

	scene = campaign()
	scene.place_build("bed", 0)
	advance(scene, 2)
	scene.cancel_selected()
	expect(scene.cycle.builds.is_empty() and scene.inventory.amount("materials") == 8, "cancel construction returns held cost once")
	scene.cancel_selected()
	expect(scene.inventory.amount("materials") == 8, "repeated cancel cannot duplicate construction materials")
	valid(scene, "cancelled construction while approaching stairs")
	var water: int = scene.inventory.amount("water")
	scene.begin_drink()
	expect(scene.inventory.amount("water") == water and not scene.cycle.actions.is_empty(), "water click starts a trip rather than remote hydration")
	advance(scene, 20)
	expect(scene.inventory.amount("water") == water - 1 and scene.survivors[0].person.thirst < 5, "actor physically reaches water and drinks one real unit")
	valid(scene, "completed physical hydration")
	night(scene)
	scene.cycle.roles.assign(["bed", "bed", "guard"])
	expect(not scene.cycle.plan_error(scene).is_empty() and not scene.start_expedition(), "bed overbooking prevents night confirmation")
	scene.cycle.roles.assign(["guard", "bed", "floor"])
	expect(scene.start_expedition() and scene.cycle.phase == "dawn", "all-stay night still resolves roles and advances the day")
	valid(scene, "all-stay morning")
	scene.free()

	scene = campaign()
	night(scene)
	scene.start_expedition()
	scene.expedition.player_x = 300
	scene.expedition._search(8, scene.survivors[scene.selected_id])
	scene._loot_open = true
	scene.simulation_time = scene.cycle.night_end - 0.03
	stock = scene.inventory.snapshot()
	advance(scene, 0.1)
	expect(scene.cycle.phase == "returning" and scene.expedition.active and not scene._loot_open and scene.expedition.loot_site == -1, "dawn deadline closes inventory and starts actual retreat rather than teleporting cargo home")
	expect(scene.inventory.snapshot() == stock and scene.expedition.player_x > 145, "late traveller remains in the field until physically extracted")
	advance(scene, 5)
	expect(scene.cycle.phase == "dawn" and not scene.expedition.active, "late retreat follows the real path to extraction")
	valid(scene, "late return summary")
	scene.free()

	for guarded in [false, true]:
		scene = campaign()
		scene.simulation_time = 1800
		scene.cycle.seed = 43
		scene.enter_night_planning()
		scene.cycle.roles.assign(["guard", "guard", "floor"] if guarded else ["floor", "bed", "floor"])
		expect(scene.start_expedition(), "test night commits an all-stay assignment")
		expect(scene.inventory.amount("raw_food") == (4 if guarded else 2), "guard assignment changes actual raid loss")
		expect(scene.cycle.report.any(func(line): return "袭击" in line), "morning explains the real defensive outcome")
		valid(scene, "raid outcome is persistent")
		scene.free()

	scene = campaign()
	var store := SaveSystem.new()
	store.path = "res://tests/fixtures/v6_campaign.json"
	var legacy := store.read_state()
	expect(legacy["ok"] and legacy["migrated"], "genuine v0.9 schema-six process save migrates")
	if legacy["ok"]:
		expect(SaveSystem.apply_state(scene, legacy["data"]).is_empty(), "legacy progress applies to the new playable campaign")
		expect(scene.upkeep.returns["works"] > 0 and scene.goals.next_trade_day > 1, "old real factory returns and paid trade ledger are retained")
		valid(scene, "legacy campaign import produces a valid new-format state")
	scene.free()
	scene = campaign()
	scene.survivors[0].hunger = 90
	scene.survivors[0].health = 60
	scene.assign_task("heal")
	expect(scene.survivors[0].orders.is_empty() and scene.inventory.amount("medicine") == 1, "medicine cannot substitute for food when the only problem is starvation")
	scene.survivors[0].injury = 40
	scene.assign_task("heal")
	advance(scene, 20)
	expect(scene.survivors[0].injury == 0 and scene.survivors[0].health < 61, "medicine still treats wounds in a starving patient but grants no food-like health restoration")
	scene.free()
	scene = campaign()
	scene.survivors[0].position = scene.stove.work_position()
	scene.assign_task("cook")
	advance(scene, 0.5)
	scene.inventory.try_take({"medicine": 1}, "explicit rejection fixture")
	scene.survivors[0].health = 60
	scene.survivors[0].injury = 40
	scene.assign_task("heal")
	expect(scene.survivors[0].orders == ["cook"] and scene.survivors[0].work_elapsed > 0, "rejected replacement preserves the ongoing valid task and progress")
	scene.cancel_selected()
	scene.place_build("bed", 2)
	advance(scene, 0.5)
	scene.scheduler.navigation.stairs_open = false
	expect(not scene.move_selected(Vector2(300, 640)) and scene.cycle.builds.size() == 1 and scene.inventory.amount("materials") == 4, "unreachable movement keeps the current blueprint and held materials")
	valid(scene, "rejected movement leaves a valid original action")
	scene.free()
	scene = campaign()
	scene.end_day()
	scene.cycle.loadout = {"medicine": 1}
	scene.start_expedition()
	var patient: Survivor = scene.survivors[scene.selected_id]
	patient.health = 60
	patient.hunger = 90
	patient.injury = 0
	patient.infection = 0
	expect(not scene.expedition.use_medicine(patient) and scene.expedition.bag["medicine"] == 1, "field medicine also cannot replace food or waste equipment on pure starvation")
	scene.free()
	print("CAMPAIGN RESULT: %d checks, %d failures" % [checks, failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
