extends "res://tests/visual_campaign.gd"

func shift_click(point: Vector2) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT; event.keycode = KEY_SHIFT; event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await click_at(point)
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game); ArchiveFixture.campaign(game)
	game.set_process(false)
	await process_frame
	game.end_day(); game.start_expedition()
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	# Declared stack presentation fixture; actual pickup/return APIs are still used.
	field.bag = {"raw_food":5,"water":5,"fuel":5,"meals":0,"materials":17,"tools":2,"medicine":3}
	field.player_x = 300
	field._search(10,actor)
	game._process(0)
	game.paused = true
	var ui: CampaignInterface = game.interface
	check(game._loot_open and field.used_capacity() == 14,"physical stack fixture fills all fourteen slots including its real weapon")
	check(ui.cargo_grid.cells.size() == 14 and ui.cargo_grid.items.size() == 14,"backpack draws exactly one cell per occupied physical stack")
	var food: Array = ui.cargo_grid.items.filter(func(item): return item["key"] == "raw_food")
	check(food.size() == 2 and food[0]["count"] == 4 and food[1]["count"] == 1,"five food are visibly split into a full stack and an overflow stack")
	check(ui.cargo_grid.items.filter(func(item): return item["key"] == "materials").size() == 3,"seventeen materials are shown in three bounded cells")
	check(ui.cargo_grid.items.any(func(item): return item["kind"] == "gear"),"equipped weapon is visible as an occupied reserved cell")
	check(not ui.loot_buttons["water"].disabled,"a full backpack still enables pickup into existing partial stacks")
	await picture("res://docs/v17-stack-transfer.png")
	await shift_click(ui.loot_buttons["raw_food"].get_global_rect().get_center())
	check(field.bag["raw_food"] == 7 and field.sites[0]["contents"]["raw_food"] == 0,"Shift click transfers the source stack through real pickup logic")
	check(field.used_capacity() == 14,"filling an existing stack does not consume a fictitious extra cell")
	await shift_click(ui.loot_returns["raw_food"].get_global_rect().get_center())
	check(field.bag["raw_food"] == 5 and field.sites[0]["contents"]["raw_food"] == 2,"whole-stack put-back still respects the real container's remaining room")
	await click_at(ui.loot_buttons["water"].get_global_rect().get_center())
	check(field.bag["water"] == 6 and field.used_capacity() == 14,"single click moves one physical unit into the partial stack")
	# Reopen and click before a layout frame: the selected cell must already be correct.
	game.close_loot(); field._search(0.01,actor); game._process(0)
	var water_rect: Rect2 = ui.loot_returns["water"].get_global_rect()
	check(not water_rect.intersects(ui.loot_returns["raw_food"].get_global_rect()),"reopened cells have distinct hit regions immediately, without waiting for a layout frame")
	await click_at(water_rect.get_center())
	check(field.bag["water"] == 5 and field.bag["raw_food"] == 5 and field.sites[0]["contents"]["water"] == 1,"immediate put-back selects water, not the neighboring food stack")
	await click_at(ui.loot_buttons["water"].get_global_rect().get_center())
	check(field.bag["water"] == 6 and field.bag["raw_food"] == 5,"taking the just-returned water preserves all other item quantities")
	field.bag["water"] = 0; field.bag["fuel"] = 0; field.bag["tools"] = 6
	field.sites[0]["contents"]["water"] = 1
	ui.refresh()
	check(field.used_capacity() == 14 and ui.loot_buttons["water"].disabled,"a new item type is disabled when no cell is free")
	for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = size
		await process_frame
		await process_frame
		var design := Rect2(Vector2.ZERO,Vector2(1440,900))
		check(design.encloses(ui.cargo_grid.get_global_rect()) and design.encloses(ui.container_grid.get_global_rect()),"both complete grids fit at "+str(size))
	root.mode = Window.MODE_FULLSCREEN
	await process_frame
	check(game._loot_open and ui.cargo_grid.visible,"stack transfer survives fullscreen")
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440,900)
	await process_frame
	await keypress(KEY_ESCAPE)
	check(not game._loot_open,"Escape closes the transfer pane")
	await keypress(KEY_I)
	game._process(0)
	check(game.expedition_view.stack_panel.visible,"I opens the same physical stack inventory in the field")
	check(game.expedition_view.stack_grid.items.size() == field.used_capacity(),"inspection includes the same item and equipment occupancy as transfer")
	await picture("res://docs/v17-stack-backpack.png")
	await keypress(KEY_I)
	game._process(0)
	check(not game.expedition_view.stack_panel.visible,"I closes the inventory without leaving a dashboard over play")
	await dispose_scene(game)
	print("BACKPACK STACKS VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
