extends SceneTree
const Pilot := preload("res://tests/expansion_pilot.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://campaign-balance.json"
	var recruiting := args.has("--recruit")
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	if args.has("--resume"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--resume") + 1]))
		var snapshot: Dictionary = data["snapshot"]
		if not snapshot["campaign"].has("return_requested"): snapshot = SaveSystem.migrate_v9(snapshot)
		if not snapshot.has("facilities"): snapshot = SaveSystem.migrate_v10(snapshot)
		if not snapshot.has("director"): snapshot = SaveSystem.migrate_v11(snapshot)
		if not snapshot["expedition"]["enemies"][0].has("home_floor"): snapshot = SaveSystem.migrate_v12(snapshot)
		if not snapshot["expedition"].has("stacked"): snapshot = SaveSystem.migrate_v13(snapshot)
		if not snapshot["expedition"].has("route_open"): snapshot = SaveSystem.migrate_v14(snapshot)
		if not snapshot.has("districts"): snapshot = SaveSystem.migrate_v15(snapshot)
		if not snapshot.has("self_care"): snapshot = SaveSystem.migrate_v16(snapshot)
		if not snapshot.has("chronicle"): snapshot = SaveSystem.migrate_v17(snapshot)
		var error := SaveSystem.apply_state(game,snapshot)
		if not error.is_empty():
			printerr(error)
			quit(2)
			return
	var pilot := Pilot.new()
	pilot.setup(game)
	pilot.policy.recruit_members = recruiting
	var last := 0
	var steps := 0
	var records: Array = []
	while ExpeditionState.day_at(game.simulation_time) <= 35 and not game.game_over and game.expansion.outcome.is_empty() and steps < 900000:
		pilot.tick(1.0 / 30)
		steps += 1
		var day := ExpeditionState.day_at(game.simulation_time)
		if day > last:
			last = day
			var alive: int = game.survivors.filter(func(actor): return actor.health > 0).size()
			var error := SaveSystem.validate(SaveSystem.capture(game))
			print("CAMPAIGN DAY %d · alive %d · trips %d · stock %s · validation %s" % [day, alive, pilot.trips, str(game.inventory.snapshot()), error])
			records.append({"day": day, "alive": alive, "trips": pilot.trips, "stock": game.inventory.snapshot(), "error": error, "expansion": game.expansion.snapshot()})
			print("EXPANSION STATE ", JSON.stringify(game.expansion.snapshot()), " CREW ", str(game.survivors.map(func(actor): return [actor.display_name, actor.health, actor.hunger, actor.fatigue, actor.infection, actor.illness])))
			var checkpoint := FileAccess.open(output + ".checkpoint.json", FileAccess.WRITE)
			checkpoint.store_string(JSON.stringify({"records": records, "snapshot": SaveSystem.capture(game)}))
			checkpoint.close()
			if not error.is_empty() or alive < 3: break
	var result := {"day": last, "trips": pilot.trips, "steps": steps, "alive": game.survivors.filter(func(actor): return actor.health > 0).size(), "records": records, "campaign": game.cycle.snapshot(), "expansion": game.expansion.snapshot()}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("CAMPAIGN BALANCE RESULT: ", JSON.stringify(result))
	var won: bool = game.expansion.outcome == "victory"
	game.free()
	await create_timer(0.12).timeout
	quit(0 if won and result["alive"] == (5 if recruiting else 3) and records.all(func(row): return row["error"].is_empty()) else 1)
