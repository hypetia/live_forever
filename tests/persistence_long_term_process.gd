extends SceneTree
## Separate processes exercise a non-default world plus earned upgrade/event state.


func _initialize() -> void:
	call_deferred("_run")


func simulate(scene: Node2D, seconds: float, controls: Dictionary = {}) -> void:
	scene.expedition_controls_override = controls
	for index in range(int(ceil(seconds * 60))): scene.advance_simulation(1.0 / 60)
	scene.expedition_controls_override = null


func fail(message: String) -> void:
	printerr("LONG TERM PROCESS FAIL: " + message)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read", "verify"]:
		fail("Usage: -- write|read|verify <fresh-test-slot>")
		return
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.save_store.path = args[1]
	if args[0] == "write" and scene.save_store.has_save():
		scene.free()
		fail("Refusing to overwrite existing test progress")
		return
	root.add_child(scene)
	scene.set_process(false)
	if args[0] == "write":
		scene.choose_destination("works")
		scene.start_expedition(false, true)
		simulate(scene, 1.2, {"axis": 1.0})
		simulate(scene, 3.2, {"interact": true})
		simulate(scene, 2.8, {"axis": 1.0, "sprint": true})
		simulate(scene, 1, {"climb": 1})
		if scene.expedition.climb_target != 1 or scene.expedition.bag["materials"] != 3 or scene.expedition.bag["fuel"] != 1:
			fail("Did not reach genuine non-default-world half-climb with earned cargo")
			return
		scene.get_window().close_requested.emit()
		if not scene.save_store.read_state()["ok"]:
			fail("Normal close did not save factory expedition")
			return
		print("LONG TERM PROCESS WRITE PASS: factory cargo and real mid-climb saved")
	elif args[0] == "read":
		if not scene.paused or not scene.expedition.active or scene.expedition.location_id != "works" or scene.expedition.climb_target != 1:
			fail("Normal startup did not restore factory mission paused")
			return
		scene.toggle_pause()
		simulate(scene, 1.2)
		simulate(scene, 2.2, {"climb": -1})
		simulate(scene, 4, {"axis": -1.0, "sprint": true})
		scene.expedition.request_retreat()
		if scene.inventory.amount("materials") != 11 or scene.inventory.amount("fuel") != 4 or scene.upkeep.returns["works"] != 1:
			fail("Factory cargo did not return exactly once")
			return
		scene.select_survivor(0)
		scene.assign_task("craft")
		scene.toggle_pause()
		simulate(scene, 20)
		if not scene.upkeep.upgrade(scene.inventory):
			fail("Earned crafting could not fund real upgrade")
			return
		simulate(scene, 480 - scene.simulation_time + 0.1)
		if not scene.upkeep.resolve_event(true, scene.inventory):
			fail("New-day event could not trade real remaining goods")
			return
		scene.get_window().close_requested.emit()
		print("LONG TERM PROCESS READ PASS: resumed factory, returned, crafted, upgraded and resolved real day2 event")
	else:
		if not scene.paused or scene.expedition.active or scene.expedition.location_id != "works" or scene.upkeep.level != 1 or scene.upkeep.resolved_events != 1 or scene.upkeep.pending_event != -1:
			fail("Upgraded resolved-event base did not survive third startup")
			return
		if scene.inventory.amount("materials") != 3 or scene.inventory.amount("water") != 10 or scene.inventory.amount("tools") != 0 or scene.inventory.amount("fuel") != 4 or scene.inventory.amount("medicine") != 1:
			fail("Third startup duplicated or lost any paid resource")
			return
		if scene.regions["works"].sites[0]["contents"]["materials"] != 0 or scene.regions["clinic"].attempts != 0 or scene.upkeep.returns["works"] != 1:
			fail("Inactive map ledger or supply-run record was reset")
			return
		print("LONG TERM PROCESS VERIFY PASS: paid upgrades/event, exact supplies and separate worlds persist once")
		scene.free()
		quit(0)
