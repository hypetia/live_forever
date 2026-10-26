extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	game.end_day()
	game.start_expedition()
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	field.player_x = 242.01
	expect(field.site_in_range(0) and field.nearby_site() == 0,"visual readiness uses the actual 58-unit search radius")
	field.player_x = 242
	expect(not field.site_in_range(0) and field.nearby_site() == -1,"exact outer boundary is not advertised as ready")
	field.player_x = 300
	field.floor_level = 1
	expect(not field.site_in_range(0),"nearby x on another floor is not interactive")
	field.floor_level = 0
	field.climb_target = 1
	expect(not field.site_in_range(0),"climbing cannot falsely show container readiness")
	field.climb_target = -1
	field._search(0.5,actor)
	var progress := field.search_progress
	expect(progress > 0 and field.loot_site == -1,"search has an actual incomplete progress phase")
	game.expedition_view.refresh()
	expect(game.expedition_view.search_bar.visible and game.expedition_view.search_bar.size.y >= 7 and game.expedition_view.search_bar.position.y < 750,"visible progress is anchored at the object rather than the bottom edge")
	var partial := SaveSystem.capture(game)
	var store := SaveSystem.new()
	store.path = "user://interaction-progress.json"
	expect(store.write_state(game)["ok"],"a partially searched container can be saved to disk")
	expect(SaveSystem.apply_state(game,store.read_state()["data"]).is_empty() and is_equal_approx(field.search_progress,progress),"partial progress survives JSON and reloading")
	field._search(15,actor)
	game._process(0)
	expect(game._loot_open,"completed search opens inventory")
	field.take_loot("raw_food",100,actor)
	var appearance := InteractionFeedback.site(game,0)
	expect(appearance["supplied"],"taking only the food leaves a genuinely nonempty water container")
	field.take_loot("water",100,actor)
	appearance = InteractionFeedback.site(game,0)
	expect(not appearance["supplied"] and appearance["body"] == InteractionFeedback.EMPTY_BODY,"taking the last item immediately desaturates the actual crate")
	expect(appearance["body"].r == appearance["body"].g and appearance["body"].g == appearance["body"].b,"empty colour is neutral grey, not green tinted")
	field.put_loot("water",1)
	expect(InteractionFeedback.site(game,0)["supplied"],"putting an item back immediately restores the supplied appearance")
	field.take_loot("water",1,actor)
	expect(store.write_state(game)["ok"],"empty container state reaches a real disk save")
	expect(SaveSystem.apply_state(game,store.read_state()["data"]).is_empty() and not InteractionFeedback.site(game,0)["supplied"],"reloading cannot recolour a fully emptied crate")
	game.expedition_retreat() # In the open loot pane: arrange actual movement, no teleport.
	expect(game.cycle.return_requested and not game._loot_open and field.active,"return from loot closes the modal and queues a physical route")
	var stock: Dictionary = game.inventory.snapshot()
	var x := field.player_x
	game.paused = true
	advance(game,1)
	expect(field.player_x == x and game.inventory.snapshot() == stock,"paused return queues movement without progressing time or crediting cargo")
	expect(store.write_state(game)["ok"],"queued return is persisted")
	expect(SaveSystem.apply_state(game,store.read_state()["data"]).is_empty() and game.cycle.return_requested,"return intent survives reload")
	game.paused = false
	advance(game,3)
	expect(game.cycle.phase == "dawn" and not field.active and not game.cycle.return_requested,"queued return walks to entrance and extracts once")
	valid(game,"finished return")
	game.free()

	game = campaign()
	game.end_day()
	game.choose_destination("works")
	game.start_expedition()
	field = game.expedition
	actor = game.survivors[field.actor_id]
	# Isolate a search-point geometry fixture; a separate GUI trip traverses the ladder normally.
	field.floor_level = 1
	field.player_y = 400
	field.player_x = 1520
	var index := 1
	for key in field.sites[index]["contents"]: field.sites[index]["contents"][key] = 0
	var pending := InteractionFeedback.site(game,index)
	expect(not pending["supplied"] and pending["pending"] and pending["body"] == InteractionFeedback.EMPTY_BODY,"quest marker is separate; zero ordinary supplies never keep a coloured crate")
	game.expansion.carried.append("relay")
	game.expansion.refresh_slots(field,actor)
	expect(not InteractionFeedback.site(game,index)["pending"],"already carried quest part has no stale collectible marker")
	game.expansion.carried.clear()
	game.expansion.refresh_slots(field,actor)
	game.expedition_retreat()
	advance(game,1)
	expect(field.player_x < 1520 and field.active,"upstairs return begins by walking toward the ladder")
	game.expedition_retreat()
	expect(not game.cycle.return_requested,"pressing return again cancels an optional route")
	var before := field.player_x
	advance(game,0.5)
	expect(field.player_x == before,"cancelled optional return no longer moves the character")
	game.expedition_retreat()
	advance(game,12)
	expect(game.cycle.phase == "dawn" and not field.active,"return handles the real ladder then entrance")
	valid(game,"upstairs return")
	game.free()

	game = campaign()
	for id in LocationCatalog.ALL_IDS:
		game.expedition = game.regions[id]
		field = game.expedition
		for container in range(field.sites.size()):
			for resource in field.sites[container]["contents"]: field.sites[container]["contents"][resource] = 0
			var empty := InteractionFeedback.site(game,container)
			expect(not empty["supplied"] and empty["body"] == InteractionFeedback.EMPTY_BODY,"every depleted container is grey on map " + id)
	game.free()

	game = campaign()
	actor = game.survivors[0]
	actor.position = game.water_store.position
	expect(game.water_store.interaction_ready(actor),"water's readiness uses its real action position")
	actor.position.x -= 30
	expect(not game.water_store.interaction_ready(actor),"generic workstation offset cannot falsely mark the water action ready")
	actor.position = game.stove.work_position()
	expect(game.stove.interaction_ready(actor),"stove readiness uses the actual scheduler work position")
	actor.position.y = 640
	expect(not game.stove.interaction_ready(actor),"daytime interaction readiness also distinguishes floors")
	game.free()

	game = campaign()
	store.path = "res://tests/fixtures/v9_equipped_night.json"
	var legacy := store.read_state()
	expect(legacy["ok"] and legacy["migrated"],"genuine schema9 night migrates through schema10")
	expect(SaveSystem.apply_state(game,legacy["data"]).is_empty() and not game.cycle.return_requested and game.expedition.magazine == 5,"old save preserves gear and does not invent a return command")
	valid(game,"old saved night")
	game.free()
	game = campaign()
	game.end_day()
	game.start_expedition()
	field = game.expedition
	actor = game.survivors[field.actor_id]
	field.player_x = 300
	game.simulation_time = game.cycle.night_end-1.0/60
	var fatigue_before := actor.fatigue
	game.expedition_retreat()
	advance(game,0.05)
	expect(game.cycle.phase == "returning" and not game.cycle.return_requested,"dawn replaces a queued optional return with mandatory extraction")
	expect(actor.fatigue >= fatigue_before+15,"starting return just before dawn cannot evade the late-return cost")
	game.expedition_retreat()
	expect(game.cycle.phase == "returning","mandatory extraction cannot be cancelled using the return command")
	valid(game,"deadline crossed during optional return")
	game.free()
	print("INTERACTIONS RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
