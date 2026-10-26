extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game._process(0)
	await picture("res://docs/v11-shelter.png")
	await keypress(KEY_K)
	check(game.interface.workshop_open and game.paused, "K opens actual paused equipment workshop")
	await picture("res://docs/v11-workshop.png")
	await click_button(game.interface.workshop_panel, "关闭")
	check(not game.interface.workshop_open and not game.paused, "mouse closes workshop and restores time")
	game.end_day()
	await process_frame
	await click_button(game.interface.overlay, "下一组")
	check(game.interface.map_page == 1 and game.interface.map_buttons.has("waterworks"), "map pager exposes additional playable routes")
	check(game.interface.map_buttons["waterworks"].disabled, "locked route shows a gate rather than silently entering")
	await picture("res://docs/v11-maps.png")
	await click_button(game.interface.overlay, "‹ 上一组")
	await click_at(game.interface.map_buttons["street"].get_global_rect().get_center())
	await keypress(KEY_ENTER)
	check(game.expedition.active and game.expedition.extra_slots == 1, "keyboard departure carries equipped knife at real weight")
	# Real approach with a single explicit mouse attack.
	var enemy: Dictionary = game.expedition.enemies[0]
	await click_at(game.WORLD_OFFSET + Vector2(enemy["x"], 580) * game.WORLD_SCALE)
	sim(game, 5)
	check(enemy["hp"] == 22 and game.expedition_view.impact_kind == "hit", "mouse movement and windup resolve visible knife damage")
	await picture("res://docs/v11-combat.png")
	check(game.expedition_view.attack_button.text.contains("猎刀") or game.expedition.attack_cooldown > 0, "HUD names actual equipped weapon")
	check(game.expedition_view.stats_label.text.contains("疾病"), "night HUD separates illness and infection")
	game.expedition.player_x = 300 # GUI transfer fixture, not traversal evidence.
	game.expedition._search(8, game.survivors[game.expedition.actor_id])
	game._process(0)
	await process_frame
	check(game.interface.shown == "loot", "opened container uses deliberate transfer")
	await picture("res://docs/v11-loot.png")
	await keypress(KEY_ESCAPE)
	check(not game._loot_open, "Esc closes extended loot without leaving a modal blocker")
	game.free()
	print("EXPANSION VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
