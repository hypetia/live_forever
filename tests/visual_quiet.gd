extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game); ArchiveFixture.campaign(game)
	game.set_process(false)
	await process_frame
	game._process(0)
	await picture("res://docs/v12-day.png")
	check(game.cards[0] is SurvivorCard and game.cards[0].text.is_empty(), "portrait cards replace permanent numeric paragraphs")
	check(not game.stock_label.visible and not game.tutorial_label.visible and not game.phase_label.visible, "long inventory and guide text is not permanently over the scene")
	check(game.cards[0].tooltip_text.contains("饱腹  55 / 100") and game.cards[0].tooltip_text.contains("精神  70 / 100"), "hover details use a single positive 100-point convention")
	await click_at(game.cards[2].get_global_rect().get_center())
	check(game.selected_id == 2, "compact portrait still selects the real character")
	var actor: Survivor = game.survivors[2]
	await click_at(game.world_root.to_global(Vector2(620,640)))
	sim(game,1)
	check(actor.position.x > 260, "new scenery and input share the same world transform")
	await keypress(KEY_K)
	check(game.interface.workshop_open, "crafting remains available on demand")
	await keypress(KEY_ESCAPE)
	check(not game.interface.workshop_open and not game.center.visible, "Esc closes the focused workshop")
	game.end_day()
	check(game.interface.role_stats[2].text.contains("精神") and game.interface.role_stats[2].text.contains("饱腹"), "night planning uses the same positive convention")
	await picture("res://docs/v12-planning.png")
	await keypress(KEY_ENTER)
	check(game.expedition.active, "new HUD still starts the real expedition")
	var enemy: Dictionary = game.expedition.enemies[0]
	await click_at(game.world_offset()+Vector2(enemy["x"],580)*game.world_scale())
	sim(game,5)
	await picture("res://docs/v12-night.png")
	check(not game.expedition_view.stats_label.visible and not game.expedition_view.area_hint.visible, "night scene is free of permanent help and stat paragraphs")
	check(enemy["hp"] < 40, "compact action UI preserves physical attacks and enemy health")
	check(game.cards[2].visible and game.cards.filter(func(card): return card.visible).size() == 1, "night retains one positive-status portrait")
	# Isolate inventory layout; traversal and two-way transfers also run in visual_campaign.
	game.expedition.player_x = 300
	game.expedition._search(8,game.survivors[game.expedition.actor_id])
	game._process(0)
	await process_frame
	await picture("res://docs/v12-loot.png")
	check(game.interface.loot_buttons["raw_food"].size.x < 120 and not game.interface.loot_buttons["raw_food"].tooltip_text.is_empty(),"loot is an icon grid with names on hover")
	await keypress(KEY_ESCAPE)
	game.expedition.player_x = 110
	game.expedition_retreat()
	game.confirm_departure()
	await process_frame
	await picture("res://docs/v12-dawn.png")
	check(game.interface.overlay.find_children("*","SurvivorCard",true,false).size() == 3,"morning starts with survivor cards rather than a wall of report text")
	check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(), "visual changes keep actual save state valid")
	await dispose_scene(game)
	print("QUIET VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
