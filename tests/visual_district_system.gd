extends "res://tests/visual_campaign.gd"

func scenario_hold(game: Node2D,key: Key,seconds: float) -> void:
	var e := InputEventKey.new();e.physical_keycode = key;e.keycode = key;e.pressed = true
	Input.parse_input_event(e);await process_frame
	sim(game,seconds)
	e.pressed = false;Input.parse_input_event(e);await process_frame

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game); ArchiveFixture.campaign(game);game.set_process(false)
	await process_frame
	await keypress(KEY_Y)
	check(game.district_view.opened and game.paused,"Y opens the spatial district map and pauses actual day play")
	await keypress(KEY_ENTER)
	await keypress(KEY_D)
	check(game.cycle.phase == "day" and not game._day_keyboard_allowed(),"district inspection consumes action and movement keys")
	await click_at(game.district_view.map_buttons["clinic"].get_global_rect().get_center())
	check(game.district_view.selected == "clinic" and game.district_view.target_button.disabled,"map click selects a district and keeps an unbuilt outpost unavailable for duty")
	await keypress(KEY_ESCAPE)
	check(not game.district_view.opened and not game.paused,"Escape restores the previous day state")
	# Explicit display fixture; the separate journey proves the same work from starting stock.
	game.inventory.deposit({"materials":6,"tools":1,"fuel":2},"declared graphical construction fixture")
	game.end_day();game.cycle.loadout = {"materials":6,"tools":1,"fuel":1}
	game.interface.refresh()
	await click_at(game.interface.depart_button.get_global_rect().get_center())
	var field: ExpeditionState = game.expedition
	for enemy in field.enemies: enemy["hp"] = 0;enemy["mode"] = "dead"
	field.player_x = field.route_x();field.floor_level = 0;field.player_y = 620
	game._process(0);game.expedition_view.queue_redraw()
	await picture("res://docs/v19-closed-access.png")
	var head: Vector2 = game.world_offset()+Vector2(field.player_x-game.expedition_view._camera(),555)*game.world_scale()
	var frame := root.get_texture().get_image()
	var pixel := frame.get_pixel(roundi(head.x),roundi(head.y))
	check(pixel.r > .6 and pixel.g > .5 and pixel.b > .35,"an uncleared access icon cannot reset the world transform or displace the rendered player")
	var point: Dictionary = field.site_definitions()[DistrictSystem.POINTS["street"]]
	field.player_x = point["x"];field.floor_level = point["floor"];field.player_y = ExpeditionState.FLOOR_Y[point["floor"]]
	game._process(0)
	await click_at(game.world_offset()+Vector2(float(point["x"])-game.expedition_view._camera()+30,315)*game.world_scale())
	sim(game,4)
	check(game._loot_open and game.interface.outpost_buttons["build"].visible and not game.interface.outpost_buttons["build"].disabled,"clicking the visible flag walks to and searches the actual outpost work site")
	var materials: int = field.bag["materials"]
	await click_at(game.interface.outpost_buttons["build"].get_global_rect().get_center())
	sim(game,.5)
	check(not game._loot_open and not game.districts.work.is_empty() and field.bag["materials"] == materials,"click begins physical timed construction without instant completion or prepayment")
	check(game.expedition_view.search_bar.visible and game.expedition_view.search_bar.value > 0,"work progress is drawn beside the real field position")
	await picture("res://docs/v19-outpost-construction.png")
	var before := field.player_x
	await scenario_hold(game,KEY_D,.2)
	check(game.districts.work.is_empty() and field.player_x > before and field.bag["materials"] == materials,"real movement interrupts engineering without free resources or remote construction")
	await scenario_hold(game,KEY_E,.2)
	check(game._loot_open,"the actual searched container reopens at the retained work point")
	await click_at(game.interface.outpost_buttons["build"].get_global_rect().get_center())
	sim(game,10)
	check(game.districts.regions["street"]["built"] and field.bag["materials"] == materials-5 and field.bag["tools"] == 0,"GUI construction completes, pays real bag items and changes the physical outpost state")
	await keypress(KEY_G)
	check(field.decoys.size() == 1 and field.bag["materials"] == 0 and field.bag["fuel"] == 0,"real G input deploys a paid field distraction")
	var enemy: Dictionary = field.enemies[2]
	enemy["hp"] = 40;enemy["mode"] = "patrol";enemy["x"] = field.player_x+215;enemy["direction"] = 1.0
	sim(game,.5)
	check(enemy["target"] == field.decoys[0]["x"] and enemy["target"] != field.player_x,"visible enemy investigation uses the separate sound source")
	await picture("res://docs/v19-decoy-investigation.png")
	await keypress(KEY_Y)
	check(game.district_view.opened and game.paused,"district map can inspect ongoing field consequences safely")
	check(game.district_view.target_button.disabled,"night inspection cannot reassign already departed logistics")
	check(game.district_view.detail.get_line_count()*game.district_view.detail.get_line_height() <= game.district_view.detail.size.y,"district detail includes costs, risk and consequences without clipped text")
	await picture("res://docs/v19-district-map.png")
	var remaining: float = field.decoys[0]["remaining"]
	sim(game,1)
	check(field.decoys[0]["remaining"] == remaining,"paused inspection does not expire a device or run hidden work")
	for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = size;await process_frame;await process_frame
		var design := Rect2(Vector2.ZERO,Vector2(1440,900))
		check(design.encloses(game.district_view.window.get_global_rect()) and game.district_view.map_buttons.values().all(func(b): return game.district_view.window.get_global_rect().encloses(b.get_global_rect())),"entire district chart and controls fit at "+str(size))
	root.mode = Window.MODE_FULLSCREEN;await process_frame
	check(game.district_view.opened,"district map survives fullscreen")
	root.mode = Window.MODE_WINDOWED;root.size = Vector2i(1440,900);await process_frame
	await keypress(KEY_ESCAPE)
	game.expedition_retreat();sim(game,30)
	check(game.departure_dialog.visible,"ordinary T route still reaches the actual exit after using a field distraction")
	await process_frame
	await process_frame
	await dialog_click(game.departure_dialog,game.departure_dialog.get_ok_button())
	check(game.cycle.phase == "dawn" and game.districts.regions["street"]["built"],"outpost persists through a real exit and dawn settlement")
	await click_button(game.interface.overlay,"开始白天")
	game.end_day()
	var option: OptionButton = game.interface.role_options[0]
	await click_at(option.get_global_rect().get_center())
	for n in range(6):
		if option.get_popup().get_focused_item() == 5: break
		await keypress(KEY_DOWN)
	await keypress(KEY_ENTER)
	check(game.cycle.roles[0] == "outpost","actual night-role dropdown selects the newly available outpost worker")
	check(game.interface.plan_capacity.text.contains("轮值预留燃料1"),"night preparation exposes the reserved logistics cost")
	await keypress(KEY_Y)
	check(game.district_view.target_button.disabled == false and game.district_view.detail.text.contains("墨衡「钉钟人」"),"planning chart previews the assigned person's real shift")
	check(game.district_view.detail.get_line_count()*game.district_view.detail.get_line_height() <= game.district_view.detail.size.y,"assigned-person preview remains readable without clipping")
	await picture("res://docs/v19-outpost-roster.png")
	await keypress(KEY_ESCAPE)
	await dispose_scene(game)
	print("DISTRICT SYSTEM VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
