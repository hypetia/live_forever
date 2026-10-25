extends "res://tests/test_shelter.gd"


func march(scene: Node2D, seconds: float, controls: Dictionary = {}) -> void:
	scene.expedition_controls_override = controls
	advance(scene, seconds)
	scene.expedition_controls_override = null


func encounter(scene: Node2D, distance: float = 35) -> Dictionary:
	# Controlled enemy fixture isolates telegraphs from unrelated patrols.
	var state: ExpeditionState = scene.expedition
	state.player_x = 800
	state.player_y = 620
	state.floor_level = 0
	state.facing = 1
	var enemy: Dictionary = state.enemies[0]
	enemy["x"] = 800 + distance
	enemy["mode"] = "chase"
	enemy["suspicion"] = 100.0
	enemy["direction"] = -1.0
	enemy["cooldown"] = 0.0
	return enemy


func _run() -> void:
	test_real_round_trip()
	test_departure_is_atomic()
	test_base_keeps_working()
	test_search_requires_input()
	test_capacity_and_leftovers()
	test_climbing()
	test_sneaking_and_cover()
	test_hearing_noise()
	test_bite_warning_and_escape()
	test_bite_consequences()
	test_tools_and_unarmed_push()
	test_locked_container()
	test_pause_and_controls()
	test_death_loses_bag()
	test_treatment()
	test_persistent_world_and_refresh()
	test_scout_advantage()
	print("EXPEDITION RESULT: %d checks, %d failures; 17 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_real_round_trip() -> void:
	var scene := make_scene()
	var original: Dictionary = scene.inventory.snapshot()
	expect(scene.start_expedition(), "living survivor can depart without mandatory equipment")
	expect(scene.survivors[0].state == Survivor.TaskState.AWAY and scene.expedition.active, "departure reserves one survivor for the expedition")
	march(scene, 1, {"axis": 1.0})
	expect(absf(scene.expedition.player_x - 300) < 0.1, "direct movement reaches first real container")
	expect(scene.inventory.snapshot() == original, "walking never grants loot")
	march(scene, 2.1, {"interact": true})
	expect(scene.expedition.bag["raw_food"] == 2 and scene.expedition.bag["water"] == 1, "held interaction actually searches a container")
	expect(scene.expedition.sites[0]["contents"]["raw_food"] == 0 and scene.inventory.snapshot() == original, "loot leaves world container but does not reach base prematurely")
	var point: float = scene.expedition.player_x
	expect(not scene.expedition.request_retreat() and scene.expedition.player_x == point, "retreat cannot teleport from a container")
	march(scene, 1, {"axis": -1.0})
	expect(scene.expedition.request_retreat(), "walking back to entry permits retreat")
	expect(not scene.expedition.active and scene.paused and scene.survivors[0].state == Survivor.TaskState.IDLE, "return restores base control and pauses for review")
	expect(scene.inventory.amount("raw_food") == 6 and scene.inventory.amount("water") == 5, "cargo is deposited exactly once at return")
	expect(not scene.expedition.request_retreat() and scene.inventory.amount("raw_food") == 6, "repeated retreat cannot duplicate cargo")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "returned world is a consistent save state")
	scene.free()
	print("PASS expedition: genuine movement-search-retreat loop")


func test_departure_is_atomic() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.stove.work_position()
	scene.assign_task("cook")
	advance(scene, 1)
	var stock: Dictionary = scene.inventory.snapshot()
	expect(not scene.start_expedition(true, false), "missing loadout is rejected")
	expect(scene.inventory.snapshot() == stock and actor.state == Survivor.TaskState.WORKING and scene.stove.occupant_id == 0, "failed departure preserves current paid work and stock")
	scene.inventory.deposit({"tools": 1}, "equipment fixture")
	expect(scene.start_expedition(true, true), "available optional equipment can be carried")
	expect(actor.orders.is_empty() and actor.held_cost.is_empty() and scene.stove.occupant_id == -1, "successful departure cancels and releases the selected worker")
	expect(scene.inventory.amount("fuel") == 3 and scene.expedition.bag["tools"] == 1 and scene.expedition.bag["medicine"] == 1, "cancelled cooking refunds while real loadout is transferred to bag")
	expect(not scene.start_expedition() and not scene.scheduler.submit(actor, "sleep"), "cannot dispatch a second traveler or assign base work to away survivor")
	scene.expedition.request_retreat()
	expect(scene.inventory.amount("tools") == 1 and scene.inventory.amount("medicine") == 1, "unused equipment returns rather than being silently consumed")
	scene.free()
	print("PASS expedition: departure atomicity and loadout")


