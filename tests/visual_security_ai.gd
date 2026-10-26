extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await keypress(KEY_Z)
	check(game.security_view.opened and game.paused,"V opens a paused security inspection from actual day play")
	await keypress(KEY_D)
	check(game.security_view.opened and not game._day_keyboard_allowed(),"inspection consumes movement keys")
	await keypress(KEY_ESCAPE)
	check(not game.security_view.opened and not game.paused,"Escape restores day play")
	game.end_day()
	game.cycle.roles.assign(["guard","floor","scavenge"])
	# Declared presentation fixture: built defenses and noise, with real assessment formulas.
	game.residence.security = {"gate":2,"mesh":1,"alarm":1,"stakes":1}
	game.residence.condition = 68
	game.residence.noise = 45
	await click_button(game.interface.overlay,"检查安防")
	check(game.security_view.opened,"night-planning button opens the same assessment")
	check(is_equal_approx(game.security_view.total_value,game.raid_defense(true)),"visible assessment equals the gameplay forecast")
	await click_at(Vector2(1390,850))
	check(game.cycle.phase == "planning" and game.security_view.opened,"modal backdrop blocks the underlying start-night button")
	await picture("res://docs/v16-security-preparation.png")
	for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size = size
		await process_frame
		await process_frame
		check(root.get_visible_rect().size.x > 0 and game.security_view.window.get_global_rect().end.x <= 1440,"security drawer stays within the logical viewport at "+str(size))
	root.mode = Window.MODE_FULLSCREEN
	await process_frame
	check(game.security_view.opened,"security drawer survives fullscreen")
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1440,900)
	await process_frame
	await keypress(KEY_ESCAPE)
	check(game.paused and game.cycle.phase == "planning","closing the drawer retains night planning")
	game.start_expedition()
	game._process(0)
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	var enemy: Dictionary = field.enemies[0]
	for other in field.enemies: other["hp"] = 0; other["mode"] = "dead"
	enemy["kind"] = "walker"; enemy["hp"] = 40; enemy["mode"] = "patrol"
	enemy["x"] = 545; enemy["direction"] = -1.0
	field.player_x = 505; field.facing = 1; field.sneaking = true
	actor.weapon_item = {"kind":"pistol","durability":100}; field.magazine = 2
	field.attack(actor)
	field._resolve_attack(actor)
	game.paused = true
	game.expedition_view.queue_redraw()
	check(enemy["hp"] == 40 and field.magazine == 1 and game.expedition_view.impact_kind == "blocked_shot","blocked crouching shot has a physical impact and consumes ammunition")
	check(game.expedition_view.combat_effects.particles.is_empty(),"a furniture impact never sprays enemy blood")
	await picture("res://docs/v16-blocked-shot.png")
	# Mouse movement approaches a blocked melee target instead of swinging forever.
	actor.weapon_item = {"kind":"knife","durability":100}
	field.attack_cooldown = 0; field.attack_windup = 0
	field.sneaking = false; game.paused = false
	game.interface.set_target(545,0,false,-1); game.interface.target_enemy = 0
	var controls: Dictionary = game._expedition_controls()
	check(controls.get("axis",0) > 0 and field.attack_windup == 0,"mouse attack walks around the obstructing front before attacking")
	game.interface.has_move_target = false
	field.player_x = field.ladder_x()-85
	enemy["x"] = field.ladder_x(); enemy["climb_target"] = 1; enemy["climb_progress"] = 0.45
	enemy["mode"] = "chase"; enemy["memory"] = 5; enemy["target_floor"] = 1; enemy["target"] = 1550
	game.paused = true; game.expedition_view.impact_time = 0
	game.expedition_view.queue_redraw()
	await picture("res://docs/v16-ladder-pursuit.png")
	check(field.enemy_y(enemy) > 400 and field.enemy_y(enemy) < 620,"rendered enemy follows the continuous ladder coordinate")
	await keypress(KEY_Z)
	check(game.security_view.opened,"inspection can be read during a night trip")
	await keypress(KEY_ESCAPE)
	check(game.paused,"closing preserves a preexisting pause")
	# Return normally; historical no-raid entry is actual first-night settlement.
	enemy["climb_target"] = -1; enemy["climb_progress"] = 0
	field.player_x = 90
	game.paused = false
	game.expedition_retreat(); game.confirm_departure()
	await process_frame
	await click_button(game.interface.overlay,"安防复盘")
	check(game.security_view.opened and game.security_view.last_night,"dawn button opens historical facts instead of current predictions")
	await picture("res://docs/v16-security-review.png")
	await keypress(KEY_ESCAPE)
	check(game.cycle.phase == "dawn" and game.paused,"closing historical review cannot start another raid")
	await dispose_scene(game)
	print("SECURITY AI VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
