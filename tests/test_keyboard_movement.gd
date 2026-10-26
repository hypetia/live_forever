extends "res://tests/test_campaign.gd"

func keys(game: Node2D, axis: float, climb: int = 0, sprint: bool = false) -> void:
	game.expedition_controls_override = {"axis":axis,"climb":climb,"sprint":sprint}

func _run() -> void:
	var game := campaign()
	var actor: Survivor = game.survivors[0]
	var start := actor.position
	keys(game,1)
	advance(game,0.5)
	expect(actor.position.x > start.x+60 and actor.position.y == start.y,"daytime right input physically moves the selected survivor")
	expect(actor.manual_walking and actor.orders.is_empty() and actor.status_text() == "移动中","keyboard movement uses walking animation without inventing a production task")
	keys(game,-1)
	advance(game,0.5)
	expect(absf(actor.position.x-start.x)<1,"daytime left input physically moves back")
	keys(game,0)
	advance(game,0.2)
	expect(not actor.manual_walking and actor.route.is_empty(),"release stops floor motion immediately without a leftover destination")
	start = actor.position
	keys(game,1,0,true)
	advance(game,0.5)
	expect(actor.position.x > start.x+120,"Shift movement is faster on shelter floors")
	var before := actor.position
	game.paused = true
	advance(game,1)
	expect(actor.position == before,"pause prevents keyboard movement")
	game.paused = false
	game.center.open(5)
	advance(game,0.5)
	expect(actor.position == before,"open handbook prevents background keyboard movement")
	game.center.close()
	keys(game,0)
	advance(game,0.1)
	valid(game,"keyboard movement state")
	game.free()

	game = campaign()
	actor = game.survivors[0]
	game.assign_task("craft")
	var materials: int = game.inventory.amount("materials")
	keys(game,1)
	advance(game,0.5)
	expect(actor.orders.is_empty() and game.facility.waiting_ids.is_empty(),"held movement cancels walking task and releases its station registration")
	keys(game,0)
	advance(game,0.1)
	game.assign_task("craft")
	advance(game,10)
	# Start a fresh batch at the actual workbench to isolate refund on interruption.
	game.inventory.deposit({"materials":4},"interruption fixture")
	game.assign_task("craft")
	advance(game,0.5)
	materials = game.inventory.amount("materials")
	expect(not actor.held_cost.is_empty(),"fixture has a genuinely started paid batch")
	keys(game,-1)
	advance(game,0.5)
	expect(actor.orders.is_empty() and actor.held_cost.is_empty() and game.inventory.amount("materials") == materials+2,"keyboard interruption refunds unfinished work exactly once")
	advance(game,0.5)
	expect(game.inventory.amount("materials") == materials+2,"continued held input cannot repeatedly refund the same task")
	valid(game,"interrupted production")
	game.free()

	game = campaign()
	game.inventory.deposit({"materials":5,"tools":2},"workshop cancellation fixture")
	game.expansion.start_job(game,"bat")
	materials = game.inventory.amount("materials")
	keys(game,1)
	advance(game,0.5)
	expect(game.expansion.jobs.is_empty() and game.inventory.amount("materials") == materials+3,"keyboard cancels a custom workshop job and refunds once")
	valid(game,"interrupted custom work")
	var store := SaveSystem.new()
	store.path = "user://keyboard-floor-save.json"
	expect(store.write_state(game)["ok"],"actual disk save while moving on a floor is valid")
	var saved: Dictionary = store.read_state()["data"]
	expect(saved["actors"][0]["route"].is_empty(),"held-key floor destination is not persisted as phantom movement")
	keys(game,0)
	expect(SaveSystem.apply_state(game,saved).is_empty(),"keyboard floor movement snapshot restores")
	actor = game.survivors[0]
	before = actor.position
	advance(game,0.3)
	expect(actor.position == before and not actor.manual_walking,"reload with released keys does not continue drifting")
	game.free()

	game = campaign()
	actor = game.survivors[0]
	game.move_selected(ShelterNavigation.BOTTOM_STAIR)
	advance(game,10)
	keys(game,0,1)
	advance(game,1)
	expect(actor.position.y < 640 and actor.position.y > 430,"W at the bottom landing uses the real stair segment")
	valid(game,"mid-stair keyboard motion")
	keys(game,0)
	advance(game,3)
	expect(actor.position.y == 430,"released stair command completes its real landing rather than leaving a floating actor")
	keys(game,0,-1)
	advance(game,3)
	expect(actor.position.y == 640,"S at the upper landing returns down the stairs")
	keys(game,-1)
	advance(game,10)
	expect(actor.position.x >= 140 and actor.position.y == 640,"held A cannot walk outside the shelter floor")
	valid(game,"floor boundary")
	game.free()

	game = campaign()
	game.end_day()
	game.start_expedition()
	var field: ExpeditionState = game.expedition
	var enemy: Dictionary = field.enemies[0]
	# Explicit combat-input fixture isolates the old priority bug.
	field.player_x = float(enemy["x"])-40
	field.attack_cooldown = 0.8
	game.interface.set_target(float(enemy["x"]),int(enemy["floor"]),false,-1)
	game.interface.target_enemy = 0
	keys(game,-1)
	var controls: Dictionary = game._expedition_controls()
	expect(controls.get("axis",0) == -1 and game.interface.target_enemy == -1,"manual night movement overrides an in-range mouse attack even during cooldown")
	game.interface.set_target(300,0,false,0)
	game.expedition_view.search_held = true
	controls = game._expedition_controls()
	expect(not game.interface.has_move_target and not game.expedition_view.search_held,"manual movement clears stale mouse search and approach intent")
	game.free()
	print("KEYBOARD MOVEMENT RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
