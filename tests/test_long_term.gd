extends "res://tests/test_expedition_saves.gd"


func _run() -> void:
	test_distinct_regions_and_genuine_trips()
	test_region_ladders_and_edges()
	test_multi_region_save()
	test_inactive_state_is_atomic()
	test_region_refresh_independent()
	test_weather_changes_perception()
	test_real_repair_and_cancel()
	test_upgrade_cost_and_limits()
	test_upkeep_and_efficiency()
	test_events_pay_once()
	test_event_shortage_and_storm_choice()
	test_menu_and_travel_guards()
	test_loadout_does_not_count_as_loot()
	test_optional_milestones_and_new_game()
	test_real_v2_expedition_migration()
	test_legacy_free_repair()
	test_invalid_progress_is_atomic()
	test_preferences_round_trip()
	test_malformed_v2_migration()
	var directory := DirAccess.open(test_directory)
	if directory != null:
		for filename in directory.get_files(): DirAccess.remove_absolute(test_directory.path_join(filename))
		DirAccess.remove_absolute(test_directory)
	print("LONG TERM RESULT: %d checks, %d failures; 19 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func loot_first(scene: Node2D, id: String) -> void:
	scene.choose_destination(id)
	scene.start_expedition()
	var distance: float = scene.expedition.site_definitions()[0]["x"] - 110
	march(scene, distance / 190, {"axis": 1.0})
	march(scene, float(scene.expedition.site_definitions()[0]["seconds"]) + 0.2, {"interact": true})
	march(scene, distance / 190 + 0.1, {"axis": -1.0})
	expect(scene.expedition.request_retreat(), "real walking returns from " + id)


func test_distinct_regions_and_genuine_trips() -> void:
	var scene := make_scene()
	for id in LocationCatalog.IDS:
		loot_first(scene, id)
		expect(scene.upkeep.returns[id] == 1, "real cargo registers a supply run for " + id)
	expect(scene.inventory.amount("raw_food") == 6 and scene.inventory.amount("water") == 8 and scene.inventory.amount("materials") == 11 and scene.inventory.amount("fuel") == 4, "three locations transfer their distinct exact cargo")
	for id in LocationCatalog.IDS:
		scene.choose_destination(id)
		expect(scene.expedition.sites[0]["contents"].values().all(func(n): return n == 0), "changing destinations never restores already searched " + id)
	expect(scene.upkeep.milestones(scene)[2][1], "three real supply runs satisfy the all-places milestone")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "three independent depleted worlds validate together")
	scene.free()


func test_region_ladders_and_edges() -> void:
	var scene := make_scene()
	for id in ["clinic", "works"]:
		scene.choose_destination(id)
		scene.start_expedition()
		var state: ExpeditionState = scene.expedition
		state.player_x = state.ladder_x() # Isolate local traversal from enemy encounters.
		march(scene, 1, {"climb": 1})
		expect(state.climb_target == 1 and state.player_y > 400 and state.player_y < 620, id + " uses its own real continuous ladder")
		expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), id + " validates its own mid-climb geometry")
		march(scene, 1.2)
		march(scene, 10, {"axis": -1.0})
		expect(state.player_x == state.upper_left(), id + " has its own upper platform edge")
		state.player_x = state.ladder_x()
		march(scene, 2.2, {"climb": -1})
		march(scene, 10, {"axis": -1.0, "sprint": true})
		state.request_retreat()
	scene.free()


func test_multi_region_save() -> void:
	var a := make_scene()
	var b := make_scene()
	loot_first(a, "street")
	a.choose_destination("clinic")
	a.start_expedition(false, true)
	march(a, 1.3, {"axis": 1.0})
	march(a, 1, {"interact": true})
	a.upkeep.integrity = 45
	if round_trip(a, b):
		expect(b.expedition.location_id == "clinic" and b.expedition.active and b.expedition.search_progress > 0, "save restores current destination and partial search")
		expect(b.regions["street"].sites[0]["contents"]["raw_food"] == 0 and b.regions["works"].sites[0]["contents"]["materials"] == 3, "inactive depleted and unvisited worlds both persist")
		march(a, 2.2, {"interact": true})
		march(b, 2.2, {"interact": true})
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "both copies continue identical multi-region simulation")
	a.free()
	b.free()


