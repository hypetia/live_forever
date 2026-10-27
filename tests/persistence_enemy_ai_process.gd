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
		game.end_day(); game.start_expedition()
		var field: ExpeditionState = game.expedition
		var enemy: Dictionary = field.enemies[0]
		enemy["x"] = field.ladder_x(); enemy["climb_target"] = 1; enemy["climb_progress"] = 0.4
		enemy["target_floor"] = 1; enemy["target"] = 1510; enemy["memory"] = 4
		enemy["mode"] = "chase"; enemy["suspicion"] = 100
	elif args[0] == "read":
		okay = game.load_game()
		var field: ExpeditionState = game.expedition
		var enemy: Dictionary = field.enemies[0]
		okay = okay and enemy["memory"] == 4 and enemy["climb_progress"] == 0.4 and field.enemy_y(enemy) == 532
		for step in range(100): field._tick_enemy(enemy,game.survivors[field.actor_id],0.02)
		okay = okay and enemy["floor"] == 1 and enemy["climb_target"] == -1
		field.player_x = 90
		game.expedition_retreat(); game.confirm_departure()
		okay = okay and game.cycle.phase == "dawn"
	elif args[0] == "verify":
		okay = game.load_game() and game.cycle.phase == "dawn"
		okay = okay and game.cycle.report.any(func(line): return line.begins_with("【安防】"))
		var before := SaveSystem.capture(game)
		game._settle_night([])
		okay = okay and before == SaveSystem.capture(game)
	else: okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("ENEMY AI PROCESS %s %s: continuous ladder pursuit and historical defense report" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
