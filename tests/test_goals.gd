extends "res://tests/test_people.gd"


func stock_fixture(scene: Node2D) -> void:
	# Independent model fixture; screenshots and endurance never add resources.
	scene.inventory.deposit({"materials": 60, "medicine": 30, "water": 15, "fuel": 20, "tools": 10, "raw_food": 15}, "goal test fixture")
	scene.upkeep.level = 3
	scene.simulation_time = 14 * 720


func search_fixture(scene: Node2D, place: String, index: int) -> void:
	# Isolate search/evidence semantics from navigation (covered by real-input tests).
	scene.choose_destination(place)
	expect(scene.start_expedition(scene.inventory.amount("tools") > 0, scene.inventory.amount("medicine") > 0), "search fixture starts a legal paid expedition")
	scene.expedition.player_x = scene.expedition.site_definitions()[index]["x"]
	scene.expedition.floor_level = scene.expedition.site_definitions()[index]["floor"]
	scene.expedition.player_y = ExpeditionState.FLOOR_Y[scene.expedition.floor_level]
	for enemy in scene.expedition.enemies: enemy["hp"] = 0; enemy["mode"] = "dead"
	march(scene, 9, {"interact": true})


func return_fixture(scene: Node2D) -> void:
	scene.expedition.floor_level = 0
	scene.expedition.player_y = 620
	scene.expedition.player_x = 110
	scene.expedition_retreat()


func _run() -> void:
	test_initial_goals()
	test_evidence_return()
	test_evidence_loss_and_empty()
	test_paid_stages_and_once()
	test_stage_prerequisites()
	test_clinic_and_network()
	test_trade_atomic_and_shared_date()
	test_away_guards()
	test_note_disk_roundtrip()
	test_invalid_goals_atomic()
	test_real_v5_migration()
	test_focus_and_reset()
	print("GOALS RESULT: %d checks, %d failures; 12 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_initial_goals() -> void:
	var scene := make_scene()
	expect(scene.center.tabs.get_tab_count() == 8 and scene.goals.stages.values().all(func(n): return n == 0), "three optional projects and actual eighth page start without progress")
	expect(scene.goals.progress_error(scene, "radio").contains("勘查") and scene.goals.trade_error(scene, "medicine").contains("据点"), "first project and aid gates give actionable requirements")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "initial optional goals validate")
	scene.free()


func test_evidence_return() -> void:
	var scene := make_scene()
	search_fixture(scene, "works", 1)
	expect(scene.goals.field_notes == ["works:1"] and scene.goals.notes.is_empty(), "real positive search records only carried evidence for the correct region")
	expect(scene.goals.progress_error(scene, "radio").contains("基地"), "field evidence cannot complete a remote project")
	return_fixture(scene)
	expect(scene.goals.notes == ["works:1"] and scene.goals.field_notes.is_empty(), "evidence reaches base only on successful physical return with supplies")
	expect(scene.goals.advance(scene, "radio") and scene.goals.stages["radio"] == 1, "actual returned survey completes only its one eligible project stage")
	scene.free()
	for pair in [["clinic", 2], ["street", 4]]:
		scene = make_scene()
		search_fixture(scene, pair[0], pair[1])
		return_fixture(scene)
		expect(scene.goals.notes == ["%s:%d" % pair], "search evidence keeps distinct source region " + pair[0])
		scene.free()


func test_evidence_loss_and_empty() -> void:
	var scene := make_scene()
	search_fixture(scene, "clinic", 2)
	scene.scheduler.mark_dead(scene.survivors[scene.selected_id])
	march(scene, 0.1)
	expect(scene.goals.notes.is_empty() and scene.goals.field_notes.is_empty(), "lost traveler cannot remotely deliver survey proof")
	scene.free()
	scene = make_scene()
	scene.choose_destination("works")
	scene.start_expedition(true, true)
	scene.expedition.request_retreat()
	expect(scene.goals.notes.is_empty(), "own gear round trip cannot fabricate objective evidence")
	search_fixture(scene, "works", 1)
	scene.expedition.drop("materials")
	scene.expedition.drop("materials")
	while scene.expedition.bag["tools"] > int(scene.upkeep.trip_loadout.get("tools", 0)): scene.expedition.drop("tools")
	return_fixture(scene)
	expect(scene.goals.notes.is_empty(), "discarding every net supply prevents delivery of carried survey proof")
	scene.free()


