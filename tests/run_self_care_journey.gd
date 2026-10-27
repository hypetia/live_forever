extends SceneTree
## New campaign, ordinary stock and needs. The only daytime orders are two
## initial cooking batches; no eat, drink or sleep commands, grants or resets.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game);game.set_process(false)
	var trace: Array = [{"event":"new campaign","snapshot":SaveSystem.capture(game)}]
	game.select_survivor(1);game.assign_task("cook");game.scheduler.submit(game.survivors[1],"cook")
	var okay := true
	for day in range(1,5):
		for n in range(13000):
			if game.cycle.phase != "day": break
			game.advance_simulation(1.0/30)
		trace.append({"event":"day %d natural sunset" % day,"snapshot":SaveSystem.capture(game)})
		okay = okay and game.cycle.phase == "planning" and SaveSystem.validate(SaveSystem.capture(game)).is_empty()
		if day < 4:
			game.cycle.roles.assign(["guard","bed","floor"])
			okay = game.start_expedition() and okay
			okay = okay and game.cycle.phase == "dawn"
			game.begin_day()
	var total_eaten := 0;var total_slept := 0
	for actor: Survivor in game.survivors:
		total_eaten += actor.completed_by_task["eat"];total_slept += actor.completed_by_task["sleep"]
	okay = okay and total_eaten == 4 and game.people.drinks == 1 and total_slept > 0 and game.survivors.all(func(a):return a.health>0)
	var report := {"passed":okay,"playable_days":4,"settled_nights":3,"no_inventory_grants":true,"no_teleports":true,"no_need_health_or_enemy_overrides":true,"manual_day_orders":["cook","cook"],"manual_eat_drink_sleep_orders":0,"meals_eaten":total_eaten,"water_uses":game.people.drinks,"day_naps":total_slept,"scope":"Starting-stock proof of care and honest shortage, not a self-sufficient economy or full campaign balance proof. No exploration or extra stock was supplied.","trace":trace}
	var args := OS.get_cmdline_user_args();var path: String = args[0] if not args.is_empty() else "user://self-care-journey.json"
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("SELF CARE JOURNEY ","PASS" if okay else "FAIL",": ",total_eaten," meals, ",game.people.drinks," water uses, ",total_slept," naps; ",path)
	game.free();await create_timer(.12).timeout;quit(0 if okay else 1)
