extends SceneTree

const Policy := preload("res://tests/balance_bot.gd")


func _initialize() -> void:
	call_deferred("_run")


func fail(message: String) -> void:
	printerr("GOALS PROCESS FAIL: " + message)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read", "verify"]:
		fail("Usage: -- write|read|verify <fresh-slot>")
		return
	var game: Node2D = load("res://scenes/shelter.tscn").instantiate()
	game.save_store.path = args[1]
	game.persistence_enabled = args[0] != "write"
	if args[0] == "write" and game.save_store.has_save():
		game.free()
		fail("Refusing to overwrite existing slot")
		return
	root.add_child(game)
	game.set_process(false)
	if args[0] == "write":
		var policy := Policy.new()
		policy.handle_projects = false
		var report := policy.run(game, 3)
		if report["alive"] != 3:
			fail("Three real days did not retain the team")
			return
		if not game.goals.notes.has("works:1"):
			game.choose_destination("works")
			if not game.start_expedition(true, true): fail("Survey could not depart"); return
			policy._trip(1)
		if not game.goals.advance(game, "radio") or not game.goals.trade(game, "medicine"):
			fail("Real returned evidence or paid aid did not qualify")
			return
		for actor: Survivor in game.survivors:
			game.scheduler.cancel(actor)
			actor.person.routine = false
		var proof := FileAccess.open(args[1] + ".expected", FileAccess.WRITE)
		proof.store_string(JSON.stringify({"stock": game.inventory.snapshot(), "goals": game.goals.snapshot()}))
		proof.close()
		game.persistence_enabled = true
		game.get_window().close_requested.emit()
		if not game.save_store.read_state()["ok"]: fail("Window close did not save projects"); return
		print("GOALS PROCESS WRITE PASS: real factory survey and paid aid saved after normal close")
	elif args[0] == "read":
		if not game.paused or game.goals.stages["radio"] != 1 or game.goals.trades["medicine"] != 1 or not game.goals.notes.has("works:1"):
			fail("Survey stage and aid history did not restore")
			return
		if game.goals.trade(game, "materials"):
			fail("Restart bypassed shared aid cooldown")
			return
		game.get_window().close_requested.emit()
		print("GOALS PROCESS READ PASS: survey, spending and common cooldown restore without rewards")
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1] + ".expected"))
		if not game.paused or game.goals.stages["radio"] != 1 or game.goals.trades["medicine"] != 1 or game.goals.field_notes.size() != 0:
			fail("Third startup altered objective progress")
			return
		for resource in ShelterInventory.NAMES:
			if game.inventory.amount(resource) != int(expected["stock"][resource]): fail("Restart changed paid inventory"); return
		if game.goals.next_trade_day != expected["goals"]["next_trade_day"] or game.goals.spent["medicine"] != 2:
			fail("Aid accounting changed across restart")
			return
		print("GOALS PROCESS VERIFY PASS: exact paid stock, notes, construction stage and cooldown survived three processes")
		game.free()
		quit(0)
