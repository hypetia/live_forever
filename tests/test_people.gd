extends "res://tests/test_expedition_saves.gd"


func recruit_fixture(scene: Node2D, id: String) -> Survivor:
	# Explicit fixture isolates recruitment from long-run resource acquisition.
	scene.simulation_time = maxf(scene.simulation_time, (int(PeopleCatalog.DATA[id]["day"]) - 1) * 720.0)
	scene.upkeep.level = maxi(1, scene.upkeep.level)
	scene.inventory.deposit({"raw_food": 4, "water": 4, "medicine": 2}, "recruitment test fixture")
	expect(scene.people.recruit(scene, id), "eligible new member joins through the real paid recruitment path")
	return scene.survivors.back()


func _run() -> void:
	test_initial_profiles()
	test_growth_is_earned()
	test_search_growth_and_no_empty_farming()
	test_stress_and_recovery()
	test_traits()
	test_mourning_once()
	test_shared_meal()
	test_recruitment_atomicity()
	test_roster_limit_and_permanent_loss()
	test_recruit_jobs_and_save()
	test_dynamic_roster_restore_and_new_game()
	test_routine_authorization()
	test_routine_preserves_work_and_pause()
	test_authorized_base_care_while_away()
	test_food_storage_loss()
	test_upgraded_storage()
	test_invalid_people_atomic()
	test_real_v3_migration()
	test_emotions_never_randomly_kill_or_refuse()
	test_away_profile_controls()
	test_drinking_and_authorization()
	test_field_water_and_dehydration()
	test_push_recovery_persists()
	test_medical_aid()
	var directory := DirAccess.open(test_directory)
	if directory != null:
		for filename in directory.get_files(): DirAccess.remove_absolute(test_directory.path_join(filename))
		DirAccess.remove_absolute(test_directory)
	print("PEOPLE RESULT: %d checks, %d failures; 24 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_initial_profiles() -> void:
	var scene := make_scene()
	expect(scene.survivors.size() == 3 and scene.people.bonds.size() == 3, "new run retains a small distinct original team")
	for index in range(3):
		expect(scene.survivors[index].person.persona == PeopleCatalog.ORIGINALS[index] and not scene.survivors[index].person.routine, "original identity and default-off care permission are explicit")
	expect(scene.center.tabs.get_tab_count() == 8 and scene.center.roster_picker != null, "people handbook is a real additional menu page")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "initial people state validates")
	scene.free()


func test_growth_is_earned() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.facility.work_position()
	scene.assign_task("craft")
	advance(scene, 1)
	scene.cancel_selected()
	expect(actor.person.experience["craft"] == 0 and scene.inventory.amount("materials") == 8, "cancelled production cannot farm experience or lose its refundable cost")
	actor.position = scene.facility.work_position()
	for index in range(3): scene.scheduler.submit(actor, "craft")
	advance(scene, 30)
	expect(actor.person.experience["craft"] > 28 and actor.person.level("craft") == 0 and scene.inventory.amount("tools") == 3, "real paid work earns bounded experience before its first threshold")
	actor.position = scene.facility.work_position()
	scene.assign_task("repair")
	advance(scene, 5)
	expect(actor.person.level("craft") == 1 and scene.inventory.amount("materials") == 1, "finished repair crosses a real skill threshold without inventing materials")
	actor.position = scene.facility.work_position()
	scene.assign_task("repair")
	advance(scene, 1)
	expect(actor.work_elapsed > 1.04, "earned craft level accelerates actual production")
	actor.person.gain("craft", 99999)
	expect(actor.person.level("craft") == 3 and actor.person.experience["craft"] == 180 and actor.person.bonus("craft") == 1.15, "experience and efficiency have a finite ceiling")
	scene.free()


func test_search_growth_and_no_empty_farming() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.2, {"interact": true})
	var actor: Survivor = scene.survivors[0]
	expect(actor.person.experience["scout"] == 6, "only actual removed container quantities award search experience")
	march(scene, 2, {"interact": true})
	expect(actor.person.experience["scout"] == 6, "empty-container interaction cannot farm experience")
	march(scene, 1, {"axis": -1.0})
	scene.expedition.request_retreat()
	expect(actor.person.experience["scout"] == 10 and actor.person.morale > 62, "genuine supplied return contributes growth and relief")
	scene.start_expedition(false, true)
	scene.expedition.request_retreat()
	expect(actor.person.experience["scout"] == 10, "carrying own equipment back is not a successful exploration reward")
	scene.free()


