class_name RegionalThreats
extends RefCounted
## Calendar/noise-driven patrols are prepared at dusk, never around an active player.
const MAX_ENEMIES := 7 # One additional slot is reserved for the announced camp migration event.
const NAMES := ["零散巡游","游荡群增多","重型护卫出没","成群巡游"]

static func tier(day: int, heat: float) -> int:
	return mini(3,(0 if day<8 else 1 if day<16 else 2 if day<24 else 3)+(1 if heat>=45 else 0))

static func secured(game: Node2D, id: String) -> bool:
	var region: Dictionary = game.districts.regions[id]
	return region["built"] and region["condition"]>30 and int(region["secured_until"])>=game.cycle.night_day

static func brief(game: Node2D, id: String) -> String:
	if secured(game,id): return "前哨整治中 · 迁入受阻"
	var heat: float = game.districts.regions[id]["heat"]
	var field: ExpeditionState = game.regions[id]
	var migrated: bool = field.persistent_loot and field.population_day==game.cycle.night_day and game.cycle.night_day>1
	return ("新巡群迁入 · " if migrated else "声源暴露 · " if heat>=45 else "")+NAMES[tier(game.expansion.day(game),heat)]

static func prepare(game: Node2D) -> void:
	if game.cycle.phase!="planning" or game.game_over: return
	var day: int = game.cycle.night_day
	for id in LocationCatalog.ALL_IDS:
		var field: ExpeditionState = game.regions[id]
		if field.active: continue
		var fresh := not field.persistent_loot and day>field.last_refresh_day
		var protected := secured(game,id)
		field.refresh_for_day(day,not protected,false)
		var level := tier(game.expansion.day(game),float(game.districts.regions[id]["heat"]))
		# Existing wounded patrols keep their identity, position and health.
		if fresh and not protected and level>0:
			for index in range(field.enemies.size()):
				var enemy: Dictionary = field.enemies[index]
				var kind := "brute" if level>=2 and index==1 else "runner" if index%2==0 else str(enemy["kind"])
				enemy["kind"]=kind;enemy["hp"]=EnemyCatalog.stats(kind)["health"]
		if protected: continue
		if field.persistent_loot and day-field.population_day<3: continue
		var alive := field.enemies.filter(func(e):return e["hp"]>0).size()
		var desired := mini(6,field.area()["guards"].size()+(1 if level>0 else 0)+(1 if level==3 else 0))
		var additions := mini(1 if field.persistent_loot else 2,maxi(0,desired-alive))
		for offset in range(additions):
			var slot := -1
			for index in range(field.enemies.size()):
				if field.enemies[index]["hp"]<=0: slot=index;break
			if slot<0:
				if field.enemies.size()>=mini(MAX_ENEMIES,field.area()["guards"].size()+3): break
				slot=field.enemies.size()
			var floor_id := offset%2
			var high := field.right_edge(floor_id)
			var low := maxf(500 if floor_id==0 else field.upper_left(),high-380)
			var x := high-25-offset*45
			var kind := "brute" if level>=2 and (day+slot)%3==0 else "runner" if level>0 else "walker"
			var enemy := {"x":x,"floor":floor_id,"home_floor":floor_id,"target_floor":floor_id,"memory":0.0,"climb_target":-1,"climb_progress":0.0,"min":low,"max":high,"direction":-1.0,"mode":"patrol","suspicion":0.0,"target":x,"timer":0.0,"cooldown":0.0,"brace":0.0,"hp":EnemyCatalog.stats(kind)["health"],"kind":kind}
			if slot==field.enemies.size():field.enemies.append(enemy);field.minds.append(EnemyMind.make(id,slot))
			else:field.enemies[slot]=enemy;field.minds[slot]=EnemyMind.make(id,slot)
			field.population_day=day
			if id=="clinic": game.neighborhood.clinic["migration_day"]=day
			elif id=="waterworks": game.neighborhood.water["migration_day"]=day
