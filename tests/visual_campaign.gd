extends "res://tests/visual_long_term.gd"


func sim(scene: Node2D, seconds: float) -> void:
	for index in range(int(ceil(seconds * 60))): scene.advance_simulation(1.0 / 60.0)
	scene._process(0)
	scene.queue_redraw()


func double_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.double_click = true
	for down in [true, false]:
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func click_button(parent: Node, prefix: String) -> void:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix):
			await click_at(child.get_global_rect().get_center())
			return
	check(false, "button is present: " + prefix)


func _run() -> void:
	var scene: Node2D = load("res://scenes/campaign.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	check(scene.cycle.phase == "day" and scene.interface.shown.is_empty(), "campaign opens onto direct shelter play")
	await click_at(scene.cards[2].get_global_rect().get_center())
	check(scene.selected_id == 2, "clicking a person card changes the controlled survivor")
	await click_at(scene.world_root.to_global(Vector2(600, 638)))
	check(scene.survivors[2].route.back().x == 600, "left-click ground creates a real walking destination")
	sim(scene, 0.5)
	var x: float = scene.survivors[2].position.x
	await double_click(scene.world_root.to_global(Vector2(750, 638)))
	sim(scene, 0.5)
	check(scene.survivors[2].move_multiplier > 1 and scene.survivors[2].position.x - x > 110, "double-click runs faster along the actual route")
	await click_at(scene.cards[0].get_global_rect().get_center())
	var water: int = scene.inventory.amount("water")
	await click_at(scene.water_store.global_position + Vector2(0, -40))
	check(scene.inventory.amount("water") == water and scene.cycle.actions.size() == 1, "water interaction starts physical travel without remote drinking")
	sim(scene, 15)
	check(scene.inventory.amount("water") == water - 1 and scene.cycle.actions.is_empty(), "walking to the water store consumes and drinks exactly once")
	await keypress(KEY_B)
	check(scene.interface.build_open, "B opens an actual construction picker")
	await click_button(scene.interface.build_panel, "简易床")
	check(scene.placement == "bed" and not scene.interface.build_open, "recipe selection enters visible placement mode")
	await click_at(scene.world_root.to_global(CampaignCycle.SLOTS[0] - Vector2(0, 25)))
	check(scene.cycle.builds.size() == 1 and scene.cycle.builds[0]["state"] == "blueprint", "scene click places a paid blueprint")
	check(scene.cycle.bed_count() == 1 and scene.inventory.amount("materials") == 4, "placement spends actual stock and grants no premature facility")
	sim(scene, 45)
	check(scene.cycle.bed_count() == 2, "builder reaches the site and completes a second usable bed")
	await picture("res://docs/v12-cycle-construction.png")
	await click_at(scene.cards[1].get_global_rect().get_center())
	await click_at(scene.stove.global_position + Vector2(0, -118))
	check(scene.context_open and scene.selected_task == "cook", "clicking the stove opens its physical production choices")
	scene.batch_count.value = 2
	await click_at(scene.assign_button.get_global_rect().get_center())
	check(scene.survivors[1].orders == ["cook", "cook"], "production quantity queues two real batches")
	sim(scene, 20)
	check(scene.inventory.amount("meals") == 4 and scene.inventory.amount("raw_food") == 2, "two batches conserve exact ingredients and output")
	await keypress(KEY_ESCAPE)
	await click_at(scene.dining_table.global_position + Vector2(-30, -30))
	check(scene.survivors[1].orders == ["eat"] and not scene.context_open, "table is a direct eating action without another dashboard confirmation")
	sim(scene, 10)
	check(scene.inventory.amount("meals") == 3, "selected person actually eats one cooked meal")
	await picture("res://docs/v12-cycle-day.png")
	await click_button(scene.compact.root, "结束白天")
	check(scene.end_day_dialog.visible and scene.cycle.phase == "day", "end-day button asks before discarding unfinished work")
	await dialog_click(scene.end_day_dialog, scene.end_day_dialog.get_ok_button())
	check(scene.cycle.phase == "planning" and scene.interface.shown == "planning" and scene.paused, "confirmation enters a separate frozen night assignment screen")
	check(scene.interface.role_options.size() == 3 and scene.cycle.bed_count() == 2, "night assignment reflects living people and the bed actually built")
	var medicine: int = scene.inventory.amount("medicine")
	await click_at(scene.interface.supply_buttons["medicine"][1].get_global_rect().get_center())
	check(scene.cycle.loadout.get("medicine", 0) == 1 and scene.inventory.amount("medicine") == medicine, "equipment transfer remains a reversible draft until departure")
	await click_at(scene.interface.map_buttons["clinic"].get_global_rect().get_center())
	check(scene.expedition.location_id == "clinic" and not scene.expedition.active, "choosing a destination does not start a trip")
	await click_at(scene.interface.map_buttons["street"].get_global_rect().get_center())
	await picture("res://docs/v12-cycle-night-planning.png")
	await click_at(scene.interface.depart_button.get_global_rect().get_center())
	check(scene.cycle.phase == "scavenge" and scene.expedition.active and not scene.paused, "night departure starts exactly one real scavenging session")
	check(scene.inventory.amount("medicine") == medicine - 1 and scene.expedition.bag["medicine"] == 1, "departure transfers exact equipment once")
	await click_at(scene.world_offset() + Vector2(300, 600) * scene.world_scale())
	check(scene.interface.has_move_target and scene.interface.target_site == 0, "clicking a container sets a physical move-and-search goal")
	sim(scene, 5)
	check(absf(scene.expedition.player_x - 300) < 10 and scene._loot_open and scene.interface.shown == "loot", "character walks to the container, searches it and opens two inventories")
	check(scene.expedition.bag["raw_food"] == 0 and scene.expedition.sites[0]["contents"]["raw_food"] == 2, "opening inventory does not auto-pick the supplies")
	var time: float = scene.simulation_time
	sim(scene, 0.5)
	check(scene.simulation_time > time and not scene.paused, "night time continues while deciding what to carry")
	await keypress(KEY_SPACE)
	time = scene.simulation_time
	sim(scene, 1)
	check(scene.paused and scene.simulation_time == time, "explicit pause freezes danger and the night clock in the loot pane")
	await picture("res://docs/v12-cycle-loot.png")
	await click_at(scene.interface.loot_buttons["raw_food"].get_global_rect().get_center())
	await click_at(scene.interface.loot_returns["raw_food"].get_global_rect().get_center())
	check(scene.expedition.bag["raw_food"] == 0 and scene.expedition.sites[0]["contents"]["raw_food"] == 2, "two-way inventory transfer conserves actual items")
	await click_at(scene.interface.loot_buttons["raw_food"].get_global_rect().get_center())
	await click_at(scene.interface.loot_buttons["raw_food"].get_global_rect().get_center())
	await click_at(scene.interface.loot_buttons["water"].get_global_rect().get_center())
	check(scene.expedition.bag["raw_food"] == 2 and scene.inventory.amount("raw_food") == 2, "chosen cargo is carried physically without remote shelter credit")
	await keypress(KEY_ESCAPE)
	check(not scene._loot_open and scene.paused, "closing inventory preserves a deliberate pause")
	await keypress(KEY_SPACE)
	await click_at(scene.world_offset() + Vector2(110, 610) * scene.world_scale())
	sim(scene, 2)
	check(scene.expedition.player_x <= 145 and scene.cycle.phase == "scavenge", "mouse movement returns physically to extraction without banking early")
	await keypress(KEY_T)
	await keypress(KEY_ENTER) # Accept the explicit departure confirmation.
	check(scene.cycle.phase == "dawn" and scene.interface.shown == "dawn", "actual extraction leads to a dawn report rather than another free trip")
	check(CampaignCycle.minute(scene.simulation_time) == 360 and scene.inventory.amount("raw_food") == 4, "return advances to 06:00 and credits the selected supplies once")
	check(scene.cycle.report.size() >= 5 and scene.cycle.report.any(func(line): return "精神" in line), "dawn report explains night roles, fatigue and the home defense result")
	await picture("res://docs/v12-cycle-dawn.png")
	var path := ProjectSettings.globalize_path("user://campaign_visual_%d.json" % OS.get_process_id())
	scene.save_store.path = path
	scene.persistence_enabled = true
	await keypress(KEY_F6)
	check(scene.save_store.read_state()["ok"], "new phase and construction ledger are saveable from the morning screen")
	var stock: Dictionary = scene.inventory.snapshot()
	await keypress(KEY_F9)
	await dialog_click(scene.load_dialog, scene.load_dialog.get_ok_button())
	check(scene.cycle.phase == "dawn" and scene.inventory.snapshot() == stock and scene.cycle.bed_count() == 2, "load restores the already-settled morning and built bed without repeating results")
	await click_button(scene.interface.overlay, "开始白天")
	check(scene.cycle.phase == "day" and scene.interface.shown.is_empty() and not scene.paused, "morning acknowledgement returns to real shelter play")
	check(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "complete physical day-night-day loop remains fully valid")
	await dispose_scene(scene)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	# Another fresh run verifies unarmed mouse combat without position or damage fixtures.
	scene = load("res://scenes/campaign.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	scene.expansion.equip(scene, 1, 2) # Deliberately test unarmed push.
	scene.end_day()
	scene.start_expedition()
	var enemy: Dictionary = scene.expedition.enemies[0]
	await click_at(scene.world_offset() + Vector2(enemy["x"], ExpeditionState.FLOOR_Y[int(enemy["floor"])] - 40) * scene.world_scale())
	check(scene.interface.target_enemy == 0, "clicking an enemy creates a physical approach-and-attack command")
	sim(scene, 5)
	check(scene.expedition.enemies[0]["brace"] > 0 and scene.expedition_view.impact_kind == "push", "mouse approach reaches the patrol and performs a real unarmed push")
	await picture("res://docs/v12-cycle-mouse-combat.png")
	await dispose_scene(scene)
	print("CAMPAIGN VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
