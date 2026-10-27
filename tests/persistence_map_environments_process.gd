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
		game.inventory.deposit({"tools":1},"declared clearance persistence fixture")
		game.end_day();game.cycle.loadout = {"tools":1};okay = game.start_expedition()
		var field: ExpeditionState = game.expedition
		for enemy in field.enemies: enemy["hp"] = 0;enemy["mode"] = "dead"
		field.player_x = field.route_x();field.condition = 1;field._clear_route(1)
		game.regions["clinic"].route_open = true
	elif args[0] == "read":
		okay = game.load_game()
		var field: ExpeditionState = game.expedition
		okay = okay and field.condition == 1 and field.route_progress == 1 and field.route_tool and field.bag["tools"] == 1 and game.regions["clinic"].route_open
		field._clear_route(2)
		okay = okay and field.route_open and field.bag["tools"] == 0
		field.tick(.01,game.survivors[field.actor_id],{"climb":1})
		field.tick(.8,game.survivors[field.actor_id],{})
		okay = okay and field.climb_target == 1 and field.climb_progress == .4
	elif args[0] == "climb":
		okay = game.load_game()
		var field: ExpeditionState = game.expedition
		okay = okay and field.route_open and field.condition == 1 and field.player_x == field.route_x() and field.climb_target == 1 and field.player_y == 532
		field.tick(1.3,game.survivors[field.actor_id],{})
		okay = okay and field.floor_level == 1 and game._route_controls(110,0,true).get("climb") == -1
		game.cycle.return_requested = true
		for step in range(1200):
			field.tick(.02,game.survivors[field.actor_id],game._expedition_controls())
			if game.departure_dialog.visible: break
		okay = okay and game.departure_dialog.visible
		game.confirm_departure()
		okay = okay and game.cycle.phase == "dawn"
	elif args[0] == "verify":
		okay = game.load_game() and game.cycle.phase == "dawn"
		okay = okay and game.expedition.route_open and game.regions["clinic"].route_open and game.inventory.amount("tools") == 0
		var before := SaveSystem.capture(game)
		game._settle_night([]);game.confirm_departure()
		okay = okay and before == SaveSystem.capture(game)
	else: okay = false
	okay = game.save_store.write_state(game)["ok"] and okay
	print("MAP ENVIRONMENTS PROCESS %s %s: conditions, persistent clearance, mid-climb and physical return" % [args[0],"PASS" if okay else "FAIL"])
	game.free()
	await create_timer(.12).timeout
	quit(0 if okay else 1)
