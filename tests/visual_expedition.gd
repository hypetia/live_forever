extends "res://tests/visual_smoke.gd"
## Actual input dispatch for departure, movement, search, save/load and return.


func held_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func held_mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame


func simulate(scene: Node2D, seconds: float) -> void:
	# No control override: the model reads the real injected held key state.
	for index in range(int(ceil(seconds * 60))): scene.advance_simulation(1.0 / 60)
	scene._refresh_hud()
	scene.expedition_view.refresh()
	scene.queue_redraw()


func picture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "actual rendered frame saved: " + path)


func _run() -> void:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	var save_path := ProjectSettings.globalize_path("user://visual_expedition_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	scene.save_store.path = save_path
	scene.persistence_enabled = true
	await process_frame
	var stock: Dictionary = scene.inventory.snapshot()
	await keypress(KEY_V)
	check(scene.prep_dialog.visible and scene.paused, "V opens paused departure preparation")
	check(scene.prep_tool.disabled and scene.prep_medicine.button_pressed, "loadout controls reflect actual stock")
	var medicine_point: Vector2 = Vector2(scene.prep_dialog.position) + scene.prep_medicine.get_global_rect().get_center()
	await click_at(medicine_point)
	check(not scene.prep_medicine.button_pressed and scene.selected_id == 0, "actual checkbox click can omit medicine without selecting a background survivor")
	await click_at(medicine_point)
	check(scene.prep_medicine.button_pressed, "actual checkbox click can restore the optional loadout")
	check(scene.prep_text.get_global_rect().end.y < scene.prep_tool.get_global_rect().position.y and scene.prep_tool.get_global_rect().end.y < scene.prep_medicine.get_global_rect().position.y, "preparation message and both loadout rows do not overlap")
	await picture("res://docs/expedition-prep.png")
	scene.prep_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not scene.expedition.active and not scene.paused and scene.inventory.snapshot() == stock, "cancel departure consumes no equipment and resumes prior state")
	await click_at(Vector2(150, 241))
	check(scene.prep_dialog.visible, "departure button opens the same preparation flow")
	scene.prep_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.expedition.active and scene.survivors[0].state == Survivor.TaskState.AWAY and scene.expedition.bag["medicine"] == 1, "confirmation transfers loadout and enters exploration")
	check(scene.base_hud_nodes.all(func(node: Control): return not node.visible) and scene.expedition_view.layer.visible, "exploration hides base controls and shows mission HUD")
	await keypress(KEY_2)
	check(scene.selected_id == 0, "base survivor shortcut cannot steal expedition control")
	await held_key(KEY_CTRL, true)
	await held_key(KEY_D, true)
	simulate(scene, 0.3)
	await held_key(KEY_D, false)
	check(scene.expedition.sneaking and absf(scene.expedition.player_x - 138.5) < 0.1, "actual Ctrl+D input moves slowly and crouches")
	await held_key(KEY_A, true)
	simulate(scene, 0.3)
	await held_key(KEY_A, false)
	await held_key(KEY_CTRL, false)
	await keypress(KEY_J)
	check(scene.expedition.attack_windup > 0, "J dispatches a real swing instead of a base job")
	simulate(scene, 0.25)
	await held_key(KEY_D, true)
	simulate(scene, 1)
	await held_key(KEY_D, false)
	check(absf(scene.expedition.player_x - 300) < 0.1, "held D directly reaches first container")
	await held_key(KEY_E, true)
	simulate(scene, 1)
	await held_key(KEY_E, false)
	check(scene.expedition.search_progress > 0.9 and scene.expedition.used_capacity() == 1, "held E advances search without prematurely granting loot")
	await keypress(KEY_F6)
	check(scene.save_store.read_state()["ok"] and scene.save_store.read_state()["data"]["expedition"]["active"], "F6 saves the active scene and partial search")
	# Controlled damage fixture verifies the actual emergency-use shortcut;
	# later load restores the earlier unmodified state before screenshots.
	scene.survivors[0].health = 70
	scene.survivors[0].injury = 20
	scene.survivors[0].infection = 15
	await keypress(KEY_R)
	check(scene.survivors[0].health == 95 and scene.survivors[0].infection == 0 and scene.expedition.bag["medicine"] == 0, "R consumes carried medicine and treats actual injury")
	await held_mouse(Vector2(1230, 630), true)
	simulate(scene, 1.2)
	await held_mouse(Vector2(1230, 630), false)
	check(scene.expedition.bag["raw_food"] == 2 and not scene.expedition_view.search_held, "holding and releasing search button works like held E")
	await keypress(KEY_F9)
	check(scene.load_dialog.visible and scene.paused, "F9 requests safe restore during expedition")
	scene.load_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.expedition.active and scene.paused and scene.expedition.search_progress > 0.9 and scene.expedition.bag["raw_food"] == 0 and scene.expedition.bag["medicine"] == 1 and scene.survivors[0].health == 100, "restore rewinds complete mission state rather than duplicating collected loot")
	var point: float = scene.expedition.player_x
	await held_key(KEY_D, true)
	simulate(scene, 0.5)
	await held_key(KEY_D, false)
	check(scene.expedition.player_x == point, "paused exploration ignores held movement")
	await keypress(KEY_SPACE)
	await held_key(KEY_E, true)
	simulate(scene, 1.2)
	await held_key(KEY_E, false)
	check(scene.expedition.bag["raw_food"] == 2 and scene.inventory.amount("raw_food") == 4, "resumed search restores cargo but still cannot credit base remotely")
	await keypress(KEY_T)
	check(scene.expedition.active and scene.expedition.player_x == point, "T away from entry gives a route hint without teleporting")
	await held_key(KEY_SHIFT, true)
	await held_key(KEY_D, true)
	simulate(scene, 4.3)
	await held_key(KEY_D, false)
	await held_key(KEY_SHIFT, false)
	check(absf(scene.expedition.player_x - ExpeditionState.LADDER_X) < 48, "actual sprint input reaches ladder across dangerous street")
	await held_key(KEY_W, true)
	simulate(scene, 1)
	check(scene.expedition.climb_target == 1 and scene.expedition.player_y > 400 and scene.expedition.player_y < 620, "W visibly climbs the real ladder")
	await picture("res://docs/expedition-preview.png")
	simulate(scene, 1.2)
	await held_key(KEY_W, false)
	check(scene.expedition.floor_level == 1, "held climb reaches second floor")
	await held_key(KEY_S, true)
	simulate(scene, 2.2)
	await held_key(KEY_S, false)
	check(scene.expedition.floor_level == 0, "S returns to street and exit route")
	await held_key(KEY_SHIFT, true)
	await held_key(KEY_A, true)
	simulate(scene, 5.1)
	await held_key(KEY_A, false)
	await held_key(KEY_SHIFT, false)
	check(scene.expedition.player_x <= 145, "player physically returns to extraction area")
	await keypress(KEY_T)
	check(not scene.expedition.active and scene.paused and scene.inventory.amount("raw_food") == 6 and scene.inventory.amount("water") == 5 and scene.inventory.amount("medicine") == 1, "T at entry extracts exact loot and unused loadout")
	check(not scene.expedition_view.layer.visible and scene.base_hud_nodes.any(func(node: Control): return node.visible), "return restores playable base interface")
	await picture("res://docs/expedition-return.png")
	await keypress(KEY_F)
	await keypress(KEY_G)
	await keypress(KEY_H)
	check(scene.survivors[0].orders == ["cook", "eat", "sleep"], "returned supplies can enter the full base life queue")
	await keypress(KEY_SPACE)
	simulate(scene, 45)
	check(scene.survivors[0].completed_by_task["cook"] == 1 and scene.survivors[0].completed_by_task["eat"] == 1 and scene.survivors[0].completed_by_task["sleep"] == 1, "actual outward trip feeds and rests a survivor through normal tasks")
	check(scene.inventory.amount("raw_food") == 5 and scene.inventory.amount("fuel") == 2 and scene.inventory.amount("meals") == 1, "whole expedition-base cycle conserves its real costs and output")
	await keypress(KEY_F6)
	check(scene.save_store.read_state()["ok"] and not scene.save_store.read_state()["data"]["expedition"]["active"], "completed cycle saves as a valid base state")
	scene.free()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("EXPEDITION VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