func test_inactive_state_is_atomic() -> void:
	var scene := make_scene()
	scene.choose_destination("works")
	var before := SaveSystem.capture(scene)
	for variant in range(5):
		var bad := before.duplicate(true)
		match variant:
			0: bad["destination"] = "invented"
			1: bad["other_regions"].erase("clinic")
			2: bad["other_regions"]["street"]["active"] = true
			3: bad["other_regions"]["clinic"]["sites"][0]["contents"]["water"] = 50
			4: bad["expedition"]["enemies"][0]["x"] = 9999
		expect(not SaveSystem.apply_state(scene, bad).is_empty() and SaveSystem.capture(scene) == before, "bad region state rejects atomically: %d" % variant)
	scene.free()


func test_region_refresh_independent() -> void:
	var scene := make_scene()
	loot_first(scene, "street")
	loot_first(scene, "clinic")
	scene.simulation_time = 1440
	scene.choose_destination("clinic")
	scene.start_expedition()
	expect(scene.expedition.last_refresh_day == 3 and scene.expedition.sites[0]["contents"]["water"] == 3, "new day replenishes selected region's rotating containers")
	expect(scene.regions["street"].last_refresh_day == 1 and scene.regions["street"].sites[0]["contents"]["raw_food"] == 0, "refreshing another region cannot silently replenish old street")
	var copy: Dictionary = scene.expedition.snapshot()
	scene.expedition.refresh_for_day(4)
	expect(scene.expedition.snapshot() == copy, "mid-mission refresh never spawns on active traveler")
	scene.free()


func test_weather_changes_perception() -> void:
	var a := make_scene()
	var b := make_scene()
	for scene in [a, b]:
		scene.start_expedition()
		scene.expedition.player_x = 570
		scene.expedition.enemies[0]["x"] = 800.0
		scene.expedition.enemies[0]["direction"] = -1.0
	b.expedition.last_refresh_day = 3
	# Keep enemy count consistent with day3 while retaining controlled first guard.
	b.expedition.enemies.append(b.expedition.enemies[1].duplicate())
	march(a, 0.3)
	march(b, 0.3)
	expect(a.expedition.enemies[0]["suspicion"] > b.expedition.enemies[0]["suspicion"], "fog changes actual vision rather than only a label")
	for scene in [a, b]:
		scene.expedition.enemies[0]["x"] = 800.0
		scene.expedition.enemies[0]["suspicion"] = 0.0
		scene.expedition.enemies[0]["mode"] = "patrol"
		scene.expedition.enemies[0]["direction"] = 1.0
	b.expedition.last_refresh_day = 2
	march(a, 0.1, {"axis": 1.0, "sprint": true})
	march(b, 0.1, {"axis": 1.0, "sprint": true})
	expect(a.expedition.enemies[0]["suspicion"] > b.expedition.enemies[0]["suspicion"], "rain masks some sprint noise at the hearing boundary")
	# Both actors are behind the same furniture front. Across its edge, the
	# physical obstruction introduced in v1.6 correctly blocks sight even nearby.
	b.expedition.player_x = 480
	b.expedition.enemies[0]["x"] = 515.0
	b.expedition.enemies[0]["direction"] = 1.0
	b.expedition.enemies[0]["suspicion"] = 0.0
	b.expedition.enemies[0]["mode"] = "patrol"
	b.expedition.last_refresh_day = 3
	march(b, 0.1, {"sneak": true})
	expect(b.expedition.enemies[0]["suspicion"] > 0, "fog and cover never hide a traveler at touching distance")
	a.free()
	b.free()


