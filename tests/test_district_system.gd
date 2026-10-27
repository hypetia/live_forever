extends "res://tests/test_campaign.gd"

func expedition(id: String = "street") -> Node2D:
	var game := campaign()
	game.inventory.deposit({"materials":12,"tools":2,"fuel":4},"declared district rule fixture")
	game.end_day();game.cycle.loadout = {"materials":12,"tools":2,"fuel":4}
	game.start_expedition()
	if id != "street":
		var cargo: Dictionary = game.expedition.bag.duplicate()
		game.expedition.active = false;game.expedition.actor_id = -1;game.expedition.extra_slots = 0;game.expedition._clear_bag()
		game.expedition = game.regions[id]
		game.expedition.begin(2,cargo,1)
		game.expedition.capacity = 14;game.expedition.extra_slots = 1
		game.districts.begin_trip(game)
	for e in game.expedition.enemies: e["hp"] = 0;e["mode"] = "dead"
	game.districts.trip_dead = game.expedition.enemies.size()
	var point: Dictionary = game.expedition.site_definitions()[DistrictSystem.POINTS[id]]
	game.expedition.player_x = point["x"];game.expedition.floor_level = point["floor"];game.expedition.player_y = ExpeditionState.FLOOR_Y[point["floor"]]
	game.expedition._search(20,game.survivors[2])
	return game

func reopen(game: Node2D) -> void:
	game.expedition._search(.01,game.survivors[game.expedition.actor_id])