func test_stress_and_recovery() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.person.morale = 20
	actor.person.stress = 85
	expect(is_equal_approx(actor.effort_factor(), 0.81), "emotion has a predictable limited effect on working and movement")
	actor.position = scene.bed.work_position()
	scene.assign_task("sleep")
	advance(scene, 20.2)
	expect(actor.completed_by_task["sleep"] == 1 and actor.person.stress < 84 and actor.person.morale > 20, "real sleep helps emotion and never slows because morale is low")
	expect(actor.health == 100 and actor.person.warned, "emotional distress warns instead of randomly killing the actor")
	scene.free()


func test_traits() -> void:
	var scene := make_scene()
	var chef := recruit_fixture(scene, "he")
	var medic := recruit_fixture(scene, "gu")
	chef.hunger = 30
	medic.fatigue = 30
	var base: Survivor = scene.survivors[2]
	base.hunger = 30
	base.fatigue = 30
	advance(scene, 10)
	expect(chef.hunger > base.hunger and medic.fatigue > base.fatigue, "recruits' hunger and fatigue weaknesses change actual consumption")
	expect(TaskCatalog.duration_for("cook", chef) == 5 and TaskCatalog.duration_for("heal", medic) == 6, "new roles retain real distinct task strengths")
	medic.person.gain("care", 10)
	expect(medic.person.experience["care"] == 12, "patient recruit learns care faster")
	scene.free()


func test_mourning_once() -> void:
	var a := make_scene()
	a.scheduler.mark_dead(a.survivors[2], "test encounter")
	expect(a.people.deaths == ["chen"] and a.survivors[0].person.morale == 42 and a.survivors[1].person.stress == 15, "death causes grief with personality-specific pressure")
	var before := SaveSystem.capture(a)
	a.scheduler.mark_dead(a.survivors[2], "duplicate encounter")
	expect(SaveSystem.capture(a) == before, "repeated death handling cannot apply grief twice")
	var b := make_scene()
	if round_trip(a, b):
		b.scheduler.mark_dead(b.survivors[2])
		expect(b.survivors[0].person.morale == 42 and b.people.deaths == ["chen"], "restoring a casualty does not reapply grief")
	a.free()
	b.free()


func test_shared_meal() -> void:
	var scene := make_scene()
	var before := SaveSystem.capture(scene)
	expect(not scene.people.support(scene, 1) and SaveSystem.capture(scene) == before, "missing meal leaves relationship and emotion unchanged")
	scene.survivors[0].position = scene.stove.work_position()
	scene.assign_task("cook")
	advance(scene, 6.2)
	var morale: float = scene.survivors[0].person.morale
	expect(scene.people.support(scene, 1), "a genuinely cooked meal can fund mutual support")
	expect(scene.inventory.amount("meals") == 1 and scene.people.relationship(0, 1) == 35 and scene.survivors[0].person.morale == morale + 10, "support consumes the meal and changes both people and trust")
	var stock: Dictionary = scene.inventory.snapshot()
	expect(not scene.people.support(scene, 2) and scene.inventory.snapshot() == stock, "changing companions cannot bypass personal cooldown")
	advance(scene, 180)
	expect(scene.people.support(scene, 1) and scene.people.relationship(0, 1) == 45 and scene.inventory.amount("meals") == 0, "support becomes available again only after simulation time and another real meal")
	scene.free()


func test_recruitment_atomicity() -> void:
	var scene := make_scene()
	var before := SaveSystem.capture(scene)
	expect(not scene.people.recruit(scene, "he") and SaveSystem.capture(scene) == before, "unannounced day1 recruit cannot cost or add anything")
	scene.simulation_time = 1440
	scene.upkeep.level = 1
	scene.inventory.try_take({"medicine": 1}, "missing recruit cost fixture")
	before = SaveSystem.capture(scene)
	expect(not scene.people.recruit(scene, "he") and SaveSystem.capture(scene) == before, "partial recruitment funds never debit or append half a member")
	scene.inventory.deposit({"medicine": 1}, "restore recruit fixture")
	expect(scene.people.recruit(scene, "he") and scene.survivors.size() == 4, "full eligible recruitment succeeds")
	expect(scene.inventory.amount("raw_food") == 2 and scene.inventory.amount("water") == 2 and scene.inventory.amount("medicine") == 0, "recruitment pays exact survival supplies")
	before = SaveSystem.capture(scene)
	expect(not scene.people.recruit(scene, "he") and SaveSystem.capture(scene) == before, "a named visitor can only join once")
	scene.free()