func test_real_repair_and_cancel() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.facility.work_position()
	scene.upkeep.integrity = 50
	scene.assign_task("repair")
	advance(scene, 1)
	expect(scene.inventory.amount("materials") == 7 and scene.upkeep.integrity < 50 and scene.upkeep.repairs == 0, "repair reserves real material but gives no premature benefit")
	scene.cancel_selected()
	expect(scene.inventory.amount("materials") == 8 and scene.upkeep.repairs == 0, "cancel refunds material without repairing")
	actor.position = scene.facility.work_position()
	scene.assign_task("repair")
	advance(scene, 4.6)
	expect(scene.upkeep.integrity > 67 and scene.upkeep.repairs == 1 and scene.inventory.amount("materials") == 7, "finished repair trades one material for actual structure")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "paid repaired state validates")
	scene.free()


func test_upgrade_cost_and_limits() -> void:
	var scene := make_scene()
	var progress: ShelterProgress = scene.upkeep
	var before: Dictionary = scene.inventory.snapshot()
	expect(not progress.upgrade(scene.inventory) and scene.inventory.snapshot() == before and progress.level == 0, "missing full upgrade cost preserves all stock")
	scene.inventory.deposit({"tools": 4, "materials": 20, "fuel": 2}, "upgrade scenario")
	for index in range(3): expect(progress.upgrade(scene.inventory), "upgrade level %d costs real goods" % (index + 1))
	expect(progress.level == 3 and scene.inventory.amount("tools") == 0 and scene.inventory.amount("materials") == 10 and scene.inventory.amount("medicine") == 0, "bounded upgrades consume exact materials and scarce equipment")
	before = scene.inventory.snapshot()
	expect(not progress.upgrade(scene.inventory) and scene.inventory.snapshot() == before, "max level cannot debit or overflow")
	scene.free()


func test_upkeep_and_efficiency() -> void:
	var a := make_scene()
	var b := make_scene()
	a.upkeep.integrity = 15
	for scene in [a, b]:
		scene.survivors[0].position = scene.stove.work_position()
		scene.assign_task("cook")
	advance(a, 3)
	advance(b, 3)
	expect(a.survivors[0].work_elapsed < b.survivors[0].work_elapsed * 0.7, "damaged structure slows real productive work")
	for scene in [a, b]:
		scene.scheduler.cancel(scene.survivors[0])
		scene.survivors[0].position = scene.bed.work_position()
		scene.assign_task("sleep")
	advance(a, 2)
	advance(b, 2)
	expect(is_equal_approx(a.survivors[0].work_elapsed, b.survivors[0].work_elapsed), "recovery never slows because a base needs repair")
	var integrity: float = b.upkeep.integrity
	b.paused = true
	advance(b, 10)
	expect(b.upkeep.integrity == integrity, "pause freezes structural wear")
	a.free()
	b.free()


func test_events_pay_once() -> void:
	var scene := make_scene()
	scene.upkeep.tick(0, 480)
	scene.simulation_time = 480
	expect(scene.upkeep.pending_event == 0 and scene.upkeep.event_day == 2, "crossing into day2 announces the first event")
	var stock: Dictionary = scene.inventory.snapshot()
	expect(scene.upkeep.resolve_event(true, scene.inventory), "explicit event choice succeeds with the full cost")
	expect(scene.inventory.amount("materials") == stock["materials"] - 2 and scene.inventory.amount("water") == stock["water"] + 6, "event actually trades finite materials for water")
	stock = scene.inventory.snapshot()
	expect(not scene.upkeep.resolve_event(true, scene.inventory) and scene.inventory.snapshot() == stock, "resolved event cannot pay or grant twice")
	scene.upkeep.tick(0, 480)
	expect(scene.upkeep.pending_event == -1, "same day does not create another event")
	var saved := SaveSystem.capture(scene)
	var b := make_scene()
	expect(SaveSystem.apply_state(b, saved).is_empty() and b.upkeep.resolved_events == 1, "event resolution persists with inventory")
	b.free()
	scene.free()


