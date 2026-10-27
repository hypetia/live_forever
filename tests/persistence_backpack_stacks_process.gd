extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(2); return
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game); ArchiveFixture.campaign(game); game.set_process(false)
	game.save_store.path = args[1]
	var okay := true
	if args[0] == "write":
		game.inventory.deposit({"water":24,"raw_food":1},"declared stack persistence fixture")
		game.end_day(); game.cycle.loadout = {"water":17,"raw_food":5}
		okay = game.start_expedition()
		game.expedition.player_x = 300
		game.expedition.loot_site = 0
		game.expedition.discovered.assign([0])
		okay = okay and game.expedition.used_capacity() == 8
	elif args[0] == "read":
		okay = game.load_game()
		var field: ExpeditionState = game.expedition
		okay = okay and field.bag["water"] == 17 and field.bag["raw_food"] == 5 and field.used_capacity() == 8 and field.stacked
		okay = okay and field.take_loot("raw_food",2,game.survivors[field.actor_id]) == 2 and field.put_loot("raw_food",1) == 1
		field.player_x = 90
		game.expedition_retreat(); game.confirm_departure()
		okay = okay and game.cycle.phase == "dawn" and game.inventory.amount("water") == 28 and game.inventory.amount("raw_food") == 6
	elif args[0] == "verify":
		okay = game.load_game() and not game.expedition.active and game.cycle.phase == "dawn"
		okay = okay and game.inventory.amount("water") == 28 and game.inventory.amount("raw_food") == 6
		var before := SaveSystem.capture(game)
		game._settle_night([]); game.confirm_departure()
		okay = okay and before == SaveSystem.capture(game)
	else: okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("BACKPACK PROCESS %s %s: exact physical quantities, slot grouping, transfer and one-time return" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
