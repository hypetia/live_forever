extends "res://tests/visual_long_term.gd"
## v0.9 input, targeting, combat and clock regression. Combat fixtures are explicit;
## screenshots of normal play are captured separately by visual_smoke/goals.


func right_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	for down in [true, false]:
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func fresh() -> Node2D:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	return scene


func _run() -> void:
	var scene := fresh()
	await process_frame
	check(not scene.context_open and scene.context_nodes.all(func(node): return not node.visible), "new game opens onto the house with task drawer closed")
	check(scene.world_root.scale.x > 1 and scene.survivors[0].get_parent() == scene.world_root, "larger physical house and actors share one world transform")
	check(scene.day_bar.visible and "距天黑" in scene.phase_label.text and "08:00" in scene.clock_label.text, "daylight clock and time to dusk are visible from the first frame")
	var old_clock: String = scene.clock_label.text
	var old_bar: float = scene.day_bar.value
	simulate(scene, 12)
	check(scene.clock_label.text != old_clock and scene.day_bar.value > old_bar, "playing in the house advances the actual clock and day timeline")
	await keypress(KEY_SPACE)
	var frozen_time: float = scene.simulation_time
	var frozen_label: String = scene.phase_label.text
	simulate(scene, 10)
	check(scene.simulation_time == frozen_time and scene.phase_label.text == frozen_label, "pause freezes the visible day countdown and underlying simulation together")
	await keypress(KEY_SPACE)
	await click_at(scene.cards[1].get_global_rect().get_center())
	check(scene.selected_id == 1, "compact roster selects the intended person")
	var stock: Dictionary = scene.inventory.snapshot()
	await click_at(scene.facility.global_position + Vector2(0, -38))
	check(scene.context_open and scene.selected_task == "repair" and scene.survivors[1].orders.is_empty() and scene.inventory.snapshot() == stock, "clicking a workstation explains the action before spending or assigning")
	check(scene.task_tabs["repair"].visible and scene.task_tabs["craft"].visible and not scene.task_tabs["heal"].visible, "workbench exposes only its own physical actions")
	await click_at(scene.assign_button.get_global_rect().get_center())
	check(scene.survivors[1].orders == ["repair"], "confirmation names and dispatches the selected actor")
	await keypress(KEY_ESCAPE)
	check(not scene.context_open and not scene.center.visible, "Escape first closes the contextual drawer without opening a menu")
	simulate(scene, 12)
	await keypress(KEY_F)
	simulate(scene, 8)
	check(scene.stove.occupant_id == 1 and scene.inventory.amount("fuel") == 2, "cooking begins physically at the stove with actual input costs")
	await keypress(KEY_ESCAPE)
	await right_click(scene.world_root.to_global(Vector2(400, 640)))
	check(scene.survivors[1].orders.is_empty() and scene.stove.occupant_id == -1 and scene.inventory.amount("fuel") == 3, "right-click movement cancels active work, refunds it and releases the station once")
	check(scene.survivors[1].route.size() == 3 and scene.survivors[1].route.has(ShelterNavigation.TOP_STAIR) and scene.survivors[1].route.has(ShelterNavigation.BOTTOM_STAIR), "cross-floor movement follows both stair landings")
	check(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "new direct movement is valid in the existing save format")
	simulate(scene, 14)
	check(scene.survivors[1].position.distance_to(Vector2(400, 640)) < 0.1 and scene.survivors[1].state == Survivor.TaskState.IDLE, "right-click destination is physically reached and returns to idle")
	var thirst: float = scene.survivors[1].person.thirst
	var water: int = scene.inventory.amount("water")
	await click_at(scene.water_store.global_position + Vector2(0, -30))
	check(scene.inventory.amount("water") == water - 1 and scene.survivors[1].person.thirst < thirst, "clicking the physical water store hydrates the selected person using real water")
	await click_at(scene.exit_door.global_position + Vector2(0, -40))
	check(scene.prep_dialog.visible and scene.paused, "the actual house door opens paused departure preparation")
	scene.prep_dialog.get_cancel_button().pressed.emit()
	await process_frame
	scene.select_survivor(2)
	# Explicit injury fixture distinguishes self-treatment from medical assistance.
	scene.survivors[2].health = 60
	scene.survivors[2].injury = 55
	scene.survivors[2].infection = 42
	var other_health: float = scene.survivors[0].health
	scene.open_station("heal")
	check(scene.assign_button.text.contains(scene.survivors[2].display_name) and scene.assign_button.text.contains("接受治疗") and scene.recipe_label.text.contains("给自己用药"), "treatment action explicitly identifies the patient and self-medication")
	check(scene.task_tabs["heal"].visible and scene.task_tabs["eat"].visible and not scene.task_tabs["repair"].visible, "table presents food and medical care instead of every action")
	await click_at(scene.assign_button.get_global_rect().get_center())
	simulate(scene, 25)
	check(scene.survivors[2].health > 80 and scene.survivors[2].injury < 10 and scene.inventory.amount("medicine") == 0, "named patient actually receives the single paid treatment")
	check(is_equal_approx(scene.survivors[0].health, other_health), "self-treatment does not heal an unselected teammate")
	scene.select_survivor(1)
	scene.open_center(5)
	await process_frame
	check(scene.center.aid_button.text.contains(scene.survivors[1].display_name) and scene.center.aid_button.text.contains("→"), "medical assistance separately names the caregiver and recipient")
	check(scene.center.aid_button.tooltip_text.contains("接受治疗者"), "assistance explanation identifies the receiver")
	var before: Array[Vector2] = []
	for actor: Survivor in scene.survivors: before.append(actor.position)
	await right_click(Vector2(500, 600))
	check(scene.survivors[1].route.is_empty() and scene.center.visible, "modal handbook blocks background movement")
	scene.center.close()
	scene.context_open = false
	scene._refresh_hud()
	await picture("res://docs/m09-shelter-preview.png")
	scene.open_station("heal")
	await picture("res://docs/m09-treatment-preview.png")
	await dispose_scene(scene)
	await process_frame
	# A fresh scene exercises combat outcomes against one controlled enemy fixture.
	scene = fresh()
	await process_frame
	scene.open_station("cook")
	scene.start_expedition()
	var field: ExpeditionState = scene.expedition
	var view: ExpeditionView = scene.expedition_view
	check(not scene.world_root.visible and not scene.context_open and not view.bag_open and view.bag_nodes.all(func(node): return not node.visible), "expedition opens on the world with no persistent inventory dashboard")
	await keypress(KEY_I)
	check(view.bag_open and view.capacity_label.visible, "I opens the optional inventory")
	await click_at(view.bag_button.get_global_rect().get_center())
	check(not view.bag_open, "inventory button closes it without consuming world input")
	field.bag["tools"] = 1
	await keypress(KEY_J)
	check(field.attack_windup > 0 and field.bag["tools"] == 1, "attack visibly starts a windup before spending equipment")
	simulate(scene, 0.25)
	check(view.impact_kind == "miss" and field.feedback.contains("挥空") and field.bag["tools"] == 1, "swinging into empty space reports a miss and preserves the tool")
	simulate(scene, 1.0)
	# Fixture: enemy on same floor, ahead and within reach; no arbitrary health edits.
	field.player_x = 850
	field.facing = 1
	field.enemies[0]["x"] = 895.0
	field.enemies[0]["mode"] = "patrol"
	field.enemies[0]["direction"] = 1.0
	field.enemies[0]["suspicion"] = 0.0
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(field.enemies[0]["hp"] == 0 and field.bag["tools"] == 0 and view.impact_kind == "hit" and view.impact_damage == 40, "tool impact couples actual enemy health loss, damage number and equipment cost")
	check(field.feedback.contains("命中") and field.feedback.contains("−40"), "successful damage has an explicit result instead of only an arc")
	await picture("res://docs/m09-hit-fixture.png")
	await dispose_scene(scene)
	await process_frame
	scene = fresh()
	await process_frame
	scene.start_expedition()
	field = scene.expedition
	view = scene.expedition_view
	field.player_x = 850
	field.facing = 1
	field.enemies[0]["x"] = 895.0
	field.enemies[0]["direction"] = 1.0
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(field.enemies[0]["hp"] == 40 and field.enemies[0]["mode"] == "stunned" and view.impact_kind == "push", "bare hands show successful knockback while preserving enemy health")
	check(field.feedback.contains("不造成伤害") and view.attack_button.text.contains("冷却"), "push result and attack recovery are explicit")
	field.attack_cooldown = 0
	field.enemies[0]["x"] = field.player_x + 45
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(view.impact_kind == "blocked" and field.enemies[0]["hp"] == 40, "braced enemy reports a blocked push rather than fake damage")
	field.attack_cooldown = 0
	field.enemies[0]["x"] = field.player_x - 45
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(view.impact_kind == "miss", "enemy behind the player does not receive a forward hit")
	field.attack_cooldown = 0
	field.enemies[0]["x"] = field.player_x + 45
	field.enemies[0]["floor"] = 1
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(view.impact_kind == "miss", "enemy on another floor cannot be hit through the ceiling")
	await keypress(KEY_SPACE)
	var cooldown: float = field.attack_cooldown
	await keypress(KEY_J)
	simulate(scene, 1)
	check(field.attack_cooldown == cooldown, "paused combat cannot spend a swing or advance cooldown")
	# Discard the fixture. Capture only normal actual play below.
	await dispose_scene(scene)
	await process_frame
	scene = fresh()
	await process_frame
	scene.select_survivor(2)
	scene.start_expedition()
	await picture("res://docs/m09-expedition-preview.png")
	await keypress(KEY_I)
	await picture("res://docs/m09-bag-preview.png")
	await keypress(KEY_I)
	await held_key(KEY_D, true)
	simulate(scene, 2.8)
	await held_key(KEY_D, false)
	for tick in range(30):
		if absf(scene.expedition.enemies[0]["x"] - scene.expedition.player_x) < 65: break
		simulate(scene, 0.1)
	scene.expedition.facing = signf(scene.expedition.enemies[0]["x"] - scene.expedition.player_x)
	await keypress(KEY_J)
	simulate(scene, 0.21)
	check(scene.expedition_view.impact_kind == "push", "fresh actual walking reaches a patrol and a real push without position or damage fixtures")
	await picture("res://docs/m09-combat-preview.png")
	check(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "actual v0.9 playable scene remains compatible with schema six saves")
	await dispose_scene(scene)
	await create_timer(0.12).timeout
	print("PRESENTATION VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
