extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2); return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		game.inventory.deposit({"materials":20,"tools":4},"persistence fixture")
		okay = game.expansion.start_job(game,"workbench_2")
		game.advance_simulation(8)
		okay = okay and game.facilities.levels["workbench"] == 1 and game.expansion.jobs[0]["elapsed"] > 0
	elif args[0] == "read":
		okay = game.load_game() and game.facilities.levels["workbench"] == 1 and game.expansion.jobs[0]["elapsed"] > 0
		game.paused = false
		game.advance_simulation(60)
		okay = okay and game.facilities.levels["workbench"] == 2 and game.expansion.jobs.is_empty()
	elif args[0] == "verify":
		okay = game.load_game() and game.facilities.levels["workbench"] == 2 and game.facility.tier == 2
		game.paused = false
		game.select_survivor(0)
		var before: Dictionary = game.inventory.snapshot()
		okay = okay and not game.expansion.start_job(game,"pistol") and game.inventory.snapshot() == before
		okay = okay and game.expansion.start_job(game,"workbench_3")
		game.cancel_selected()
		game.cancel_selected()
		okay = okay and game.inventory.snapshot() == before and game.facilities.levels["workbench"] == 2
	else: okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("FACILITIES PROCESS %s %s: partial upgrade, resumed construction, persistent unlocks and exact cancellation" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
