extends "res://tests/test_shelter.gd"

var test_directory := OS.get_cache_dir().path_join("live_forever_save_tests_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
var slot_number := 0


func slot() -> SaveSystem:
	DirAccess.make_dir_recursive_absolute(test_directory)
	slot_number += 1
	var store := SaveSystem.new()
	store.path = test_directory.path_join("slot_%d.json" % slot_number)
	return store


func equivalent(a: Variant, b: Variant) -> bool:
	# JSON's decimal parser can differ by a final binary digit (~1e-14).
	# Discrete fields stay exact; only numeric round-trip noise is tolerated.
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not equivalent(a[index], b[index]): return false
		return true
	return a == b


func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	test_initial_and_stair_restore()
	test_active_costs_and_waiters()
	test_no_repeated_completed_output()
	test_backup_recovery()
	test_checksum_and_version()
	test_invalid_state_is_atomic()
	test_auto_save_and_resume()
	test_sleep_restore()
	test_failure_restore_and_new_game()
	test_oversized_file()
	test_eating_restore_and_cancel()
	test_bad_files_disable_auto_save()
	var directory := DirAccess.open(test_directory)
	for filename in directory.get_files():
		DirAccess.remove_absolute(test_directory.path_join(filename))
	DirAccess.remove_absolute(test_directory)
	print("SAVE RESULT: %d checks, %d failures; 12 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_initial_and_stair_restore() -> void:
	var a := make_scene()
	var b := make_scene()
	expect(SaveSystem.validate(SaveSystem.capture(a)).is_empty(), "initial scene is a valid snapshot")
	a.select_survivor(2)
	a.assign_task("cook")
	advance(a, 4)
	expect(a.survivors[2].position.y > 430 and a.survivors[2].position.y < 640, "save scenario reaches the actual stair edge")
	var store := slot()
	expect(store.write_state(a)["ok"], "stair snapshot writes to disk")
	var loaded := store.read_state()
	expect(loaded["ok"] and not loaded["backup"], "fresh primary loads and passes checksum")
	expect(SaveSystem.apply_state(b, loaded["data"]).is_empty(), "validated stair snapshot applies")
	expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "load restores route, clock, needs, choices and stock within floating-point precision")
	advance(a, 30)
	advance(b, 30)
	expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "restored stair task produces the same future as uninterrupted play")
	a.free()
	b.free()
	print("PASS save: moving across stairs")


func test_active_costs_and_waiters() -> void:
	var a := make_scene()
	var b := make_scene()
	a.survivors[0].position = a.stove.work_position()
	a.survivors[2].position = a.facility.work_position()
	a.scheduler.submit(a.survivors[0], "cook")
	a.scheduler.submit(a.survivors[1], "cook")
	a.scheduler.submit(a.survivors[2], "craft")
	advance(a, 2)
	expect(a.stove.occupant_id == 0 and a.facility.occupant_id == 2 and a.survivors[1].state == Survivor.TaskState.WAITING, "save contains two workers and an actual waiting survivor")
	var store := slot()
	expect(store.write_state(a)["ok"], "snapshot with paid inputs and FIFO waiters writes")
	var loaded := store.read_state()
	expect(loaded["ok"] and SaveSystem.apply_state(b, loaded["data"]).is_empty(), "paid inputs and waiters restore")
	expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "active snapshot restores every logical field")
	b.scheduler.cancel(b.survivors[0])
	b.scheduler.cancel(b.survivors[0])
	expect(b.inventory.amount("fuel") == 3 and b.inventory.amount("materials") == 6, "cancel after load refunds one cook but not another worker's materials")
	advance(b, 30)
	expect(b.inventory.amount("meals") == 2 and b.inventory.amount("tools") == 1, "restored waiter and craft finish exactly once")
	expect(b.inventory.amount("fuel") == 2 and b.inventory.amount("materials") == 6, "restore and cancel cannot create duplicate inputs")
	a.free()
	b.free()
	print("PASS save: held inputs and multiple facilities")


func test_no_repeated_completed_output() -> void:
	var a := make_scene()
	var b := make_scene()
	a.scheduler.submit(a.survivors[0], "cook")
	a.scheduler.submit(a.survivors[2], "craft")
	advance(a, 25)
	var stock: Dictionary = a.inventory.snapshot()
	expect(SaveSystem.apply_state(b, SaveSystem.capture(a)).is_empty(), "finished tasks restore as finished")
	advance(b, 25)
	expect(b.inventory.snapshot() == stock and b.stove.completed_jobs == 1 and b.facility.completed_jobs == 1, "finished jobs never repeat output on load")
	a.free()
	b.free()
	print("PASS save: completed outputs are not replayed")


