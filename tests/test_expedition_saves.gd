extends "res://tests/test_saves.gd"


func march(scene: Node2D, seconds: float, controls: Dictionary = {}) -> void:
	scene.expedition_controls_override = controls
	advance(scene, seconds)
	scene.expedition_controls_override = null


func round_trip(a: Node2D, b: Node2D) -> bool:
	var store := slot()
	var written := store.write_state(a)
	expect(written["ok"], "expedition state writes a valid current-version snapshot: %s" % written.get("message", ""))
	if not written["ok"]: return false
	var loaded := store.read_state()
	expect(loaded["ok"] and not loaded.get("migrated", true), "current-version file reads without a migration")
	if not loaded["ok"]: return false
	expect(SaveSystem.apply_state(b, loaded["data"]).is_empty(), "validated expedition snapshot applies")
	expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "expedition snapshot restores all logical fields")
	return true


func _run() -> void:
	test_partial_search()
	test_mid_climb()
	test_enemy_windup()
	test_player_windup()
	test_cargo_credit_once()
	test_casualty_state()
	test_real_v1_fixture()
	test_migration_write_and_backup()
	test_invalid_expedition_atomic()
	test_depleted_map_and_refresh()
	test_startup_away_resume()
	test_treatment_progress()
	var directory := DirAccess.open(test_directory)
	if directory != null:
		for filename in directory.get_files(): DirAccess.remove_absolute(test_directory.path_join(filename))
		DirAccess.remove_absolute(test_directory)
	print("EXPEDITION SAVE RESULT: %d checks, %d failures; 12 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_partial_search() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition()
	march(a, 1, {"axis": 1.0})
	march(a, 1, {"interact": true})
	expect(a.expedition.search_index == 0 and a.expedition.used_capacity() == 0, "search fixture is genuinely half complete")
	if round_trip(a, b):
		march(a, 1.2, {"interact": true})
		march(b, 1.2, {"interact": true})
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.expedition.bag["raw_food"] == 2, "restored search completes the same container once")
	a.free()
	b.free()
	print("PASS expedition save: partial search continuity")


func test_mid_climb() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition()
	a.expedition.player_x = ExpeditionState.LADDER_X
	march(a, 1, {"climb": 1})
	expect(a.expedition.climb_target == 1 and a.expedition.player_y > 400 and a.expedition.player_y < 620, "save fixture is midway up ladder")
	if round_trip(a, b):
		march(a, 1.2)
		march(b, 1.2)
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.expedition.floor_level == 1, "restored ladder movement reaches identical floor without teleporting")
	a.free()
	b.free()
	print("PASS expedition save: mid-climb continuity")


func test_enemy_windup() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition()
	a.expedition.player_x = 800
	a.expedition.enemies[0]["x"] = 835.0
	a.expedition.enemies[0]["mode"] = "chase"
	a.expedition.enemies[0]["suspicion"] = 100.0
	march(a, 0.3)
	expect(a.expedition.enemies[0]["mode"] == "windup", "save fixture contains pending enemy attack")
	if round_trip(a, b):
		march(a, 0.6)
		march(b, 0.6)
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.survivors[0].health == 86, "loading does not reset attack timer or duplicate damage")
	a.free()
	b.free()
	print("PASS expedition save: enemy attack telegraph persists")


func test_player_windup() -> void:
	var a := make_scene()
	var b := make_scene()
	a.inventory.deposit({"tools": 1}, "swing fixture")
	a.start_expedition(true)
	a.expedition.player_x = 800
	a.expedition.facing = 1
	a.expedition.enemies[0]["x"] = 845.0
	a.expedition.enemies[0]["mode"] = "chase"
	a.expedition.enemies[0]["suspicion"] = 100.0
	a.expedition_attack()
	march(a, 0.1)
	expect(a.expedition.attack_windup > 0 and a.expedition.bag["tools"] == 1, "save fixture precedes actual tool impact")
	if round_trip(a, b):
		march(a, 0.25)
		march(b, 0.25)
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.expedition.bag["tools"] == 0 and b.expedition.enemies[0]["hp"] == 0, "pending player swing consumes one tool and defeats one target after load")
	a.free()
	b.free()
	print("PASS expedition save: pending player action persists")