func test_base_keeps_working() -> void:
	var scene := make_scene()
	scene.scheduler.submit(scene.survivors[1], "cook")
	scene.scheduler.submit(scene.survivors[2], "craft")
	scene.speed = 3
	scene.start_expedition()
	scene.select_survivor(1)
	expect(scene.selected_id == 0 and scene.speed == 1, "traveler stays selected and expedition forces normal speed")
	march(scene, 12)
	expect(scene.survivors[1].completed_by_task["cook"] == 1 and scene.survivors[2].completed_by_task["craft"] == 1, "remaining survivors perform independent base jobs during exploration")
	expect(absf(scene.simulation_time - 12) < 0.001 and scene.inventory.amount("meals") == 2 and scene.inventory.amount("tools") == 1, "base resources and clock share expedition time")
	scene.expedition.request_retreat()
	expect(scene.speed == 3 and scene.paused, "return restores previous base speed but remains paused")
	scene.free()
	print("PASS expedition: concurrent base simulation")


func test_search_requires_input() -> void:
	var scene := make_scene()
	scene.start_expedition()
	march(scene, 1, {"axis": 1.0})
	march(scene, 3)
	expect(scene.expedition.used_capacity() == 0, "standing by loot never auto-collects it")
	march(scene, 1, {"interact": true})
	expect(scene.expedition.search_progress > 0.9 and scene.expedition.used_capacity() == 0, "partial search has real progress without premature loot")
	var progress: float = scene.expedition.search_progress
	march(scene, 1)
	expect(scene.expedition.search_progress == progress, "releasing search pauses its progress")
	march(scene, 1.2, {"interact": true})
	expect(scene.expedition.used_capacity() == 3 and scene.expedition.search_index == -1, "resumed interaction completes the same search once")
	scene.free()
	print("PASS expedition: input-driven interruptible search")


func test_capacity_and_leftovers() -> void:
	var scene := make_scene()
	scene.start_expedition()
	var state: ExpeditionState = scene.expedition
	state.player_x = 300
	state.bag["raw_food"] = 9 # Explicit capacity fixture, not base inventory.
	march(scene, 2.1, {"interact": true})
	expect(state.used_capacity() == 10 and state.sites[0]["contents"]["raw_food"] == 1 and state.sites[0]["contents"]["water"] == 1, "partial pickup leaves uncarried quantities in the world")
	var contents: Dictionary = state.sites[0]["contents"].duplicate()
	march(scene, 3, {"interact": true})
	expect(state.sites[0]["contents"] == contents and state.used_capacity() == 10, "full bag cannot delete or overdraw container items")
	expect(state.drop("raw_food"), "explicit discard frees one slot")
	march(scene, 2.1, {"interact": true})
	expect(state.used_capacity() == 10 and state.sites[0]["contents"]["raw_food"] == 0 and state.sites[0]["contents"]["water"] == 1, "freed space can collect the remaining exact quantity")
	expect(not state.drop("unknown") and not state.drop("medicine"), "invalid or empty discard cannot create negative quantities")
	scene.free()
	print("PASS expedition: bounded bag and conserved leftovers")


func test_climbing() -> void:
	var scene := make_scene()
	scene.start_expedition()
	var state: ExpeditionState = scene.expedition
	state.player_x = ExpeditionState.LADDER_X
	march(scene, 1, {"climb": 1})
	expect(state.climb_target == 1 and state.player_y > 400 and state.player_y < 620, "ladder climb is real continuous motion")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "mid-climb position can be saved consistently")
	march(scene, 1.2, {"climb": 1})
	expect(state.floor_level == 1 and state.player_y == 400 and state.climb_target == -1, "climbing reaches upper walkable floor")
	march(scene, 5, {"axis": -1.0})
	expect(state.player_x == 1250, "upper level bounds prevent walking into empty space")
	march(scene, 1.25, {"axis": 1.0})
	march(scene, 2.2, {"climb": -1})
	expect(state.floor_level == 0 and state.player_y == 620, "player can climb back down to retreat route")
	scene.free()
	print("PASS expedition: connected two-floor exploration")


func test_sneaking_and_cover() -> void:
	var a := make_scene()
	var b := make_scene()
	for scene in [a, b]:
		scene.start_expedition()
		scene.expedition.player_x = 475
		scene.expedition.enemies[0]["x"] = 750.0
		scene.expedition.enemies[0]["direction"] = -1.0
	march(a, 0.5, {"axis": 1.0, "sneak": true})
	march(b, 0.5, {"axis": 1.0})
	expect(a.expedition.in_cover() and a.expedition.noise < b.expedition.noise, "crouched cover reduces visible exposure and noise")
	expect(a.expedition.enemies[0]["suspicion"] < b.expedition.enemies[0]["suspicion"], "cover changes actual enemy detection, not just a HUD label")
	expect(a.expedition.player_x < b.expedition.player_x, "stealth has a movement speed tradeoff")
	a.free()
	b.free()
	print("PASS expedition: stealth and cover affect AI")


