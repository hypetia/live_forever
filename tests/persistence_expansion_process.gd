extends SceneTree
## Three real processes verify an interrupted reload and exact gear accounting.
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
	var ok := true
	if args[0] == "write":
		# Explicit serialization fixture, not a claim of natural acquisition.
		game.expansion.grant("pistol")
		game.expansion.grant("vest", "chen")
		game.expansion.grant("coat", "chen")
		game.expansion.equip(game, 2, 2)
		game.expansion.ammo = 16
		game.end_day()
		game.expansion.ammo_loadout = 16
		ok = game.start_expedition()
		game.expedition.facing = -1
		game.expedition.attack(game.survivors[2])
		game.expedition.tick(0.12, game.survivors[2], {})
		game.expedition.reload(game.survivors[2])
		game.expedition.tick(0.4, game.survivors[2], {})
		game.expansion.refresh_slots(game.expedition, game.survivors[2])
		game.paused = true
		game.persistence_enabled = true
		ok = ok and game.save_game()
	elif args[0] == "read":
		game.persistence_enabled = true
		ok = game.load_game() and game.expedition.magazine == 5 and game.expedition.reserve_ammo == 10 and is_equal_approx(game.expedition.reload_remaining, 1.0) and game.survivors[2].weapon_item["durability"] == 99
		if ok:
			game.paused = false
			game.expedition.tick(1.01, game.survivors[2], {})
			ok = game.expedition.magazine == 6 and game.expedition.reserve_ammo == 9
			game.expedition_retreat()
			ok = ok and game.expansion.ammo == 15 and game.cycle.phase == "dawn" and game.save_game()
	elif args[0] == "verify":
		game.persistence_enabled = true
		ok = game.load_game() and game.expansion.ammo == 15 and game.survivors[2].weapon_item["durability"] == 99 and game.expedition.extra_slots == 0
		var before := SaveSystem.capture(game)
		game._settle_night([])
		ok = ok and before == SaveSystem.capture(game)
	else: ok = false
	print("EXPANSION PROCESS %s %s: interrupted reload, canonical durability, one-time ammo return" % [args[0], "PASS" if ok else "FAIL"])
	game.free()
	await create_timer(0.12).timeout
	quit(0 if ok else 1)
