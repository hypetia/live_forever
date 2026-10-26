extends "res://tests/visual_story.gd"


func _run() -> void:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	await keypress(KEY_O)
	check(scene.center.visible and scene.center.tabs.current_tab == 7 and scene.paused, "O opens the real optional-project and aid handbook")
	check(scene.center.goal_picker.item_count == 3 and scene.center.goal_button.disabled and scene.center.goal_text.text.contains("勘查"), "three routes state real missing survey requirements before construction")
	check(scene.center.trade_buttons.values().all(func(b): return b.disabled), "new campaign cannot claim gated aid")
	await dialog_click(scene.center, scene.center.goal_picker)
	var popup: PopupMenu = scene.center.goal_picker.get_popup()
	await click_at(Vector2(popup.position) + Vector2(popup.size.x * 0.5, popup.size.y * 0.5))
	check(scene.goals.tracked == "clinic", "actual project selector tracks the medical route")
	await dialog_click(scene.center, scene.center.goal_picker)
	await click_at(Vector2(popup.position) + Vector2(popup.size.x * 0.5, popup.size.y / 6.0))
	check(scene.goals.tracked == "radio", "actual project selector returns to the radio route")
	await keypress(KEY_ESCAPE)
	var policy := Policy.new()
	policy.handle_projects = false
	var report := policy.run(scene, 3)
	check(report["alive"] == 3 and report["save_error"].is_empty(), "three genuine simulated days earn supplies and shelter level without injected inventory")
	var departed := true
	if not scene.goals.notes.has("works:1"):
		scene.choose_destination("works")
		departed = scene.start_expedition(true, true)
		policy._trip(1)
	check(departed, "survey evidence is obtained through a legal paid expedition")
	check(scene.goals.notes.has("works:1") and not scene.expedition.active, "real walking, climbing, searching and return deliver the factory blueprint")
	await keypress(KEY_O)
	check(not scene.center.goal_button.disabled, "returned evidence enables actual first project confirmation")
	await dialog_click(scene.center, scene.center.goal_button)
	check(scene.goals.stages["radio"] == 1, "actual button completes survey once")
	check(not scene.center.goal_button.disabled and scene.center.goal_button.text.contains("材料"), "actual construction button shows full cost and is affordable")
	var before: Dictionary = scene.inventory.snapshot()
	await dialog_click(scene.center, scene.center.goal_button)
	check(scene.goals.stages["radio"] == 2 and scene.inventory.amount("materials") == before["materials"] - 8 and scene.inventory.amount("tools") == before["tools"] - 2, "real UI construction consumes all its required resources once")
	check(scene.center.goal_button.disabled and scene.center.goal_text.text.contains("10天"), "next-stage calendar requirement is visible and cannot be skipped")
	await picture("res://docs/goals-preview.png")
	before = scene.inventory.snapshot()
	check(not scene.center.trade_buttons["medicine"].disabled, "earned surplus medicine can pay for real aid")
	await dialog_click(scene.center, scene.center.trade_buttons["medicine"])
	check(scene.inventory.amount("medicine") == before["medicine"] - 2 and scene.inventory.amount("water") == before["water"] + 2 and scene.goals.trades["medicine"] == 1, "actual aid button pays medicine and receives explicit supplies")
	check(scene.center.trade_buttons.values().all(func(b): return b.disabled), "all visible aid options share the same two-day lock")
	await picture("res://docs/aid-preview.png")
	await keypress(KEY_ESCAPE)
	await keypress(KEY_F11)
	for frame in range(4): await process_frame
	check(scene.game_audio.fullscreen and scene.center.fullscreen_check.button_pressed, "F11 enters real fullscreen and synchronizes settings")
	await keypress(KEY_F11)
	for frame in range(4): await process_frame
	check(not scene.game_audio.fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "second F11 returns to native windowed mode")
	await dispose_scene(scene)
	await process_frame
	# A fresh actual run keeps the first patrol alive; no damage/position fixture.
	scene = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	await keypress(KEY_V)
	await dialog_click(scene.prep_dialog, scene.prep_dialog.get_ok_button())
	var health: float = scene.survivors[scene.selected_id].health
	await held_key(KEY_D, true)
	simulate(scene, 2.8)
	await held_key(KEY_D, false)
	for tick in range(24):
		if scene.survivors[scene.selected_id].health < health: break
		simulate(scene, 0.25)
		await process_frame
	check(scene.survivors[scene.selected_id].health < health and scene.expedition_view.hurt_time > 0, "actual enemy bite produces health loss and transient visual feedback")
	await picture("res://docs/combat-feedback.png")
	await keypress(KEY_T)
	check(scene.expedition.active and scene.expedition.feedback.contains("步"), "failed remote retreat explains actual distance rather than teleporting")
	check(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "actual new-game injury and field state remain fully saveable")
	await dispose_scene(scene)
	await create_timer(0.12).timeout
	print("GOALS VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