func test_paid_stages_and_once() -> void:
	var scene := make_scene()
	stock_fixture(scene)
	scene.goals.notes.append("works:1")
	scene.goals.notes.append("street:4")
	expect(scene.goals.advance(scene, "radio"), "first survey can be confirmed without fabricated resource rewards")
	var before: Dictionary = scene.inventory.snapshot()
	expect(scene.goals.advance(scene, "radio") and scene.inventory.amount("materials") == before["materials"] - 8 and scene.inventory.amount("tools") == before["tools"] - 2, "antenna spends full construction cost once")
	expect(scene.goals.advance(scene, "radio") and scene.goals.stages["radio"] == 3 and not scene.game_over, "final transmission completes optional route without ending survival")
	before = SaveSystem.capture(scene)
	expect(not scene.goals.advance(scene, "radio") and equivalent(before, SaveSystem.capture(scene)), "completed project cannot repeatedly charge or reward")
	expect(scene.goals.spent["materials"] == 14 and SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "project spending ledger exactly matches completed stages")
	scene.free()


func test_stage_prerequisites() -> void:
	var scene := make_scene()
	scene.goals.notes.append("works:1")
	scene.goals.advance(scene, "radio")
	expect(scene.goals.progress_error(scene, "radio").contains("2级"), "construction requires genuine shelter level")
	scene.upkeep.level = 2
	var before: Dictionary = SaveSystem.capture(scene)
	expect(not scene.goals.advance(scene, "radio") and equivalent(before, SaveSystem.capture(scene)), "unaffordable construction rejects without partial payment or progress")
	stock_fixture(scene)
	scene.goals.advance(scene, "radio")
	scene.simulation_time = 5 * 720
	expect(scene.goals.progress_error(scene, "radio").contains("10天"), "transmission cannot skip its calendar milestone")
	scene.simulation_time = 14 * 720
	expect(scene.goals.progress_error(scene, "radio").contains("勘查"), "late game does not invent missing deep-street evidence")
	scene.free()


func test_clinic_and_network() -> void:
	var scene := make_scene()
	stock_fixture(scene)
	scene.goals.notes.append("clinic:2")
	expect(scene.goals.progress_error(scene, "clinic").contains("照料"), "medical route requires actual completed care rather than queued intentions")
	scene.select_survivor(1)
	for index in range(3):
		scene.assign_task("heal")
		advance(scene, 18)
	expect(scene.goals.advance(scene, "clinic") and scene.goals.advance(scene, "clinic") and scene.goals.advance(scene, "clinic"), "real paid care and complete contributions finish medical route")
	expect(scene.goals.progress_error(scene, "network").contains("三处"), "network begins with physical returns from all three places")
	for id in LocationCatalog.IDS: scene.upkeep.returns[id] = 1
	expect(scene.goals.advance(scene, "network") and scene.goals.advance(scene, "network") and scene.goals.advance(scene, "network"), "prepared network requires a completed radio or medical route and full spending")
	expect(scene.goals.stages["network"] == 3 and scene.goals.trade_error(scene, "convoy").is_empty(), "completed network unlocks its paid aid option")
	scene.free()


