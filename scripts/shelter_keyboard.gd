class_name ShelterKeyboard
extends RefCounted
## Held movement is transient input. Floor steps finish within the tick; stairs remain real routes.
var actor_id := -1

func step(game: Node2D, delta: float, controls: Dictionary) -> void:
	var axis := signf(float(controls.get("axis",0)))
	var climb := int(controls.get("climb",0))
	var actor: Survivor = game.survivors[game.selected_id]
	if actor.health <= 0 or (axis == 0 and climb == 0): stop(game); return
	var on_floor := is_equal_approx(actor.position.y,430) or is_equal_approx(actor.position.y,640)
	var floor_id: int = game.scheduler.navigation.floor_at(actor.position)
	var route: Array[Vector2] = []
	var multiplier := 1.8 if controls.get("sprint",false) else 1.0
	if not on_floor:
		# Finish the real next landing; held input cannot cut diagonally off the stairs.
		route = actor.route.duplicate() if not actor.route.is_empty() else game.scheduler.navigation.route_between(actor.position,ShelterNavigation.TOP_STAIR if floor_id == 1 else ShelterNavigation.BOTTOM_STAIR)
	elif climb != 0:
		var entry := ShelterNavigation.BOTTOM_STAIR if floor_id == 0 else ShelterNavigation.TOP_STAIR
		if (climb > 0 and floor_id == 0) or (climb < 0 and floor_id == 1):
			if actor.position.distance_to(entry) <= 40 and game.scheduler.navigation.stairs_open:
				route = game.scheduler.navigation.route_between(actor.position,ShelterNavigation.TOP_STAIR if floor_id == 0 else ShelterNavigation.BOTTOM_STAIR)
	if route.is_empty() and on_floor and axis != 0:
		var x := clampf(actor.position.x+axis*Survivor.MOVE_SPEED*actor.effort_factor()*multiplier*delta,140,960)
		if not is_equal_approx(x,actor.position.x): route.append(Vector2(x,actor.position.y))
	if route.is_empty(): stop(game); return
	if actor_id != actor.survivor_id:
		stop(game)
		game._cancel_external(actor.survivor_id)
		game.scheduler.cancel(actor)
		actor_id = actor.survivor_id
		game.context_open = false
	actor.route = route
	actor.state = Survivor.TaskState.RETURNING
	actor.move_multiplier = multiplier
	actor.manual_walking = true

func finish_step(game: Node2D) -> void:
	if actor_id < 0: return
	var actor: Survivor = game.survivors[actor_id]
	if actor.health <= 0: stop(game); return
	if is_equal_approx(actor.position.y,430) or is_equal_approx(actor.position.y,640):
		# No held-key destination is stored in a save or allowed to drift after release.
		if actor.route.is_empty() or (actor.route.size() == 1 and is_equal_approx(actor.route[0].y,actor.position.y)):
			actor.route.clear()
			actor.state = Survivor.TaskState.IDLE

func stop(game: Node2D) -> void:
	if actor_id >= 0 and actor_id < game.survivors.size():
		var actor: Survivor = game.survivors[actor_id]
		actor.manual_walking = false
		actor.move_multiplier = 1
		if actor.health > 0 and actor.state == Survivor.TaskState.RETURNING and (is_equal_approx(actor.position.y,430) or is_equal_approx(actor.position.y,640)):
			actor.route.clear()
			actor.state = Survivor.TaskState.IDLE
	actor_id = -1

func reset(game: Node2D) -> void:
	actor_id = -1
	for actor in game.survivors: actor.manual_walking = false