func test_backup_recovery() -> void:
	var scene := make_scene()
	var store := slot()
	expect(store.write_state(scene)["ok"], "first save succeeds")
	advance(scene, 1)
	expect(store.write_state(scene)["ok"] and FileAccess.file_exists(store.path + ".bak"), "second save preserves previous valid file as backup")
	var backup_bytes := FileAccess.get_file_as_string(store.path + ".bak")
	write_text(store.path, "{truncated")
	var recovered := store.read_state()
	expect(recovered["ok"] and recovered["backup"] and recovered["data"]["simulation_time"] == 0, "corrupt primary recovers previous snapshot from backup")
	expect(store.write_state(scene)["ok"], "valid runtime can replace corrupt primary")
	expect(FileAccess.get_file_as_string(store.path + ".bak") == backup_bytes, "corrupt primary never overwrites a valid backup")
	expect(store.read_state()["ok"] and not store.read_state()["backup"], "new primary is readable after recovery")
	scene.free()
	print("PASS save: atomic replacement and backup recovery")


func test_checksum_and_version() -> void:
	var scene := make_scene()
	var store := slot()
	expect(store.write_state(scene)["ok"], "checksum test writes a valid primary")
	var original := FileAccess.get_file_as_string(store.path)
	var envelope: Dictionary = JSON.parse_string(original)
	envelope["data_json"] += " "
	write_text(store.path, JSON.stringify(envelope))
	expect(not store.read_state()["ok"], "changed payload with stale checksum is rejected")
	envelope = JSON.parse_string(original)
	envelope["version"] = 999
	write_text(store.path, JSON.stringify(envelope))
	expect(not store.read_state()["ok"], "unsupported schema version is rejected")
	expect(scene.simulation_time == 0 and scene.inventory.amount("fuel") == 3, "failed reads do not mutate the running scene")
	scene.free()
	print("PASS save: checksum and version errors")


func test_invalid_state_is_atomic() -> void:
	var scene := make_scene()
	var initial := SaveSystem.capture(scene)
	var mutations: Array[Dictionary] = []
	var bad := initial.duplicate(true)
	bad["stock"]["fuel"] = -1
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["health"] = NAN
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["orders"] = ["unknown"]
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["route"] = [[500, 520]]
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["held_cost"] = {"raw_food": 1}
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["stations"]["stove"]["waiters"] = [0, 0]
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["completed_jobs"] = 1
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["speed"] = INF
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["actors"][0]["state"] = Survivor.TaskState.DEAD
	mutations.append(bad)
	bad = initial.duplicate(true)
	bad["history"] = [{"kind": "credit", "items": {"tools": -1}, "reason": "invalid"}]
	mutations.append(bad)
	for mutation in mutations:
		expect(not SaveSystem.apply_state(scene, mutation).is_empty(), "invalid state is rejected before application")
		expect(SaveSystem.capture(scene) == initial, "failed validation leaves the entire existing scene intact")
	var store := slot()
	expect(store.write_state(scene)["ok"], "guarded write has an existing valid file")
	var original := FileAccess.get_file_as_string(store.path)
	scene.survivors[0].hunger = -1
	expect(not store.write_state(scene)["ok"], "invalid live state is refused before writing")
	expect(FileAccess.get_file_as_string(store.path) == original, "failed write retains prior save bytes")
	scene.survivors[0].hunger = 45
	scene.scheduler.submit(scene.survivors[0], "cook")
	bad = SaveSystem.capture(scene)
	bad["actors"][0]["work_duration"] = 1
	expect(not SaveSystem.validate(bad).is_empty(), "tampered queued duration cannot accelerate work after load")
	scene.free()
	print("PASS save: complete validation before mutation")


func test_auto_save_and_resume() -> void:
	var scene := make_scene()
	var store := slot()
	scene.save_store.path = store.path
	scene.persistence_enabled = true
	advance(scene, 59.9)
	expect(not FileAccess.file_exists(store.path), "autosave does not write early")
	advance(scene, 0.2)
	expect(FileAccess.file_exists(store.path) and store.read_state()["ok"], "autosave produces a valid snapshot at interval")
	scene.survivors[0].hunger = 90
	expect(scene.load_game() and scene.paused and scene.survivors[0].hunger < 60, "user load restores saved needs and pauses for review")
	var saved_time: float = scene.simulation_time
	advance(scene, 10)
	expect(scene.simulation_time == saved_time, "resumed save has no offline or paused time consumption")
	var fresh: Node2D = load("res://scenes/shelter.tscn").instantiate()
	fresh.save_store.path = store.path
	root.add_child(fresh)
	fresh.set_process(false)
	expect(fresh.paused and absf(fresh.simulation_time - saved_time) < 0.001, "new scene automatically resumes disk save at exact time")
	fresh.start_new_game()
	expect(fresh.simulation_time == 0 and not fresh.paused and store.read_state()["data"]["simulation_time"] == 0, "confirmed new game replaces primary with a valid fresh snapshot")
	expect(FileAccess.file_exists(store.path + ".bak"), "new game keeps previously saved run as backup")
	fresh.free()
	scene.free()
	print("PASS save: autosave, startup resume and new game")


