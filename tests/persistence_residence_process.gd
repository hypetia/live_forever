extends SceneTree
## Four independent processes span paid work, prepared convoy, dawn and reload.
func _initialize() -> void:
	call_deferred("_run")

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
		# Explicit serialization fixture; the separate journey has no resource injection.
		game.simulation_time = 2820
		game.residence.surveyed.append("row")
		game.residence.cleared.append("row")
		game.inventory.deposit({"meals":8,"water":12,"fuel":3,"tools":2},"convoy serialization fixture")
		okay = game.expansion.start_job(game,"pack_row")
		for tick in range(600): game.advance_simulation(1.0/60)
		okay = okay and game.expansion.jobs.size() == 1 and game.expansion.jobs[0]["elapsed"] > 0
	elif args[0] == "pack":
		okay = game.load_game()
		game.paused = false
		for tick in range(3600): game.advance_simulation(1.0/60)
		okay = okay and game.expansion.jobs.is_empty() and game.residence.convoy == "row" and game.residence.current == "shelter"
	elif args[0] == "move":
		okay = game.load_game() and game.residence.convoy == "row"
		game.end_day()
		okay = okay and game.start_expedition() and game.residence.current == "row" and game.cycle.phase == "dawn"
	elif args[0] == "verify":
		okay = game.load_game() and game.residence.current == "row" and game.residence.moves.size() == 1
		var before := SaveSystem.capture(game)
		game._settle_night([])
		okay = okay and SaveSystem.capture(game) == before and not game.residence.cancel_convoy(game)
	else: okay = false
	game.persistence_enabled = true
	var write_result: Dictionary = game.save_store.write_state(game)
	if not okay or not write_result["ok"]: print("DETAIL ",write_result," JOBS ",game.expansion.jobs," CREW ",str(game.survivors.map(func(a):return [a.position,a.state,a.fatigue])))
	okay = okay and write_result["ok"]
	print("RESIDENCE PROCESS %s %s: paid work, convoy, one-time move and salvage" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
