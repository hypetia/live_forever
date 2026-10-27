class_name TaskScheduler
extends RefCounted
## Owns task transitions. Each facility has independent FIFO waiters and one
## occupant; all facilities share the transactional inventory.

signal event_reported(message: String)
signal task_finished(actor_id: int, task: String)
signal survivor_lost(actor_id: int)
signal tasks_cancelled(actor_id: int)
signal task_failed(actor_id: int)

var survivors: Array[Survivor] = []
var facilities: Dictionary = {}
var inventory: ShelterInventory
var navigation := ShelterNavigation.new()
var external_busy := Callable()
var station_reserved := Callable()
var production_rate := Callable()
var upkeep: ShelterProgress
const MAX_ORDERS := 3


func configure(actors: Array[Survivor], stations: Array[Workstation], stock: ShelterInventory) -> void:
	survivors = actors
	inventory = stock
	for station in stations:
		facilities[station.facility_id] = station


func submit(actor: Survivor, task_id: String = "repair") -> bool:
	if external_busy.is_valid() and external_busy.call(actor.survivor_id): return false
	if actor.state == Survivor.TaskState.AWAY:
		event_reported.emit("%s正在外出，不能执行基地任务。" % actor.display_name)
		return false
	if actor.health <= 0.0:
		event_reported.emit("%s已死亡，无法安排工作。" % actor.display_name)
		return false
	if not TaskCatalog.TASKS.has(task_id):
		event_reported.emit("未知任务：%s。" % task_id)
		return false
	if actor.orders.size() >= MAX_ORDERS:
		event_reported.emit("%s的队列已满（最多 3 项），请等待或取消。" % actor.display_name)
		return false
	if actor.state == Survivor.TaskState.BLOCKED:
		event_reported.emit("%s的路线已阻塞，请先取消任务。" % actor.display_name)
		return false
	var definition: Dictionary = TaskCatalog.TASKS[task_id]
	if not can_plan_materials(actor, task_id):
		var reason := "缺料：%s" % inventory.missing_text(definition["cost"])
		if actor.orders.is_empty():
			actor.feedback = reason
		event_reported.emit("%s无法安排%s，%s。" % [actor.display_name, definition["label"], reason])
		return false
	actor.orders.append(task_id)
	if actor.orders.size() == 1:
		_activate(actor)
		if actor.state == Survivor.TaskState.BLOCKED:
			return true
	event_reported.emit("已为%s安排%s%s。" % [actor.display_name, definition["label"], " · 已追加到队列" if actor.orders.size() > 1 else ""])
	return true


func can_plan_materials(actor: Survivor, task_id: String) -> bool:
	var cost: Dictionary = TaskCatalog.TASKS[task_id]["cost"]
	if inventory.can_take(cost):
		return true
	# Allow cook -> eat even when there are no cooked meals yet. This is a
	# forecast for this actor, never a reservation; start-time checks remain.
	var forecast := inventory.snapshot()
	for index in range(actor.orders.size()):
		var recipe: Dictionary = TaskCatalog.TASKS[actor.orders[index]]
		var already_paid := index == 0 and actor.state == Survivor.TaskState.WORKING
		var possible := true
		for resource in recipe["cost"]:
			if not already_paid and forecast[resource] < recipe["cost"][resource]:
				possible = false
		if not possible:
			continue
		if not already_paid:
			for resource in recipe["cost"]:
				forecast[resource] -= recipe["cost"][resource]
		for resource in recipe["output"]:
			forecast[resource] += (CharacterAbilities.cooking_output(actor) if actor.orders[index] == "cook" else recipe["output"])[resource]
	for resource in cost:
		if forecast[resource] < cost[resource]:
			return false
	return true


