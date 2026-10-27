extends RefCounted
## Frame-driven actual gameplay, used only by the optional acceptance pack.

const Policy := preload("res://tests/balance_bot.gd")
var campaign_driver: RefCounted
var game: Node2D
var policy := Policy.new()
var target := -1
var returning := false
var planning_time := 0.0
var search_time := 0.0
var trips := 0


func setup(scene: Node2D) -> void:
	game = scene
	if game.has_method("campaign_snapshot"):
		campaign_driver = preload("res://tests/tactical_pilot.gd").new()
		campaign_driver.style = "fortify"
		campaign_driver.daytime_seconds = 70.0
		campaign_driver.setup(game)
		return
	policy.game = scene
	policy.provide_care = true
	policy.handle_projects = true
	for actor: Survivor in game.survivors: actor.person.routine = true


func tick(delta: float) -> void:
	if is_instance_valid(campaign_driver):
		if not game.expansion.outcome.is_empty(): game.expansion.endless = true
		campaign_driver.tick(delta)
		game._process(0)
		trips = campaign_driver.trips
		return
	if game.game_over: return
	if game.paused: game.toggle_pause()
	var input := {}
	if not game.expedition.active:
		planning_time -= delta
		if planning_time <= 0:
			planning_time = 0.5
			policy._manage()
			var next: Dictionary = policy._supply_target()
			var traveler: int = policy._traveler()
			if not next.is_empty() and traveler >= 0:
				game.select_survivor(traveler)
				game.choose_destination(next["region"])
				if game.start_expedition(game.inventory.amount("tools") > 0, game.inventory.amount("medicine") > 0):
					target = int(next["site"])
					returning = false
					search_time = 0
					policy.retreat_now = false
	else:
		var world: ExpeditionState = game.expedition
		if policy.retreat_now or world.used_capacity() >= 10 or search_time > 22 or world.sites[target]["contents"].values().all(func(n): return n == 0): returning = true
		var x: float = 110 if returning else world.site_definitions()[target]["x"]
		var floor: int = 0 if returning else world.site_definitions()[target]["floor"]
		if world.climb_target != -1:
			input = {}
		elif world.floor_level != floor:
			if absf(world.player_x - world.ladder_x()) > 9: input = {"axis": signf(world.ladder_x() - world.player_x), "sprint": true}
			else: input = {"climb": 1 if floor == 1 else -1}
		elif absf(world.player_x - x) > 10:
			input = {"axis": signf(x - world.player_x), "sprint": true}
		elif returning:
			game.expedition_retreat()
			trips += 1
		else:
			input = {"interact": true}
			search_time += delta
		if world.active: input = policy.combat_input(input)
	game.expedition_controls_override = input
	game.advance_simulation(delta)
	game.expedition_controls_override = null
	game._refresh_hud()
	game.queue_redraw()
