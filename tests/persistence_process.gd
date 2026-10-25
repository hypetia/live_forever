extends SceneTree
## Separate-process lifecycle probe. Supply: -- write|read /tmp/unique/slot.json


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0] in ["write", "read"]:
		printerr("Usage: -- write|read /tmp/unique/slot.json")
		quit(1)
		return
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.save_store.path = args[1]
	if args[0] == "write" and scene.save_store.has_save():
		scene.free()
		printerr("Probe refuses to replace an existing save; choose a fresh slot.")
		quit(1)
		return
	root.add_child(scene)
	scene.set_process(false)
	if args[0] == "write":
		scene.survivors[0].position = scene.stove.work_position()
		scene.assign_task("cook")
		for index in range(120): scene.advance_simulation(1.0 / 60)
		if scene.stove.occupant_id != 0 or scene.inventory.amount("fuel") != 2:
			printerr("Probe did not start a real cooking job")
			quit(1)
			return
		# Exercise the actual WM-close handler, not just SaveSystem.write_state.
		scene.get_window().close_requested.emit()
		if not scene.save_store.read_state()["ok"]:
			printerr("Close handler did not persist a valid save")
			quit(1)
		else:
			print("PROCESS WRITE PASS: close saved a paid, unfinished cooking task")
	else:
		var actor: Survivor = scene.survivors[0]
		if not scene.paused or absf(scene.simulation_time - 2) > 0.0001 or scene.stove.occupant_id != 0 or actor.orders != ["cook"] or actor.held_cost.get("fuel") != 1 or scene.inventory.amount("fuel") != 2:
			printerr("New process did not resume exact paid task state")
			quit(1)
			return
		scene.toggle_pause()
		for index in range(7 * 60): scene.advance_simulation(1.0 / 60)
		if scene.inventory.amount("meals") != 2 or scene.inventory.amount("fuel") != 2:
			printerr("Resumed process duplicated consumption or output")
			quit(1)
			return
		print("PROCESS READ PASS: fresh process resumed paused and produced exactly once")
		scene.free()
		quit(0)