func cancel(actor: Survivor) -> void:
	if actor.orders.is_empty():
		return
	# Clear held inputs first; cancellation must never refund twice.
	var refund := actor.held_cost.duplicate()
	actor.held_cost.clear()
	actor.legacy_repair = false
	var used_station: Workstation = null
	for station: Workstation in facilities.values():
		station.waiting_ids.erase(actor.survivor_id)
		if station.occupant_id == actor.survivor_id:
			used_station = station
			station.occupant_id = -1
	actor.orders.clear()
	actor.route.clear()
	actor.work_elapsed = 0.0
	actor.state = Survivor.TaskState.IDLE
	actor.feedback = "任务已取消 · 等待安排"
	inventory.deposit(refund, "%s取消任务，退回用料" % actor.display_name)
	if used_station != null:
		_step_aside(actor, used_station)
	actor.queue_redraw()
	event_reported.emit("已取消%s的全部任务。%s" % [actor.display_name, "退还%s。" % ShelterInventory.describe(refund) if not refund.is_empty() else "未消耗材料。"])
	tasks_cancelled.emit(actor.survivor_id)


func step(delta: float) -> void:
	if delta <= 0.0:
		return
	for actor in survivors:
		if actor.state in [Survivor.TaskState.MOVING, Survivor.TaskState.RETURNING]:
			var returning := actor.state == Survivor.TaskState.RETURNING
			actor.advance_route(delta)
			if actor.route.is_empty():
				actor.state = Survivor.TaskState.IDLE if returning else Survivor.TaskState.WAITING
	# A busy station must not stop independent work at the other one.
	for station: Workstation in facilities.values():
		_try_start(station)
	for actor in survivors:
		if actor.state != Survivor.TaskState.WORKING:
			continue
		var recovery_task := actor.orders[0] in ["eat", "sleep", "heal"]
		var skill_bonus := actor.person.bonus("care" if actor.orders[0] == "heal" else "craft") if actor.orders[0] not in ["eat", "sleep"] else 1.0
		var station_rate := float(production_rate.call(TaskCatalog.TASKS[actor.orders[0]]["facility"])) if production_rate.is_valid() and not recovery_task else 1.0
		actor.work_elapsed += delta * skill_bonus * station_rate * (CharacterAbilities.factor(actor,"work") if not recovery_task else 1.0) * (1.0 if recovery_task else actor.effort_factor() * (upkeep.efficiency() if upkeep != null else 1.0))
		actor.queue_redraw()
		if actor.work_elapsed >= actor.work_duration:
			_finish(actor)


func _try_start(station: Workstation) -> void:
	if station_reserved.is_valid() and station_reserved.call(station.facility_id): return
	if station.occupant_id != -1 or station.waiting_ids.is_empty():
		return
	var actor := survivors[station.waiting_ids[0]]
	if actor.state != Survivor.TaskState.WAITING:
		return
	if actor.position.distance_to(station.work_position()) > 1.0:
		actor.route = navigation.route_between(actor.position, station.work_position())
		actor.state = Survivor.TaskState.MOVING
		return
	var definition: Dictionary = TaskCatalog.TASKS[actor.orders[0]]
	station.waiting_ids.pop_front()
	# Queued orders reserve nothing. Check the complete recipe again now,
	# then deduct atomically before awarding occupancy or starting progress.
	if not inventory.try_take(definition["cost"], "%s开始%s" % [actor.display_name, definition["label"]]):
		_fail_current(actor, "缺料：%s" % inventory.missing_text(definition["cost"]))
		return
	actor.held_cost = definition["cost"].duplicate()
	actor.legacy_repair = false
	station.occupant_id = actor.survivor_id
	actor.state = Survivor.TaskState.WORKING
	actor.work_elapsed = 0.0
	actor.facing = 1.0
	event_reported.emit("%s开始%s%s。" % [actor.display_name, definition["label"], "，消耗%s" % ShelterInventory.describe(actor.held_cost) if not actor.held_cost.is_empty() else station.display_name])


func _activate(actor: Survivor) -> void:
	var task_id := actor.orders[0]
	var station: Workstation = facilities[TaskCatalog.TASKS[task_id]["facility"]]
	actor.task_label = TaskCatalog.label_for(task_id)
	actor.target_label = station.display_name
	actor.work_duration = TaskCatalog.duration_for(task_id, actor)
	var target := station.work_position() if station.waiting_ids.is_empty() and station.occupant_id == -1 else station.waiting_position(actor.survivor_id)
	actor.route = navigation.route_between(actor.position, target)
	if actor.route.is_empty():
		actor.state = Survivor.TaskState.BLOCKED
		event_reported.emit("%s无法到达%s：楼梯不通。请取消任务后重新安排。" % [actor.display_name, station.display_name])
		return
	station.waiting_ids.append(actor.survivor_id)
	actor.state = Survivor.TaskState.MOVING
	actor.work_elapsed = 0.0


