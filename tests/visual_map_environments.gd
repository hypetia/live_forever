extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var atlas := Image.create(1440,900,false,Image.FORMAT_RGB8)
	var ordinal := 0
	for id: String in LocationCatalog.ALL_IDS:
		var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
		game.persistence_enabled = false
		root.add_child(game); ArchiveFixture.campaign(game);game.set_process(false)
		await process_frame
		# Declared unlocked-map presentation fixture, not a natural campaign journey.
		game.expansion.stage = 4;game.simulation_time = 27*720
		game.inventory.deposit({"tools":1},"declared map GUI fixture")
		game.end_day();game.choose_destination(id);game.cycle.loadout = {"tools":1}
		check(game.start_expedition(),id+" starts its actual map through the normal departure API")
		var field: ExpeditionState = game.expedition
		for enemy in field.enemies: enemy["hp"] = 0;enemy["mode"] = "dead"
		field.player_x = field.route_x()-70
		game._process(0)
		await process_frame
		var click: Vector2 = game.world_offset()+Vector2(field.route_x()-game.expedition_view._camera(),512)*game.world_scale()
		await click_at(click)
		check(game.interface.target_site == -2 and game.interface.has_move_target,id+" clicking the blocked ladder selects real approach and clearing")
		sim(game,1)
		check(field.route_progress > 0 and not field.route_open and not game.expedition_view.search_button.disabled,id+" mouse approaches into range and shows live clearing")
		check(game.expedition_view.search_bar.visible and game.expedition_view.search_bar.value > 0,id+" clearing has a visible in-world progress bar")
		sim(game,6)
		check(field.route_open and field.bag["tools"] == 0,id+" mouse action completes once and consumes the carried tool")
		game.expedition_view.search_held = false
		# Physical W input drives the same ladder used by mouse routing.
		var event := InputEventKey.new();event.keycode = KEY_W;event.physical_keycode = KEY_W;event.pressed = true
		Input.parse_input_event(event);await process_frame
		sim(game,2.2)
		event.pressed = false;Input.parse_input_event(event);await process_frame
		check(field.floor_level == 1 and field.player_x == field.route_x(),id+" W traverses the cleared ladder and lands at the real upper-floor coordinate")
		# Move within the upper walkway to expose room groups in the screenshot.
		field.player_x = maxf(field.upper_left()+220,field.route_x()-260)
		game._process(0);game.expedition_view.queue_redraw()
		await picture("res://docs/v18-map-"+id+".png")
		var shot := root.get_texture().get_image();shot.convert(Image.FORMAT_RGB8);shot.resize(480,300,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(shot,Rect2i(0,0,480,300),Vector2i(ordinal%3*480,ordinal/3*300))
		ordinal += 1
		# A click on the ground chooses the nearby second ladder on the return trip.
		await click_at(game.world_offset()+Vector2(field.route_x()-game.expedition_view._camera(),650)*game.world_scale())
		sim(game,5)
		check(field.floor_level == 0 and absf(field.player_x-field.route_x()) < 12,id+" mouse routing descends by the opened secondary path")
		if id == "waterworks":
			for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
				root.size = size;await process_frame;await process_frame
				game._process(0)
				check(game.expedition_view.visible and game.expedition_view.layer.visible and game.expedition_view.retreat_button.get_global_rect().end.x <= 1440,"map actions fit at "+str(size))
			root.mode = Window.MODE_FULLSCREEN;await process_frame
			check(game.expedition_view.visible and field.route_open,"physical route and scene survive fullscreen")
			root.mode = Window.MODE_WINDOWED;root.size = Vector2i(1440,900);await process_frame
		await dispose_scene(game)
	atlas.save_png("res://docs/v18-map-atlas.png")
	print("MAP ENVIRONMENTS VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
