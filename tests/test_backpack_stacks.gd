extends "res://tests/test_campaign.gd"

func _run() -> void:
	var rules := {"raw_food":4,"water":4,"fuel":4,"meals":4,"materials":8,"tools":1,"medicine":2}
	for key in rules:
		var maximum: int = rules[key]
		expect(BackpackStacks.limit(key) == maximum,"declared stack ceiling: "+key)
		expect(BackpackStacks.slots({key:maximum}) == 1,"a full stack takes one slot: "+key)
		expect(BackpackStacks.slots({key:maximum+1}) == 2,"overflow takes another slot: "+key)
		var entries := BackpackStacks.entries({key:maximum+1})
		expect(entries.size() == 2 and entries[0]["count"] == maximum and entries[1]["count"] == 1,"overflow is physically rendered as two stacks: "+key)
		expect(BackpackStacks.room({key:1},key,1) == maximum-1,"a partial stack accepts units even when all slots are occupied: "+key)
	expect(BackpackStacks.slots({"water":4,"fuel":4}) == 2,"different item types never share a slot")
	expect(BackpackStacks.slots({"water":4},false) == 4,"legacy fixture format keeps its declared unit rule")
	var field := ExpeditionState.new()
	field.stacked = true
	field.begin(0,{"raw_food":1},1)
	field.extra_slots = 9
	field.loot_site = 0
	var actor := Survivor.new()
	expect(field.used_capacity() == 10 and field.room_for("raw_food") == 3,"full-slot fixture still has room inside its existing food stack")
	expect(field.take_loot("raw_food",100,actor) == 2 and field.bag["raw_food"] == 3 and field.used_capacity() == 10,"pickup fills the partial stack without inventing an extra slot")
	expect(field.take_loot("water",1,actor) == 0 and field.sites[0]["contents"]["water"] == 1,"full bag refuses a new item type without removing it from the container")
	expect(field.put_loot("raw_food",100) == 2 and field.bag["raw_food"] == 1,"put-back conserves physical units and original container capacity")
	expect(field.put_loot("raw_food",1) == 0,"put-back cannot overfill the original container")
	field.extra_slots = 0
	field.bag["raw_food"] = 0
	field.bag["water"] = 39
	expect(field.used_capacity() == 10 and field.room_for("water") == 1,"39 water occupy ten slots with room for exactly one more")
	expect(field.take_loot("water",100,actor) == 1 and field.used_capacity() == 10 and field.bag["water"] == 40,"maximum stack fill is bounded by both source and capacity")
	field.drop("water")
	expect(field.bag["water"] == 39 and field.used_capacity() == 10,"dropping one unit from a full stack does not falsely free a slot")
	field.bag["water"] = 37
	field.drop("water")
	expect(field.bag["water"] == 36 and field.used_capacity() == 9,"removing the final unit from a stack actually frees its slot")
	actor.free()
	field = ExpeditionState.new(); field.stacked = true
	field.begin(0,{"medicine":3},1)
	actor = Survivor.new()
	actor.weapon_item = {"kind":"pistol","durability":100}
	actor.armor_item = {"kind":"vest","durability":100}
	field.magazine = 2; field.reserve_ammo = 7; field.extra_slots = 4
	var carried := BackpackStacks.carried(field,actor,[])
	expect(carried.size() == 6 and field.used_capacity() == 6,"medicine stacks, real equipment and nine rounds occupy six cells together")
	var ammo: Array = carried.filter(func(item): return item["kind"] == "ammo")
	expect(ammo.size() == 2 and ammo[0]["count"] == 8 and ammo[1]["count"] == 1,"ammunition has its own eight-round stack ceiling")
	field.attack(actor)
	expect(field.reserve_ammo+field.magazine == 8 and field.extra_slots == 3,"firing the ninth round merges ammo occupancy immediately")
	field.attack_cooldown = 0; field.magazine = 1; field.reserve_ammo = 0
	field.attack(actor)
	expect(field.extra_slots == 2 and BackpackStacks.carried(field,actor,[]).all(func(item): return item["kind"] != "ammo"),"the last round frees its visible cell without removing equipped gear")
	actor.health = 30; actor.hunger = 0
	expect(field.use_medicine(actor) and field.bag["medicine"] == 2 and field.used_capacity() == 3,"consuming the lone overflow medicine frees exactly one stack")
	field.medicine_cooldown = 0
	expect(field.use_medicine(actor) and field.bag["medicine"] == 1 and field.used_capacity() == 3,"consuming part of a two-dose stack keeps its cell occupied")
	actor.free()
	var largest := 0
	for id in LocationCatalog.ALL_IDS:
		for site in LocationCatalog.area(id)["sites"]:
			largest = maxi(largest,BackpackStacks.entries(site["items"]).size()+1)
	expect(largest <= 16,"all actual container inventories, including a possible unique part, fit the sixteen-cell source grid")
	var game := campaign()
	game.inventory.deposit({"water":24,"raw_food":1},"declared stacking fixture")
	game.end_day()
	game.cycle.loadout = {"water":17,"raw_food":5}
	expect(game.cycle.plan_error(game).is_empty(),"preparation accepts more units than slots when bounded stacks fit")
	expect(game.start_expedition(),"valid stacked draft departs through the actual campaign transaction")
	field = game.expedition
	actor = game.survivors[field.actor_id]
	expect(field.stacked and field.used_capacity() == 8,"five water stacks, two food stacks and one weapon use eight slots")
	valid(game,"high-unit, low-slot real campaign save")
	var save_path := "/tmp/stack_roundtrip_%d.json" % OS.get_process_id()
	game.save_store.path = save_path
	expect(game.save_store.write_state(game)["ok"],"actual stacked state writes to a checksummed disk save")
	var saved: Dictionary = game.save_store.read_state()
	expect(saved["ok"] and SaveSystem.apply_state(game,saved["data"]).is_empty(),"stacked high-unit state loads from actual disk")
	expect(game.expedition.bag["water"] == 17 and game.expedition.bag["raw_food"] == 5 and game.expedition.used_capacity() == 8,"reload preserves every unit and the same occupied slots")
	var bad: Dictionary = SaveSystem.capture(game)
	bad["expedition"]["bag"]["water"] = 56
	expect(not SaveSystem.validate(bad).is_empty(),"save validation rejects combined over-capacity stacks, including equipment")
	bad = SaveSystem.capture(game); bad["expedition"]["bag"]["water"] = 1.5
	expect(not SaveSystem.validate(bad).is_empty(),"save validation rejects fractional physical units")
	bad = SaveSystem.capture(game); bad["expedition"]["stacked"] = false
	expect(not SaveSystem.validate(bad).is_empty(),"a campaign save cannot secretly switch to a different capacity policy")
	bad = SaveSystem.capture(game); bad["expedition"]["stacked"] = "true"
	expect(not SaveSystem.validate(bad).is_empty(),"stack policy must be an actual boolean")
	field = game.expedition
	field.player_x = 90
	var stock: Dictionary = game.inventory.snapshot()
	game.expedition_retreat(); game.confirm_departure()
	expect(game.inventory.amount("water") == stock["water"]+17 and game.inventory.amount("raw_food") == stock["raw_food"]+5,"normal exit credits all physical units, rather than the number of slots")
	var returned: Dictionary = game.inventory.snapshot()
	game.confirm_departure()
	expect(game.inventory.snapshot() == returned,"repeated exit cannot duplicate stacked cargo")
	valid(game,"stacked return and dawn save")
	game.free()
	DirAccess.remove_absolute(save_path)
	for suffix in [".bak",".tmp"]: DirAccess.remove_absolute(save_path+suffix)
	game = campaign()
	game.end_day()
	game.cycle.loadout = {"water":52}
	expect(not game.cycle.plan_error(game).is_empty(),"draft still checks real shelter inventory, not just slot math")
	var archive := SaveSystem.new()
	archive.path = "res://tests/fixtures/v12_equipped_campaign.json"
	var migrated := archive.read_state()
	expect(migrated["ok"] and migrated["migrated"],"archived schema12 equipment state migrates through the new policy")
	if migrated["ok"]:
		expect(migrated["data"]["expedition"]["stacked"] and migrated["data"]["other_regions"].values().all(func(region): return region["stacked"]),"migration enables stacks on active and all inactive campaign maps")
		var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(archive.path))
		var before: Dictionary = JSON.parse_string(legacy["data_json"])
		expect(before["stock"] == migrated["data"]["stock"] and before["expedition"]["bag"] == migrated["data"]["expedition"]["bag"],"migration does not alter physical stock or carried units")
	archive.path = "res://tests/fixtures/v13_equipped_campaign.json"
	var old_v13 := archive.read_state()
	expect(old_v13["ok"] and old_v13["migrated"],"archived previous-release schema13 saves migrate directly")
	if old_v13["ok"]:
		var original: Dictionary = JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(archive.path))["data_json"])
		expect(original["expedition"]["bag"] == old_v13["data"]["expedition"]["bag"] and original["expedition"]["enemies"] == old_v13["data"]["expedition"]["enemies"],"direct migration preserves carried units and the saved enemy AI")
	game.free()
	print("BACKPACK STACKS RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
