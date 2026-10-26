extends "res://tests/test_campaign.gd"

func isolated(kind: String = "walker") -> ExpeditionState:
	var field := ExpeditionState.new()
	field.begin(0,{},1)
	for enemy in field.enemies: enemy["hp"] = 0; enemy["mode"] = "dead"
	var enemy: Dictionary = field.enemies[0]
	enemy["kind"] = kind
	enemy["hp"] = EnemyCatalog.stats(kind)["health"]
	enemy["x"] = 800.0
	enemy["mode"] = "patrol"
	enemy["direction"] = 1.0
	return field

func tick_enemy(field: ExpeditionState, actor: Survivor, seconds: float) -> void:
	for step in range(ceili(seconds/0.02)):
		field._tick_enemy(field.enemies[0],actor,0.02)

func _run() -> void:
	var resumed := isolated()
	resumed.enemies[0]["floor"] = 1; resumed.enemies[0]["x"] = 1500
	resumed.enemies[0]["target_floor"] = 0; resumed.enemies[0]["target"] = 200
	resumed.begin(0,{},1)
	expect(resumed.enemies[0]["target_floor"] == 1 and resumed.enemies[0]["target"] == 1500,"revisiting a map clears stale remembered coordinates on the previous target floor")
	var actor := Survivor.new()
	actor.metabolism = 0.4
	var field := isolated()
	var enemy: Dictionary = field.enemies[0]
	field.player_x = 900
	tick_enemy(field,actor,0.1)
	expect(enemy["target"] == 900 and enemy["memory"] > 0,"seeing stores a real last-known position")
	field.player_x = 1400
	field.noise = 0
	tick_enemy(field,actor,0.1)
	expect(enemy["target"] == 900,"lost sight does not reveal the player's new position")
	tick_enemy(field,actor,7)
	expect(enemy["mode"] == "patrol" and enemy["memory"] == 0,"lost contact eventually returns to patrol")
	field = isolated()
	enemy = field.enemies[0]
	enemy["x"] = 540
	enemy["direction"] = -1.0
	field.player_x = 510
	field.sneaking = true
	field.noise = 0
	tick_enemy(field,actor,0.1)
	expect(enemy["suspicion"] == 0,"visible low cover hides a crouching player from sight")
	field.sneaking = false
	enemy["direction"] = -1.0
	tick_enemy(field,actor,0.1)
	expect(enemy["suspicion"] > 0,"standing exposes the player above that same cover")
	field = isolated()
	enemy = field.enemies[0]
	enemy["x"] = 1450
	field.floor_level = 1
	field.player_y = 400
	field.player_x = 1510
	field.noise = 100
	tick_enemy(field,actor,1)
	expect(enemy["target_floor"] == 1 and enemy["memory"] > 0,"loud sound travels through the actual ladder route")
	expect(enemy["climb_target"] == 1 and enemy["x"] == field.ladder_x(),"investigation reaches the ladder before changing floors")
	expect(field.enemy_y(enemy) < 620 and field.enemy_y(enemy) > 400,"enemy climbs continuously instead of teleporting")
	var before := float(enemy["climb_progress"])
	enemy["mode"] = "stunned"; enemy["timer"] = 0.35
	tick_enemy(field,actor,0.2)
	expect(enemy["climb_progress"] == before,"hit stun pauses a climb")
	tick_enemy(field,actor,3)
	expect(enemy["floor"] == 1 and enemy["climb_target"] == -1,"enemy can land upstairs and resume investigation")
	field.player_x = 2450; field.noise = 0
	tick_enemy(field,actor,35)
	expect(enemy["floor"] == 0 and enemy["climb_target"] == -1,"after losing contact the enemy physically returns to its home floor")
	field = isolated()
	enemy = field.enemies[0]; enemy["x"] = 900
	field.floor_level = 1; field.player_y = 400; field.player_x = 2200; field.noise = 100
	tick_enemy(field,actor,0.1)
	expect(enemy["memory"] == 0,"distant cross-floor sound cannot give omniscient target acquisition")
	var progresses := {}
	for kind in ["walker","runner","brute"]:
		field = isolated(kind); enemy = field.enemies[0]
		enemy["x"] = field.ladder_x(); enemy["climb_target"] = 1
		tick_enemy(field,actor,0.5)
		progresses[kind] = enemy["climb_progress"]
	expect(progresses["runner"] > progresses["walker"] and progresses["walker"] > progresses["brute"],"three archetypes retain different mobility on ladders")
	# Recheck actual hit conditions when a telegraphed bite lands.
	for mode in ["range","behind","floor","cover","valid"]:
		field = isolated(); enemy = field.enemies[0]
		field.player_x = 760; enemy["x"] = 800; enemy["direction"] = -1.0
		enemy["mode"] = "windup"; enemy["timer"] = 0.01
		actor.health = 100; actor.injury = 0; actor.infection = 0
		match mode:
			"range": field.player_x = 690
			"behind": field.player_x = 835
			"floor": field.floor_level = 1; field.player_y = 400
			"cover": field.player_x = 500; enemy["x"] = 540
		tick_enemy(field,actor,0.02)
		expect(actor.health == (86 if mode == "valid" else 100),"bite resolution checks "+mode)
		expect(enemy["cooldown"] > 0,"a missed bite still has recovery: "+mode)
	# Player attacks use the same low-cover geometry.
	for weapon in ["knife","spear","pistol"]:
		for crouching in [false,true]:
			field = isolated(); enemy = field.enemies[0]
			field.player_x = 505; enemy["x"] = 545
			field.sneaking = crouching
			actor.weapon_item = {"kind":weapon,"durability":100}
			var events: Array = []
			field.combat_resolved.connect(func(kind: String,_p: Vector2,damage: int): events.append([kind,damage]))
			field.magazine = 2
			expect(field.attack(actor),"attack can start: "+weapon+str(crouching))
			field._resolve_attack(actor)
			var blocked: bool = weapon != "pistol" or crouching
			expect(enemy["hp"] == 40 if blocked else enemy["hp"] < 40,"shared occlusion handles "+weapon+str(crouching))
			expect(events[0][1] == 0 if blocked else events[0][1] > 0,"blocked attacks cannot fake damage or quest hits")
			if weapon == "pistol": expect(field.magazine == 1 and actor.weapon_item["durability"] < 100,"obstructed gunfire still spends the shot and wear")
	field = isolated(); enemy = field.enemies[0]; enemy["x"] = 500
	field.player_x = 460; actor.weapon_item = {"kind":"knife","durability":100}
	field._resolve_attack(actor)
	expect(enemy["hp"] < 40,"actors behind the same furniture can still fight, preventing cover invulnerability")
	field = isolated(); enemy = field.enemies[0]
	field.player_x = 765; enemy["x"] = 800; field.sneaking = true
	enemy["direction"] = 1.0; actor.weapon_item = {"kind":"knife","durability":100}
	field._resolve_attack(actor)
	expect(enemy["hp"] == 0 or (enemy["suspicion"] == 100 and enemy["memory"] > 0),"quiet damaging ambush never leaves a surviving enemy oblivious")
	field = isolated(); enemy = field.enemies[0]; enemy["x"] = field.ladder_x(); enemy["climb_target"] = 1
	field.player_x = field.ladder_x()-30
	actor.weapon_item = {"kind":"knife","durability":100}
	enemy["climb_progress"] = 0.5
	field._resolve_attack(actor)
	expect(enemy["hp"] == 40,"cannot hit a climber midway between floors")
	enemy["climb_progress"] = 0.05; enemy["hp"] = 10
	field._resolve_attack(actor)
	expect(enemy["hp"] == 0 and enemy["floor"] == 0 and enemy["climb_target"] == -1,"lethal hit by a landing leaves a grounded corpse")
	field = isolated(); enemy = field.enemies[0]
	enemy["x"] = 540
	var second: Dictionary = field.enemies[1]
	second["hp"] = 40; second["mode"] = "patrol"; second["floor"] = 0; second["x"] = 565
	field.player_x = 510; field.sneaking = true
	actor.weapon_item = {"kind":"pistol","durability":100}; field.magazine = 2
	field._resolve_attack(actor)
	expect(enemy["hp"] == 40 and second["hp"] == 40,"an obstructed nearest target cannot be skipped to magically hit the next enemy")
	field = isolated(); field.player_x = 490; field.sneaking = true; field.magazine = 2
	for body in field.enemies: body["hp"] = 0; body["mode"] = "dead"
	var shot: Array = []
	field.combat_resolved.connect(func(kind: String,point: Vector2,damage: int): shot.append([kind,point,damage]))
	field.attack(actor); field._resolve_attack(actor)
	expect(shot[0][0] == "blocked_shot" and shot[0][2] == 0,"gunfire still impacts furniture when there is no target beyond it")
	expect(field.magazine == 1,"an obstructed empty-lane shot consumes exactly one bullet")
	field = isolated(); field.player_x = 700; field.magazine = 2
	for body in field.enemies: body["hp"] = 0; body["mode"] = "dead"
	shot.clear()
	field.combat_resolved.connect(func(kind: String,point: Vector2,damage: int): shot.append([kind,point,damage]))
	field.attack(actor); field._resolve_attack(actor)
	expect(shot[0][0] == "shot_miss" and shot[0][2] == 0,"standing gun miss has a visible trajectory without inventing a hit")
	actor.free()
	# Full real save/load must retain AI routes on active and inactive maps.
	var game := campaign()
	game.end_day(); game.start_expedition()
	field = game.expedition; enemy = field.enemies[0]
	enemy["x"] = field.ladder_x(); enemy["target"] = 1510; enemy["target_floor"] = 1
	enemy["mode"] = "chase"; enemy["memory"] = 4.0; enemy["suspicion"] = 100
	enemy["climb_target"] = 1; enemy["climb_progress"] = 0.4
	valid(game,"mid enemy climb is a valid save")
	var snapshot := SaveSystem.capture(game)
	expect(SaveSystem.apply_state(game,snapshot).is_empty(),"AI mid-climb snapshot applies")
	expect(game.expedition.enemy_y(game.expedition.enemies[0]) == 532,"loading preserves continuous climb position")
	var broken := snapshot.duplicate(true)
	broken["expedition"]["enemies"][0]["x"] += 5
	expect(not SaveSystem.validate(broken).is_empty(),"save validation rejects a climb away from the ladder")
	broken = snapshot.duplicate(true); broken["expedition"]["enemies"][0]["memory"] = INF
	expect(not SaveSystem.validate(broken).is_empty(),"save validation rejects unbounded AI memory")
	broken = snapshot.duplicate(true); broken["expedition"]["enemies"][0]["target_floor"] = 0
	broken["expedition"]["enemies"][0]["target"] = 80
	expect(not SaveSystem.validate(broken).is_empty(),"save validation bounds remembered positions by their target floor")
	var store := SaveSystem.new(); store.path = "res://tests/fixtures/v12_equipped_campaign.json"
	var old := store.read_state()
	expect(old["ok"] and old["migrated"] and SaveSystem.validate(old["data"]).is_empty(),"archived old campaign migrates to bounded AI fields on every map")
	game.free()
	print("ENEMY AI RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