func _finish(actor: Survivor) -> void:
	var legacy := actor.legacy_repair
	var task_id: String = actor.orders.pop_front()
	var definition: Dictionary = TaskCatalog.TASKS[task_id]
	var station: Workstation = facilities[definition["facility"]]
	actor.held_cost.clear()
	actor.legacy_repair = false
	var output: Dictionary = CharacterAbilities.cooking_output(actor) if task_id == "cook" else definition["output"]
	inventory.deposit(output, "%s完成%s" % [actor.display_name, definition["label"]])
	if task_id == "repair" and upkeep != null and not legacy:
		upkeep.repair()
	elif task_id == "eat":
		actor.hunger = maxf(0, actor.hunger - SurvivalRules.MEAL_RECOVERY)
	elif task_id == "heal":
		# In the campaign, medicine treats wounds; it cannot replace food.
		if actor.metabolism >= 1 or actor.hunger < 80: actor.health = minf(100, actor.health + 25)
		actor.injury = maxf(0, actor.injury - 50)
		actor.infection = maxf(0, actor.infection - 40)
		actor.illness = maxf(0, actor.illness - 35)
		if actor.metabolism < 1 and actor.person.persona == "gu":
			actor.injury = maxf(0, actor.injury - 15)
			actor.illness = maxf(0, actor.illness - 10)
	actor.completed_jobs += 1
	actor.completed_by_task[task_id] += 1
	station.completed_jobs += 1
	station.occupant_id = -1
	task_finished.emit(actor.survivor_id, task_id)
	actor.state = Survivor.TaskState.IDLE
	actor.feedback = "%s完成 · 等待安排" % definition["label"]
	actor.work_elapsed = 0.0
	event_reported.emit("%s完成%s。%s" % [actor.display_name, definition["label"], "获得%s。" % ShelterInventory.describe(output) if not output.is_empty() else "可以安排下一项工作了。"])
	if not actor.orders.is_empty():
		_activate(actor)
	else:
		_step_aside(actor, station)


func mark_dead(actor: Survivor, cause: String = "长期未处理的生存状态") -> void:
	if actor.state == Survivor.TaskState.DEAD: return
	# Death loses the unfinished batch, rather than refunding scarce inputs.
	for station: Workstation in facilities.values():
		station.waiting_ids.erase(actor.survivor_id)
		if station.occupant_id == actor.survivor_id:
			station.occupant_id = -1
	actor.orders.clear()
	actor.route.clear()
	actor.held_cost.clear()
	actor.legacy_repair = false
	actor.work_elapsed = 0.0
	actor.health = 0.0
	actor.state = Survivor.TaskState.DEAD
	actor.feedback = "已死亡"
	survivor_lost.emit(actor.survivor_id)
	actor.queue_redraw()
	event_reported.emit("%s因%s死亡。未完成任务的用料已损失。" % [actor.display_name, cause])


func _step_aside(actor: Survivor, station: Workstation) -> void:
	# Logical occupancy is already free. Vacate its visual interaction point,
	# too, so an idle survivor does not hide the next worker on top of them.
	actor.route = navigation.route_between(actor.position, station.waiting_position(actor.survivor_id))
	actor.state = Survivor.TaskState.RETURNING if not actor.route.is_empty() else Survivor.TaskState.IDLE


func _fail_current(actor: Survivor, reason: String) -> void:
	var task_id: String = actor.orders.pop_front()
	var label := TaskCatalog.label_for(task_id)
	var station: Workstation = facilities[TaskCatalog.TASKS[task_id]["facility"]]
	actor.route.clear()
	actor.work_elapsed = 0.0
	actor.state = Survivor.TaskState.IDLE
	actor.feedback = reason
	event_reported.emit("%s的%s未执行，%s；此项已移出队列，未扣料。" % [actor.display_name, label, reason])
	task_failed.emit(actor.survivor_id)
	if not actor.orders.is_empty():
		_activate(actor)
	else:
		_step_aside(actor, station)
