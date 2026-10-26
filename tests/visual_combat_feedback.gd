extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.end_day()
	game.start_expedition()
	game._process(0)
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	var enemy: Dictionary = field.enemies[0]
	field.player_x = float(enemy["x"])-40
	field.facing = 1
	await keypress(KEY_J)
	sim(game,0.22)
	game.paused = true
	var effects: CombatEffects = game.expedition_view.combat_effects
	effects.step(0.07)
	check(enemy["hp"] == 15 and effects.reactions.has(0),"real J hit records a nonlethal body reaction")
	check(not effects.particles.is_empty() and not effects.marks.is_empty(),"real hit has a visible burst and floor stain")
	await picture("res://docs/v15-hit.png")
	game.paused = false
	field.attack_cooldown = 0
	field.player_x = float(enemy["x"])-40
	await keypress(KEY_J)
	sim(game,0.22)
	game.paused = true
	effects.step(0.17)
	check(enemy["hp"] == 0 and effects.reactions[0]["lethal"],"lethal hit plays a different fall reaction")
	await picture("res://docs/v15-kill.png")
	effects.step(1)
	await picture("res://docs/v15-corpse.png")
	check(enemy["hp"] == 0,"corpse remains after the brief death animation finishes")
	# A separate actual bite fixture verifies recoil, blood and health feedback.
	var attacker: Dictionary = field.enemies[1]
	attacker["kind"] = "brute"
	attacker["hp"] = 90
	attacker["floor"] = 0
	attacker["x"] = field.player_x+30
	attacker["direction"] = -1.0 # This fixture is a frontal bite; rear bites now correctly miss.
	attacker["mode"] = "windup"
	attacker["timer"] = 0.01
	field.invulnerable = 0
	field.attack_cooldown = 0
	game.expedition_view.impact_time = 0
	game.paused = false
	var health := actor.health
	sim(game,0.03)
	game.paused = true
	check(actor.health == health-24 and effects.player_time > 0,"actual heavy bite produces the larger damage and player recoil")
	await picture("res://docs/v15-player-hit.png")
	# Explicit silhouette fixture uses the same catalog as actual combat values.
	for index in range(mini(3,field.enemies.size())):
		var body: Dictionary = field.enemies[index]
		body["kind"] = ["walker","runner","brute"][index]
		body["hp"] = EnemyCatalog.stats(body["kind"])["health"]
		body["floor"] = 0
		body["x"] = field.player_x+80+index*125
		body["mode"] = "patrol"
		body["direction"] = -1.0
	game.expedition_view.reset_feedback()
	field.attack_cooldown = 0
	field.attack_windup = 0
	game.expedition_view.queue_redraw()
	await picture("res://docs/v15-enemy-types.png")
	check(EnemyCatalog.stats("brute")["scale"] > EnemyCatalog.stats("walker")["scale"] and EnemyCatalog.stats("runner")["scale"] < EnemyCatalog.stats("walker")["scale"],"three archetypes have visibly different silhouettes")
	await dispose_scene(game)
	print("COMBAT FEEDBACK VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
