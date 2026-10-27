extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false;root.add_child(game); ArchiveFixture.campaign(game);game.set_process(false)
	await process_frame;await process_frame
	await keypress(KEY_P)
	check(game.center.routine_toggle.button_pressed and not game.center.cooking_toggle.button_pressed,"new game exposes enabled basic self-care and separate optional cooking")
	await dialog_click(game.center,game.center.routine_toggle)
	check(not game.self_care.enabled(game.survivors[0]),"real checkbox disables care for the selected resident")
	await dialog_click(game.center,game.center.routine_toggle)
	check(game.self_care.enabled(game.survivors[0]),"real checkbox restores independent basic care")
	await dialog_click(game.center,game.center.cooking_toggle)
	check(game.survivors[0].person.routine,"optional cooking checkbox controls actual recipe permission")
	await dialog_click(game.center,game.center.cooking_toggle)
	check(not game.survivors[0].person.routine,"fuel-consuming optional cooking can be switched back off")
	for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = size
		for frame in range(5): await process_frame
		var panel := Rect2(Vector2.ZERO,Vector2(game.center.size))
		check(panel.encloses(game.center.routine_toggle.get_global_rect()) and panel.encloses(game.center.cooking_toggle.get_global_rect()),"both care policies fit the people page at %dx%d" % [size.x,size.y])
	root.size = Vector2i(1440,900)
	await picture("res://docs/v20-self-care-settings.png")
	game.center.close()
	for actor: Survivor in game.survivors: game.self_care.set_enabled(game,actor,actor.survivor_id==0)
	game.survivors[0].person.thirst = 85
	await click_at(game.cards[2].get_global_rect().get_center())
	sim(game,.1)
	check(game.selected_id == 2 and game.survivors[0].self_care_kind == "drink" and game.survivors[0].route.size() > 1,"uncontrolled thirsty person uses the actual downstairs water route")
	check(game.inventory.amount("water") == 4 and game.survivors[0].person.thirst > 84,"visible autonomous travel does not hydrate before arrival")
	sim(game,2)
	check(game.cards[0].tooltip_text.contains("基本自理开启") and game.survivors[0].status_text().contains("自行饮水"),"card feedback identifies autonomous intent without extra world text")
	await picture("res://docs/v20-autonomous-water.png")
	await keypress(KEY_SPACE)
	var snapshot := SaveSystem.capture(game)
	sim(game,4)
	check(snapshot == SaveSystem.capture(game),"actual pause input freezes autonomous travel and pending resource payment")
	await keypress(KEY_SPACE)
	sim(game,20)
	check(game.inventory.amount("water") == 3 and game.people.drinks == 1 and game.survivors[0].person.thirst < 30,"arrival visibly completes one ordinary drink")
	# People-page drink is also a scene command, rather than a remote stat edit.
	await click_at(game.cards[1].get_global_rect().get_center())
	game.survivors[1].person.thirst = 80
	await keypress(KEY_P)
	var water: int = game.inventory.amount("water")
	await dialog_click(game.center,game.center.drink_button)
	check(not game.center.visible and game.cycle.actions.any(func(a):return a["actor"] == 1 and a["kind"] == "drink") and game.inventory.amount("water") == water,"people-page drink button starts physical water use and returns to the scene")
	sim(game,20)
	check(game.inventory.amount("water") == water-1 and game.people.drinks == 2,"manual people-page drink obeys the same arrival cost")
	await click_at(game.cards[0].get_global_rect().get_center())
	game.survivors[0].hunger = 85
	game.inventory.deposit({"meals":1},"declared graphical last-meal fixture")
	sim(game,1.1)
	check(game.survivors[0].self_care_kind == "eat","hungry person starts actual self-chosen eating")
	await held_key(KEY_D,true);sim(game,.4);await held_key(KEY_D,false)
	check(game.survivors[0].self_care_kind.is_empty() and game.survivors[0].orders.is_empty() and game.inventory.amount("meals") == 1,"real D input immediately takes over and preserves an unfinished meal")
	var x: float = game.survivors[0].position.x
	sim(game,5)
	check(game.survivors[0].self_care_kind.is_empty() and is_equal_approx(game.survivors[0].position.x,x),"released movement key stays stopped during the manual grace period")
	check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),"final graphical autonomy state remains ordinarily saveable")
	game.free();await create_timer(.15).timeout
	print("SELF CARE VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
