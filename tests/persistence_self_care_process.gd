extends SceneTree
func _initialize() -> void: call_deferred("_run")
func step(game: Node2D, seconds: float) -> void:
	for n in range(ceili(seconds*60)): game.advance_simulation(1.0/60)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2);return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game);game.set_process(false);game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		game.inventory.deposit({"meals":1},"declared cross-process autonomy fixture")
		game.survivors[0].person.thirst = 95;game.survivors[0].hunger = 85
		game.self_care.set_enabled(game,game.survivors[1],false)
		step(game,.1)
		okay = game.survivors[0].self_care_kind == "drink" and game.inventory.amount("water") == 4
	elif args[0] == "read":
		okay = game.load_game()
		var actor: Survivor = game.survivors[0]
		okay = okay and actor.self_care_kind == "drink" and not game.self_care.enabled(game.survivors[1]) and game.inventory.amount("water") == 4
		var snapshot := SaveSystem.capture(game);step(game,3)
		okay = okay and snapshot == SaveSystem.capture(game)
		game.toggle_pause()
		for n in range(3600):
			step(game,1.0/60)
			if actor.state == Survivor.TaskState.WORKING and actor.orders == ["eat"]: break
		okay = okay and game.people.drinks == 1 and game.inventory.amount("water") == 3 and game.inventory.amount("meals") == 0 and actor.held_cost == {"meals":1} and actor.self_care_kind == "eat"
	elif args[0] == "verify":
		okay = game.load_game()
		var actor: Survivor = game.survivors[0]
		okay = okay and actor.self_care_kind == "eat" and actor.held_cost == {"meals":1} and game.inventory.amount("meals") == 0 and game.people.drinks == 1 and not game.self_care.enabled(game.survivors[1])
		game.toggle_pause();game.cancel_selected()
		okay = okay and game.inventory.amount("meals") == 1 and actor.self_care_kind.is_empty()
		step(game,7)
		okay = okay and actor.orders.is_empty() and game.inventory.amount("meals") == 1
		step(game,12)
		okay = okay and actor.completed_by_task["eat"] == 1 and game.inventory.amount("meals") == 0 and game.people.drinks == 1
	else: okay = false
	var result: Dictionary = game.save_store.write_state(game)
	okay = result["ok"] and okay
	print("SELF CARE PROCESS %s %s: real water travel, paid meal, independent policy and cancellation survive separate processes; %s" % [args[0],"PASS" if okay else "FAIL",result["message"]])
	game.free();await create_timer(.12).timeout;quit(0 if okay else 1)
