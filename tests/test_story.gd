extends "res://tests/test_people.gd"


func at_day(scene: Node2D, day: int) -> void:
	# Explicit calendar fixture; positive endurance cases never jump time.
	scene.simulation_time = (day - 1) * 720.0
	scene.story.tick(scene)


func radio(scene: Node2D) -> void:
	scene.assign_task("repair")
	advance(scene, 20)
	at_day(scene, 2)


func _run() -> void:
	test_actual_guide()
	test_supply_guide()
	test_story_cost_and_once()
	test_free_choice()
	test_insufficient_cost()
	test_postpone_and_pause()
	test_away_choice_guard()
	test_loss_pending()
	test_all_personal_chapters()
	test_conflict_and_mourning()
	test_story_roundtrip_and_invalid()
	test_real_v4_fixture()
	test_reset_story()
	print("STORY RESULT: %d checks, %d failures; 13 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_actual_guide() -> void:
	var scene := make_scene()
	expect(scene.story.guide.is_empty() and scene.story.guide_index() == 0, "guide starts with an actual next action")
	scene.center.open(5)
	expect(scene.story.guide.has("people") and scene.story.guide_index() == 1, "opening real people page completes only the profile objective")
	scene.center.close()
	scene.assign_task("cook")
	scene.assign_task("eat")
	advance(scene, 2)
	expect(not scene.story.guide.has("eat"), "queued or moving meal cannot complete eating objective")
	advance(scene, 35)
	expect(scene.story.guide.has("eat") and not scene.story.guide.has("drink"), "actual meal completion records food separately from drinking")
	var water: int = scene.inventory.amount("water")
	expect(scene.people.drink(scene, 0) and scene.story.guide.has("drink") and scene.inventory.amount("water") == water - 1, "real paid water completes drinking objective")
	scene.assign_task("sleep")
	advance(scene, 40)
	expect(scene.story.guide.has("sleep"), "only a completed sleep objective checks the rest step")
	scene.assign_task("repair")
	advance(scene, 25)
	expect(scene.story.guide.has("maintain"), "completed paid structural repair checks maintenance")
	var before: Dictionary = scene.story.snapshot()
	scene.paused = true
	advance(scene, 20)
	expect(scene.story.snapshot() == before, "pause freezes all story clocks and progression")
	scene.free()


func test_supply_guide() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	scene.expedition.request_retreat()
	expect(not scene.story.guide.has("supplies"), "own equipment round trip does not claim supply objective")
	scene.start_expedition(false, true)
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.3, {"interact": true})
	expect(not scene.story.guide.has("supplies"), "cargo in field is not yet a successful return")
	march(scene, 1.1, {"axis": -1.0})
	scene.expedition_retreat()
	expect(scene.story.guide.has("supplies") and scene.inventory.amount("raw_food") == 6, "actual physical net supply return completes guidance")
	scene.free()


func test_story_cost_and_once() -> void:
	var scene := make_scene()
	radio(scene)
	expect(scene.story.pending.get("id") == "lin_radio" and not scene.paused, "earned second-day workshop chapter appears without stealing pause")
	var material: int = scene.inventory.amount("materials")
	var trust: int = scene.people.relationship(0, 1)
	expect(scene.story.resolve(scene, true), "paid chapter resolves through normal inventory transaction")
	expect(scene.inventory.amount("materials") == material - 2 and scene.people.relationship(0, 1) == trust + 6, "complete visible resource cost and relationship effect apply once")
	var before: Dictionary = SaveSystem.capture(scene)
	expect(not scene.story.resolve(scene, true) and equivalent(before, SaveSystem.capture(scene)), "repeat choice cannot debit or reward twice")
	at_day(scene, 6)
	expect(scene.story.pending.get("id") != "lin_radio" and scene.story.history.size() == 1, "finished authored chapter never returns on later days")
	scene.free()