func test_roster_limit_and_permanent_loss() -> void:
	var scene := make_scene()
	recruit_fixture(scene, "he")
	recruit_fixture(scene, "gu")
	scene.simulation_time = 6000
	var before := SaveSystem.capture(scene)
	expect(not scene.people.recruit(scene, "tang") and SaveSystem.capture(scene) == before, "five living members is a hard small-team limit")
	scene.scheduler.mark_dead(scene.survivors[1])
	recruit_fixture(scene, "tang")
	expect(scene.survivors.size() == 6 and scene.survivors[1].health == 0 and scene.people.deaths == ["xu"], "replacement recruitment preserves the original casualty and identity history")
	expect(scene.survivors.filter(func(a): return a.health > 0).size() == 5 and scene.cards.size() == 6, "history can include a casualty without becoming a six-person living colony")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "expanded roster and casualty ledger validate together")
	scene.free()


func test_recruit_jobs_and_save() -> void:
	var a := make_scene()
	var chef := recruit_fixture(a, "he")
	a.select_survivor(3)
	chef.position = a.stove.work_position()
	a.assign_task("cook")
	advance(a, 2)
	expect(chef.state == Survivor.TaskState.WORKING and chef.work_duration == 5 and chef.held_cost["fuel"] == 1, "recruit really occupies the shared stove with its own duration and paid recipe")
	var b := make_scene()
	if round_trip(a, b):
		advance(a, 3.2)
		advance(b, 3.2)
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)) and b.survivors[3].completed_by_task["cook"] == 1, "recruited worker's paid progress continues exactly across a real save")
	a.free()
	b.free()


func test_dynamic_roster_restore_and_new_game() -> void:
	var a := make_scene()
	recruit_fixture(a, "he")
	recruit_fixture(a, "gu")
	var b := make_scene()
	if round_trip(a, b):
		expect(b.survivors.size() == 5 and b.scheduler.survivors.size() == 5 and b.cards.size() == 5, "restoration rebuilds actors, scheduler and cards consistently")
		var nonoverlap := true
		for index in range(1, b.cards.size()): nonoverlap = nonoverlap and b.cards[index - 1].get_rect().end.x < b.cards[index].position.x
		expect(nonoverlap, "five-member cards fit without overlapping")
		b.select_survivor(4)
		b.start_new_game()
		expect(b.survivors.size() == 3 and b.cards.size() == 3 and b.people.bonds.size() == 3 and b.selected_id == 0, "new run resets dynamic party state and selection")
		expect(b.get_children().filter(func(n): return n is Survivor).size() == 3, "removed recruits leave no ghost actor nodes")
	a.free()
	b.free()


func test_routine_authorization() -> void:
	var scene := make_scene()
	advance(scene, 20)
	expect(scene.inventory.amount("fuel") == 3 and scene.survivors.all(func(a): return a.orders.is_empty()), "default-off routine spends no goods without authorization")
	var actor: Survivor = scene.survivors[1]
	actor.hunger = 61
	actor.person.routine = true
	advance(scene, 60)
	expect(actor.completed_by_task["cook"] == 1 and actor.completed_by_task["eat"] == 1 and actor.completed_by_task["sleep"] == 1, "authorized routine genuinely cooks, eats and rests")
	expect(scene.inventory.amount("fuel") == 2 and scene.inventory.amount("meals") == 1 and actor.hunger < 20, "routine pays actual recipes and restores actual needs")
	scene.free()


func test_routine_preserves_work_and_pause() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.facility.work_position()
	scene.assign_task("craft")
	actor.person.routine = true
	actor.hunger = 65
	advance(scene, 1)
	expect(actor.orders == ["craft"] and actor.work_elapsed > 0, "standing care never replaces an existing work order")
	scene.paused = true
	var before := SaveSystem.capture(scene)
	advance(scene, 100)
	expect(SaveSystem.capture(scene) == before, "pause freezes routines, growth, mood, storage and all clocks")
	scene.free()


func test_authorized_base_care_while_away() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[1]
	actor.person.routine = true
	actor.hunger = 61
	scene.select_survivor(2)
	scene.start_expedition()
	march(scene, 45)
	expect(actor.completed_by_task["cook"] == 1 and actor.completed_by_task["eat"] == 1, "preauthorized standing care works for a left-behind survivor during real exploration")
	expect(scene.expedition.active and scene.selected_id == 2, "care never steals expedition control")
	scene.free()