func test_hearing_noise() -> void:
	var scene := make_scene()
	scene.start_expedition()
	scene.expedition.player_x = 500
	scene.expedition.enemies[0]["x"] = 750.0
	scene.expedition.enemies[0]["direction"] = 1.0
	march(scene, 0.3, {"axis": 1.0, "sprint": true})
	expect(scene.expedition.noise == 75 and scene.expedition.enemies[0]["mode"] == "investigate", "sprint noise can attract a guard facing away")
	expect(scene.expedition.enemies[0]["suspicion"] > 0, "investigation has real rising suspicion")
	scene.free()
	print("PASS expedition: noise investigation")


func test_bite_warning_and_escape() -> void:
	var scene := make_scene()
	scene.start_expedition()
	var enemy := encounter(scene)
	march(scene, 0.4)
	expect(enemy["mode"] == "windup" and scene.survivors[0].health == 100, "bite is visibly telegraphed before damage")
	march(scene, 0.8, {"axis": -1.0})
	expect(scene.survivors[0].health == 100 and scene.survivors[0].infection == 0, "direct retreat during windup avoids the bite")
	scene.free()
	print("PASS expedition: avoidable attack windup")


func test_bite_consequences() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	encounter(scene)
	march(scene, 0.9)
	var actor: Survivor = scene.survivors[0]
	expect(actor.health == 86 and actor.injury == 12 and actor.infection >= 8, "contact bite has health, injury and infection consequences")
	var health := actor.health
	march(scene, 0.5)
	expect(actor.health == health and scene.expedition.invulnerable > 0, "post-hit grace period prevents per-frame damage")
	scene.expedition_medicine()
	expect(scene.expedition.bag["medicine"] == 0 and actor.health == 100 and actor.injury == 0 and actor.infection == 0, "real carried medicine repairs damage and is consumed once")
	scene.expedition_medicine()
	expect(scene.expedition.bag["medicine"] == 0, "medicine cooldown and empty stock prevent duplicate use")
	scene.free()
	print("PASS expedition: bite, infection and first aid")


func test_tools_and_unarmed_push() -> void:
	var armed := make_scene()
	armed.inventory.deposit({"tools": 1}, "tool fixture")
	armed.start_expedition(true)
	var target := encounter(armed, 45)
	armed.expedition_attack()
	march(armed, 0.1)
	expect(target["hp"] == 40 and armed.expedition.bag["tools"] == 1, "swing has a real windup")
	march(armed, 0.2)
	expect(target["hp"] == 0 and target["mode"] == "dead" and armed.expedition.bag["tools"] == 0, "one tool defeats exactly one enemy and is spent")
	expect(target["suspicion"] == 0 and target["timer"] == 0, "defeated enemy cannot leave a permanent false attack alert")
	var unarmed := make_scene()
	unarmed.start_expedition()
	var pushed := encounter(unarmed, 45)
	unarmed.expedition_attack()
	march(unarmed, 0.3)
	expect(pushed["hp"] == 40 and pushed["mode"] == "stunned" and pushed["x"] > 845, "unarmed push creates space but never kills")
	expect(unarmed.survivors[0].health == 100, "timely shove interrupts a pending bite")
	armed.free()
	unarmed.free()
	print("PASS expedition: finite tools and defensive shove")


func test_locked_container() -> void:
	var a := make_scene()
	a.inventory.deposit({"tools": 1}, "lock tool")
	a.start_expedition(true)
	a.expedition.player_x = 1200
	march(a, 3.1, {"interact": true})
	expect(a.expedition.bag["tools"] == 0 and a.expedition.bag["fuel"] == 3 and not a.expedition.sites[2]["locked"], "tool opens the fuel cabinet quickly and is consumed")
	var b := make_scene()
	b.start_expedition()
	b.expedition.player_x = 1200
	march(b, 3.1, {"interact": true})
	expect(b.expedition.used_capacity() == 0 and b.expedition.search_duration == 8, "no-tool entry takes longer rather than inventing a key")
	march(b, 5.1, {"interact": true})
	expect(b.expedition.bag["fuel"] == 3 and b.expedition.bag["materials"] == 2, "slow noisy opening remains a viable risk choice")
	a.free()
	b.free()
	print("PASS expedition: tool versus noisy search choice")