func test_event_shortage_and_storm_choice() -> void:
	var scene := make_scene()
	scene.upkeep.tick(0, 480)
	scene.inventory.try_take({"materials": 8}, "empty material fixture")
	var before: Dictionary = scene.upkeep.snapshot()
	var stock: Dictionary = scene.inventory.snapshot()
	expect(not scene.upkeep.resolve_event(true, scene.inventory) and before == scene.upkeep.snapshot() and stock == scene.inventory.snapshot(), "unaffordable event preserves choice and stock atomically")
	expect(scene.upkeep.resolve_event(false, scene.inventory) and scene.inventory.snapshot() == stock, "ordinary declined trade does not steal goods")
	scene.upkeep.tick(0, 1920)
	var integrity: float = scene.upkeep.integrity
	expect(scene.upkeep.pending_event == 2, "day4 offers an explicitly described storm preparation")
	scene.upkeep.resolve_event(false, scene.inventory)
	expect(scene.upkeep.integrity == integrity - 8 and scene.survivors[0].health == 100, "declined storm choice has only its advertised structural consequence")
	scene.upkeep.resolve_event(false, scene.inventory)
	expect(scene.upkeep.integrity == integrity - 8, "storm consequence cannot repeat")
	scene.free()


func test_menu_and_travel_guards() -> void:
	var scene := make_scene()
	scene.open_center(0)
	expect(scene.center.visible and scene.paused, "handbook opens and freezes the simulation")
	var state := SaveSystem.capture(scene)
	advance(scene, 2)
	expect(SaveSystem.capture(scene) == state, "menu freezes all simulation fields")
	scene.center.close()
	expect(not scene.paused, "menu restores the original running state")
	scene.start_expedition(false, true)
	expect(not scene.choose_destination("clinic") and scene.expedition.location_id == "street", "active mission cannot swap worlds")
	scene.open_center(1)
	var stock: Dictionary = scene.inventory.snapshot()
	scene.center._upgrade()
	scene.center._event(true)
	expect(scene.inventory.snapshot() == stock and scene.upkeep.level == 0, "travel menu cannot remotely upgrade or trade")
	scene.expedition_retreat()
	expect(scene.expedition.active, "paused retreat command cannot bypass pause")
	scene.center.close()
	scene.expedition_retreat()
	expect(not scene.expedition.active and scene.paused, "resumed entry retreat still works")
	scene.free()


func test_loadout_does_not_count_as_loot() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	scene.expedition.request_retreat()
	expect(scene.upkeep.returns["street"] == 0 and scene.upkeep.recovered["medicine"] == 0, "carrying own medicine out and back cannot satisfy exploration goals")
	scene.start_expedition()
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.2, {"interact": true})
	scene.survivors[0].health = 0
	march(scene, 0.1)
	expect(scene.upkeep.returns["street"] == 0 and scene.upkeep.trip_loadout.is_empty(), "death never counts lost cargo as successful supply run")
	scene.free()


func test_optional_milestones_and_new_game() -> void:
	var scene := make_scene()
	scene.simulation_time = 4320
	expect(scene.upkeep.milestones(scene)[5][1] and not scene.game_over, "seventh day milestone never forces an ending")
	scene.upkeep.level = 2
	scene.upkeep.integrity = 5
	scene.choose_destination("works")
	scene.start_new_game()
	expect(scene.expedition.location_id == "street" and scene.upkeep.level == 0 and scene.upkeep.integrity == 82 and scene.upkeep.repairs == 0, "explicit new run resets progression and destination")
	expect(scene.regions["works"].attempts == 0 and scene.inventory.amount("materials") == 8, "new run restores all worlds and initial stock")
	scene.free()