func test_cargo_credit_once() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition(false, true)
	march(a, 1, {"axis": 1.0})
	march(a, 2.1, {"interact": true})
	expect(a.inventory.amount("raw_food") == 4 and a.expedition.bag["raw_food"] == 2, "stored cargo remains separate from base")
	if round_trip(a, b):
		march(b, 1, {"axis": -1.0})
		b.expedition.request_retreat()
		expect(b.inventory.amount("raw_food") == 6 and b.inventory.amount("medicine") == 1, "return after load credits loot and unused loadout once")
		b.expedition.request_retreat()
		expect(b.inventory.amount("raw_food") == 6 and b.expedition.used_capacity() == 0, "repeat return cannot credit saved cargo twice")
	a.free()
	b.free()
	print("PASS expedition save: no early or duplicate cargo credit")


func test_casualty_state() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition(false, true)
	a.survivors[0].health = 0
	march(a, 0.1)
	expect(not a.expedition.active and a.survivors[0].state == Survivor.TaskState.DEAD, "dead traveler clears active expedition before save")
	if round_trip(a, b):
		expect(b.survivors[0].health == 0 and not b.expedition.active and b.inventory.amount("medicine") == 0, "load never resurrects traveler or refunds lost loadout")
	a.free()
	b.free()
	print("PASS expedition save: permanent expedition loss")


func test_real_v1_fixture() -> void:
	var scene := make_scene()
	var store := slot()
	write_text(store.path, FileAccess.get_file_as_string("res://tests/fixtures/v1_working.json"))
	var legacy := store.read_state()
	expect(legacy["ok"] and legacy.get("migrated", false), "actual archived v0.3 save migrates from schema 1")
	if legacy["ok"]:
		expect(SaveSystem.apply_state(scene, legacy["data"]).is_empty(), "migrated real save validates and restores")
		expect(scene.survivors[0].state == Survivor.TaskState.WORKING and scene.survivors[0].held_cost["fuel"] == 1 and scene.inventory.amount("fuel") == 2, "migration preserves paid in-progress cooking")
		expect(scene.inventory.amount("medicine") == 0 and scene.survivors[0].injury == 0 and scene.survivors[0].infection == 0 and scene.survivors[0].completed_by_task["heal"] == 0, "new fields initialize without granting free supplies")
		advance(scene, 7)
		expect(scene.inventory.amount("meals") == 2 and scene.inventory.amount("fuel") == 2, "migrated task finishes without spending inputs twice")
	scene.free()
	print("PASS expedition save: authentic schema-1 migration")


func test_migration_write_and_backup() -> void:
	var scene := make_scene()
	var store := slot()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/v1_working.json")
	write_text(store.path, original)
	scene.save_store.path = store.path
	expect(scene.load_game() and scene.paused and "迁移" in scene._save_status, "user load announces migration and pauses")
	expect(store.write_state(scene)["ok"], "migrated state saves using current version")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	expect(envelope["version"] == SaveSystem.VERSION and FileAccess.get_file_as_string(store.path + ".bak") == original, "upgrade retains original schema-1 bytes as backup")
	expect(store.read_state()["ok"] and not store.read_state().get("migrated", true), "upgraded primary needs no second migration")
	write_text(store.path, "broken upgraded primary")
	expect(scene.load_game() and "备份" in scene._save_status and "迁移" in scene._save_status, "legacy-backup recovery reports both fallback and migration")
	scene.free()
	print("PASS expedition save: migration notice and recoverable backup")


