extends "res://tests/test_campaign.gd"

func one_actor() -> Node2D:
	var game := campaign()
	for actor: Survivor in game.survivors:
		game.self_care.set_enabled(game,actor,actor.survivor_id == 0)
	return game

func _run() -> void:
	var game := campaign()
	var actor: Survivor
	expect(game.survivors.all(func(a):return game.self_care.enabled(a)),"basic self care starts enabled for every initial survivor")
	expect(game.survivors.all(func(a):return not a.person.routine),"automatic cooking remains a separate opt-in fuel policy")
	var stock: Dictionary = game.inventory.snapshot()
	advance(game,2)
	expect(game.inventory.snapshot() == stock and game.survivors.all(func(a):return a.orders.is_empty()),"comfortable people do not spend supplies merely to fill bars")
	valid(game,"default autonomous campaign")
	game.free()

	game = campaign()
	for a: Survivor in game.survivors: game.self_care.set_enabled(game,a,a.survivor_id == 1)
	game.inventory.try_take({"water":3},"declared last-water reservation fixture")
	game.survivors[1].person.thirst = 90
	game.select_survivor(0);game.assign_task("cook")
	advance(game,.1)
	expect(game.survivors[1].self_care_wait == "等待饮用水" and game.survivors[1].self_care_kind.is_empty(),"autonomy protects the final water unit promised to a manual cooking order")
	advance(game,20)
	expect(game.survivors[0].completed_by_task["cook"] == 1 and game.people.drinks == 0,"manual cooking can finish without autonomous drinking stealing its inputs")
	valid(game,"manual recipe stock protection")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.fatigue = 90
	advance(game,1)
	expect(actor.self_care_kind == "sleep","autonomous rest begins before an emergency need appears")
	actor.person.thirst = 95
	advance(game,4)
	expect(actor.self_care_kind == "drink" and not actor.orders.has("sleep"),"urgent dehydration interrupts an autonomous nap without overriding manual work")
	valid(game,"emergency self care priority")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared late supply race")
	advance(game,.1)
	game.inventory.try_take({"meals":1},"declared competing explicit resource spend")
	advance(game,12)
	expect(actor.orders.is_empty() and actor.self_care_kind.is_empty() and actor.completed_by_task["eat"] == 0,"lost supplies during approach clear ownership safely without free recovery")
	valid(game,"failed autonomous start remains saveable")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared manual work policy fixture")
	game.assign_task("craft")
	game.self_care.set_enabled(game,actor,false)
	expect(actor.orders == ["craft"],"switching basic care off does not cancel a manually assigned job")
	valid(game,"manual work survives policy change")
	game.free()

	game = campaign()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v16_autonomy_upgrade_campaign.json"))
	var original: Dictionary = JSON.parse_string(fixture["data_json"])
	var upgraded: Dictionary = SaveSystem.migrate_v16(original)
	expect(SaveSystem.validate(upgraded).is_empty(),"authentic previous-release snapshot migrates to basic autonomy")
	expect(upgraded["stock"] == original["stock"] and upgraded["actors"] == original["actors"] and upgraded["districts"] == original["districts"],"migration changes no stock, character state, existing cooking choices or district history")
	expect(upgraded["self_care"]["members"].values().all(func(r):return r["enabled"] and r["action"].is_empty()),"older living residents receive basic care without inventing active tasks")
	expect(SaveSystem.apply_state(game,upgraded).is_empty(),"migrated real save applies through the ordinary restoration path")
	game.self_care.set_enabled(game,game.survivors[0],false)
	var optout := SaveSystem.capture(game)
	expect(SaveSystem.apply_state(game,optout).is_empty() and not game.self_care.enabled(game.survivors[0]),"new-version save restoration preserves an explicit opt-out")
	valid(game,"restored individual care policy")
	game.free()

	game = one_actor()
	actor = game.survivors[0]
	actor.person.thirst = 85
	game.select_survivor(2)
	advance(game,.1)
	expect(actor.self_care_kind == "drink" and not actor.route.is_empty(),"unselected thirsty actor chooses a physical trip to the water bucket")
	expect(game.selected_id == 2 and game.inventory.amount("water") == 4 and actor.person.thirst > 84,"decision neither steals selection nor hydrates remotely")
	valid(game,"autonomous hydration walking")
	var pending := SaveSystem.capture(game)
	game.paused = true;advance(game,10)
	expect(SaveSystem.capture(game) == pending.merged({"paused":true},true),"pause freezes autonomous travel, needs, payments and clock")
	expect(SaveSystem.apply_state(game,pending).is_empty() and actor.self_care_kind == "drink","in-flight autonomous action restores with its visible intent")
	game.paused = false;advance(game,22)
	expect(game.inventory.amount("water") == 3 and actor.person.thirst < 30 and game.people.drinks == 1,"physical arrival and use consume one actual water unit once")
	valid(game,"completed autonomous hydration")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared one-meal autonomy fixture")
	advance(game,.1)
	expect(actor.orders == ["eat"] and actor.hunger > 84,"hungry idle actor plans actual table service rather than immediate recovery")
	valid(game,"autonomous table queue")
	advance(game,30)
	expect(actor.completed_by_task["eat"] == 1 and actor.hunger < 40 and game.inventory.amount("meals") == 0,"eating pays a real cooked meal and records ordinary task completion")
	valid(game,"completed autonomous meal")
	game.free()

	game = campaign()
	game.inventory.deposit({"meals":1},"declared last meal race")
	for a: Survivor in game.survivors: a.hunger = [75,90,85][a.survivor_id]
	advance(game,.1)
	expect(game.survivors[1].self_care_kind == "eat" and game.survivors[0].orders.is_empty() and game.survivors[2].orders.is_empty(),"most urgent person gets the last meal; others cannot double-book it")
	expect(game.survivors[0].self_care_wait == "等待熟食","waiting needs have concise persistent feedback")
	advance(game,30)
	expect(game.survivors[1].completed_by_task["eat"] == 1 and game.inventory.amount("meals") == 0,"three hungry people cannot consume one meal three times")
	expect(game.inventory.amount("fuel") == 3 and game.inventory.amount("raw_food") == 4,"basic autonomy does not silently spend cooking inputs")
	var waits: int = game.logs.filter(func(s):return s.contains("林舟自理等待：等待熟食")).size()
	advance(game,5)
	expect(game.logs.filter(func(s):return s.contains("林舟自理等待：等待熟食")).size() == waits,"missing-food feedback does not flood the log every decision tick")
	valid(game,"scarce cooked food")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85;actor.person.routine = true
	advance(game,.1)
	expect(actor.orders == ["cook","eat"] and actor.self_care_kind == "cook_eat","opt-in cooking queues stove then table using real orders")
	valid(game,"autonomous cooking chain")
	advance(game,38)
	expect(actor.completed_by_task["cook"] == 1 and actor.completed_by_task["eat"] == 1 and actor.hunger < 40,"permitted cook actually prepares and eats the batch")
	expect(game.inventory.amount("raw_food") == 3 and game.inventory.amount("water") == 3 and game.inventory.amount("fuel") == 2 and game.inventory.amount("meals") == 1,"cooking is neither free nor repeated just because several needs exist")
	valid(game,"completed cooking chain")
	game.free()

	game = campaign()
	for a: Survivor in game.survivors: a.hunger = 85;a.person.routine = true
	advance(game,.1)
	expect(game.survivors.filter(func(a):return a.orders.has("cook")).size() == 1,"multiple autonomous cooks share one imminent batch instead of spending three fuel")
	valid(game,"one kitchen batch for multiple hungry people")
	game.free()

	game = one_actor();actor = game.survivors[0]
	actor.person.thirst = 95;actor.hunger = 80;actor.fatigue = 90
	game.inventory.deposit({"meals":1},"declared competing needs fixture")
	advance(game,.1)
	expect(actor.self_care_kind == "drink","most urgent need wins instead of a fixed eat-first or sleep-first list")
	advance(game,100)
	expect(actor.person.thirst < 40 and actor.hunger < 50 and actor.fatigue < 20,"one idle person can drink, eat and rest sequentially without player micromanagement")
	valid(game,"all three basic needs resolved")
	game.free()

	game = campaign();game.select_survivor(0)
	expect(game.place_build("bed",0),"additional beds are built through the actual construction API")
	advance(game,50)
	game.self_care.set_enabled(game,game.survivors[0],false)
	game.survivors[1].fatigue = 90;game.survivors[2].fatigue = 90
	advance(game,1.2)
	expect(game.survivors[1].self_care_kind == "sleep" and game.survivors[2].self_care_kind == "sleep","two tired people use distinct physical beds")
	expect(game.cycle.actions.filter(func(a):return a["kind"] == "sleep").size() == 1 and game.bed.waiting_ids.size() <= 1,"built and original bed reservations do not overlap")
	valid(game,"parallel autonomous beds")
	advance(game,65)
	expect(game.survivors[1].fatigue < 20 and game.survivors[2].fatigue < 20,"autonomous sleep continues until rested and releases both beds")
	expect(game.bed.occupant_id == -1 and game.cycle.actions.is_empty(),"rested people leave beds available to others")
	valid(game,"released physical beds")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.fatigue = 90
	game.scheduler.submit(game.survivors[1],"sleep")
	advance(game,.1)
	expect(actor.self_care_wait == "等待空床" and actor.orders.is_empty(),"an autonomous sleeper waits for a manually reserved bed")
	advance(game,60)
	expect(actor.completed_by_task["sleep"] > 0 and actor.fatigue < 20,"waiting retries when the real bed is released")
	valid(game,"bed queue eventually drains")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared cancellable meal fixture")
	actor.position = game.dining_table.work_position()
	advance(game,.1)
	expect(actor.state == Survivor.TaskState.WORKING and actor.held_cost == {"meals":1},"autonomous meal holds its ordinary paid input")
	game.cancel_selected()
	expect(game.inventory.amount("meals") == 1 and actor.self_care_kind.is_empty(),"manual cancellation refunds the unfinished meal and releases autonomous ownership")
	advance(game,7)
	expect(actor.orders.is_empty() and actor.self_care_kind.is_empty(),"cancel command is respected rather than immediately undone by AI")
	advance(game,2)
	expect(actor.self_care_kind == "eat","basic care can resume after the manual grace period")
	valid(game,"resumed basic care")
	game.self_care.set_enabled(game,actor,false)
	expect(actor.orders.is_empty() and game.inventory.amount("meals") == 1,"disabling a running autonomous meal safely stops and refunds it")
	advance(game,12)
	expect(actor.orders.is_empty() and not game.self_care.enabled(actor),"disabled policy stays disabled")
	valid(game,"explicit self care opt-out")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared manual priority fixture")
	game.assign_task("craft");advance(game,1)
	expect(actor.orders == ["craft"] and actor.self_care_kind.is_empty(),"hungry person keeps an explicit work order")
	valid(game,"manual production retains priority")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.person.thirst = 85
	game.inventory.try_take({"water":4},"declared dry shelter fixture")
	var before: Dictionary = game.inventory.snapshot()
	advance(game,3)
	expect(actor.self_care_wait == "等待饮用水" and game.cycle.actions.is_empty() and game.inventory.snapshot() == before,"no water causes feedback without free hydration or negative stock")
	game.inventory.deposit({"water":1},"declared restored water supply")
	advance(game,20)
	expect(game.people.drinks == 1 and game.inventory.amount("water") == 0,"waiting hydration resumes after supplies return")
	valid(game,"water shortage recovery")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.fatigue = 95;actor.person.thirst = 95
	game.inventory.try_take({"water":4},"declared emergency thirst plus exhaustion fixture")
	advance(game,5)
	expect(actor.self_care_wait == "等待饮用水" and actor.orders.is_empty() and game.cycle.actions.is_empty(),"critical thirst without water waits rather than repeatedly starting and cancelling naps")
	expect(actor.completed_by_task["sleep"] == 0 and game.logs.filter(func(s):return s.contains("已为林舟安排睡觉") or s.contains("已取消林舟的全部任务")).is_empty(),"unresolved emergency creates no repeated sleep/cancel work or log storm")
	game.inventory.deposit({"water":1},"declared water returned after emergency")
	advance(game,55)
	expect(game.people.drinks == 1 and actor.person.thirst < 40 and actor.fatigue < 20,"returned water resolves the emergency and then permits useful autonomous rest")
	valid(game,"stable recovery from simultaneous thirst and exhaustion")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.fatigue = 90;actor.position = Vector2(260,640)
	game.scheduler.navigation.stairs_open = false
	advance(game,2)
	expect(actor.self_care_wait == "床位路线不通" and actor.route.is_empty() and actor.state == Survivor.TaskState.IDLE,"inaccessible bed does not create a blocked task or walk through a floor")
	game.scheduler.navigation.stairs_open = true
	advance(game,2)
	expect(actor.self_care_kind == "sleep","reopening the actual stairs permits care to retry")
	valid(game,"reopened care route")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85;actor.person.thirst = 85
	game.inventory.deposit({"meals":1},"declared skipped-day fixture")
	game.end_day()
	expect(game.inventory.amount("meals") == 1 and game.inventory.amount("water") == 4 and game.cycle.actions.is_empty(),"skipping daylight cannot secretly run self care or spend provisions")
	valid(game,"night planning clears autonomy")
	game.cycle.roles.assign(["guard","bed","floor"]);game.start_expedition()
	valid(game,"night settlement does not plan daytime self care")
	game.begin_day();advance(game,25)
	expect(game.people.drinks > 0 or actor.completed_by_task["eat"] > 0,"next playable day resumes ordinary autonomous needs")
	valid(game,"new dawn care")
	game.free()

	game = one_actor();actor = game.survivors[0];actor.hunger = 85
	game.inventory.deposit({"meals":1},"declared death fixture")
	advance(game,.1);game.scheduler.mark_dead(actor,"declared self-care death case")
	var dead := SaveSystem.capture(game)
	expect(not dead["self_care"]["members"]["lin"]["enabled"] and dead["self_care"]["members"]["lin"]["action"].is_empty(),"death removes autonomous ownership and cannot revive the person")
	valid(game,"permanent death with basic autonomy")
	var bad := dead.duplicate(true);bad["self_care"]["members"]["lin"]["enabled"] = true
	expect(not SaveSystem.validate(bad).is_empty(),"invalid dead-person autonomy is rejected")
	bad = dead.duplicate(true);bad["self_care"]["members"]["xu"]["action"] = "drink"
	expect(not SaveSystem.validate(bad).is_empty(),"autonomous ownership without a corresponding real action is rejected")
	bad = dead.duplicate(true);bad["self_care"]["members"]["xu"]["manual_until"] = game.simulation_time+100
	expect(not SaveSystem.validate(bad).is_empty(),"unbounded future control grace is rejected")
	game.free()
	print("SELF CARE RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
