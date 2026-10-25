extends SceneTree

const Policy := preload("res://tests/balance_bot.gd")


func _initialize() -> void:
	call_deferred("_run")


func simulate(game: Node2D, seconds: float, controls: Dictionary = {}) -> void:
	game.expedition_controls_override = controls
	game.advance_simulation(seconds)
	game.expedition_controls_override = null


func fail(message: String) -> void:
	printerr("PEOPLE PROCESS FAIL: " + message)
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
		fail("Refusing to overwrite an existing test slot")
		return
	root.add_child(game)
	game.set_process(false)
	if args[0] == "write":
		var policy := Policy.new()
		var report := policy.run(game, 3, true)
		if game.survivors.size() != 4 or report["alive"] != 4 or not report["save_error"].is_empty():
			fail("Three real days did not earn an actual new team member")
			return
		for actor: Survivor in game.survivors:
			game.scheduler.cancel(actor)
			actor.person.routine = false
		game.survivors[3].person.routine = true
		var expected := {"stock": game.inventory.snapshot(), "experience": game.survivors[3].person.experience.duplicate()}
		var proof := FileAccess.open(args[1] + ".expected", FileAccess.WRITE)
		proof.store_string(JSON.stringify(expected))
		proof.close()
		game.select_survivor(3)
		game.choose_destination("street")
		if not game.start_expedition(game.inventory.amount("tools") > 0, game.inventory.amount("medicine") > 0):
			fail("Recruited member could not depart")
			return
		simulate(game, 0.5, {"axis": 1.0})
		game.persistence_enabled = true
		game.get_window().close_requested.emit()
		if not game.save_store.read_state()["ok"]:
			fail("Window close failed to persist dynamic recruited traveler")
			return
		print("PEOPLE PROCESS WRITE PASS: genuine three-day survival, paid recruitment and fourth-member expedition saved")
	elif args[0] == "read":
		if not game.paused or game.survivors.size() != 4 or not game.expedition.active or game.expedition.actor_id != 3 or game.survivors[3].person.persona != "he":
			fail("Startup did not rebuild and resume the recruited fourth traveler")
			return
		game.toggle_pause()
		simulate(game, 0.6, {"axis": -1.0})
		game.expedition_retreat()
		if game.expedition.active or not game.paused:
			fail("Recruited traveler could not physically return")
			return
		game.get_window().close_requested.emit()
		print("PEOPLE PROCESS READ PASS: fourth traveler restored, physically returned and saved without duplicate growth")
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1] + ".expected"))
		if not game.paused or game.survivors.size() != 4 or game.expedition.active or not game.survivors[3].person.routine:
			fail("Recruited roster/authorization did not survive third startup")
			return
		var stock_matches := true
		for resource in ShelterInventory.NAMES:
			stock_matches = stock_matches and game.inventory.amount(resource) == int(expected["stock"][resource])
		for skill in CharacterState.SKILLS:
			stock_matches = stock_matches and is_equal_approx(float(game.survivors[3].person.experience[skill]), float(expected["experience"][skill]))
		if not stock_matches:
			fail("Own loadout round trip duplicated or lost goods/experience")
			return
		if game.people.bonds.size() != 6 or game.people.daily.size() < 3:
			fail("Relationships or genuine daily ledger were reset")
			return
		print("PEOPLE PROCESS VERIFY PASS: four identities, paid stock, capped growth, relationships and care policy persisted once")
		game.free()
		quit(0)
