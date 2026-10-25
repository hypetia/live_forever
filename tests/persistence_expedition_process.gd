extends SceneTree
## Three separate processes: half-search close -> resume/return close -> verify.


func _initialize() -> void:
	call_deferred("_run")


func simulate(scene: Node2D, seconds: float, controls: Dictionary = {}) -> void:
	scene.expedition_controls_override = controls
	for index in range(int(ceil(seconds * 60))): scene.advance_simulation(1.0 / 60)
	scene.expedition_controls_override = null


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read", "verify"]:
		printerr("Usage: -- write|read|verify <fresh-test-slot>")
		quit(1)
		return
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.save_store.path = args[1]
	if args[0] == "write" and scene.save_store.has_save():
		scene.free()
		printerr("Refusing to overwrite an existing expedition test slot")
		quit(1)
		return
	root.add_child(scene)
	scene.set_process(false)
	if args[0] == "write":
		scene.start_expedition(false, true)
		simulate(scene, 1, {"axis": 1.0})
		simulate(scene, 1, {"interact": true})
		if not scene.expedition.active or scene.expedition.search_progress < 0.9 or scene.expedition.used_capacity() != 1:
			printerr("Did not reach genuine partial search with carried medicine")
			quit(1)
			return
		scene.get_window().close_requested.emit()
		if not scene.save_store.read_state()["ok"]:
			printerr("Close did not persist expedition")
			quit(1)
			return
		print("EXPEDITION PROCESS WRITE PASS: close saved partial search and real loadout")
	elif args[0] == "read":
		if not scene.paused or not scene.expedition.active or scene.expedition.search_progress < 0.9 or scene.expedition.bag["medicine"] != 1 or scene.inventory.amount("medicine") != 0:
			printerr("Startup did not restore exact expedition state paused")
			quit(1)
			return
		scene.toggle_pause()
		simulate(scene, 1.2, {"interact": true})
		simulate(scene, 1, {"axis": -1.0})
		scene.expedition.request_retreat()
		if scene.expedition.active or scene.inventory.amount("raw_food") != 6 or scene.inventory.amount("medicine") != 1:
			printerr("Resumed search and return did not transfer exact cargo")
			quit(1)
			return
		scene.get_window().close_requested.emit()
		print("EXPEDITION PROCESS READ PASS: fresh process resumed, looted, returned and saved")
	else:
		if not scene.paused or scene.expedition.active or scene.inventory.amount("raw_food") != 6 or scene.inventory.amount("water") != 5 or scene.inventory.amount("medicine") != 1 or scene.expedition.sites[0]["contents"]["raw_food"] != 0:
			printerr("Returned save duplicated cargo or restored looted container")
			quit(1)
			return
		print("EXPEDITION PROCESS VERIFY PASS: returned cargo and depleted world persist exactly once")
		scene.free()
		quit(0)
