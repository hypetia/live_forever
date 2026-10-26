extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	var d: CampaignDirector = game.director
	expect(d.offers(game).size() == 3 and d.status.is_empty(),"new campaign exposes three optional opportunities without accepting anything")
	game.save_store.path = "user://director_empty.json"
	expect(game.save_store.write_state(game)["ok"],"empty opportunity state round-trips JSON integer conversion")
	expect(game.save_store.read_state()["ok"],"empty opportunity state reloads from disk")
	var enemies: Array = game.expedition.enemies.duplicate(true)
	game.facilities.levels = {"workbench":3,"stove":3}
	expect(d.offers(game).has("ranged_works") and d.offers(game).has("meal_pot"),"upgrades open more demanding and better rewarded opportunities")
	expect(game.expedition.enemies == enemies,"equipment progress never silently scales enemy stats")
	game.facilities.levels = {"workbench":1,"stove":1}
	game.inventory.deposit({"meals":4},"existing-stock fixture")
	expect(d.accept(game,"meal_basic"),"player explicitly accepts a food opportunity")
	var before: Dictionary = game.inventory.snapshot()
	expect(not d.claim(game) and game.inventory.snapshot() == before,"old stock cannot skip the actual cooking objective")
	expect(not d.accept(game,"clear_street"),"active contract cannot be rerolled for another reward")
	game.scheduler.submit(game.survivors[0],"cook")
	advance(game,22)
	expect(d.progress == 2 and d.status == "active","actual basic cooking records the real produced quantity")
	var store := SaveSystem.new()
	store.path = "user://director_progress.json"
	expect(store.write_state(game)["ok"],"partial objective persists to disk")
	expect(SaveSystem.apply_state(game,store.read_state()["data"]).is_empty() and d.progress == 2,"reload preserves progress instead of re-awarding it")
	game.paused = false
	game.scheduler.submit(game.survivors[0],"cook")
	advance(game,12)
	expect(d.progress == 4 and d.status == "ready","required cooking makes the opportunity ready")
	before = game.inventory.snapshot()
	expect(d.claim(game),"ready objective can exchange its displayed food cost for supplies")
	expect(game.inventory.amount("meals") == before["meals"]-4 and game.inventory.amount("water") == before["water"]+3 and game.inventory.amount("fuel") == before["fuel"]+1,"claim debits food and credits exactly the displayed supplies")
	before = game.inventory.snapshot()
	expect(not d.claim(game) and not d.accept(game,"meal_basic") and game.inventory.snapshot() == before,"neither repeated claim nor another same-window contract can duplicate supplies")
	valid(game,"claimed optional opportunity")
	game.free()

	game = campaign()
	game.simulation_time = 2*720
	game.end_day()
	expect(not game.director.accept(game,"meal_basic"),"last-night planning never offers an impossible cooking deadline")
	game.residence.convoy = "row" # Forecast-only planning fixture.
	expect(game.night_forecast().contains("迁居") and not game.night_forecast().contains("防守稳固"),"convoy forecast describes escort instead of a stationary home defense")
	expect(not game.director.accept(game,"survey_street"),"last-night convoy does not offer an impossible field objective")
	game.residence.convoy = ""
	expect(game.director.accept(game,"survey_street"),"last-night departure can still take a feasible field opportunity")
	game.free()

	game = campaign()
	d = game.director
	d.accept(game,"meal_basic")
	game.simulation_time = 3*720 # Isolated calendar-boundary fixture.
	d.sync_day(game)
	expect(d.status == "expired" and d.deadline == 3,"unfinished opportunity expires after its third night")
	expect(d.accept(game,"meal_basic") and d.deadline == 6,"next three-day window has a fresh, bounded opportunity")
	before = game.inventory.snapshot()
	expect(d.abandon(game) and not d.accept(game,"meal_basic") and game.inventory.snapshot() == before,"abandonment costs no inventory but consumes the current window")
	valid(game,"expired and abandoned opportunities")
	game.free()

	game = campaign()
	d = game.director
	d.accept(game,"survey_street")
	game.end_day()
	game.start_expedition()
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	field.floor_level = 1
	field.player_y = 400
	field.player_x = 1620 # Search geometry fixture; navigation is exercised by GUI/core tests.
	for key in field.sites[3]["contents"]: field.sites[3]["contents"][key] = 0
	expect(InteractionFeedback.pending_action(game,3) and not InteractionFeedback.site(game,3)["supplied"],"objective pin is separate from the neutral depleted-container colour")
	field._search(20,actor)
	d.observe_trip(game)
	expect(d.trip_progress == 1 and d.progress == 0 and d.status == "active","visiting the target carries evidence without banking it remotely")
	expect(not InteractionFeedback.pending_action(game,3),"recorded evidence removes the objective pin")
	game._process(0)
	valid(game,"carried survey evidence")
	game.close_loot()
	field.floor_level = 0
	field.player_y = 620
	field.player_x = 110
	game.expedition_retreat()
	game.confirm_departure()
	expect(d.status == "ready" and d.progress == 1 and d.trip_progress == 0,"successful extraction banks the evidence once")
	expect(not d.claim(game),"morning summary cannot be used as an extra action phase")
	game.begin_day()
	before = game.inventory.snapshot()
	expect(d.claim(game) and game.inventory.amount("materials") == before["materials"]+2 and game.inventory.amount("medicine") == before["medicine"]+1,"returned evidence earns exactly one supply cache")
	valid(game,"survey reward deposited")
	game.free()

	game = campaign()
	d = game.director
	d.accept(game,"survey_street")
	game.end_day()
	game.start_expedition()
	field = game.expedition
	actor = game.survivors[field.actor_id]
	field.floor_level = 1
	field.player_y = 400
	field.player_x = 1620
	field._search(20,actor)
	d.observe_trip(game)
	actor.health = 0
	advance(game,0.1)
	expect(d.status == "active" and d.progress == 0 and d.trip_progress == 0,"death loses carried evidence and awards no reward")
	valid(game,"lost evidence after expedition death")
	game.free()

	game = campaign()
	d = game.director
	d.accept(game,"clear_street")
	game.regions["street"].enemies[1]["hp"] = 0
	game.regions["street"].enemies[1]["mode"] = "dead"
	game.end_day()
	game.start_expedition()
	field = game.expedition
	actor = game.survivors[field.actor_id]
	d.observe_trip(game)
	expect(d.trip_progress == 0,"enemies dead before departure cannot satisfy a new combat objective")
	var enemy: Dictionary = field.enemies[0]
	for hit in range(2):
		field.player_x = float(enemy["x"])-35
		field.facing = 1
		field.attack_cooldown = 0 # Isolated attack timing; damage still uses the real resolver.
		expect(field.attack(actor),"actual weapon attack starts for combat objective")
		advance(game,0.4)
	expect(enemy["hp"] == 0 and d.trip_progress == 1 and d.progress == 0,"real new kill is carried until extraction")
	field.player_x = 110
	game.expedition_retreat()
	game.confirm_departure()
	expect(d.status == "ready" and d.progress == 1,"combat success requires a living return")
	valid(game,"combat objective at dawn")
	game.free()

	game = campaign()
	d = game.director
	game.facilities.levels["workbench"] = 3
	game.expansion.grant("pistol")
	game.expansion.equip(game,2,2)
	game.expansion.ammo = 6
	d.accept(game,"ranged_works")
	game.end_day()
	game.choose_destination("works")
	game.expansion.ammo_loadout = 6
	game.start_expedition()
	field = game.expedition
	actor = game.survivors[field.actor_id]
	enemy = field.enemies[0]
	field.player_x = float(enemy["x"])-140
	field.facing = 1
	d.shot(game,"miss",0)
	expect(d.trip_progress == 0,"missed or zero-damage events do not count as firearm hits")
	field.attack(actor)
	advance(game,0.3)
	expect(d.trip_progress == 1 and field.magazine == 5,"a real damaging shot consumes ammo and records exactly one hit")
	valid(game,"saved partial firearm opportunity")
	var saved := SaveSystem.capture(game)
	for key in ["deadline","progress","trip_progress"]:
		var bad := saved.duplicate(true)
		bad["director"][key] = 999
		expect(not SaveSystem.validate(bad).is_empty(),"impossible objective state is rejected: "+key)
	game.free()

	game = campaign()
	store.path = "res://tests/fixtures/v11_facility_levels.json"
	var legacy := store.read_state()
	expect(legacy["ok"] and legacy["migrated"] and SaveSystem.apply_state(game,legacy["data"]).is_empty(),"authentic schema eleven facility save migrates")
	expect(game.facilities.levels["workbench"] == 2 and game.director.status.is_empty(),"migration preserves upgrades and invents no accepted contract or reward")
	game.free()
	for pair in [[GameUi.TEXT,GameUi.PANEL,10.0],[GameUi.SECONDARY,GameUi.PANEL,7.0],[GameUi.MUTED,Color("1c2937"),4.5],[GameUi.ACCENT,GameUi.PANEL,7.0]]:
		expect(contrast(pair[0],pair[1]) >= pair[2],"panel typography has measured readable contrast")
	print("DIRECTOR RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)

func contrast(a: Color,b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la,lb)+0.05)/(minf(la,lb)+0.05)

func luminance(color: Color) -> float:
	var rgb: Array[float] = []
	for channel in [color.r,color.g,color.b]: rgb.append(channel/12.92 if channel <= 0.04045 else pow((channel+0.055)/1.055,2.4))
	return rgb[0]*0.2126+rgb[1]*0.7152+rgb[2]*0.0722