func test_sleep_restore() -> void:
	var a := make_scene()
	var b := make_scene()
	a.survivors[0].position = a.bed.work_position()
	a.survivors[0].fatigue = 90
	a.assign_task("sleep")
	advance(a, 5)
	var store := slot()
	expect(store.write_state(a)["ok"], "partially restored fatigue and sleep progress can be saved")
	expect(SaveSystem.apply_state(b, store.read_state()["data"]).is_empty(), "sleep snapshot restores")
	advance(a, 16)
	advance(b, 16)
	expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.survivors[0].completed_by_task["sleep"] == 1, "restored sleep recovers identical fatigue without replaying rest")
	a.free()
	b.free()
	print("PASS save: interrupted sleep continuity")


func test_failure_restore_and_new_game() -> void:
	var a := make_scene()
	var b := make_scene()
	for actor in a.survivors:
		a.scheduler.mark_dead(actor)
	advance(a, 0.1)
	var store := slot()
	expect(store.write_state(a)["ok"], "failed run is a valid persistent state")
	expect(SaveSystem.apply_state(b, store.read_state()["data"]).is_empty(), "death state restores")
	expect(b.game_over and b.paused and b.survivors.all(func(actor: Survivor): return actor.health == 0), "load does not resurrect dead survivors")
	b.start_new_game()
	expect(not b.game_over and b.survivors[0].health == 100 and b.inventory.amount("fuel") == 3, "explicit new game resets failure rather than silently reviving save")
	a.free()
	b.free()
	print("PASS save: permanent death state and explicit reset")


func test_oversized_file() -> void:
	var store := slot()
	write_text(store.path, "x".repeat(SaveSystem.MAX_BYTES + 1))
	expect(not store.read_state()["ok"], "oversized file is rejected before JSON parsing")
	print("PASS save: size guard")


func test_eating_restore_and_cancel() -> void:
	var a := make_scene()
	var b := make_scene()
	a.survivors[0].position = a.dining_table.work_position()
	a.survivors[0].hunger = 90
	a.inventory.deposit({"meals": 1}, "test eating")
	a.assign_task("eat")
	advance(a, 2)
	var store := slot()
	expect(store.write_state(a)["ok"], "half-eaten task snapshots paid meal without early benefit")
	expect(SaveSystem.apply_state(b, store.read_state()["data"]).is_empty(), "half-eaten task restores")
	b.cancel_selected()
	b.cancel_selected()
	expect(b.inventory.amount("meals") == 1 and b.survivors[0].hunger >= 90, "cancel after eating restore refunds once and does not improve hunger")
	advance(a, 3)
	expect(a.inventory.amount("meals") == 0 and a.survivors[0].hunger < 40, "uninterrupted eating consumes and restores only on completion")
	a.free()
	b.free()
	print("PASS save: eating refund remains safe after load")


func test_bad_files_disable_auto_save() -> void:
	var scene := make_scene()
	var store := slot()
	write_text(store.path, "bad primary")
	write_text(store.path + ".bak", "bad backup")
	scene.save_store.path = store.path
	scene.persistence_enabled = true
	var stock: Dictionary = scene.inventory.snapshot()
	var point: Vector2 = scene.survivors[0].position
	expect(not scene.load_game() and not scene.auto_save_allowed, "two corrupt files disable automatic saving")
	expect(scene.inventory.snapshot() == stock and scene.survivors[0].position == point, "failed user load preserves current inventory and position")
	advance(scene, 65)
	expect(FileAccess.get_file_as_string(store.path) == "bad primary" and FileAccess.get_file_as_string(store.path + ".bak") == "bad backup", "autosave interval does not overwrite failed files silently")
	expect(scene.save_game() and scene.auto_save_allowed and store.read_state()["ok"], "explicit manual save restores valid primary and re-enables autosave")
	expect(scene.load_game() and scene.paused, "repaired slot can resume normally")
	scene.free()
	print("PASS save: bad files remain protected until an explicit save")