func test_pause_and_controls() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	scene.toggle_pause()
	var frozen := SaveSystem.capture(scene)
	scene.expedition_attack()
	scene.expedition_medicine()
	march(scene, 3, {"axis": 1.0, "interact": true})
	expect(SaveSystem.capture(scene) == frozen, "pause freezes enemies, player, search, needs and action use")
	scene.toggle_pause()
	scene.toggle_speed()
	expect(scene.speed == 1, "expedition cannot accelerate danger")
	scene.free()
	print("PASS expedition: pause and fixed speed")


func test_death_loses_bag() -> void:
	var scene := make_scene()
	scene.start_expedition(false, true)
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.1, {"interact": true})
	scene.survivors[0].health = 10
	encounter(scene)
	march(scene, 1)
	expect(not scene.expedition.active and scene.survivors[0].state == Survivor.TaskState.DEAD and scene.paused, "fatal bite returns to base with permanent casualty")
	expect(scene.inventory.amount("raw_food") == 4 and scene.inventory.amount("water") == 4 and scene.inventory.amount("medicine") == 0, "lost cargo and carried medicine are not refunded")
	expect(not scene.game_over and scene.expedition.used_capacity() == 0, "surviving team can continue after losing its traveler")
	expect(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "casualty and cleared expedition are consistent save data")
	scene.free()
	print("PASS expedition: permanent expedition loss")


func test_treatment() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.dining_table.work_position()
	actor.health = 50
	actor.injury = 70
	actor.infection = 50
	scene.assign_task("heal")
	advance(scene, 4)
	expect(scene.inventory.amount("medicine") == 0 and actor.health == 50 and actor.injury == 70, "unfinished treatment spends real medicine without premature benefit")
	scene.cancel_selected()
	expect(scene.inventory.amount("medicine") == 1 and actor.injury == 70, "cancelled treatment refunds without free healing")
	actor.position = scene.dining_table.work_position()
	scene.assign_task("heal")
	advance(scene, 8.2)
	expect(actor.completed_by_task["heal"] == 1 and actor.health == 75 and actor.injury == 20 and actor.infection < 11, "completed treatment repairs health, injury and infection")
	expect(scene.inventory.amount("medicine") == 0 and TaskCatalog.duration_for("heal", scene.survivors[1]) == 6, "medicine is finite and medic has a real treatment advantage")
	scene.free()
	print("PASS expedition: base treatment and cancellation")


func test_persistent_world_and_refresh() -> void:
	var scene := make_scene()
	scene.start_expedition()
	march(scene, 1, {"axis": 1.0})
	march(scene, 2.1, {"interact": true})
	march(scene, 1, {"axis": -1.0})
	scene.expedition.request_retreat()
	scene.start_expedition()
	expect(scene.expedition.sites[0]["contents"]["raw_food"] == 0, "same-day reentry cannot farm a depleted container")
	scene.expedition.refresh_for_day(3)
	expect(scene.expedition.last_refresh_day == 1 and scene.expedition.enemies.size() == 3, "new enemies never spawn on an active player")
	scene.expedition.request_retreat()
	scene.simulation_time = 1440
	scene.expedition.refresh_for_day(3)
	expect(scene.expedition.sites[0]["contents"]["raw_food"] == 2 and scene.expedition.enemies.size() == 4, "announced new-day migration changes supply and enemy count")
	for enemy in scene.expedition.enemies: expect(enemy["hp"] == 40, "later days never inflate enemy health")
	scene.expedition.sites[0]["contents"]["raw_food"] = 0
	scene.expedition.refresh_for_day(3)
	expect(scene.expedition.sites[0]["contents"]["raw_food"] == 0, "refresh runs once per day, not each interaction")
	scene.free()
	print("PASS expedition: persistent depletion and bounded world changes")


func test_scout_advantage() -> void:
	var a := make_scene()
	var b := make_scene()
	a.start_expedition()
	b.select_survivor(2)
	b.start_expedition()
	a.expedition.player_x = 300
	b.expedition.player_x = 300
	march(a, 1, {"interact": true})
	march(b, 1, {"interact": true})
	expect(b.expedition.search_progress > a.expedition.search_progress * 1.19, "scout has a real search advantage")
	march(a, 0.1, {"axis": 1.0, "sprint": true})
	march(b, 0.1, {"axis": 1.0, "sprint": true})
	expect(b.expedition.noise < a.expedition.noise, "scout movement is quieter without making it silent")
	a.free()
	b.free()
	print("PASS expedition: survivor specialization matters")