func test_free_choice() -> void:
	var scene := make_scene()
	radio(scene)
	var stock: Dictionary = scene.inventory.snapshot()
	var hunger: float = scene.survivors[0].hunger
	expect(scene.story.resolve(scene, false), "conserving supplies is a complete valid narrative branch")
	expect(scene.inventory.snapshot() == stock and scene.survivors[0].hunger == hunger, "free conversation does not invent food or satisfy physical hunger")
	expect(scene.story.history[0]["outcome"] == "b" and scene.people.relationship(0, 1) == 27, "free branch is remembered with its small explicit trust effect")
	scene.free()


func test_insufficient_cost() -> void:
	var scene := make_scene()
	radio(scene)
	scene.inventory.try_take({"materials": scene.inventory.amount("materials")}, "isolated shortage fixture")
	var before: Dictionary = SaveSystem.capture(scene)
	expect(not scene.story.resolve(scene, true) and equivalent(before, SaveSystem.capture(scene)), "unaffordable choice preserves pending story, inventory and emotions atomically")
	expect(scene.story.choice_error(scene, true).contains("缺") and scene.story.resolve(scene, false), "shortage gives an actionable reason and always leaves a free choice")
	scene.free()


func test_postpone_and_pause() -> void:
	var scene := make_scene()
	radio(scene)
	var pending: Dictionary = scene.story.pending.duplicate()
	at_day(scene, 20)
	expect(scene.story.pending == pending and scene.story.history.is_empty(), "postponing has no expiry, automatic cost or forced outcome")
	scene.center.open(6)
	expect(scene.center.story_text.text.contains("收音机") and scene.center.story_paid.text.contains("材料"), "real UI exposes authored text and complete cost before decision")
	scene.story.guide_hidden = true
	expect(scene.story.hint(scene).contains("同伴"), "optional tutorial hiding preserves pending companion notification")
	scene.center.close()
	scene.free()


func test_away_choice_guard() -> void:
	var scene := make_scene()
	radio(scene)
	scene.start_expedition()
	var before: Dictionary = SaveSystem.capture(scene)
	expect(not scene.story.resolve(scene, false) and equivalent(before, SaveSystem.capture(scene)), "active expedition cannot remotely resolve even a free conversation")
	expect(scene.story.choice_error(scene, false).contains("基地"), "travel guard tells player to return")
	scene.free()


func test_loss_pending() -> void:
	var scene := make_scene()
	radio(scene)
	var material: int = scene.inventory.amount("materials")
	scene.scheduler.mark_dead(scene.survivors[0])
	expect(not scene.story.resolve(scene, true), "deceased participant cannot speak or receive benefits")
	scene.story.next_poll = scene.simulation_time
	scene.story.tick(scene)
	expect(scene.story.pending.is_empty() and scene.story.history[0]["outcome"] == "lost" and scene.inventory.amount("materials") == material, "unfinished chapter records loss without spending supplies")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "loss resolution remains a fully valid world save")
	scene.free()


func test_all_personal_chapters() -> void:
	for persona in PeopleCatalog.DATA:
		var scene := make_scene()
		if PeopleCatalog.CANDIDATES.has(persona): recruit_fixture(scene, persona)
		var actor: Survivor = scene.survivors.filter(func(a): return a.person.persona == persona)[0]
		actor.completed_by_task["craft"] = 1 # Chapter-eligibility fixture, not a gameplay reward.
		scene.upkeep.returns["street"] = 1
		var id: String = StoryCatalog.IDS[PeopleCatalog.DATA.keys().find(persona)]
		var day := maxi(StoryCatalog.DATA[id]["day"], actor.person.joined_day + 1)
		var pair: Array = scene.story._eligible(scene, id, day)
		expect(not pair.is_empty() and scene.survivors[pair[0]].person.persona == persona, "personal chapter belongs to actual recruited identity " + persona)
		expect(scene.story._eligible(scene, id, 1).is_empty(), "personal chapter is unavailable before its announced day " + persona)
		scene.free()