func test_real_v2_expedition_migration() -> void:
	var scene := make_scene()
	var store := slot()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/v2_expedition.json")
	write_text(store.path, original)
	var old := store.read_state()
	expect(old["ok"] and old.get("migrated", false), "authentic v0.4 half-search save migrates")
	if old["ok"]:
		expect(SaveSystem.apply_state(scene, old["data"]).is_empty() and scene.expedition.active and scene.expedition.location_id == "street", "old active traveler restores in original map")
		expect(scene.expedition.search_progress > 0.9 and scene.expedition.bag["medicine"] == 1 and scene.inventory.amount("medicine") == 0, "old search and paid loadout survive upgrade without free medicine")
		march(scene, 1.2, {"interact": true})
		march(scene, 1, {"axis": -1.0})
		scene.expedition.request_retreat()
		expect(scene.inventory.amount("raw_food") == 6 and scene.inventory.amount("medicine") == 1, "migrated active mission returns exact cargo once")
		expect(scene.upkeep.recovered["medicine"] == 0 and scene.upkeep.recovered["raw_food"] == 2, "legacy loadout is conservatively excluded from new net-loot statistics")
		expect(store.write_state(scene)["ok"] and FileAccess.get_file_as_string(store.path + ".bak") == original, "upgrading schema2 preserves original bytes as backup")
	scene.free()


func test_legacy_free_repair() -> void:
	var scene := make_scene()
	var store := slot()
	write_text(store.path, FileAccess.get_file_as_string("res://tests/fixtures/v2_repair.json"))
	var old := store.read_state()
	expect(old["ok"], "authentic ongoing free legacy repair can migrate")
	if old["ok"]:
		SaveSystem.apply_state(scene, old["data"])
		expect(scene.survivors[0].legacy_repair and scene.survivors[0].held_cost.is_empty(), "old unpaid practice retains explicit legacy semantics")
		var materials: int = scene.inventory.amount("materials")
		advance(scene, 5)
		expect(scene.inventory.amount("materials") == materials and scene.upkeep.repairs == 0 and not scene.survivors[0].legacy_repair, "finishing old practice neither spends material nor grants a new repair")
		SaveSystem.apply_state(scene, old["data"])
		scene.scheduler.cancel(scene.survivors[0])
		expect(scene.inventory.amount("materials") == materials and not scene.survivors[0].legacy_repair, "cancelling old free practice cannot refund an unspent new material")
	scene.free()


func test_invalid_progress_is_atomic() -> void:
	var scene := make_scene()
	var before := SaveSystem.capture(scene)
	for variant in range(7):
		var bad := before.duplicate(true)
		match variant:
			0: bad["upkeep"]["integrity"] = -1
			1: bad["upkeep"]["level"] = 4
			2: bad["upkeep"]["last_day"] = 20
			3: bad["upkeep"]["pending_event"] = 0
			4: bad["upkeep"]["returns"]["clinic"] = -1
			5: bad["upkeep"]["trip_loadout"] = {"tools": 1}
			6: bad["actors"][0]["legacy_repair"] = true
		expect(not SaveSystem.apply_state(scene, bad).is_empty() and SaveSystem.capture(scene) == before, "invalid progression leaves current game untouched: %d" % variant)
	scene.free()


func test_preferences_round_trip() -> void:
	var store := slot()
	var a := GameAudio.new()
	a.settings_path = store.path + ".preferences"
	root.add_child(a)
	a.enabled = false
	a.ambience = true
	a.volume = 0.25
	a.apply_preferences()
	var b := GameAudio.new()
	b.settings_path = a.settings_path
	root.add_child(b)
	expect(not b.enabled and b.ambience and b.volume == 0.25, "audio preferences persist independently of the game save")
	a.free()
	b.free()


func test_malformed_v2_migration() -> void:
	var store := slot()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_expedition.json"))
	for variant in range(4):
		var envelope := original.duplicate(true)
		var data: Dictionary = JSON.parse_string(envelope["data_json"])
		match variant:
			0: data["actors"][0]["orders"] = 3
			1: data["actors"][0]["held_cost"] = []
			2: data["actors"][0]["state"] = "away"
			3: data["unexpected"] = true
		envelope["data_json"] = JSON.stringify(data)
		envelope["sha256"] = envelope["data_json"].sha256_text()
		write_text(store.path, JSON.stringify(envelope))
		expect(not store.read_state()["ok"], "malformed legacy input safely rejects without script error: %d" % variant)
