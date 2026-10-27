extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2); return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game); ArchiveFixture.campaign(game)
	game.set_process(false)
	game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		okay = game.director.accept(game,"meal_basic")
		game.scheduler.submit(game.survivors[0],"cook")
		game.advance_simulation(22)
		okay = okay and game.director.progress == 2 and game.director.status == "active"
	elif args[0] == "read":
		okay = game.load_game() and game.director.progress == 2
		game.paused = false
		game.scheduler.submit(game.survivors[0],"cook")
		game.advance_simulation(15)
		okay = okay and game.director.status == "ready" and game.director.claim(game)
	elif args[0] == "verify":
		okay = game.load_game() and game.director.status == "claimed" and game.director.rewards_received == 1
		var before: Dictionary = game.inventory.snapshot()
		okay = okay and not game.director.claim(game) and not game.director.accept(game,"meal_basic") and game.inventory.snapshot() == before
	else: okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("DIRECTOR PROCESS %s %s: actual cooking, persistent progress and one-time supply exchange" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