func _run() -> void:
	for id: String in LocationCatalog.ALL_IDS:
		var game := expedition(id)
		var d: DistrictSystem = game.districts
		var field: ExpeditionState = game.expedition
		var stock: Dictionary = game.inventory.snapshot()
		var material: int = field.bag["materials"];var tools: int = field.bag["tools"]
		expect(d.begin_work(game,"build"),id+" actual point accepts a cleared, paid construction plan")
		expect(field.loot_site == -1 and field.bag["materials"] == material and field.bag["tools"] == tools,id+" beginning work closes loot without prepaying or awarding output")
		d.tick_work(game,.5,{})
		valid(game,id+" partial outpost work saves")
		d.tick_work(game,.02,{"axis":1})
		expect(d.work.is_empty() and field.bag["materials"] == material,id+" moving cancels field engineering without a refund exploit")
		reopen(game);d.begin_work(game,"build")
		d.tick_work(game,10,{})
		expect(d.regions[id]["built"] and d.regions[id]["condition"] == 100,id+" completed physical work creates the outpost")
		expect(field.bag["materials"] == material-5 and field.bag["tools"] == tools-1 and game.inventory.snapshot() == stock,id+" completion debits actual bag items only")
		d.tick_work(game,100,{})
		expect(field.bag["materials"] == material-5,id+" repeated ticks cannot charge again")
		valid(game,id+" completed outpost snapshot")
		reopen(game)
		expect(not d.action_error(game,"build").is_empty() and not d.begin_work(game,"build"),id+" an existing outpost cannot be rebuilt for rewards")
		d.regions[id]["condition"] = 35.0
		expect(d.begin_work(game,"repair"),id+" worn outpost accepts real maintenance")
		d.tick_work(game,6,{})
		expect(d.regions[id]["condition"] == 90 and field.bag["materials"] == material-7,id+" maintenance costs two materials and restores a bounded fifty-five points")
		reopen(game);d.regions[id]["heat"] = 60.0
		var fuel: int = field.bag["fuel"]
		expect(d.begin_work(game,"suppress"),id+" pressure has a physical intervention")
		d.tick_work(game,8,{})
		expect(d.regions[id]["heat"] == 35 and field.bag["materials"] == material-8 and field.bag["fuel"] == fuel-1,id+" cleanup trades real supplies and work for pressure reduction")
		valid(game,id+" maintained and cleaned district saves")
		game.free()
	var game := expedition()
	var d: DistrictSystem = game.districts
	var field: ExpeditionState = game.expedition
	var foe: Dictionary = field.enemies[0]
	foe["hp"] = 40;foe["mode"] = "patrol";foe["floor"] = field.floor_level;foe["x"] = field.player_x+50
	expect(not d.action_error(game,"build").is_empty(),"nearby living enemies prevent construction")
	foe["floor"] = 0;foe["x"] = field.ladder_x();foe["climb_target"] = 1;foe["climb_progress"] = .9
	expect(not d.area_clear(field),"an approaching climber near the landing counts as a real nearby threat")
	foe["climb_target"] = -1;foe["climb_progress"] = 0;foe["floor"] = field.floor_level
	foe["x"] = field.player_x+300
	expect(d.begin_work(game,"build"),"luring enemies away can enable construction without killing them")
	game.survivors[field.actor_id].health -= 5
	d.tick_work(game,.1,{})
	expect(d.work.is_empty() and not d.regions["street"]["built"],"taking damage cancels work and never creates a completed outpost")
	foe["hp"] = 0;foe["mode"] = "dead"
	reopen(game);d.begin_work(game,"build");d.tick_work(game,.5,{})
	var snapshot := SaveSystem.capture(game)
	expect(SaveSystem.apply_state(game,snapshot).is_empty() and game.districts.work["elapsed"] == .5,"ordinary save restore retains incomplete paid work without duplicating its resources")
	var bad := snapshot.duplicate(true);bad["districts"]["work"]["elapsed"] = 10
	expect(not SaveSystem.validate(bad).is_empty(),"invalid completed-but-pending work is rejected")
	bad = snapshot.duplicate(true);bad["districts"]["regions"]["street"]["heat"] = INF
	expect(not SaveSystem.validate(bad).is_empty(),"nonfinite persistent pressure is rejected")
	bad = snapshot.duplicate(true);bad["districts"]["regions"]["street"]["condition"] = 100
	expect(not SaveSystem.validate(bad).is_empty(),"an unbuilt station cannot retain durability")
	game.districts.work.clear();reopen(game);game.districts.begin_work(game,"build")
	for n in range(2): game.expedition_drop("tools")
	expect(game.districts.work.is_empty(),"dropping required work tools cancels immediately, before a same-frame save")
	valid(game,"dropped construction tool snapshot")
	game.free()
	# Actual funded shift, settlement and one-time production use the normal API.
	game = campaign();d = game.districts
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 100.0
	game.end_day();game.cycle.roles.assign(["outpost","guard","scavenge"])
	var fuel: int = game.inventory.amount("fuel")
	expect(game.start_expedition(),"one real worker can be reserved for outpost duty alongside a scavenger")
	expect(game.inventory.amount("fuel") == fuel-1 and not d.shift.is_empty(),"shift fuel is reserved before any scavenged supplies return")
	valid(game,"active funded outpost shift")
	field = game.expedition;field.player_x = 90
	game.expedition_retreat();game.confirm_departure()
	expect(game.cycle.phase == "dawn" and d.shift.is_empty(),"real return settles an existing outpost shift")
	expect(game.inventory.amount("raw_food") == 6 and game.inventory.amount("water") == 5,"funded first shift returns the exact district yield")
	expect(d.regions["street"]["condition"] == 84 and d.regions["street"]["shifts"] == 1,"production wears the outpost and counts one completed shift")
	expect(game.survivors[0].fatigue >= 45 and game.cycle.roles[0] == "outpost","outpost work consumes a person's night rather than simultaneously providing sleep or guard duty")
	valid(game,"settled outpost shift")
	var before := SaveSystem.capture(game)
	var lines: Array[String] = [];d.dawn(game,lines);game._settle_night([])
	expect(before == SaveSystem.capture(game),"repeated dawn cannot generate more supplies or wear")
	game.begin_day();game.end_day();game.cycle.roles.assign(["outpost","guard","scavenge"])
	d.regions["street"]["condition"] = 19
	expect(not game.cycle.plan_error(game).is_empty(),"a worn-out outpost cannot run a free supply loop")
	d.regions["street"]["condition"] = 100;game.inventory.try_take({"fuel":game.inventory.amount("fuel")},"declared empty-fuel rule fixture")
	expect(not game.cycle.plan_error(game).is_empty(),"shift cannot rely on fuel that has not yet been brought home")
	game.free()
	# Roles have different productive value at different sites.
	game = campaign();d = game.districts
	var medic: Survivor = game.survivors[1];var maker: Survivor = game.survivors[0];var scout: Survivor = game.survivors[2]
	expect(d.shift_yield(medic,"clinic")["medicine"] == 2 and d.shift_yield(scout,"clinic")["medicine"] == 1,"medical ability changes actual clinic recovery")
	expect(d.shift_yield(maker,"works")["materials"] == 5 and d.shift_yield(medic,"works")["materials"] == 4,"craft ability changes actual workshop recovery")
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 100
	var armed_risk := d.shift_risk(scout,"street")
	d.regions["street"]["heat"] = 100;d.regions["street"]["condition"] = 20
	expect(d.shift_risk(scout,"street") > armed_risk,"noise pressure and neglect increase the risk of operating a station")
	d.regions["street"]["heat"] = 0;d.regions["street"]["condition"] = 100
	scout.health = 45;scout.fatigue = 80;scout.injury = 50;scout.illness = 30
	expect(d.shift_risk(scout,"street") > armed_risk,"injury, illness, health and vigor affect an actual person's duty risk")
	game.free()
	game = campaign();d = game.districts
	game.simulation_time = 1440;game.cycle.seed = 1
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 20;d.regions["street"]["heat"] = 100
	game.end_day();game.cycle.roles.assign(["outpost","guard","floor"])
	var before_fuel: int = game.inventory.amount("fuel")
	var before_health: float = game.survivors[0].health
	expect(game.start_expedition(),"a hazardous but valid station can be deliberately staffed")
	expect(d.regions["street"]["shifts"] == 0 and d.regions["street"]["condition"] == 0,"a failed shift yields no production and can exhaust a neglected station")
	expect(game.survivors[0].health < before_health and game.inventory.amount("fuel") == before_fuel-1,"failure has actual injury and fuel costs")
	expect(game.cycle.report.any(func(line): return line.contains("本夜未回收物资")),"dawn explains the failed production instead of claiming an automatic payout")
	valid(game,"failed shift settlement")
	game.free()
	game = campaign();game.cycle.night_day = 13;game.cycle.roles.assign(["outpost","bed","guard"])
	game.expansion.night_heat = 300
	var climate_report: Array[String] = []
	game.expansion.dawn(game,300,climate_report)
	expect(game.survivors[0].cold_exposure > game.survivors[2].cold_exposure,"outside duty cannot borrow the home's night heating")
	game.free()
	game = campaign();d = game.districts
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 100
	game.expansion.grant("pistol");game.expansion.equip(game,game.expansion.gear.back()["id"],0)
	game.end_day();game.cycle.roles.assign(["outpost","guard","scavenge"])
	game.expansion.ammo = 1
	expect(game.cycle.plan_error(game).contains("弹药"),"an empty outpost gun cannot provide free armed protection")
	game.expansion.ammo = 2;game.expansion.ammo_loadout = 1
	expect(game.cycle.plan_error(game).contains("弹药"),"outpost and scavenger cannot reserve the same cartridges")
	game.expansion.ammo = 3
	var weapon_before: int = game.survivors[0].weapon_item["durability"]
	expect(game.start_expedition() and game.expansion.ammo == 0 and game.districts.shift["ammo"] == 2 and game.expedition.reserve_ammo == 1,"outpost gunfire and carried ammunition are prepaid separately")
	valid(game,"armed outpost reservation")
	game.expedition.player_x = 90;game.expedition_retreat();game.confirm_departure()
	expect(game.expansion.ammo == 1 and game.survivors[0].weapon_item["durability"] == weapon_before-1,"only unused carried ammunition returns; outpost ammunition and weapon wear stay spent")
	valid(game,"armed outpost settlement")
	game.free()
	game = campaign();d = game.districts
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 100
	game.expansion.grant("knife");game.expansion.equip(game,game.expansion.gear.back()["id"],0)
	game.end_day();game.cycle.roles.assign(["outpost","guard","scavenge"]);game.start_expedition()
	# Explicit fatal-outcome fixture; the ordinary dawn path handles gear and rewards.
	game.survivors[0].health = 0
	game.expedition_retreat();game.confirm_departure()
	expect(d.regions["street"]["shifts"] == 0 and game.inventory.history.all(func(entry): return not entry["reason"].begins_with("前哨轮值回收")),"a worker who cannot return cannot deliver a posthumous payout")
	expect(game.expansion.gear.all(func(item): return item["owner"] != "lin") and game.survivors[0].weapon_item.is_empty(),"outside worker death loses actually assigned gear")
	valid(game,"fatal outpost duty settlement")
	game.free()
	game = campaign();d = game.districts
	d.regions["street"]["built"] = true;d.regions["street"]["condition"] = 100
	game.cycle.builds.append({"slot":0,"type":"heater","state":"complete","actor":-1,"elapsed":40.0})
	game.expansion.use_night_heat = true
	game.end_day();game.cycle.roles.assign(["outpost","guard","scavenge"]);game.cycle.loadout = {"fuel":1}
	expect(game.cycle.plan_error(game).contains("取暖"),"outpost duty cannot silently steal fuel promised to night heating")
	game.cycle.loadout = {}
	expect(game.start_expedition() and game.inventory.amount("fuel") == 0 and game.expansion.night_heat >= game.cycle.night_end-game.cycle.night_start,"combined heating and duty are funded together before departure")
	valid(game,"combined paid heat and outpost reservation")
	game.free()
	# Archived v1.8 saves retain map and physical inventory state.
	var store := SaveSystem.new();store.path = "res://tests/fixtures/v15_open_route_campaign.json"
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	var old: Dictionary = JSON.parse_string(original["data_json"])
	var result := store.read_state()
	expect(result["ok"] and result["migrated"],"authentic schema15 campaign migrates through the ordinary loader")
	if result["ok"]:
		var migrated: Dictionary = result["data"]
		expect(migrated["stock"] == old["stock"] and migrated["expedition"]["route_open"] == old["expedition"]["route_open"] and migrated["expedition"]["enemies"] == old["expedition"]["enemies"],"migration preserves stock, opened map route and enemy AI")
		expect(migrated["districts"]["regions"]["street"]["heat"] == 0 and not migrated["districts"]["regions"]["street"]["built"],"migration adds no free outposts or inherited penalties")
	print("DISTRICT SYSTEM RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(.12).timeout
	quit(1 if failures else 0)
