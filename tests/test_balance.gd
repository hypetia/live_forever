extends "res://tests/test_shelter.gd"

const Policy := preload("res://tests/balance_bot.gd")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://balance_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(directory)
	for mode in ["three", "five", "no_supply", "no_care"]:
		var scene := make_scene()
		var policy := Policy.new()
		var report := policy.run(scene, 14, mode == "five", mode != "no_supply", mode != "no_care")
		var file := FileAccess.open(directory.path_join(mode + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		file.close()
		expect(report["save_error"].is_empty(), mode + " ends with fully valid characters, jobs, stock and worlds")
		if mode in ["three", "five"]:
			var expected := 5 if mode == "five" else 3
			expect(report["days_elapsed"] >= 13.9999 and report["alive"] == expected and not report["game_over"], mode + " genuinely survives fourteen complete days")
			expect(report["trips"] >= 14 and report["drinks"] >= 14 and report["recovered"]["raw_food"] > 0, mode + " still needs repeated real exploration and paid drinking")
			expect(report["level"] > 0 and report["repairs"] > 0, mode + " pays for actual bounded upgrades and maintenance")
			expect(report["daily"].size() == 14, mode + " records every calendar boundary without skipping days")
			expect(scene.survivors.all(func(a): return a.health >= 60 and a.person.thirst < 80 and a.hunger < 95), mode + " keeps needs manageable through care rather than invulnerability")
			expect(scene.survivors.any(func(a): return a.person.level("craft") > 0 or a.person.level("scout") > 0), mode + " earns real growth while surviving")
			var bounded := true
			for world: ExpeditionState in scene.regions.values():
				bounded = bounded and world.enemies.size() <= 5
				for enemy in world.enemies: bounded = bounded and enemy["hp"] in [0, 40]
			expect(bounded, mode + " never relies on escalating monster health or unbounded counts")
			if mode == "five": expect(report["peak_people"] == 5 and scene.inventory.amount("medicine") >= 0, "two distinct paid recruits remain within the small-team cap")
		else:
			expect(report["game_over"] and report["alive"] == 0 and report["days_elapsed"] < 14, mode + " has an actual failure consequence")
			if mode == "no_supply": expect(report["trips"] == 0 and report["recovered"].values().all(func(n): return n == 0), "base care alone cannot invent supplies")
			else: expect(report["stock"]["raw_food"] > 0 and report["drinks"] == 0, "stockpiling without authorized care does not feed or hydrate anyone")
		print("BALANCE VERIFIED %s: %.2f days, %d alive, %d real trips, %d drinks" % [mode, report["days_elapsed"], report["alive"], report["trips"], report["drinks"]])
		scene.free()
	print("BALANCE RESULT: %d checks, %d failures; 4 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)
