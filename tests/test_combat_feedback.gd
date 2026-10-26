extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	game.end_day()
	game.start_expedition()
	game._process(0)
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	var enemy: Dictionary = field.enemies[0]
	field.player_x = float(enemy["x"])-35
	field.facing = 1
	field.attack(actor)
	advance(game,0.3)
	var effects: CombatEffects = game.expedition_view.combat_effects
	expect(enemy["hp"] < 40 and not effects.particles.is_empty() and effects.reactions.has(0),"actual damaging hit produces blood and a body reaction")
	expect(not effects.reactions[0]["lethal"],"nonlethal reaction does not pretend the enemy died")
	effects.clear()
	actor.weapon_item["durability"] = 0
	field.attack_cooldown = 0
	field.player_x = float(enemy["x"])-35
	var hp: int = enemy["hp"]
	field.attack(actor)
	advance(game,0.3)
	expect(enemy["hp"] == hp and effects.particles.is_empty() and effects.reactions.is_empty(),"zero-damage push never creates fake blood or death effects")
	actor.weapon_item["durability"] = 60
	field.attack_cooldown = 0
	field.player_x = float(enemy["x"])-35
	field.attack(actor)
	advance(game,0.3)
	expect(enemy["hp"] == 0 and effects.reactions[0]["lethal"],"actual lethal hit triggers a distinct fall and corpse state")
	valid(game,"combat presentation adds no invalid simulation fields")
	var saved := SaveSystem.capture(game)
	expect(SaveSystem.apply_state(game,saved).is_empty() and game.expedition.enemies[0]["hp"] == 0,"loading retains the dead enemy")
	expect(effects.particles.is_empty() and effects.reactions.is_empty(),"loading never replays old hit bursts")
	game.free()
	for kind in EnemyCatalog.TYPES:
		var state := ExpeditionState.new()
		var victim := Survivor.new()
		state.begin(0,{},1)
		for other in state.enemies: other["hp"] = 0; other["mode"] = "dead"
		var attacker: Dictionary = state.enemies[0]
		attacker["kind"] = kind
		attacker["hp"] = EnemyCatalog.stats(kind)["health"]
		attacker["x"] = 130
		attacker["floor"] = 0
		attacker["mode"] = "windup"
		attacker["timer"] = 0.01
		var received: Array = []
		state.player_hurt.connect(func(_point: Vector2,_direction: float,damage: int): received.append(damage))
		state.tick(0.02,victim,{})
		expect(victim.health == 100-EnemyCatalog.stats(kind)["damage"],"enemy archetype retains its actual distinct damage: "+kind)
		expect(received == [EnemyCatalog.stats(kind)["damage"]],"player-hit event comes from real health loss: "+kind)
		victim.free()
	expect(EnemyCatalog.stats("runner")["chase_speed"] > EnemyCatalog.stats("walker")["chase_speed"] and EnemyCatalog.stats("walker")["chase_speed"] > EnemyCatalog.stats("brute")["chase_speed"],"runner, walker and brute have distinct pursuit speeds")
	expect(EnemyCatalog.stats("brute")["health"] == 90 and EnemyCatalog.stats("walker")["health"] == 40 and EnemyCatalog.stats("runner")["health"] == 30,"archetypes do not share a fixed number of hits")
	var bounded := CombatEffects.new()
	for index in range(200): bounded.hit(index%6,Vector2.ZERO,1,10,false)
	expect(bounded.particles.size() <= CombatEffects.MAX_PARTICLES and bounded.marks.size() <= CombatEffects.MAX_MARKS and bounded.reactions.size() <= 6,"long fights cannot grow visual particles and stains without bounds")
	bounded.step(2)
	expect(bounded.particles.is_empty() and bounded.reactions.is_empty(),"expired transient effects are removed")
	bounded.clear()
	expect(bounded.marks.is_empty(),"changing trips clears old stains")
	print("COMBAT FEEDBACK RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
