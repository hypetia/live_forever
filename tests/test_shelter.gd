extends SceneTree
## Real-scene regression checks. No testing plugin or external dependencies.

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func make_scene() -> Node2D:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	return scene


func advance(scene: Node2D, seconds: float) -> void:
	for tick_index in range(int(ceil(seconds * 60))):
		scene.advance_simulation(1.0 / 60.0)


func _run() -> void:
	test_scene_and_selection()
	test_stair_route_and_completion()
	test_three_survivors_and_fairness()
	test_task_queue_limit()
	test_cancel_moving_and_reassign()
	test_cancel_working_and_waiting()
	test_blocked_route_feedback()
	test_pause_and_speed()
	print("RESULT: %d checks, %d failures; 8 scenarios executed." % [checks, failures])
	quit(1 if failures else 0)


func test_scene_and_selection() -> void:
	var scene := make_scene()
	expect(scene.survivors.size() == 3, "three survivors exist in the real scene")
	expect(scene.progress_bar.size.y <= 8, "resolved progress-bar theme preserves the intended thin layout")
	scene.select_survivor(2)
	expect(scene.selected_id == 2 and scene.survivors[2].selected, "selection changes scene and survivor")
	expect(not scene.survivors[0].selected, "previous survivor is deselected")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_2
	event.pressed = true
	scene._unhandled_key_input(event)
	expect(scene.selected_id == 1, "keyboard 2 selects the second survivor")
	scene.facility.clicked.emit()
	expect(scene.context_open and scene.survivors[1].orders.is_empty(), "workstation click opens action details before committing resources")
	scene.free()
	print("PASS scenario: selection and facility input")


func test_stair_route_and_completion() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	scene.assign_selected()
	expect(actor.state == Survivor.TaskState.MOVING, "order starts movement")
	expect(actor.route.size() == 3, "cross-floor route includes both stair landings")
	expect(actor.route[0] == ShelterNavigation.TOP_STAIR and actor.route[1] == ShelterNavigation.BOTTOM_STAIR, "stairs connect the correct floors")
	advance(scene, 1)
	expect(is_equal_approx(actor.position.y, 430), "actor walks on the upper floor before the stairs")
	advance(scene, 20)
	expect(actor.completed_jobs == 1 and actor.orders.is_empty(), "walking and working produces one completion")
	expect(actor.state == Survivor.TaskState.IDLE and scene.facility.occupant_id == -1, "completion releases facility and returns idle")
	expect(actor.position.distance_to(scene.facility.waiting_position(0)) < 0.1, "finished survivor vacates work position for the next worker")
	scene.free()
	print("PASS scenario: cross-floor movement and completion")


func test_three_survivors_and_fairness() -> void:
	var scene := make_scene()
	var completion_order: Array[String] = []
	scene.scheduler.event_reported.connect(func(message: String):
		if "完成修整。" in message:
			completion_order.append(message.substr(0, 2))
	)
	for index in range(3):
		scene.select_survivor(index)
		scene.assign_selected()
	var valid_occupancy := true
	var observed_waiting := false
	for tick_index in range(40 * 60):
		scene.advance_simulation(1.0 / 60)
		var workers := 0
		for actor in scene.survivors:
			if actor.state == Survivor.TaskState.WAITING:
				observed_waiting = true
			if actor.state == Survivor.TaskState.WORKING:
				workers += 1
				valid_occupancy = valid_occupancy and scene.facility.occupant_id == actor.survivor_id
		valid_occupancy = valid_occupancy and workers <= 1
	expect(observed_waiting, "competing survivors visibly wait")
	expect(valid_occupancy, "at most one worker occupies the facility throughout the run")
	expect(completion_order == ["林舟", "许遥", "陈野"], "submission order is fair despite different arrival times")
	expect(scene.facility.completed_jobs == 3, "all three survivors finish independently")
	expect(scene.facility.waiting_ids.is_empty(), "no stale waiters remain after completion")
	scene.free()
	print("PASS scenario: three survivors, exclusive occupancy and FIFO fairness")