func test_invalid_expedition_atomic() -> void:
	var scene := make_scene()
	scene.start_expedition()
	var initial := SaveSystem.capture(scene)
	var mutations: Array[Dictionary] = []
	var bad := initial.duplicate(true)
	bad["expedition"]["bag"]["raw_food"] = 11
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["actor_id"] = 1
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["enemies"][0]["mode"] = "unknown"
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["enemies"][0]["hp"] = 41
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["enemies"][0]["hp"] = 0
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["player_y"] = 500
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["climb_target"] = 1
	bad["expedition"]["climb_progress"] = 0.5
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["search_index"] = 0
	bad["expedition"]["search_progress"] = 3
	bad["expedition"]["search_duration"] = 2
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["state"] = Survivor.TaskState.IDLE
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["speed"] = 3.0
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["expedition"]["sites"][0]["contents"]["raw_food"] = 99
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["selected_id"] = 1
	mutations.append(bad)
	for mutation in mutations:
		expect(not SaveSystem.apply_state(scene, mutation).is_empty(), "inconsistent expedition is refused before restoration")
		expect(SaveSystem.capture(scene) == initial, "refused expedition cannot partially change current run")
	scene.free()
	print("PASS expedition save: whole-state validation")


func test_depleted_map_and_refresh() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition()
	march(a, 1, {"axis": 1.0})
	march(a, 2.1, {"interact": true})
	march(a, 1, {"axis": -1.0})
	a.expedition.request_retreat()
	if round_trip(a, b):
		b.start_expedition()
		expect(b.expedition.sites[0]["contents"]["raw_food"] == 0, "load and reentry cannot reset looted containers")
		b.expedition.request_retreat()
		b.simulation_time = 1440
		b.expedition.refresh_for_day(3)
		var store := slot()
		expect(store.write_state(b)["ok"], "daily map and enemy changes are saved")
		var restored := make_scene()
		expect(SaveSystem.apply_state(restored, store.read_state()["data"]).is_empty() and restored.expedition.last_refresh_day == 3 and restored.expedition.enemies.size() == 4, "world refresh ledger survives load")
		restored.expedition.sites[0]["contents"]["raw_food"] = 0
		restored.expedition.refresh_for_day(3)
		expect(restored.expedition.sites[0]["contents"]["raw_food"] == 0, "restored day marker prevents a second refill")
		restored.free()
	a.free()
	b.free()
	print("PASS expedition save: persistent world depletion and day ledger")


func test_startup_away_resume() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	march(scene, 1, {"axis": 1.0})
	march(scene, 1, {"interact": true})
	var store := slot()
	expect(store.write_state(scene)["ok"], "active exploration can be saved before process restart")
	var fresh: Node2D = load("res://scenes/shelter.tscn").instantiate()
	fresh.save_store.path = store.path
	root.add_child(fresh)
	fresh.set_process(false)
	expect(fresh.paused and fresh.expedition.active and fresh.survivors[0].state == Survivor.TaskState.AWAY and fresh.expedition.search_progress > 0.9, "startup restores expedition mode, control and partial search, paused")
	fresh.toggle_pause()
	march(fresh, 1.2, {"interact": true})
	expect(fresh.expedition.bag["raw_food"] == 2 and fresh.inventory.amount("raw_food") == 4, "resumed search keeps cargo out of base until return")
	fresh.free()
	scene.free()
	print("PASS expedition save: automatic startup resumes current scene")


func test_treatment_progress() -> void:
	var a := make_scene()
	var b := make_scene()
	var actor: Survivor = a.survivors[1]
	actor.position = a.dining_table.work_position()
	actor.health = 60
	actor.injury = 55
	actor.infection = 40
	a.select_survivor(1)
	a.assign_task("heal")
	advance(a, 3)
	if round_trip(a, b):
		b.cancel_selected()
		b.cancel_selected()
		expect(b.inventory.amount("medicine") == 1 and b.survivors[1].health == 60 and b.survivors[1].injury == 55, "restored treatment can only refund once, never heal on cancellation")
		advance(a, 4)
		expect(a.survivors[1].completed_by_task["heal"] == 1 and a.survivors[1].health == 85 and a.survivors[1].injury == 5 and a.inventory.amount("medicine") == 0, "uninterrupted medic finishes one paid treatment")
	a.free()
	b.free()
	print("PASS expedition save: injury, infection and treatment continuity")
