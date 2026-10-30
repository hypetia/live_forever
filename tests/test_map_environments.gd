extends "res://tests/test_campaign.gd"

func field_at(id: String, tools: int = 1) -> ExpeditionState:
	var field := ExpeditionState.new(id)
	field.stacked = true
	field.environment_active = true
	field.begin(0,{"tools":tools},1)
	field.player_x = field.route_x()
	for enemy in field.enemies: enemy["hp"] = 0; enemy["mode"] = "dead"
	return field

func valid_field(field: ExpeditionState,message: String) -> void:
	var actors: Array = [{"state":Survivor.TaskState.AWAY}] if field.active else []
	var error := ExpeditionState.validate_snapshot(field.snapshot(),actors,field.location_id)
	expect(error.is_empty(),message+": "+error)

func _run() -> void:
	var actor := Survivor.new()
	actor.metabolism = .1
	for id: String in LocationCatalog.ALL_IDS:
		actor.tool_item={"kind":"toolkit","durability":100}
		var profile := LocationEnvironment.profile(id)
		var field := field_at(id)
		expect(profile["rooms"].size() >= 3 and profile["containers"].size() == field.sites.size(),id+" has room groups and an actual container style for every site")
		expect(field.route_x() > field.upper_left() and field.route_x() < field.right_edge(1) and absf(field.route_x()-field.ladder_x()) > 100,id+" secondary access is a distinct valid landing on both floors")
		for z: Array in profile["zones"]:
			expect(z[0] < z[1] and z[0] >= (90 if z[2] == 0 else field.upper_left()) and z[1] <= field.right_edge(int(z[2])),id+" surface interval matches a real walkable floor")
		var original: Array = field.sites.duplicate(true)
		field._clear_route(.5,actor)
		expect(field.route_progress == .5 and field.route_tool and field.bag["tools"] == 1,id+" tooling is timed and not prepaid")
		valid_field(field,id+" partial clearing saves")
		var paused := field.route_progress
		field.tick(.1,actor,{})
		expect(field.route_progress == paused,id+" releasing interact pauses clearing")
		var loaded := ExpeditionState.new(id)
		loaded.environment_active = true
		loaded.restore_validated(field.snapshot())
		loaded._clear_route(LocationEnvironment.route_seconds(id,true)-.5,actor)
		expect(loaded.route_open and loaded.bag["tools"] == 1 and actor.tool_item["durability"]==88 and loaded.sites == original,id+" clearing wears the same toolkit without consuming components or granting loot")
		loaded._clear_route(100,actor)
		expect(loaded.bag["tools"] == 1 and actor.tool_item["durability"]==88,id+" completed clearing cannot spend again")
		valid_field(loaded,id+" completed route saves")
		expect(loaded.nearest_ladder(loaded.route_x()+10) == loaded.route_x() and loaded.route_ladder(loaded.route_x()-50,loaded.route_x()+20) == loaded.route_x(),id+" physical route planner chooses the opened nearby ladder")
		loaded.tick(.01,actor,{"climb":1})
		expect(loaded.climb_target == 1 and loaded.player_x == loaded.route_x(),id+" W uses the new access")
		loaded.tick(.8,actor,{})
		valid_field(loaded,id+" second-ladder mid-climb saves")
		loaded.tick(1.3,actor,{})
		expect(loaded.floor_level == 1 and loaded.player_y == 400,id+" reaches the correct upper floor continuously")
		loaded.tick(.01,actor,{"climb":-1});loaded.tick(2.01,actor,{})
		expect(loaded.floor_level == 0 and loaded.player_y == 620,id+" new ladder also provides a real return route")
		loaded.player_x = 110;loaded.confirm_retreat(-1)
		loaded.refresh_for_day(2)
		expect(loaded.route_open and loaded.condition == 1,id+" return and daily migration preserve clearance while changing announced conditions")
		valid_field(loaded,id+" inactive world saves after daily refresh")
		actor.tool_item={}
		var forced := field_at(id,0)
		forced._clear_route(LocationEnvironment.route_seconds(id,false)-.1,actor)
		expect(not forced.route_open and forced.noise_burst == 95,id+" no-tool alternative is slower and conspicuously noisy")
		forced._clear_route(.1,actor)
		expect(forced.route_open and forced.bag["tools"] == 0,id+" no-tool alternative remains viable")
		actor.tool_item={"kind":"toolkit","durability":100}
		field = field_at(id)
		field._clear_route(.5,actor);field.tick(.02,actor,{"axis":-1})
		expect(field.route_progress == 0 and not field.route_tool and field.bag["tools"] == 1,id+" walking cancels without spending")
		field.player_x = field.route_x();field._clear_route(.5,actor);field.drop("tools")
		expect(field.route_progress == 0,id+" dropping the held tool cancels clearing safely")
		for condition in [0,1]:
			field = field_at(id,0);field.condition = condition
			for z: Array in LocationEnvironment.zones(id,condition):
				field.floor_level = int(z[2]);field.player_y = ExpeditionState.FLOOR_Y[field.floor_level]
				field.player_x = (float(z[0])+float(z[1]))*.5
				var start := field.player_x
				actor.fatigue = 0;actor.hunger = 0;actor.injury = 0;actor.health = 100
				field.tick(.02,actor,{"axis":1})
				var speed: float = (field.player_x-start)/.02
				var loud := field.noise
				expect(speed < 190 and loud > 0,id+" actual movement is affected by "+str(z[3]))
				field.tick(.02,actor,{"axis":1,"sneak":true})
				expect(field.noise < loud,id+" cautious movement reduces actual surface noise")
		# Enemy route access matches player access; unopened shortcuts cannot be used.
		field = ExpeditionState.new(id);field.route_open = true
		var enemy: Dictionary = field.enemies[0]
		enemy["x"] = field.route_x()-30
		field._enemy_route(enemy,field.route_x()+20,1,100,.5)
		expect(enemy["x"] == field.route_x() and enemy["climb_target"] == 1,id+" enemies can use the opened shortcut rather than teleport")
		field.route_open = false
		expect(not ExpeditionState.valid_ladder(id,field.route_x(),false),id+" unopened access is rejected by save geometry")
	# Exercise campaign mouse-route controls and schema validation, including original v1.7 bytes.
	var game := campaign()
	game.end_day();game.start_expedition()
	var world: ExpeditionState = game.expedition
	world.route_open = true;world.player_x = world.route_x();world.floor_level = 1;world.player_y = 400
	var controls: Dictionary = game._route_controls(world.route_x()-30,0,false)
	expect(controls.get("climb") == -1,"mouse routing chooses second access when it shortens the actual cross-floor path")
	controls = game._route_controls(110,0,true)
	expect(controls.get("climb") == -1,"T return prefers the nearby opened landing when horizontal route lengths are equal")
	world.player_x = world.route_x();world.floor_level = 0;world.player_y = 620
	world.route_open = false;world.bag["tools"] = 1;world._clear_route(.5,game.survivors[world.actor_id])
	valid(game,"campaign clearing snapshot")
	var snapshot := SaveSystem.capture(game)
	var bad := snapshot.duplicate(true);bad["expedition"]["route_open"] = true
	expect(not SaveSystem.validate(bad).is_empty(),"completed access cannot retain live clearing")
	bad = snapshot.duplicate(true);bad["expedition"]["route_progress"] = NAN
	expect(not SaveSystem.validate(bad).is_empty(),"nonfinite clearing progress is rejected")
	bad = snapshot.duplicate(true);bad["expedition"]["condition"] = 3
	expect(not SaveSystem.validate(bad).is_empty(),"unknown map variant is rejected")
	var store := SaveSystem.new();store.path = "res://tests/fixtures/v14_stacked_campaign.json"
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	var previous: Dictionary = JSON.parse_string(envelope["data_json"])
	var result := store.read_state()
	expect(result["ok"] and result["migrated"],"authentic v1.7 schema14 file migrates through ordinary loading")
	if result["ok"]:
		var migrated: Dictionary = result["data"]
		expect(migrated["expedition"]["bag"] == previous["expedition"]["bag"] and migrated["stock"] == previous["stock"] and migrated["expedition"]["enemies"] == previous["expedition"]["enemies"],"migration preserves physical quantities and enemy AI")
		expect(not migrated["expedition"]["route_open"] and migrated["expedition"]["route_progress"] == 0,"old worlds start with original access and no invented work")
		expect(SaveSystem.validate(migrated).is_empty(),"all nine migrated regions validate")
	game.free();actor.free()
	print("MAP ENVIRONMENTS RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(.12).timeout
	quit(1 if failures else 0)
