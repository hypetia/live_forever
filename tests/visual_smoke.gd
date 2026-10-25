extends SceneTree
## Requires a graphical display; verifies real GUI input and captures a frame.
## Run: godot --path . --resolution 1440x900 --script tests/visual_smoke.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL visual: ", message)
	else:
		print("PASS visual: ", message)


func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func keypress(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _run() -> void:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	await process_frame
	await click_at(Vector2(450, 820))
	check(scene.selected_id == 1, "avatar card selects the second survivor")
	await click_at(Vector2(330, 390))
	check(scene.selected_id == 0, "clicking a scene character selects that survivor")
	await click_at(Vector2(450, 820))
	await click_at(Vector2(500, 590))
	check(scene.survivors[1].orders.size() == 1, "scene workbench receives a mouse click")
	await click_at(Vector2(1230, 610))
	check(scene.survivors[1].orders.size() == 2, "action button appends a task")
	await keypress(KEY_SPACE)
	check(scene.paused, "Space pauses after clicking a GUI button")
	await keypress(KEY_SPACE)
	check(not scene.paused, "Space resumes")
	await keypress(KEY_3)
	check(scene.selected_id == 2, "keyboard selection is dispatched")
	await click_at(Vector2(1230, 661))
	await keypress(KEY_E)
	check(scene.survivors[2].orders.size() == 1, "keyboard assignment works")
	await keypress(KEY_Q)
	check(scene.survivors[2].orders.is_empty(), "keyboard cancellation works")
	for actor in scene.survivors:
		scene.scheduler.cancel(actor)
	await keypress(KEY_1)
	await click_at(Vector2(945, 390))
	check(scene.selected_task == "cook" and scene.survivors[0].orders == ["cook"], "clicking stove selects cooking and assigns it")
	check("生食×1" in scene.recipe_label.text and "熟食×2" in scene.recipe_label.text, "recipe UI shows the real cost and output")
	for tick_index in range(5 * 60):
		scene.advance_simulation(1.0 / 60)
	scene._refresh_hud()
	check(scene.inventory.amount("fuel") == 2 and "生食3" in scene.stock_label.text, "visible stock reflects the cooking debit")
	await click_at(Vector2(1230, 661))
	check(scene.inventory.amount("fuel") == 3 and scene.inventory.amount("meals") == 0, "GUI cancellation refunds active cooking without output")
	await keypress(KEY_F)
	await click_at(Vector2(1170, 407))
	await click_at(Vector2(1230, 610))
	check(scene.survivors[0].orders == ["cook", "repair"] and "做饭 → 修整" in scene.queue_label.text, "tabs and assignment show the mixed queue in order")
	for actor in scene.survivors:
		scene.scheduler.cancel(actor)
	# Capture a completed first batch, another cook and a repair in parallel.
	scene.select_survivor(1)
	scene.assign_task("cook")
	scene.select_survivor(2)
	scene.assign_task("repair")
	scene.assign_task("repair")
	scene.select_survivor(0)
	scene.assign_task("cook")
	for tick_index in range(11 * 60):
		scene.advance_simulation(1.0 / 60)
	scene.select_survivor(0)
	scene._refresh_hud()
	check(scene.inventory.amount("meals") == 2 and scene.stove.occupant_id == 0 and scene.facility.occupant_id == 2, "rendered example includes actual food production and parallel work")
	check(scene.survivors[1].position.distance_to(scene.survivors[0].position) > 35, "completed cook stands clear of the next worker")
	check(scene.progress_bar.size.y <= 8 and scene.progress_bar.position.y + scene.progress_bar.size.y < scene.completed_label.position.y, "progress bar stays thin and does not overlap the completion label")
	# Exercise the new player-facing facilities using actual input dispatch.
	for actor in scene.survivors:
		scene.scheduler.cancel(actor)
	await keypress(KEY_2)
	scene.survivors[1].hunger = 88
	await click_at(Vector2(500, 390))
	check(scene.selected_task == "eat" and scene.survivors[1].orders == ["eat"], "scene dining table assigns eating")
	for tick_index in range(8 * 60): scene.advance_simulation(1.0 / 60)
	scene._refresh_hud()
	check(scene.inventory.amount("meals") == 1 and scene.survivors[1].hunger < 40, "eating consumes actual cooked food and restores hunger")
	await keypress(KEY_1)
	scene.survivors[0].fatigue = 90
	await click_at(Vector2(385, 400))
	check(scene.selected_task == "sleep" and scene.survivors[0].orders == ["sleep"], "scene bed assigns rest")
	for tick_index in range(8 * 60): scene.advance_simulation(1.0 / 60)
	check(scene.survivors[0].fatigue < 90, "bed rest actually lowers fatigue")
	await keypress(KEY_Q)
	await keypress(KEY_H)
	check(scene.survivors[0].orders == ["sleep"], "sleep keyboard shortcut works")
	await keypress(KEY_Q)
	await keypress(KEY_3)
	var materials_before_craft: int = scene.inventory.amount("materials")
	await keypress(KEY_C)
	check(scene.survivors[2].orders == ["craft"], "craft shortcut selects fifth task")
	for tick_index in range(11 * 60): scene.advance_simulation(1.0 / 60)
	check(scene.inventory.amount("tools") == 1 and scene.inventory.amount("materials") == materials_before_craft - 2, "craft action creates a real tool from materials")
	scene._refresh_hud()
	check(scene.task_tabs.size() == 6 and scene.task_tabs["cook"].position.y + scene.task_tabs["cook"].size.y < scene.task_tabs["sleep"].position.y, "all six task buttons fit without overlap")
	# UI persistence uses an isolated test slot, never a player's default save.
	var save_path := ProjectSettings.globalize_path("user://visual_smoke_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	scene.save_store.path = save_path
	scene.persistence_enabled = true
	await keypress(KEY_F6)
	check(scene.save_store.has_save() and "保存成功" in scene.save_label.text, "F6 persists and reports a valid local save")
	scene.survivors[0].hunger = 99
	await keypress(KEY_F9)
	check(scene.load_dialog.visible and scene.paused, "F9 requests confirmation while simulation is paused")
	scene.load_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.paused and scene.survivors[0].hunger < 99 and not scene.load_dialog.visible, "confirm load restores saved state and remains paused")
	var preserved := SaveSystem.capture(scene)
	await click_at(Vector2(1015, 92))
	check(scene.new_dialog.visible, "new game button requires confirmation")
	scene.new_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(SaveSystem.capture(scene) == preserved, "cancelling new game retains the current run")
	scene.free()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	# Build the screenshot from a fresh real run, with no extra resources or
	# teleported characters: eating, sleeping and crafting happen together.
	scene = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	scene.select_survivor(0)
	scene.assign_task("cook")
	scene.assign_task("eat")
	scene.assign_task("sleep")
	scene.select_survivor(1)
	scene.assign_task("sleep")
	scene.select_survivor(2)
	scene.assign_task("craft")
	scene.assign_task("craft")
	for tick_index in range(13.5 * 60): scene.advance_simulation(1.0 / 60)
	scene.select_survivor(0)
	scene.select_task("eat")
	scene._refresh_hud()
	scene.queue_redraw()
	check(scene.dining_table.occupant_id == 0 and scene.bed.occupant_id == 1 and scene.facility.occupant_id == 2, "fresh-run frame shows eating, sleeping and crafting simultaneously")
	check(scene.survivors[1].fatigue < 35 and scene.inventory.amount("tools") == 1, "fresh-run frame contains earned rest and crafted output")
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var target := "res://docs/shelter-preview.png"
	check(frame.save_png(target) == OK, "rendered scene saved to docs/shelter-preview.png")
	var day_pixel := frame.get_pixel(130, 350)
	# Actually advance the same run into night; do not just change its clock.
	for tick_index in range(int((301 - 13.5) * 60)): scene.advance_simulation(1.0 / 60)
	scene.select_survivor(1)
	scene._refresh_hud()
	scene.queue_redraw()
	check("夜间" in scene.clock_label.text and scene.survivors[1].warned["hunger"], "night clock and earned hunger warning appear after actual simulation")
	await process_frame
	await RenderingServer.frame_post_draw
	var night_frame := root.get_texture().get_image()
	check(night_frame.get_pixel(130, 350).get_luminance() < day_pixel.get_luminance(), "night visibly dims the shelter background")
	check(night_frame.save_png("res://docs/night-preview.png") == OK, "actual night frame is saved")
	print("VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	scene.free()
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
