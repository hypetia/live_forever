extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	var actor: Survivor = game.survivors[2]
	expect(game.regions.size() == 9, "campaign creates nine independent persistent maps")
	expect(actor.weapon().get("damage") == 18, "starting scout holds a real knife")
	valid(game, "new expansion")
	game.select_survivor(0)
	var before: Dictionary = game.inventory.snapshot()
	expect(game.expansion.start_job(game, "bat"), "workshop reserves exact recipe")
	expect(game.inventory.amount("materials") == before["materials"] - 3 and game.expansion.gear.size() == 1, "materials are paid before walking, gear does not appear early")
	expect(not game.scheduler.submit(game.survivors[0], "repair"), "background base jobs cannot steal a custom workshop worker")
	valid(game, "walking workshop job")
	advance(game, 5)
	valid(game, "active workshop job")
	game.cancel_selected()
	expect(game.inventory.amount("materials") == before["materials"] and game.expansion.jobs.is_empty(), "cancel refunds once")
	game.cancel_selected()
	expect(game.inventory.snapshot() == before, "repeated cancel never duplicates materials")
	expect(game.expansion.start_job(game, "bat"), "restarted workshop job")
	advance(game, 40)
	expect(game.expansion.jobs.is_empty() and game.expansion.gear.size() == 2, "gear appears only after physical arrival and work")
	expect(game.expansion.equip(game, 2, 2), "assign crafted bat to scout")
	expect(actor.weapon().get("damage") == 26 and game.expansion.gear[0]["owner"] == "", "one weapon slot releases previous knife")
	valid(game, "equipped gear")
	game.interface.toggle_workshop()
	expect(game.interface.workshop_open and game.paused, "workshop UI opens and explicitly pauses")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	expect(not game.interface.workshop_open and not game.paused, "closing workshop restores clock")
	night(game)
	game.cycle.loadout = {"water": 1, "raw_food": 1}
	expect(game.start_expedition(), "depart with food and water")
	valid(game, "ordinary resource loadout save regression")
	var field: ExpeditionState = game.expedition
	expect(field.used_capacity() == 3, "equipped weapon consumes one real backpack slot")
	var enemy: Dictionary = field.enemies[0]
	field.player_x = enemy["x"] - 80
	field.facing = 1
	var durability: int = actor.weapon_item["durability"]
	expect(field.attack(actor), "bat attack starts a windup")
	expect(enemy["hp"] == 40, "windup does not deal immediate hidden damage")
	field._resolve_attack(actor)
	field.attack_windup = 0
	expect(enemy["hp"] == 4 and actor.weapon_item["durability"] == durability - 3, "bat damages progressively and wears only on hit")
	field.attack_cooldown = 0
	field.attack(actor)
	field._resolve_attack(actor)
	field.attack_windup = 0
	expect(enemy["hp"] == 0 and enemy["mode"] == "dead", "second actual hit kills zombie")
	valid(game, "partial durability and zombie death")
	field.player_x = 110
	game.expedition_retreat()
	expect(actor.weapon_item["durability"] == durability - 6, "return never repairs gear for free")
	game.begin_day()
	game.inventory.deposit({"materials": 20, "tools": 4, "fuel": 5}, "test fixture for crafting")
	game.select_survivor(2)
	expect(game.expansion.start_job(game, "pistol"), "gun can be crafted")
	advance(game, 65)
	expect(game.expansion.equip(game, 3, 2), "crafted firearm equips")
	expect(game.expansion.start_job(game, "ammo"), "ammo costs materials and fuel")
	advance(game, 60)
	expect(game.expansion.ammo == 8, "ammo recipe grants exactly eight rounds")
	night(game)
	game.cycle.roles.assign(["guard", "bed", "scavenge"])
	game.expansion.ammo_loadout = 8
	expect(game.start_expedition(), "depart with reserved rounds")
	field = game.expedition
	expect(field.magazine == 6 and field.reserve_ammo == 2 and game.expansion.ammo == 0, "magazine and reserve conserve paid rounds")
	valid(game, "gun expedition")
	field.player_x = 110
	field.facing = -1
	field.attack(actor)
	field._resolve_attack(actor)
	field.attack_windup = 0
	expect(field.magazine == 5 and actor.weapon_item["durability"] == 99, "missed shot still spends ammo and durability")
	expect(field.reload(actor), "reload starts only with available reserve")
	valid(game, "reload mid action")
	field.tick(1.4, actor, {})
	expect(field.magazine == 6 and field.reserve_ammo == 1, "reload transfers only needed rounds")
	var boundary := field.extra_slots
	field.reserve_ammo = 0
	field.magazine = 1
	game.expansion.refresh_slots(field, actor)
	field.attack_cooldown = 0
	field.attack(actor)
	expect(field.extra_slots == game.expansion.equipped_slots(actor), "last shot immediately frees ammo weight before the next simulation tick")
	valid(game, "save immediately after final shot")
	# Restore the seven unused rounds for the separate conservation assertion.
	field.attack_windup = 0
	field.magazine = 6
	field.reserve_ammo = 1
	field.extra_slots = boundary
	actor.weapon_item["durability"] = 99
	game.expedition_retreat()
	expect(game.expansion.ammo == 7 and field.extra_slots == 0, "unused rounds return once and carried weight clears")
	valid(game, "gun return")
	game.begin_day()
	actor.illness = 70
	actor.cold_exposure = 0
	var hp := actor.health
	game.expansion.climate(actor, 200, -12)
	expect(actor.cold_exposure > 0 and actor.illness > 70, "unprotected cold causes exposure then illness")
	game.expansion.grant("coat", "chen")
	game.expansion.sync(game)
	var cold := actor.cold_exposure
	actor.hunger = 40
	game.expansion.climate(actor, 300, 8, true)
	expect(actor.cold_exposure < cold and actor.illness < 75, "warm rest reduces exposure and sickness")
	expect(actor.warmth() == 16, "coat warmth changes effective temperature")
	actor.illness = 60
	actor.health = 100
	actor.injury = 0
	actor.infection = 0
	actor.hunger = 40
	game.select_survivor(2)
	game.inventory.deposit({"medicine": 1}, "illness treatment fixture")
	game.assign_task("heal")
	advance(game, 65)
	expect(actor.illness < 30, "medicine treats illness even at full health")
	expect(hp > 0, "test actor alive before cold")
	valid(game, "illness save")
	var snapshot := SaveSystem.capture(game)
	var restored := campaign()
	expect(SaveSystem.apply_state(restored, snapshot).is_empty(), "equipment and illness snapshot restores")
	expect(restored.survivors[2].weapon_item["id"] == actor.weapon_item["id"] and restored.survivors[2].illness == actor.illness, "restored live gear references use canonical durability")
	for mutation in ["negative_ammo", "duplicate_owner", "bad_durability", "bad_cold", "wrong_slots", "bad_job"]:
		var bad := snapshot.duplicate(true)
		match mutation:
			"negative_ammo": bad["expansion"]["ammo"] = -1
			"duplicate_owner": bad["expansion"]["gear"][0]["owner"] = "chen"
			"bad_durability": bad["expansion"]["gear"][0]["durability"] = 999
			"bad_cold": bad["actors"][2]["cold_exposure"] = -1
			"wrong_slots": bad["expedition"]["extra_slots"] = 1
			"bad_job": bad["expansion"]["jobs"].append({})
		expect(not SaveSystem.validate(bad).is_empty(), "corrupt expansion rejected before mutation: " + mutation)
	restored.expansion.gear[0]["durability"] = 1
	restored.select_survivor(0)
	restored.survivors[0].hunger = 40
	restored.survivors[0].fatigue = 10
	expect(restored.expansion.start_job(restored, "repair", 1), "restored gear can reserve physical repair")
	advance(restored, 80)
	expect(restored.expansion.gear[0]["durability"] == 60, "restored repair updates canonical durability and caps at maximum")
	valid(restored, "repaired restored equipment")
	restored.free()
	game.free()

	game = campaign()
	game.inventory.deposit({"materials": 20, "tools": 2, "fuel": 5}, "heater construction fixture")
	expect(game.place_build("heater", 4), "heater uses a real construction slot")
	advance(game, 70)
	expect(game.cycle.has_build("heater"), "heater only operates after construction")
	expect(game.expansion.ignite(game), "explicit ignition pays fuel")
	var fuel: int = game.inventory.amount("fuel")
	expect(not game.expansion.ignite(game) and game.inventory.amount("fuel") == fuel, "cannot stack burning fuel by repeated clicks")
	game.expansion.use_night_heat = true
	night(game)
	game.cycle.roles.assign(["guard", "bed", "floor"])
	expect(game.start_expedition(), "all home night reserves heat")
	expect(game.cycle.phase == "dawn" and game.expansion.heater_remaining >= 0, "heater settles without a trip")
	valid(game, "heated morning")
	game.free()

	game = campaign()
	game.end_day()
	game.choose_destination("works")
	game.start_expedition()
	field = game.expedition
	# Unit fixture isolates cargo settlement; full traversal is checked separately.
	field.player_x = 1380
	field.floor_level = 1
	field.player_y = 400
	field._search(8, game.survivors[2])
	expect(game.expansion.take_part(game), "part can be selected from the actual opened cache")
	expect(game.expansion.parts.is_empty() and game.expansion.carried == ["relay"], "part is not credited to shelter remotely")
	valid(game, "carried part")
	field.player_x = 110
	field.floor_level = 0
	field.player_y = 620
	game.expedition_retreat()
	expect(game.expansion.parts == ["relay"] and game.expansion.collected == ["relay"], "physical exit commits unique part")
	game.begin_day()
	game.inventory.deposit({"materials": 10, "tools": 2}, "campaign project fixture")
	expect(game.expansion.start_job(game, "radio"), "project requires real returned part")
	advance(game, 60)
	expect(game.expansion.stage == 1 and not game.expansion.parts.has("relay"), "completed radio consumes unique relay")
	expect(game.expansion.unlocked(game, "market") and not game.expansion.unlocked(game, "evac"), "campaign gates routes rather than menu rewards")
	expect(not game.expansion.start_job(game, "radio"), "completed project cannot repeat rewards")
	valid(game, "radio progression")
	game.free()
	game = campaign()
	game.survivors[2].illness = 60
	game.select_survivor(1)
	game.center._refresh_people()
	for index in range(game.center.support_picker.item_count):
		if game.center.support_picker.get_item_metadata(index) == 2: game.center.support_picker.select(index)
	game.center._refresh_support()
	expect(not game.center.aid_button.disabled, "medic aid UI enables treatment for illness at full health")
	expect(game.people.aid(game, 2) and game.survivors[2].illness == 25, "named medic aid cures illness without inventing an injury")
	game.free()
	# Explicit late-campaign fixtures verify terminal accounting separately from
	# the no-injection journey pilot. They are not evidence of natural balance.
	game = campaign()
	game.simulation_time = 19380 # Day 28, 06:00.
	game.expansion.stage = 4
	game.expansion.warm_nights = 2
	game.expansion.collected.assign(["relay", "filter_core", "power_cell", "beacon_core", "route"])
	game.expansion.parts.assign(["route"])
	game.cycle.night_day = 27
	game.cycle.night_start = 19080
	game.cycle.night_end = 19380
	game.cycle.roles.assign(["guard", "bed", "floor"])
	game.inventory.deposit({"meals": 5, "water": 8, "fuel": 5}, "late-campaign fixture")
	game._settle_night([])
	expect(game.expansion.outcome == "victory" and game.expansion.stage == 5, "actual supplies and returned route produce one victory")
	valid(game, "victory snapshot")
	var final_stock: Dictionary = game.inventory.snapshot()
	game._settle_night([])
	expect(game.inventory.snapshot() == final_stock, "victory cost cannot be charged twice")
	game.begin_day()
	expect(game.cycle.phase == "dawn", "campaign result waits for explicit endless choice")
	game.expansion.endless = true
	game.begin_day()
	expect(game.cycle.phase == "day", "endless choice resumes existing survivors")
	valid(game, "endless survival after victory")
	game.free()
	game = campaign()
	game.simulation_time = 25140 # Day 36, 06:00.
	game.cycle.night_day = 35
	game.cycle.night_start = 24840
	game.cycle.night_end = 25140
	game.cycle.roles.assign(["guard", "bed", "floor"])
	game._settle_night([])
	expect(game.expansion.outcome == "missed" and not game.game_over, "missed deadline leaves survivors alive and offers endless play")
	valid(game, "missed evacuation")
	game.free()
	game = campaign()
	game.expansion.grant("vest", "chen")
	game.expansion.sync(game)
	game.end_day()
	game.start_expedition()
	actor = game.survivors[game.expedition.actor_id]
	field = game.expedition
	var attacker: Dictionary = field.enemies[0]
	attacker["x"] = field.player_x + 20
	attacker["mode"] = "windup"
	attacker["timer"] = 0.01
	var before_hp := actor.health
	field._tick_enemy(attacker, actor, 0.02)
	expect(is_equal_approx(before_hp - actor.health, 7) and actor.armor_item["durability"] == 92, "armor halves actual bite damage and wears on impact")
	actor.health = 0
	field._finish(false)
	expect(game.expansion.gear.is_empty(), "death loses equipped weapon and armor exactly once")
	valid(game, "permanent field equipment loss")
	game.free()
	for id in LocationCatalog.ALL_IDS:
		var map := ExpeditionState.new(id)
		expect(ExpeditionState.validate_snapshot(map.snapshot(), [], id).is_empty(), "valid original map geometry and zombies: " + id)
	var store := SaveSystem.new()
	store.path = "res://tests/fixtures/v7_campaign_active.json"
	var legacy := store.read_state()
	expect(legacy["ok"], "genuine previous-version active save migrates")
	if legacy["ok"]:
		game = campaign()
		expect(SaveSystem.apply_state(game, legacy["data"]).is_empty(), "old active trip restores without wiping cargo")
		expect(game.expedition.bag["raw_food"] == 1 and game.regions.size() == 9 and game.expansion.gear.is_empty(), "old contents retained, new gear not granted on reload")
		valid(game, "migrated active campaign")
		game.free()
	print("EXPANSION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