func test_trade_atomic_and_shared_date() -> void:
	var scene := make_scene()
	stock_fixture(scene)
	var before: Dictionary = scene.inventory.snapshot()
	expect(scene.goals.trade(scene, "medicine"), "surplus medicine exchanges through real full-cost transaction")
	expect(scene.inventory.amount("medicine") == before["medicine"] - 2 and scene.inventory.amount("raw_food") == before["raw_food"] + 3 and scene.inventory.amount("water") == before["water"] + 2, "mutual aid never creates supplies without its exact paid input")
	before = SaveSystem.capture(scene)
	expect(not scene.goals.trade(scene, "materials") and equivalent(before, SaveSystem.capture(scene)), "all aid options share one calendar cooldown")
	scene.simulation_time += 720
	expect(not scene.goals.trade(scene, "materials"), "waiting one day cannot bypass two-day aid interval")
	scene.simulation_time += 720
	expect(scene.goals.trade(scene, "materials") and scene.goals.trades["materials"] == 1, "legitimate second day unlocks one new paid aid transaction")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "aid clock and exact spending ledger stay saveable")
	scene.free()


func test_away_guards() -> void:
	var scene := make_scene()
	stock_fixture(scene)
	scene.start_expedition()
	var before: Dictionary = SaveSystem.capture(scene)
	expect(not scene.goals.advance(scene, "network") and not scene.goals.trade(scene, "medicine") and equivalent(before, SaveSystem.capture(scene)), "expedition cannot remotely construct or receive aid")
	scene.free()


func test_note_disk_roundtrip() -> void:
	var scene := make_scene()
	var copy := make_scene()
	search_fixture(scene, "works", 1)
	expect(round_trip(scene, copy), "carried objective proof restores through actual checksummed save")
	return_fixture(copy)
	expect(copy.goals.notes == ["works:1"] and copy.goals.field_notes.is_empty(), "restored traveler delivers survey once on return")
	copy.goals.advance(copy, "radio")
	expect(round_trip(copy, scene) and scene.goals.stages["radio"] == 1, "completed survey does not repeat after another restore")
	scene.free()
	copy.free()


func test_invalid_goals_atomic() -> void:
	var scene := make_scene()
	var before: Dictionary = SaveSystem.capture(scene)
	for mutation in ["unknown", "stage", "duplicate", "field", "spent", "future"]:
		var bad: Dictionary = before.duplicate(true)
		match mutation:
			"unknown": bad["goals"]["tracked"] = "unknown"
			"stage": bad["goals"]["stages"]["radio"] = 4
			"duplicate": bad["goals"]["notes"] = ["works:1", "works:1"]
			"field": bad["goals"]["field_notes"] = ["clinic:2"]
			"spent": bad["goals"]["spent"]["materials"] = 12
			"future": bad["goals"]["next_trade_day"] = 99
		expect(not SaveSystem.apply_state(scene, bad).is_empty() and equivalent(before, SaveSystem.capture(scene)), "malformed goal rejected before world mutation: " + mutation)
	scene.free()


func test_real_v5_migration() -> void:
	var store := slot()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/v5_story.json")
	write_text(store.path, original)
	var loaded := store.read_state()
	expect(loaded["ok"] and loaded["migrated"], "real archived schema5 workshop story migrates")
	if not loaded["ok"]: return
	var scene := make_scene()
	expect(SaveSystem.apply_state(scene, loaded["data"]).is_empty() and scene.story.pending.get("id") == "lin_radio", "schema6 migration preserves pending story and genuine old progress")
	expect(scene.goals.notes.is_empty() and scene.goals.stages.values().all(func(n): return n == 0), "migration invents no survey evidence, construction or paid aid")
	expect(store.write_state(scene)["ok"] and FileAccess.get_file_as_string(store.path + ".bak") == original, "schema5 original remains byte-for-byte backup after new save")
	scene.free()


func test_focus_and_reset() -> void:
	var scene := make_scene()
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(scene.paused and scene.logs[0].contains("焦点"), "losing application focus pauses actual simulation with a clear message")
	var seconds: float = scene.simulation_time
	advance(scene, 20)
	expect(scene.simulation_time == seconds, "unfocused world does not consume supplies or move enemies")
	scene.goals.tracked = "clinic"
	scene.goals.notes.append("works:1")
	scene.start_new_game()
	expect(scene.goals.tracked == "radio" and scene.goals.notes.is_empty() and scene.goals.next_trade_day == 4, "new campaign resets all project and aid state")
	scene.free()
