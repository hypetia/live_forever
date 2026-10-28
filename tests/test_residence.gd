extends "res://tests/test_campaign.gd"
## Deliberately isolated fixtures exercise costs, interrupted jobs, hazards and migration.

func provision(game: Node2D) -> void:
	game.inventory.deposit({"materials":100,"tools":20,"fuel":20,"raw_food":20,"meals":20,"water":50,"medicine":10},"explicit test supplies")

func ready_home(game: Node2D) -> void:
	game.simulation_time = 2820 # Day 5, 06:00; isolate convoy rules from campaign progression.
	game.residence.surveyed.append("row")
	game.residence.cleared.append("row")
	provision(game)

func project(game: Node2D, kind: String, seconds: float = 70) -> void:
	expect(game.expansion.start_job(game,kind),"start paid physical project " + kind)
	advance(game,seconds)
	expect(game.expansion.jobs.is_empty(),"finish physical project " + kind)

func _run() -> void:
	var game := campaign()
	provision(game)
	game.simulation_time = 1380 # Day 3, six in the morning.
	game.people.last_day = 3 # Isolate cooking from the separately covered surplus-spoilage boundary.
	var chef: Survivor = game.add_survivor("he")
	chef.person.joined_day = 3
	game.people.sync_members(game.survivors)
	game.select_survivor(3)
	var meals: int = game.inventory.amount("meals")
	var food: int = game.inventory.amount("raw_food")
	game.assign_task("cook")
	advance(game,25)
	expect(game.inventory.amount("meals") == meals+3 and game.inventory.amount("raw_food") == food-1,"chef physically cooks three meals from one normal recipe")
	game.select_survivor(0)
	game.assign_task("cook")
	advance(game,25)
	expect(game.inventory.amount("meals") == meals+5,"another survivor cooks two with the same recipe")
	valid(game,"mixed specialist cooking ledger")
	game.free()

	game = campaign()
	game.end_day()
	game.start_expedition()
	var scout: Survivor = game.survivors[2]
	var field: ExpeditionState = game.expedition
	var enemy: Dictionary = field.enemies[0]
	field.player_x = enemy["x"]-60
	field.facing = 1
	field.attack(scout)
	field._resolve_attack(scout)
	field.attack_windup = 0
	expect(enemy["hp"] == 15,"same starting knife deals 25 for the melee specialist")
	field.attack_cooldown = 0
	field.attack(scout)
	field._resolve_attack(scout)
	field.attack_windup = 0
	expect(enemy["hp"] == 0,"specialist needs two real hits against a walker")
	game.free()
	game = campaign()
	game.end_day()
	game.cycle.roles.assign(["scavenge","bed","guard"])
	game.expansion.equip(game,1,0)
	game.start_expedition()
	field = game.expedition
	enemy = field.enemies[0]
	field.player_x = enemy["x"]-60
	field.facing = 1
	for hit in range(2):
		field.attack_cooldown = 0
		field.attack(game.survivors[0])
		field._resolve_attack(game.survivors[0])
		field.attack_windup = 0
	expect(enemy["hp"] == 4,"same knife needs a third hit for the craftsman")
	game.free()
	game = campaign()
	game.end_day()
	game.start_expedition()
	field = game.expedition
	enemy = field.enemies[0]
	field.player_x = enemy["x"]-64
	enemy["direction"] = 1.0
	field.facing = 1
	field.tick(0.01,game.survivors[2],{"sneak":true})
	field.attack(game.survivors[2])
	for tick in range(12): field.tick(1.0/60,game.survivors[2],{"sneak":true})
	expect(enemy["hp"] == 0 and field.feedback.contains("突袭"),"real windup preserves a quiet behind-the-back ambush")
	valid(game,"ambush result")
	game.free()

	game = campaign()
	provision(game)
	game.simulation_time = 5700 # Day 9.
	var athlete: Survivor = game.add_survivor("tang")
	athlete.person.joined_day = 9
	game.people.sync_members(game.survivors)
	game.select_survivor(4 if game.survivors.size()>4 else 3)
	athlete.fatigue = 90
	athlete.hunger = 20
	athlete.injury = 10
	athlete.health = 70
	game.assign_task("sleep")
	advance(game,30)
	expect(athlete.fatigue < 20 and athlete.health > 70 and athlete.injury < 10,"athlete restores vigor and minor wounds during real fed sleep")
	game.upkeep.level = 1
	var stock: Dictionary = game.inventory.snapshot()
	var quote: Dictionary = game.goals.trade_output(game,"materials")
	expect(quote["water"] == 4 and quote["fuel"] == 2,"negotiator quote includes an explicit better price")
	expect(game.goals.trade(game,"materials"),"negotiator commits the same finite mutual-aid offer")
	expect(game.inventory.amount("materials") == stock["materials"]-4 and game.inventory.amount("water") == stock["water"]+4 and game.inventory.amount("fuel") == stock["fuel"]+2,"trade consumes exact inputs and credits quoted specialist output")
	expect(not game.goals.trade(game,"materials"),"negotiation cannot bypass the shared two-day cooldown")
	valid(game,"specialist trade has a conserved input ledger")
	game.free()

	game = campaign()
	provision(game)
	game.select_survivor(1)
	game.survivors[0].health = 50
	game.survivors[0].injury = 60
	game.survivors[0].hunger = 10
	expect(game.people.aid(game,0) and game.survivors[0].health == 80,"Xu's medical aid actually restores ten more health")
	project(game,"guitar")
	var listener: Survivor = game.survivors[0]
	listener.person.stress = 50
	var mood := listener.person.morale
	project(game,"music",40)
	expect(listener.person.stress < 42 and listener.person.morale > mood+4,"ordinary guitarist calms living companions after reaching the guitar")
	expect(not game.expansion.start_job(game,"music"),"same performer cannot farm music repeatedly that day")
	valid(game,"music cooldown persists")
	game.free()

	game = campaign()
	provision(game)
	var start: Dictionary = game.inventory.snapshot()
	expect(game.expansion.start_job(game,"gate"),"security job reserves real supplies before activation")
	expect(game.residence.security["gate"] == 0,"blueprint does not grant early security")
	advance(game,2)
	var pending: Dictionary = SaveSystem.capture(game)
	valid(game,"security job during walking")
	game.cancel_selected()
	game.cancel_selected()
	expect(game.inventory.snapshot() == start,"cancelling unfinished security refunds precisely once")
	expect(SaveSystem.apply_state(game,pending).is_empty(),"interrupted security work restores")
	advance(game,50)
	expect(game.residence.security["gate"] == 1,"restored work finishes exactly once")
	project(game,"mesh")
	project(game,"alarm")
	project(game,"stakes")
	var defense: float = game.residence.defense()
	game.residence.wear(2)
	expect(game.residence.condition < 100 and game.residence.defense() < defense,"a real attack wears defenses and reduces protection")
	project(game,"maintain",35)
	expect(game.residence.condition == 100,"maintenance spends materials and restores worn security")
	expect(game.residence.guard_multiplier() > 1,"alarm amplifies a guard rather than creating an imaginary guard")
	var chance: int = game.residence.attack_chance(55)
	game.residence.noise = 100
	expect(game.residence.attack_chance(55) > chance,"manufacturing noise makes attraction risk visible in rules")
	valid(game,"security state")
	game.free()

	game = campaign()
	provision(game)
	game.cycle.roles.assign(["guard","bed","floor"])
	game.cycle.night_day = 10
	game.survivors[0].fatigue = 28
	var raid_report: Array[String] = []
	var guard: Survivor = game.survivors[0]
	game._resolve_raid(raid_report)
	expect(guard.health < 100,"one unfortified guard can actually be breached by a later raid")
	guard.health = 100
	game.residence.security["gate"] = 1
	game._resolve_raid(raid_report)
	expect(guard.health == 100 and game.residence.condition < 100,"a paid gate changes the actual raid outcome and takes wear")
	game.residence.condition = 0
	game._resolve_raid(raid_report)
	expect(guard.health < 100,"destroyed security cannot silently retain its defense bonus")
	game.residence.security["gate"] = 0
	game.residence.security["alarm"] = 1
	game.residence.condition = 100
	guard.health = 100
	game._resolve_raid(raid_report)
	expect(guard.health == 100,"an operational alarm helps a real guard avert the same attack")
	game.residence.security["alarm"] = 0
	game.cycle.seed = 20890 # Roll80: quiet base70 does not attract a raid; noise100 raises it to90.
	game.residence.noise = 0
	game._resolve_raid(raid_report)
	expect(guard.health == 100,"quiet shelter avoids the selected attraction roll")
	game.residence.noise = 100
	game._resolve_raid(raid_report)
	expect(guard.health < 100,"loud workshop really attracts an additional attack")
	game.free()

	game = campaign()
	provision(game)
	game.expansion.start_job(game,"gate")
	advance(game,10)
	var job_store := SaveSystem.new()
	job_store.path = "user://residence-active-job-test.json"
	expect(job_store.write_state(game)["ok"],"actual disk save accepts multi-material security work")
	var interrupted := job_store.read_state()
	expect(interrupted["ok"] and SaveSystem.apply_state(game,interrupted["data"]).is_empty(),"JSON numeric conversion preserves in-progress workshop jobs")
	game.cancel_selected()
	game.place_build("bed",0)
	advance(game,0.5)
	expect(job_store.write_state(game)["ok"],"actual disk save also accepts a walking base blueprint")
	interrupted = job_store.read_state()
	expect(interrupted["ok"] and SaveSystem.apply_state(game,interrupted["data"]).is_empty(),"base blueprint survives JSON and load validation")
	game.free()

	game = campaign()
	expect(not game.expansion.start_job(game,"clear_row"),"unvisited home cannot be cleared from a menu")
	game.simulation_time = 660
	game.end_day()
	game.choose_destination("residential")
	game.start_expedition()
	field = game.expedition
	var site: Dictionary = field.site_definitions()[3]
	field.player_x = site["x"]
	field.floor_level = site["floor"]
	field.player_y = ExpeditionState.FLOOR_Y[field.floor_level]
	field._search(15,game.survivors[field.actor_id])
	expect(game.residence.survey(game),"searching at a physically reached new home allows recording a survey")
	expect(not game.residence.surveyed.has("row"),"survey still has to be carried home")
	valid(game,"carried survey saves in the field")
	field.floor_level = 0
	field.player_y = ExpeditionState.FLOOR_Y[0]
	field.player_x = 110
	game.close_loot()
	game.expedition_retreat()
	game.confirm_departure()
	expect(game.residence.surveyed.has("row") and game.residence.carried.is_empty(),"only genuine return registers a surveyed home")
	game.begin_day()
	provision(game)
	game.select_survivor(1)
	project(game,"clear_row",120)
	expect(game.residence.prepared.has("row") and not game.residence.cleared.has("row"),"workshop only prepares tools, never remotely kills zombies or clears a house")
	game.end_day()
	game.choose_destination("residential")
	game.start_expedition()
	field = game.expedition
	field.player_x = site["x"]
	field.floor_level = site["floor"]
	field.player_y = ExpeditionState.FLOOR_Y[field.floor_level]
	field._search(15,game.survivors[field.actor_id])
	# A threat fixture isolates confirmation; physical combat is checked above and in the journey pilot.
	var threat: Dictionary = field.enemies[0]
	threat["x"] = site["x"]-40
	expect(not game.residence.survey(game),"clearance cannot be certified while a zombie is nearby")
	for foe in field.enemies:
		foe["hp"] = 0
		foe["mode"] = "dead"
	expect(game.residence.survey(game) and game.residence.carried_clear,"after actual threat clearance confirmation still travels with the scout")
	valid(game,"carried clearance proof")
	game.residence.trip_return(game,false)
	expect(not game.residence.cleared.has("row") and game.residence.prepared.has("row"),"dying with a confirmation does not unlock the house")
	game.free()

	game = campaign()
	ready_home(game)
	game.survivors[1].illness = 80
	expect(not game.expansion.start_job(game,"pack_row"),"critically ill companions cannot be silently transported")
	game.survivors[1].illness = 0
	game.survivors[1].fatigue = 10
	start = game.inventory.snapshot()
	project(game,"pack_row")
	expect(game.residence.current == "shelter" and game.residence.convoy == "row","completed packing reserves transport but does not teleport the home")
	valid(game,"packed convoy")
	var packed: Dictionary = SaveSystem.capture(game)
	expect(game.residence.cancel_convoy(game),"predeparture convoy can be cancelled")
	var after: Dictionary = game.inventory.snapshot()
	expect(after["fuel"] == start["fuel"] and after["tools"] == start["tools"],"cancellation refunds the prepaid transport costs")
	expect(not game.residence.cancel_convoy(game) and game.inventory.snapshot() == after,"repeated convoy cancellation cannot duplicate supplies")
	expect(SaveSystem.apply_state(game,packed).is_empty(),"packed convoy persists across reload")
	game.end_day()
	expect(game.cycle.roles.count("guard") == 3 and game.cycle.scavenger() == -1,"convoy night assigns everyone to the actual journey")
	game.cycle.roles[2] = "scavenge"
	expect(not game.start_expedition(),"a convoy cannot also send out a scavenger")
	game.cycle.roles[2] = "guard"
	var guard_vigor: float = game.survivors[0].fatigue
	expect(game.start_expedition(),"committing the paid convoy resolves one entire travel night")
	expect(game.cycle.phase == "dawn" and game.residence.current == "row" and game.residence.convoy.is_empty(),"new home is occupied at dawn, not before")
	expect(game.survivors[0].fatigue > guard_vigor and game.cycle.report.any(func(line): return line.contains("迁入")),"journey costs vigor and appears in the morning outcome")
	valid(game,"completed move")
	var finished: Dictionary = SaveSystem.capture(game)
	game._settle_night([])
	expect(SaveSystem.capture(game) == finished,"repeat settlement cannot move, salvage, or debit twice")
	game.begin_day()
	expect(not game.expansion.start_job(game,"pack_shelter"),"cooldown prevents moving straight back for a free reset")
	var damaged := SaveSystem.capture(game)
	damaged["residence"]["current"] = "depot"
	expect(not SaveSystem.validate(damaged).is_empty(),"save rejects a fabricated current home without its route and clearing")
	damaged = SaveSystem.capture(game)
	damaged["residence"]["security"]["gate"] = 99
	expect(not SaveSystem.validate(damaged).is_empty(),"save rejects impossible fortification levels")
	game.free()

	game = campaign()
	var store := SaveSystem.new()
	store.path = "res://tests/fixtures/v8_equipped_night.json"
	var loaded := store.read_state()
	expect(loaded["ok"] and loaded["migrated"],"genuine pre-change v8 night migrates through v9")
	expect(SaveSystem.apply_state(game,loaded["data"]).is_empty(),"legacy equipped night loads without losing active reload")
	expect(game.expedition.magazine == 5 and is_equal_approx(game.expedition.reload_remaining,1.0) and game.residence.current == "shelter","migration preserves real ammo and starts at the existing home")
	valid(game,"old equipped save")
	game.free()
	game = campaign()
	provision(game)
	var noise_before: float = game.residence.noise
	project(game,"bat",40)
	expect(game.residence.noise > noise_before,"equipment workshop also contributes real manufacturing noise")
	game.residence.noise = 50
	var time_before: float = game.simulation_time
	game.end_day()
	expect(is_equal_approx(game.residence.noise,50-(game.simulation_time-time_before)*0.006),"ending daylight dissipates noise over the same skipped simulation time")
	game.free()
	print("RESIDENCE RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