func test_task_queue_limit() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	for index in range(3):
		expect(scene.scheduler.submit(actor), "orders within queue limit are accepted")
	expect(not scene.scheduler.submit(actor), "fourth order is rejected")
	expect(actor.orders.size() == 3, "rejected order does not change queue")
	advance(scene, 50)
	expect(actor.completed_jobs == 3 and actor.orders.is_empty(), "queued tasks finish exactly once each")
	scene.free()
	print("PASS scenario: per-survivor queue and bounded repeated orders")


func test_cancel_moving_and_reassign() -> void:
	var scene := make_scene()
	var actor: Survivor = scene.survivors[0]
	scene.assign_selected()
	advance(scene, 3)
	expect(actor.position.y > 430 and actor.position.y < 640, "test reaches the middle of the stairs")
	scene.cancel_selected()
	var stopped_at := actor.position
	advance(scene, 1)
	expect(actor.position == stopped_at and actor.orders.is_empty(), "cancelling stops movement and clears orders")
	scene.assign_selected()
	expect(actor.route[0] == ShelterNavigation.TOP_STAIR or actor.route[0] == ShelterNavigation.BOTTOM_STAIR, "reassignment from stairs follows a landing, never crosses a room diagonally")
	advance(scene, 25)
	expect(actor.completed_jobs == 1, "mid-stair cancellation and reassignment completes normally")
	scene.free()
	print("PASS scenario: mid-stair cancellation and reassignment")


func test_cancel_working_and_waiting() -> void:
	var scene := make_scene()
	scene.select_survivor(2)
	scene.assign_selected()
	advance(scene, 2)
	expect(scene.facility.occupant_id == 2, "third survivor has acquired workbench")
	scene.select_survivor(1)
	scene.assign_selected()
	advance(scene, 0.5)
	scene.cancel_selected()
	expect(not scene.facility.waiting_ids.has(1), "cancelling a pending order removes its ticket")
	scene.assign_selected()
	scene.select_survivor(2)
	scene.cancel_selected()
	expect(scene.facility.occupant_id == -1, "cancelling active work releases occupancy immediately")
	expect(scene.survivors[2].completed_jobs == 0, "cancelled work creates no completion")
	advance(scene, 25)
	expect(scene.survivors[1].completed_jobs == 1, "next survivor can take over after cancellation")
	scene.free()
	print("PASS scenario: cancelling pending and active work")


func test_blocked_route_feedback() -> void:
	var scene := make_scene()
	scene.scheduler.navigation.stairs_open = false
	scene.assign_selected()
	var actor: Survivor = scene.survivors[0]
	expect(actor.state == Survivor.TaskState.BLOCKED, "closed stair produces explicit blocked state")
	expect("楼梯不通" in scene.logs[0] or "楼梯不通" in scene.logs[1], "blocked reason reaches the event log")
	expect(not scene.facility.waiting_ids.has(0), "unreachable survivor does not deadlock facility queue")
	scene.select_survivor(2)
	scene.assign_selected()
	advance(scene, 15)
	expect(scene.survivors[2].completed_jobs == 1, "same-floor work remains possible when stair is blocked")
	scene.select_survivor(0)
	scene.cancel_selected()
	scene.scheduler.navigation.stairs_open = true
	scene.assign_selected()
	advance(scene, 25)
	expect(actor.completed_jobs == 1, "opening route and resubmitting recovers blocked work")
	scene.free()
	print("PASS scenario: explicit blocked feedback and recovery")


func test_pause_and_speed() -> void:
	var scene := make_scene()
	scene.assign_selected()
	advance(scene, 0.5)
	scene.toggle_pause()
	var point: Vector2 = scene.survivors[0].position
	var time: float = scene.simulation_time
	advance(scene, 5)
	expect(scene.survivors[0].position == point and scene.simulation_time == time, "pause freezes both movement and simulation time")
	scene.toggle_pause()
	scene.toggle_speed()
	advance(scene, 1)
	expect(absf(scene.simulation_time - time - 3) < 0.001, "3x speed consistently scales simulation time")
	advance(scene, 10)
	expect(scene.survivors[0].completed_jobs == 1, "resumed accelerated task completes")
	scene.free()
	print("PASS scenario: pause, resume and simulation speed")