func test_food_storage_loss() -> void:
	var scene := make_scene()
	scene.inventory.deposit({"raw_food": 16, "meals": 10}, "explicit over-capacity storage fixture")
	advance(scene, 480.2)
	expect(scene.inventory.amount("raw_food") == 18 and scene.inventory.amount("meals") == 9, "new-day surplus loses only its announced rounded percentages")
	expect(scene.people.spoiled == {"raw_food": 2, "meals": 1} and scene.people.daily.size() == 1, "spoilage and daily stock are accounted once")
	var b := make_scene()
	if round_trip(scene, b):
		advance(b, 1)
		expect(b.inventory.amount("raw_food") == 18 and b.people.spoiled["raw_food"] == 2, "restoring a new-day boundary cannot apply storage loss twice")
	scene.free()
	b.free()


func test_upgraded_storage() -> void:
	var scene := make_scene()
	scene.upkeep.level = 3
	scene.inventory.deposit({"raw_food": 16, "meals": 10}, "upgraded protected-capacity fixture")
	advance(scene, 480.2)
	expect(scene.people.protected_food(scene) == {"raw_food": 24, "meals": 12} and scene.inventory.amount("raw_food") == 20 and scene.inventory.amount("meals") == 10, "bounded shelter upgrades protect a finite larger food stock")
	scene.free()


func test_invalid_people_atomic() -> void:
	var scene := make_scene()
	var before := SaveSystem.capture(scene)
	for variant in range(10):
		var bad := before.duplicate(true)
		match variant:
			0: bad["actors"][0]["person"]["persona"] = "unknown"
			1: bad["actors"][0]["person"]["experience"]["craft"] = 181
			2: bad["actors"][0]["person"]["stress"] = "calm"
			3: bad["actors"][0]["person"]["joined_day"] = 3
			4: bad["actors"][0]["person"]["last_support"] = 100
			5: bad["people"]["bonds"].erase("0:1")
			6: bad["people"]["deaths"] = ["xu"]
			7: bad["people"]["next_routine"] = 3
			8: bad["people"]["spoiled"]["meals"] = -1
			9: bad["actors"].append(bad["actors"][0].duplicate(true))
		expect(not SaveSystem.apply_state(scene, bad).is_empty() and SaveSystem.capture(scene) == before, "invalid person/party snapshot rejects atomically: %d" % variant)
	scene.free()


func test_real_v3_migration() -> void:
	var scene := make_scene()
	var store := slot()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/v3_factory.json")
	write_text(store.path, original)
	var loaded := store.read_state()
	expect(loaded["ok"] and loaded.get("migrated", false), "authentic v0.5 schema3 save migrates")
	if loaded["ok"]:
		expect(SaveSystem.apply_state(scene, loaded["data"]).is_empty() and scene.expedition.location_id == "works" and scene.expedition.climb_target == 1, "migration preserves old destination, cargo and real mid-climb position")
		expect(scene.expedition.bag["materials"] == 3 and scene.survivors.all(func(a): return not a.person.routine), "old loadout and default-off care policy are preserved without free stock")
		expect(store.write_state(scene)["ok"] and FileAccess.get_file_as_string(store.path + ".bak") == original, "schema4 upgrade keeps original valid schema3 bytes as backup")
	scene.free()


func test_emotions_never_randomly_kill_or_refuse() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.person.morale = 0
	actor.person.stress = 100
	actor.position = scene.stove.work_position()
	expect(scene.scheduler.submit(actor, "cook"), "distressed survivor still accepts explicit recovery planning")
	advance(scene, 8)
	expect(actor.health == 100 and actor.completed_by_task["cook"] == 1, "low morale slows production without random death, disappearance or refusal")
	scene.free()


func test_away_profile_controls() -> void:
	var scene := make_scene()
	scene.start_expedition()
	scene.open_center(5)
	expect(scene.center.routine_toggle.disabled and scene.center.recruit_button.disabled and scene.center.support_button.disabled, "field handbook cannot remotely authorize care, recruit or share a meal")
	var before := SaveSystem.capture(scene)
	expect(not scene.people.support(scene, 1) and not scene.people.recruit(scene, "he") and SaveSystem.capture(scene) == before, "model also enforces remote social-action guards")
	scene.center.close()
	scene.free()