func test_conflict_and_mourning() -> void:
	var scene := make_scene()
	scene.people.bonds["0:1"] = 15
	scene.survivors[0].person.stress = 40
	expect(scene.story._eligible(scene, "friction", 4) == [0, 1], "low trust with actual pressure triggers the pair's conflict")
	scene.people.bonds["0:1"] = 60
	expect(scene.story._eligible(scene, "friction", 4).is_empty(), "trusted healthy relationships do not randomly manufacture conflict")
	expect(scene.story._eligible(scene, "remembrance", 4).is_empty(), "mourning chapter requires a real loss record")
	scene.scheduler.mark_dead(scene.survivors[2])
	expect(scene.story._eligible(scene, "remembrance", 4) == [0, 1], "surviving pair can remember a permanently lost companion")
	scene.free()


func test_story_roundtrip_and_invalid() -> void:
	var scene := make_scene()
	var copy := make_scene()
	radio(scene)
	scene.story.note("people")
	scene.story.guide_hidden = true
	expect(round_trip(scene, copy), "pending story and guide restore through actual checksummed disk save")
	expect(copy.story.pending == scene.story.pending and copy.story.guide_hidden, "participants, decision and tutorial preference survive restore")
	var stock: Dictionary = copy.inventory.snapshot()
	expect(copy.story.resolve(copy, true) and copy.inventory.amount("materials") == stock["materials"] - 2, "restored pending story pays once on actual resolution")
	var before: Dictionary = SaveSystem.capture(copy)
	for mutation in ["unknown", "participant", "identity", "duplicate", "future", "guide"]:
		var bad: Dictionary = before.duplicate(true)
		match mutation:
			"unknown": bad["story"]["history"][0]["id"] = "res://evil"
			"participant": bad["story"]["history"][0]["target"] = 99
			"identity": bad["story"]["history"][0]["actor"] = 2
			"duplicate": bad["story"]["history"].append(bad["story"]["history"][0].duplicate())
			"future": bad["story"]["history"][0]["day"] = 999
			"guide": bad["story"]["guide"] = ["people", "people"]
		expect(not SaveSystem.apply_state(copy, bad).is_empty() and equivalent(before, SaveSystem.capture(copy)), "bad story rejected before any state mutation: " + mutation)
	scene.free()
	copy.free()


func test_real_v4_fixture() -> void:
	var store := slot()
	var original := FileAccess.get_file_as_string("res://tests/fixtures/v4_people.json")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	var loaded := store.read_state()
	expect(loaded["ok"] and loaded["migrated"], "archived v0.6 schema4 paid-recruit traveler migrates to schema5")
	if not loaded["ok"]: return
	var scene := make_scene()
	expect(SaveSystem.apply_state(scene, loaded["data"]).is_empty() and scene.survivors.size() == 4 and scene.expedition.actor_id == 3, "migration preserves four actual identities and ongoing fourth-person exploration")
	expect(scene.story.pending.is_empty() and scene.story.history.is_empty() and not scene.story.guide.has("people"), "migration invents no old narrative choices or profile visits")
	expect(scene.story.guide.has("eat") and scene.story.guide.has("supplies") and scene.story.guide.has("drink"), "migration seeds guidance only from recorded real activity")
	expect(store.write_state(scene)["ok"] and FileAccess.get_file_as_string(store.path + ".bak") == original, "new write retains original schema4 file byte for byte as backup")
	scene.free()


func test_reset_story() -> void:
	var scene := make_scene()
	radio(scene)
	scene.story.resolve(scene, false)
	scene.story.note("people")
	scene.story.guide_hidden = true
	scene.start_new_game()
	expect(scene.story.history.is_empty() and scene.story.pending.is_empty() and scene.story.guide.is_empty() and not scene.story.guide_hidden, "new run resets story, decisions and guidance alongside roster")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "reset chapter clocks and participants validate")
	scene.free()
