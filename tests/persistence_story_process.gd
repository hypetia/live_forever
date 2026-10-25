extends SceneTree

const Policy := preload("res://tests/balance_bot.gd")


func _initialize() -> void:
	call_deferred("_run")


func fail(message: String) -> void:
	printerr("STORY PROCESS FAIL: " + message)
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
		fail("Refusing to overwrite an existing slot")
		return
	root.add_child(game)
	game.set_process(false)
	if args[0] == "write":
		var policy := Policy.new()
		policy.handle_stories = false
		var report := policy.run(game, 2)
		if report["alive"] != 3 or game.story.pending.get("id") != "lin_radio" or not report["save_error"].is_empty():
			fail("Real two-day run did not earn pending workshop conversation")
			return
		for actor: Survivor in game.survivors:
			game.scheduler.cancel(actor)
			actor.person.routine = false
		game.story.guide_hidden = true
		var proof := FileAccess.open(args[1] + ".expected", FileAccess.WRITE)
		proof.store_string(JSON.stringify({"stock": game.inventory.snapshot(), "guide": game.story.guide}))
		proof.close()
		game.persistence_enabled = true
		game.get_window().close_requested.emit()
		if not game.save_store.read_state()["ok"]:
			fail("Normal close did not persist story")
			return
		print("STORY PROCESS WRITE PASS: actual two-day chapter and guidance saved on close")
	elif args[0] == "read":
		if not game.paused or game.story.pending.get("id") != "lin_radio" or not game.story.guide_hidden or not game.story.history.is_empty():
			fail("Pending choice or tutorial preference did not restore")
			return
		if not game.story.resolve(game, false):
			fail("Restored chapter could not take its real free branch")
			return
		game.get_window().close_requested.emit()
		print("STORY PROCESS READ PASS: restored decision resolved and saved exactly once")
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1] + ".expected"))
		if not game.paused or not game.story.pending.is_empty() or game.story.history.size() != 1 or game.story.history[0]["outcome"] != "b" or game.story.guide != expected["guide"]:
			fail("Resolved outcome or actual guidance repeated or disappeared")
			return
		for resource in ShelterInventory.NAMES:
			if game.inventory.amount(resource) != int(expected["stock"][resource]):
				fail("Free conversation changed supplies on restart")
				return
		if game.story.resolve(game, true):
			fail("Completed chapter repeated its payment or reward")
			return
		print("STORY PROCESS VERIFY PASS: history, guide and stock survive third startup without repeated rewards")
		game.free()
		quit(0)
