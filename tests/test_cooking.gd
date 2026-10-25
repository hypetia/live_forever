extends "res://tests/test_shelter.gd"
## Reuse scene/advance/assert helpers, but execute this suite independently.


func _run() -> void:
	test_inventory_transactions()
	test_cook_lifecycle()
	test_refund_once()
	test_cancellation_before_work()
	test_last_batch_and_recovery()
	test_parallel_facilities()
	test_mixed_queue()
	test_cooking_pause()
	test_blocked_cooking()
	test_rejection_preserves_active_task()
	print("COOKING RESULT: %d checks, %d failures; 10 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_inventory_transactions() -> void:
	var stock := ShelterInventory.new()
	var initial := stock.snapshot()
	expect(not stock.try_take({"raw_food": 1, "fuel": 4}, "insufficient batch"), "one insufficient ingredient rejects the entire transaction")
	expect(stock.snapshot() == initial, "failed debit never partially consumes available ingredients")
	expect(not stock.try_take({"raw_food": -1}, "invalid"), "negative costs cannot create resources")
	expect(not stock.deposit({"meals": 2, "unknown": 1}, "invalid"), "invalid output rejects entire credit")
	expect(stock.snapshot() == initial, "invalid credit does not create partial output")
	var copy := stock.snapshot()
	copy["raw_food"] = -100
	expect(stock.amount("raw_food") == 4, "editing a snapshot cannot mutate real stock")
	expect(stock.try_take({"raw_food": 4}, "use all"), "exact remaining amount can be spent")
	expect(not stock.try_take({"raw_food": 1}, "overspend"), "zero stock cannot be overspent")
	expect(stock.amount("raw_food") == 0 and stock.history.size() == 1, "only successful transactions enter history")
	print("PASS cooking: atomic inventory")


func test_cook_lifecycle() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	var initial: Dictionary = scene.inventory.snapshot()
	scene.assign_task("cook")
	expect(scene.inventory.snapshot() == initial, "submitting cooking does not spend inputs")
	expect(actor.target_label == "灶台" and actor.orders == ["cook"], "cooking routes to the stove")
	advance(scene, 4)
	expect(actor.state == Survivor.TaskState.WORKING and scene.stove.occupant_id == 0, "arrival acquires stove and starts cooking")
	expect(scene.inventory.amount("raw_food") == 3 and scene.inventory.amount("water") == 3 and scene.inventory.amount("fuel") == 2, "cooking start debits the whole recipe once")
	expect(scene.inventory.amount("meals") == 0 and not actor.held_cost.is_empty(), "unfinished cooking creates no food and retains a refundable batch")
	advance(scene, 10)
	expect(scene.inventory.amount("meals") == 2 and scene.stove.completed_jobs == 1, "completed cooking creates exactly two meals")
	expect(actor.orders.is_empty() and actor.held_cost.is_empty() and scene.stove.occupant_id == -1, "completion clears inputs, order and occupancy")
	expect(actor.position.distance_to(scene.stove.waiting_position(0)) < 0.1, "completed cook walks aside instead of overlapping the next worker")
	expect(scene.inventory.history.size() == 2, "one debit and one output credit are recorded")
	var finished: Dictionary = scene.inventory.snapshot()
	scene.cancel_selected()
	advance(scene, 10)
	expect(scene.inventory.snapshot() == finished, "cancelling after completion cannot refund or duplicate output")
	scene.free()
	print("PASS cooking: complete lifecycle")


func test_refund_once() -> void:
	var scene := make_scene()
	var initial: Dictionary = scene.inventory.snapshot()
	scene.assign_task("cook")
	advance(scene, 5)
	expect(scene.survivors[0].state == Survivor.TaskState.WORKING, "refund scenario cancels actual active work")
	scene.cancel_selected()
	expect(scene.inventory.snapshot() == initial, "active cancellation refunds the exact inputs")
	expect(scene.stove.occupant_id == -1 and scene.stove.completed_jobs == 0, "cancellation releases stove and produces no meal")
	expect(scene.survivors[0].state == Survivor.TaskState.RETURNING, "cancelled active cook also vacates the interaction point")
	scene.cancel_selected()
	advance(scene, 20)
	expect(scene.inventory.snapshot() == initial and scene.inventory.history.size() == 2, "repeated cancellation cannot duplicate refunds")
	scene.assign_task("cook")
	advance(scene, 15)
	expect(scene.inventory.amount("meals") == 2 and scene.inventory.amount("fuel") == 2, "refunded inputs can be used in a fresh successful batch")
	scene.free()
	print("PASS cooking: cancellation refund is idempotent")


func test_cancellation_before_work() -> void:
	var scene := make_scene()
	var initial: Dictionary = scene.inventory.snapshot()
	scene.assign_task("cook")
	advance(scene, 0.5)
	scene.cancel_selected()
	expect(scene.inventory.snapshot() == initial and scene.inventory.history.is_empty(), "cancelling en route neither spends nor refunds anything")
	scene.assign_task("cook")
	scene.select_survivor(1)
	scene.assign_task("cook")
	advance(scene, 4.5)
	expect(scene.survivors[1].state == Survivor.TaskState.WAITING, "second cook visibly waits for the stove")
	var paid: Dictionary = scene.inventory.snapshot()
	scene.cancel_selected()
	expect(scene.inventory.snapshot() == paid and scene.stove.occupant_id == 0, "cancelling waiter does not refund another cook's batch")
	advance(scene, 10)
	expect(scene.inventory.amount("meals") == 2 and scene.stove.waiting_ids.is_empty(), "remaining cook finishes without a stale waiting ticket")
	scene.free()
	print("PASS cooking: pending and moving cancellation")


func test_last_batch_and_recovery() -> void:
	var scene := make_scene()
	scene.inventory.try_take({"raw_food": 3, "water": 3, "fuel": 2}, "leave one batch")
	var messages: Array[String] = []
	scene.scheduler.event_reported.connect(func(message: String): messages.append(message))
	for index in range(3):
		scene.select_survivor(index)
		expect(scene.scheduler.submit(scene.survivors[index], "cook"), "orders may queue without reserving the last batch")
	# This order must survive a failed cooking order in front of it.
	scene.scheduler.submit(scene.survivors[1], "repair")
	var never_negative := true
	for tick_index in range(70 * 60):
		scene.advance_simulation(1.0 / 60)
		for amount: int in scene.inventory.snapshot().values():
			never_negative = never_negative and amount >= 0
	expect(never_negative, "three requests for the last batch never create negative stock")
	expect(scene.stove.completed_jobs == 1 and scene.inventory.amount("meals") == 2, "last batch is spent and produced exactly once")
	expect(scene.inventory.amount("raw_food") == 0 and scene.inventory.amount("water") == 0 and scene.inventory.amount("fuel") == 0, "failed requests spend no partial ingredients")
	expect(scene.stove.waiting_ids.is_empty() and scene.stove.occupant_id == -1, "insufficient queued work does not deadlock the stove")
	expect(scene.survivors[1].completed_by_task["repair"] == 1, "next repair executes after the earlier cooking task fails")
	expect(scene.survivors[2].state == Survivor.TaskState.IDLE and "缺料" in scene.survivors[2].feedback, "failed cook retains an explicit idle reason")
	expect("未扣料" in "\n".join(messages), "failed execution explains removal and zero debit")
	var before: Dictionary = scene.inventory.snapshot()
	expect(not scene.scheduler.submit(scene.survivors[2], "cook"), "new cooking is rejected immediately when ingredients are gone")
	expect(scene.inventory.snapshot() == before and scene.survivors[2].orders.is_empty(), "rejection changes neither stock nor queue")
	scene.free()
	print("PASS cooking: contention for last batch and failure recovery")


func test_parallel_facilities() -> void:
	var scene := make_scene()
	scene.survivors[0].position = scene.facility.work_position()
	scene.survivors[1].position = scene.stove.work_position()
	scene.scheduler.submit(scene.survivors[0], "repair")
	scene.scheduler.submit(scene.survivors[1], "cook")
	scene.scheduler.submit(scene.survivors[2], "repair")
	advance(scene, 0.1)
	expect(scene.facility.occupant_id == 0 and scene.stove.occupant_id == 1, "different survivors can occupy different facilities simultaneously")
	var invariant := true
	for tick_index in range(15 * 60):
		scene.advance_simulation(1.0 / 60)
		for station: Workstation in [scene.facility, scene.stove]:
			var workers := 0
			for actor in scene.survivors:
				if actor.state == Survivor.TaskState.WORKING and actor.target_label == station.display_name:
					workers += 1
					invariant = invariant and station.occupant_id == actor.survivor_id
			invariant = invariant and workers <= 1
	expect(invariant, "each facility maintains exclusive and matching occupancy")
	expect(scene.stove.completed_jobs == 1 and scene.facility.completed_jobs == 2, "workbench waiter movement cannot stall independent cooking")
	scene.free()
	print("PASS cooking: independent facilities")


func test_mixed_queue() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	scene.assign_task("cook")
	scene.assign_task("repair")
	scene.assign_task("cook")
	expect(actor.orders == ["cook", "repair", "cook"], "mixed tasks preserve exact queue order")
	expect(not scene.scheduler.submit(actor, "repair"), "mixed queue still shares the three-task limit")
	advance(scene, 10)
	expect(actor.task_label == "修整" and is_equal_approx(actor.work_duration, 4.5), "switching from cooking restores the craftsman's repair speed")
	advance(scene, 45)
	expect(actor.completed_by_task["cook"] == 2 and actor.completed_by_task["repair"] == 1, "one actor completes mixed tasks across floors")
	expect(actor.orders.is_empty() and scene.inventory.amount("meals") == 4 and scene.inventory.amount("fuel") == 1, "mixed queue has exact final output and costs")
	scene.free()
	print("PASS cooking: mixed task queue")


func test_cooking_pause() -> void:
	var scene := make_scene()
	scene.assign_task("cook")
	advance(scene, 4.5)
	scene.toggle_pause()
	var paid: Dictionary = scene.inventory.snapshot()
	var elapsed: float = scene.survivors[0].work_elapsed
	advance(scene, 20)
	expect(scene.inventory.snapshot() == paid and scene.survivors[0].work_elapsed == elapsed, "paused cooking changes neither progress nor paid stock")
	scene.toggle_pause()
	scene.toggle_speed()
	advance(scene, 3)
	expect(scene.inventory.amount("meals") == 2 and scene.inventory.amount("fuel") == 2, "resuming at 3x speed produces once without a second debit")
	scene.free()
	print("PASS cooking: pause and accelerated completion")


func test_blocked_cooking() -> void:
	var scene := make_scene()
	scene.scheduler.navigation.stairs_open = false
	scene.select_survivor(2)
	var initial: Dictionary = scene.inventory.snapshot()
	scene.assign_task("cook")
	expect(scene.survivors[2].state == Survivor.TaskState.BLOCKED, "lower-floor actor reports an unreachable stove")
	expect(scene.inventory.snapshot() == initial and scene.stove.waiting_ids.is_empty(), "unreachable cooking consumes nothing and cannot block the stove")
	scene.select_survivor(0)
	scene.assign_task("cook")
	advance(scene, 15)
	expect(scene.stove.completed_jobs == 1, "upper-floor cook can still work despite another blocked actor")
	scene.free()
	print("PASS cooking: blocked route")


func test_rejection_preserves_active_task() -> void:
	var scene := make_scene()
	scene.select_survivor(2)
	scene.assign_task("repair")
	advance(scene, 2)
	scene.inventory.try_take({"fuel": 3}, "deplete fuel")
	var actor: Survivor = scene.survivors[2]
	var progress_before := actor.work_elapsed
	expect(not scene.scheduler.submit(actor, "cook"), "missing fuel rejects an appended cooking order")
	expect(actor.state == Survivor.TaskState.WORKING and actor.orders == ["repair"] and actor.work_elapsed == progress_before, "rejection does not interrupt active repair or reset its progress")
	advance(scene, 10)
	expect(actor.completed_by_task["repair"] == 1, "repair still finishes after rejected cooking")
	scene.free()
	print("PASS cooking: safe rejection while working")
