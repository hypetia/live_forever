extends "res://tests/test_campaign.gd"

func quiet_field() -> ExpeditionState:
	var f := ExpeditionState.new();f.environment_active = true;f.stacked = true
	f.begin(0,{"materials":6,"fuel":6},1)
	for e in f.enemies: e["hp"] = 0;e["mode"] = "dead"
	return f

func _run() -> void:
	var actor := Survivor.new();actor.metabolism = .4
	var f := quiet_field();f.player_x = 650;f.facing = 1
	var supplies := f.bag.duplicate()
	expect(f.deploy_decoy(actor),"G-style deployment uses a real carried decoy recipe")
	expect(f.bag["materials"] == supplies["materials"]-1 and f.bag["fuel"] == supplies["fuel"]-1,"one deployment spends exactly one material and one fuel")
	expect(f.decoys.size() == 1 and f.decoys[0]["x"] == 890 and f.decoys[0]["remaining"] == 18,"device has a separate physical sound source and a bounded lifetime")
	expect(not f.deploy_decoy(actor) and f.decoys.size() == 1,"throw cooldown cannot be bypassed by repeated button presses")
	var enemy: Dictionary = f.enemies[0]
	enemy["x"] = 900;enemy["hp"] = 40;enemy["mode"] = "patrol";enemy["direction"] = 1.0
	f.noise = 0
	f._tick_enemy(enemy,actor,.1)
	expect(enemy["target"] == 890 and enemy["mode"] == "investigate","enemy investigates the device instead of being given the player's hidden position")
	expect(enemy["hp"] == 40 and actor.health == 100,"a noise lure does not fake damage or grant invulnerability")
	f.player_x = 770;enemy["direction"] = -1.0
	f._tick_enemy(enemy,actor,.1)
	expect(enemy["target"] == 770,"real sight overrides the distraction")
	f.player_x = 500;f.sneaking = true;f.noise = 0
	f._tick_enemy(enemy,actor,.1)
	expect(enemy["target"] == 890,"after losing the real target, a continuing local sound can be investigated again")
	var snapshot := f.snapshot()
	expect(ExpeditionState.validate_snapshot(snapshot,[{"state":Survivor.TaskState.AWAY}]).is_empty(),"live distraction and enemy memory are valid field save data")
	var loaded := ExpeditionState.new();loaded.restore_validated(snapshot)
	expect(loaded.decoys == f.decoys and loaded.bag == f.bag and loaded.lure_cooldown == 3,"restoring a lure never consumes its ingredients again")
	var bad := snapshot.duplicate(true);bad["decoys"][0]["remaining"] = INF
	expect(not ExpeditionState.validate_snapshot(bad,[{"state":Survivor.TaskState.AWAY}]).is_empty(),"nonfinite device lifetime is rejected")
	bad = snapshot.duplicate(true);bad["decoys"][0]["x"] = 100000
	expect(not ExpeditionState.validate_snapshot(bad,[{"state":Survivor.TaskState.AWAY}]).is_empty(),"sound source cannot be restored outside the map")
	bad = snapshot.duplicate(true);bad["decoys"].append(snapshot["decoys"][0]);bad["decoys"].append(snapshot["decoys"][0]);bad["decoys"].append(snapshot["decoys"][0])
	expect(not ExpeditionState.validate_snapshot(bad,[{"state":Survivor.TaskState.AWAY}]).is_empty(),"active sound source count is bounded")
	for e in f.enemies: e["hp"] = 0;e["mode"] = "dead"
	f.tick(18.01,actor,{})
	expect(f.decoys.is_empty() and f.lure_cooldown == 0,"expired sources are actually removed")
	for index in range(3):
		expect(f.deploy_decoy(actor),"bounded consecutive deployment "+str(index))
		f.tick(3.01,actor,{})
	supplies = f.bag.duplicate()
	expect(not f.deploy_decoy(actor) and f.bag == supplies,"three active sources prevent spam without consuming more ingredients")
	f.player_x = 90;f.confirm_retreat(-1)
	expect(f.decoys.is_empty() and f.lure_cooldown == 0,"return removes field devices without refunding used ingredients")
	expect(ExpeditionState.validate_snapshot(f.snapshot(),[]).is_empty(),"inactive field has no orphaned transient devices")
	f = quiet_field();f.player_x = f.upper_left();f.floor_level = 1;f.player_y = 400
	f.deploy_decoy(actor);f.noise = 0
	enemy = f.enemies[0];enemy["x"] = f.ladder_x();enemy["hp"] = 40;enemy["mode"] = "patrol"
	f._tick_enemy(enemy,actor,.1)
	expect(enemy["target_floor"] == 1 and enemy["target"] == f.decoys[0]["x"] and enemy["climb_target"] == 1,"cross-floor distraction uses the actual ladder route")
	# Real campaign gunfire, pressure, emergence and a quieter right-side return.
	var game := campaign()
	game.expansion.grant("pistol");game.end_day()
	game.expansion.equip(game,game.expansion.gear.back()["id"],2)
	game.expansion.ammo = 3;game.expansion.ammo_loadout = 3
	game.start_expedition();f = game.expedition
	for index in range(3):
		game.expedition_attack()
		expect(f.attack_windup > 0,"real gunshot starts "+str(index))
		advance(game,1.1)
	expect(game.districts.regions["street"]["heat"] >= 12 and f.magazine == 0,"hits, misses and their real noise accumulate persistent district pressure while spending ammunition")
	expect(game.districts.regions["clinic"]["heat"] == 0,"local fighting does not mark every district equally")
	valid(game,"gunfire pressure snapshot")
	game.districts.regions["street"]["heat"] = 80
	var count := f.enemies.size()
	game.districts.begin_trip(game)
	expect(f.enemies.size() == count and f.enemies[0]["kind"] == "runner" and f.enemies[1]["kind"] == "brute","high-pressure next-trip composition changes archetypes without scaling health or enemy count to gear")
	expect(f.enemies[1]["hp"] == EnemyCatalog.stats("brute")["health"],"pressure uses the existing bounded enemy archetype stats")
	valid(game,"pressure-composed population snapshot")
	game.districts.alert = 0;f.player_x = f.right_edge(0)
	game.districts.trip_return(game,true)
	var right_alert: float = game.districts.alert
	game.districts.alert = 0;game.districts.begin_trip(game);f.player_x = 90
	game.districts.trip_return(game,true)
	expect(game.districts.alert > right_alert,"using the far exit reduces the trail brought toward the shelter")
	game.districts.begin_trip(game)
	f.route_open = true;f.floor_level = 1;f.player_y = 400;f.player_x = f.route_x()
	var points := InteractionFeedback.route(game,Vector2(110,620))
	expect(points[1].x == f.route_x() and points[2].x == f.route_x(),"visual route feedback matches the actual opened-ladder return plan")
	game.free();actor.free()
	print("DECOYS RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(.12).timeout
	quit(1 if failures else 0)
