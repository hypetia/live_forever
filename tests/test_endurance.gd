extends "res://tests/test_shelter.gd"

const Policy := preload("res://tests/balance_bot.gd")


func store_report(directory: String, name: String, report: Dictionary) -> void:
	var file := FileAccess.open(directory.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://endurance_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for mode in ["three30", "five60"]:
		var game := make_scene()
		var days := 30 if mode == "three30" else 60
		var report := Policy.new().run(game, days, mode == "five60")
		store_report(directory, mode, report)
		expect(report["days_elapsed"] >= days - 0.0001 and report["alive"] == (3 if mode == "three30" else 5) and not report["game_over"], mode + " survives every actual simulation second")
		expect(report["save_error"].is_empty(), mode + " complete world remains saveable")
		expect(report["daily"].size() == days and game.people.daily.size() == 30, mode + " report retains complete timeline while save history stays bounded")
		expect(report["trips"] >= days and report["drinks"] >= days and report["repairs"] >= 3, mode + " requires repeated paid exploration, water and structural maintenance")
		expect(game.survivors.all(func(a): return a.health >= 60 and a.person.thirst < 80 and a.hunger < 95), mode + " needs remain manageable without restored health or free resources")
		expect(report["stories"].size() >= (3 if mode == "three30" else 5) and report["stories"].size() <= 8, mode + " encounters distinct paid or free chapters without infinite rewards")
		var bounded := true
		for actor: Survivor in game.survivors:
			for amount in actor.person.experience.values(): bounded = bounded and amount <= 180
		for world: ExpeditionState in game.regions.values():
			bounded = bounded and world.enemies.size() <= 5
			for enemy in world.enemies: bounded = bounded and enemy["hp"] in [0, 40]
		expect(bounded and report["level"] <= 3, mode + " skills, enemies and upgrades remain bounded at late game")
		var restored := make_scene()
		expect(SaveSystem.apply_state(restored, SaveSystem.capture(game)).is_empty() and restored.people.daily.size() == 30 and restored.story.history == game.story.history, mode + " late-game ledger and story outcomes restore exactly")
		print("ENDURANCE VERIFIED %s: %.2f days, %d alive, %d trips" % [mode, report["days_elapsed"], report["alive"], report["trips"]])
		restored.free()
		game.free()
	var game := make_scene()
	var baseline := Policy.new().run(game, 3, true)
	expect(baseline["alive"] == 4, "hardship setup first earns actual recruitment and three days of supplies")
	for actor: Survivor in game.survivors: game.scheduler.cancel(actor)
	game.scheduler.mark_dead(game.survivors[1], "独立压力测试：伤亡夹具")
	game.survivors[2].health = 65
	game.survivors[2].injury = 45
	game.survivors[2].infection = 35
	game.upkeep.integrity = 18
	for resource in ["raw_food", "water", "fuel", "medicine"]:
		var retained := 0 if resource == "medicine" else 1
		game.inventory.try_take({resource: maxi(0, game.inventory.amount(resource) - retained)}, "独立压力测试：低库存夹具")
	var incident := SaveSystem.capture(game)
	expect(SaveSystem.validate(incident).is_empty(), "explicit adverse fixture is a legal playable state")
	var report := Policy.new().run(game, 12, true)
	report["fixture"] = {"day_elapsed": 3, "permanent_loss": "xu", "chen_health": 65, "chen_injury": 45, "chen_infection": 35, "integrity": 18, "remaining_raw_water_fuel": 1, "remaining_medicine": 0}
	store_report(directory, "recovery", report)
	expect(report["days_elapsed"] >= 14.9999 and not report["game_over"], "care, search and paid replacement recover after real time advances twelve more days")
	expect(report["alive"] == 5 and game.survivors.size() == 6 and game.people.deaths == ["xu"], "replacement uses distinct available identities without resurrecting the lost member")
	expect(game.survivors[2].health >= 60 and game.survivors[2].infection < 30 and game.upkeep.integrity >= 40, "real medicine and repairs restore the injured scout and damaged shelter")
	expect(report["save_error"].is_empty() and game.story.history.any(func(e): return e["id"] == "remembrance"), "recovery preserves loss, grief and authored remembrance in a valid save")
	print("ENDURANCE VERIFIED recovery: %.2f days, %d alive, %d trips" % [report["days_elapsed"], report["alive"], report["trips"]])
	game.free()
	print("ENDURANCE RESULT: %d checks, %d failures; 3 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)
