extends "res://tests/test_shelter.gd"


func _run() -> void:
	test_life_pipeline()
	test_eating_cancel()
	test_partial_sleep()
	test_shared_bed()
	test_warnings_and_effort()
	test_pause_and_equal_time()
	test_day_cycle()
	test_death_and_restart()
	test_crafting()
	test_no_unapproved_consumption()
	test_failed_dependency()
	test_bounds_and_recovery()
	print("SURVIVAL RESULT: %d checks, %d failures; 12 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_life_pipeline() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	expect(TaskCatalog.TASKS.size() == 6 and scene.scheduler.facilities.size() == 4, "six tasks use four facilities")
	expect(scene.scheduler.submit(actor, "cook"), "pipeline accepts cooking")
	expect(scene.scheduler.submit(actor, "eat"), "pipeline accepts future food from its earlier cooking order")
	expect(scene.scheduler.submit(actor, "sleep"), "pipeline accepts rest as third task")
	expect(actor.orders == ["cook", "eat", "sleep"] and scene.inventory.amount("meals") == 0, "forecast does not create food early")
	advance(scene, 65)
	expect(actor.completed_by_task["cook"] == 1 and actor.completed_by_task["eat"] == 1 and actor.completed_by_task["sleep"] == 1, "cook-eat-sleep executes as a complete loop")
	expect(scene.inventory.amount("meals") == 1 and scene.inventory.amount("fuel") == 2, "pipeline produces two meals and consumes exactly one")
	expect(actor.hunger < 6 and actor.fatigue < 5 and actor.health == 100, "food and actual rest improve the survivor")
	expect(actor.orders.is_empty() and actor.state == Survivor.TaskState.IDLE, "pipeline ends without stuck orders")
	scene.free()
	print("PASS survival: complete cook-eat-sleep pipeline")


func test_eating_cancel() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.hunger = 88
	actor.position = scene.dining_table.work_position()
	scene.inventory.deposit({"meals": 1}, "test meal")
	scene.assign_task("eat")
	advance(scene, 1)
	expect(actor.state == Survivor.TaskState.WORKING and scene.inventory.amount("meals") == 0, "eating reserves a real meal at start")
	expect(actor.hunger >= 88, "unfinished eating cannot restore hunger")
	scene.cancel_selected()
	scene.cancel_selected()
	expect(scene.inventory.amount("meals") == 1 and actor.hunger >= 88, "repeated cancellation refunds one meal without free restoration")
	actor.position = scene.dining_table.work_position()
	scene.assign_task("eat")
	advance(scene, 4.2)
	expect(actor.completed_by_task["eat"] == 1 and actor.hunger > 33 and actor.hunger < 35, "eating completes in four seconds despite high hunger")
	expect(scene.inventory.amount("meals") == 0, "completed eating cannot refund its consumed meal")
	scene.free()
	print("PASS survival: eating and cancellation")


func test_partial_sleep() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.bed.work_position()
	actor.fatigue = 90
	var stock: Dictionary = scene.inventory.snapshot()
	scene.assign_task("sleep")
	expect(actor.fatigue == 90, "sleep order does not instantly restore fatigue")
	advance(scene, 2)
	expect(actor.fatigue > 83 and actor.fatigue < 85, "sleep restores only actual time spent resting")
	var rested := actor.fatigue
	scene.cancel_selected()
	expect(actor.fatigue == rested and scene.inventory.snapshot() == stock, "interrupted sleep retains earned rest without spending stock")
	expect(scene.bed.occupant_id == -1 and actor.completed_by_task["sleep"] == 0, "interrupted sleep releases bed without a completion")
	scene.free()
	print("PASS survival: partial sleep")


func test_shared_bed() -> void:
	var scene := make_scene()
	var order: Array[String] = []
	scene.scheduler.event_reported.connect(func(message: String):
		if "完成睡觉。" in message: order.append(message.get_slice("完成",0))
	)
	scene.scheduler.submit(scene.survivors[0], "sleep")
	scene.scheduler.submit(scene.survivors[1], "sleep")
	var exclusive := true
	var waited := false
	for tick_index in range(60 * 60):
		scene.advance_simulation(1.0 / 60)
		var sleepers := 0
		for actor in scene.survivors:
			if actor.state == Survivor.TaskState.WAITING and actor.target_label == "床位": waited = true
			if actor.state == Survivor.TaskState.WORKING and actor.orders[0] == "sleep": sleepers += 1
		exclusive = exclusive and sleepers <= 1
	expect(exclusive and waited, "single shared bed visibly queues without double occupancy")
	expect(order == ["墨衡「钉钟人」", "闻人灯「白鸦」"] and scene.bed.completed_jobs == 2, "sleeping preserves FIFO order")
	expect(scene.bed.waiting_ids.is_empty() and scene.bed.occupant_id == -1, "bed is fully released after both rests")
	scene.free()
	print("PASS survival: shared bed FIFO")


func test_warnings_and_effort() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[2]
	actor.hunger = 80
	actor.fatigue = 85
	actor.position = scene.facility.work_position()
	# Needs warnings are scene events recorded through _log, so inspect flags.
	scene.scheduler.submit(actor, "repair")
	advance(scene, 6.1)
	expect(actor.state == Survivor.TaskState.WORKING and actor.work_elapsed < 4, "hunger and fatigue reduce productive work rate")
	expect(actor.warned["hunger"] and actor.warned["fatigue"], "high needs trigger persistent warnings")
	actor.hunger = 95
	var health := actor.health
	advance(scene, 10)
	expect(actor.health < health and actor.health > health - 2, "critical hunger causes gradual and bounded health loss")
	scene.scheduler.cancel(actor)
	actor.position = scene.dining_table.work_position()
	scene.inventory.deposit({"meals": 1}, "recovery")
	scene.scheduler.submit(actor, "eat")
	advance(scene, 4.2)
	actor.position = scene.bed.work_position()
	scene.scheduler.submit(actor, "sleep")
	advance(scene, 20.2)
	expect(actor.hunger < 80 and actor.fatigue < 40 and is_equal_approx(actor.effort_factor(), 1), "food and sleep restore productive efficiency")
	scene.free()
	print("PASS survival: warnings and recoverable slowdown")


func test_pause_and_equal_time() -> void:
	var a := make_scene()
	var b := make_scene()
	a.toggle_pause()
	var frozen := SaveSystem.capture(a)
	advance(a, 10)
	expect(SaveSystem.capture(a) == frozen, "pause freezes needs, tasks, inventory and clock together")
	a.toggle_pause()
	b.toggle_speed()
	advance(a, 60)
	advance(b, 20)
	expect(absf(a.simulation_time - b.simulation_time) < 0.0001, "1x and 3x use identical total simulation time")
	for index in range(3):
		expect(absf(a.survivors[index].hunger - b.survivors[index].hunger) < 0.0001 and absf(a.survivors[index].fatigue - b.survivors[index].fatigue) < 0.0001, "need rates agree at different speeds")
	a.free()
	b.free()
	print("PASS survival: pause and scaled time")


func test_day_cycle() -> void:
	var scene := make_scene()
	expect("第 1 天  08:00" in SurvivalRules.clock_text(0), "new game begins at day one morning")
	advance(scene, 301)
	expect(SurvivalRules.is_night(scene.simulation_time), "clock and lighting enter night")
	advance(scene, 419)
	expect("第 2 天  08:00" in SurvivalRules.clock_text(scene.simulation_time + 0.001), "a full 720-second day advances calendar")
	expect(not scene.game_over, "there is no forced ending on a day boundary")
	expect("第 101 天" in SurvivalRules.clock_text(720 * 100), "calendar supports continued survival without a fixed final day")
	scene.free()
	print("PASS survival: a complete day and night")


func test_death_and_restart() -> void:
	var scene := make_scene()
	scene.survivors[0].position = scene.stove.work_position()
	scene.assign_task("cook")
	for actor in scene.survivors:
		actor.hunger = 100
		actor.fatigue = 100
		actor.health = 0.1
	advance(scene, 2)
	expect(scene.game_over and scene.paused, "all deaths produce a paused failure state")
	expect(scene.inventory.amount("fuel") == 2 and scene.inventory.amount("meals") == 0, "death loses the unfinished cooking batch rather than duplicating a refund")
	for station: Workstation in scene.scheduler.facilities.values():
		expect(station.occupant_id == -1 and station.waiting_ids.is_empty(), "death clears every facility ticket and occupant")
	expect(not scene.scheduler.submit(scene.survivors[0], "sleep"), "dead survivors cannot be resurrected by new tasks")
	scene.toggle_pause()
	expect(scene.paused, "failure cannot be unpaused")
	scene.start_new_game()
	expect(not scene.game_over and not scene.paused and scene.simulation_time == 0, "new game resets the failed run")
	expect(scene.survivors[0].health == 100 and scene.inventory.amount("fuel") == 3, "new game restores original survivor and stock state")
	scene.free()
	print("PASS survival: deterministic death and restart")


func test_crafting() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.position = scene.facility.work_position()
	scene.assign_task("craft")
	advance(scene, 0.1)
	expect(scene.inventory.amount("materials") == 6 and scene.inventory.amount("tools") == 0, "crafting debits two materials and has no premature output")
	advance(scene, 7)
	expect(scene.inventory.amount("tools") == 1 and actor.completed_by_task["craft"] == 1, "crafting yields one persistent tool")
	actor.position = scene.facility.work_position()
	scene.assign_task("craft")
	advance(scene, 0.5)
	scene.cancel_selected()
	expect(scene.inventory.amount("materials") == 6 and scene.inventory.amount("tools") == 1, "cancelled second craft refunds only its own inputs")
	scene.free()
	print("PASS survival: fifth task crafts tools")


func test_no_unapproved_consumption() -> void:
	var scene := make_scene()
	scene.inventory.deposit({"meals": 2}, "stocked meals")
	scene.survivors[0].hunger = 85
	advance(scene, 10)
	expect(scene.inventory.amount("meals") == 2 and scene.survivors[0].hunger > 85, "idle survivors do not consume scarce food without an order")
	expect(scene.survivors[1].fatigue > 65, "idle survivors do not silently start sleeping")
	scene.free()
	print("PASS survival: player controls scarce consumption")


func test_failed_dependency() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	scene.assign_task("cook")
	scene.assign_task("eat")
	scene.assign_task("sleep")
	scene.inventory.try_take({"fuel": 3}, "another demand depleted fuel")
	advance(scene, 60)
	expect(actor.completed_by_task["cook"] == 0 and actor.completed_by_task["eat"] == 0 and actor.completed_by_task["sleep"] == 1, "failed cooking and eating do not prevent a later valid sleep")
	expect(scene.inventory.amount("meals") == 0 and actor.orders.is_empty(), "forecast failure creates neither phantom meals nor a stuck queue")
	scene.free()
	print("PASS survival: failed forecast recovers")


func test_bounds_and_recovery() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	actor.hunger = 10
	actor.fatigue = 10
	actor.health = 50
	advance(scene, 10)
	expect(actor.health > 50 and actor.health < 51, "well-fed rested survivor recovers health slowly")
	actor.position = scene.bed.work_position()
	actor.fatigue = 0
	scene.assign_task("sleep")
	advance(scene, 20.1)
	expect(actor.fatigue >= 0 and actor.fatigue < 1 and actor.health <= 100, "rest and healing remain bounded")
	scene.free()
	print("PASS survival: bounded needs and recovery")
