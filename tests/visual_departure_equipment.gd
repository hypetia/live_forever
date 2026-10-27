extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game); ArchiveFixture.campaign(game)
	game.set_process(false)
	await process_frame
	game.expansion.grant("vest","chen")
	game.expansion.grant("coat","chen")
	game.expansion.sync(game)
	game.end_day()
	await keypress(KEY_ENTER)
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	game._process(0)
	var view: ExpeditionView = game.expedition_view
	check(view.equipment_buttons.size() == 3 and view.equipment_buttons[0].is_visible_in_tree(),"night exposes three compact real equipment slots")
	check(view.equipment_name.text == "猎刀","equipped weapon name is visible without a hover")
	check(view.equipment_buttons[1].tooltip_text.contains("防咬背心"),"armor inspection matches the actual loadout")
	await click_at(view.equipment_buttons[0].get_global_rect().get_center())
	check(view.equipment_dialog.visible and game.paused,"clicking equipment opens details and pauses danger")
	check(view.equipment_dialog.dialog_text.contains("60/60") and view.equipment_dialog.dialog_text.contains("厚冬衣"),"details include exact durability and all equipped slots")
	await keypress(KEY_ENTER)
	check(not view.equipment_dialog.visible and not game.paused,"closing equipment restores running time")
	game.paused = true
	await click_at(view.equipment_buttons[1].get_global_rect().get_center())
	await keypress(KEY_ESCAPE)
	check(game.paused and not view.equipment_dialog.visible and not game.center.visible,"equipment Escape preserves pause without opening another menu")
	game.paused = false
	# Mouse movement reaches the actual edge rather than stopping nine units short.
	await click_at(game.world_offset()+Vector2(65,610)*game.world_scale())
	sim(game,0.3)
	check(game.departure_dialog.visible and game.paused,"mouse walking to the left boundary opens confirmation")
	await keypress(KEY_ESCAPE)
	check(field.active and not game.paused,"Escape cancels departure without ending the night")
	# Isolate the camera/geometry fixture on the opposite world edge.
	field.player_x = field.right_edge(0)-20
	var camera := view._camera()
	await click_at(game.world_offset()+Vector2(field.right_edge(0)-camera+20,610)*game.world_scale())
	sim(game,0.3)
	check(game.departure_dialog.visible and game._departure_side == 1,"mouse also reaches the far right exit")
	await picture("res://docs/v133-right-exit.png")
	await keypress(KEY_ESCAPE)
	# Each existing weapon silhouette is captured from a real equipment fixture.
	for kind in ["knife","bat","spear","pistol"]:
		actor.weapon_item = {"kind":kind,"durability":GearCatalog.ITEMS[kind]["durability"]}
		field.player_x = 300
		field.facing = 1
		game._process(0)
		view.queue_redraw()
		await picture("res://docs/v133-"+kind+".png")
		check(view.equipment_name.text == GearCatalog.ITEMS[kind]["name"],"visible equipped weapon switches to "+kind)
	actor.weapon_item["durability"] = 0
	game._process(0)
	check(view.equipment_name.text.contains("损坏"),"broken equipment is unmistakable at a glance")
	field.player_x = field.right_edge(0)
	await keypress(KEY_T)
	await keypress(KEY_ENTER)
	check(not field.active and game.cycle.phase == "dawn","keyboard confirmation completes right-side departure")
	await dispose_scene(game)
	print("DEPARTURE EQUIPMENT VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