func test_drinking_and_authorization() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.person.thirst = 90
	expect(scene.people.drink(scene, 0) and scene.inventory.amount("water") == 3 and actor.person.thirst == 30 and scene.people.drinks == 1, "drinking trades a real water for exactly60 thirst relief")
	actor.person.thirst = 0
	var before := SaveSystem.capture(scene)
	expect(not scene.people.drink(scene, 0) and SaveSystem.capture(scene) == before, "a fully hydrated actor cannot spend water or farm effects")
	actor.person.routine = true
	actor.person.thirst = 61
	actor.position = scene.facility.work_position()
	scene.assign_task("craft")
	advance(scene, 1.2)
	expect(scene.inventory.amount("water") == 2 and actor.person.thirst < 2 and actor.orders == ["craft"], "authorized water use works without interrupting a paid ongoing job")
	scene.free()


func test_field_water_and_dehydration() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.person.thirst = 80
	scene.start_expedition()
	var before: Dictionary = scene.inventory.snapshot()
	expect(not scene.people.drink(scene, 0) and not scene.people.drink(scene, 1) and scene.inventory.snapshot() == before, "field drinking cannot reach remote base water or another survivor")
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.2, {"interact": true})
	expect(scene.people.drink(scene, 0) and scene.expedition.bag["water"] == 0 and actor.person.thirst < 21, "field water must really be found in the backpack and is consumed")
	march(scene, 1, {"axis": -1.0})
	scene.expedition.request_retreat()
	expect(scene.inventory.amount("water") == 4, "drunk cargo cannot also return to base")
	actor.person.thirst = 95
	actor.health = 1
	scene.paused = false
	advance(scene, 20)
	expect(actor.state == Survivor.TaskState.DEAD and scene.people.deaths.has("lin") and not scene.game_over, "unhandled severe dehydration has actual slow permanent consequences")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "dehydration casualty and survivor grief remain a consistent save")
	scene.free()


func test_push_recovery_persists() -> void:
	var a := make_scene()
	a.start_expedition()
	a.expedition.player_x = 800
	var enemy: Dictionary = a.expedition.enemies[0]
	enemy["x"] = 840.0
	enemy["mode"] = "chase"
	enemy["suspicion"] = 100.0
	var fatigue: float = a.survivors[0].fatigue
	a.expedition_attack()
	march(a, 0.3)
	expect(enemy["mode"] == "stunned" and enemy["brace"] > 3 and a.survivors[0].fatigue > fatigue + 4, "barehand push creates finite breathing room and pays real fatigue")
	march(a, 0.85)
	var remaining: float = enemy["timer"]
	a.expedition_attack()
	march(a, 0.25)
	expect(enemy["timer"] < remaining and enemy["brace"] > 2, "another swing cannot renew stun during recovery")
	var b := make_scene()
	if round_trip(a, b):
		expect(is_equal_approx(b.expedition.enemies[0]["brace"], enemy["brace"]), "enemy recovery is preserved across disk save instead of resetting control immunity")
		march(a, 1)
		march(b, 1)
		expect(equivalent(SaveSystem.capture(a), SaveSystem.capture(b)), "combat recovery and fatigue continue identically after restore")
	a.free()
	b.free()


func test_medical_aid() -> void:
	var scene := make_scene()
	var patient: Survivor = scene.survivors[0]
	patient.health = 40
	patient.injury = 60
	patient.infection = 45
	expect(not scene.people.aid(scene, 1), "non-medical role cannot perform a medic's aid")
	scene.select_survivor(1)
	expect(scene.people.aid(scene, 0), "medic can spend a real medicine helping another injured survivor")
	expect(patient.health == 60 and patient.injury == 20 and patient.infection == 10 and scene.inventory.amount("medicine") == 0, "aid changes the actual patient's persistent condition and pays the full medicine")
	expect(scene.survivors[1].person.experience["care"] == 8 and scene.people.relationship(0, 1) == 30, "care work develops the medic and mutual trust")
	scene.inventory.deposit({"medicine": 1}, "aid cooldown fixture")
	var before := SaveSystem.capture(scene)
	expect(not scene.people.aid(scene, 0) and SaveSystem.capture(scene) == before, "medical cooldown cannot be bypassed by repeated commands")
	var b := make_scene()
	if round_trip(scene, b): expect(not b.people.aid(b, 0) and b.survivors[0].health == 60, "aid and both participant cooldowns survive a real disk round trip")
	b.free()
	scene.scheduler.mark_dead(patient)
	before = SaveSystem.capture(scene)
	expect(not scene.people.aid(scene, 0) and SaveSystem.capture(scene) == before, "medical aid never revives a dead member or wastes medicine on them")
	scene.free()
