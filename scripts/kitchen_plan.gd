class_name KitchenPlan
extends RefCounted
## Shared kitchen decisions use real jobs, reachable stations and unpromised stock.
const ADVANCED := ["cook_batch","cook_stew","cook_pot"]

static func pending(game: Node2D) -> bool:
	for actor: Survivor in game.survivors:
		if actor.health<=0 or actor.state in [Survivor.TaskState.BLOCKED,Survivor.TaskState.AWAY,Survivor.TaskState.DEAD]:continue
		if actor.orders.is_empty() or actor.orders[0]!="cook":continue
		if not game.scheduler.navigation.route_between(actor.position,game.stove.work_position()).is_empty():return true
	for job in game.expansion.jobs:
		if not ADVANCED.has(job["kind"]):continue
		var actor:Survivor=game.survivors[int(job["actor"])]
		if actor.health>0 and not game.scheduler.navigation.route_between(actor.position,SurvivalExpansion.job_position(job["kind"])).is_empty():return true
	if game.camp.enabled and game.camp.food.jobs.any(func(job):return CampFoodCatalog.RECIPES[job['kind']].get('output',{}).has('meals')):return true
	return false

static func hungry(game: Node2D) -> int:
	var count:=0
	for actor:Survivor in game.survivors:
		if actor.health>0 and actor.state!=Survivor.TaskState.AWAY and actor.hunger>=SelfCareSystem.NEEDS["eat"] and not actor.orders.has("eat"):count+=1
	return count

static func drinking_water(game: Node2D) -> int:
	var count:=0
	for actor:Survivor in game.survivors:
		if not game.self_care.enabled(actor) or actor.state==Survivor.TaskState.AWAY or actor.person.thirst<SelfCareSystem.NEEDS["drink"]:continue
		# Existing drinking trips are already deducted by available().
		if not game.cycle.actions.any(func(action):return action["kind"]=="drink" and action["actor"]==actor.survivor_id):count+=1
	return count

static func can_pay(game: Node2D,cost: Dictionary) -> bool:
	for resource in cost:
		var free:=SelfCareSystem.available(game,resource)
		if resource=="water":free=maxi(0,free-drinking_water(game))
		if free<int(cost[resource]):return false
	return true

static func choose(game: Node2D,actor: Survivor) -> String:
	var need:=maxi(1,hungry(game)-SelfCareSystem.available(game,"meals"))
	var choices:Array[String]=["cook"]
	for kind:String in ADVANCED:
		if game.facilities.job_error(game,kind).is_empty():choices.append(kind)
	var best:="";var score:=INF
	for kind in choices:
		var cost:Dictionary=TaskCatalog.TASKS["cook"]["cost"] if kind=="cook" else FacilitySystem.RECIPES[kind]["cost"]
		if not can_pay(game,cost):continue
		var output:int=CharacterAbilities.cooking_output(actor)["meals"] if kind=="cook" else FacilitySystem.cooking_output(kind,actor)["meals"]
		# Small households must not trigger oversized, perishable batches.
		if kind!="cook" and output>need+1:continue
		var value:float=(3.0*int(cost.get("fuel",0))+int(cost.get("raw_food",0))+int(cost.get("water",0)))/mini(need,output)+maxi(0,output-need)*.1
		if value<score:best=kind;score=value
	return best
