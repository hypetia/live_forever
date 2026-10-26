extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	game.end_day()
	game.start_expedition()
	var field: ExpeditionState = game.expedition
	var actor: Survivor = game.survivors[field.actor_id]
	advance(game,0.1)
	expect(not game.departure_dialog.visible,"spawn beside the entrance does not ask to leave")
	field.bag["water"] = 1 # Isolated cargo accounting fixture.
	var stock: int = game.inventory.amount("water")
	field.player_x = 91
	game.expedition_controls_override = {"axis":-1}
	advance(game,0.1)
	expect(game.departure_dialog.visible and game.paused and field.active,"walking into left world edge opens a paused confirmation")
	expect(game.inventory.amount("water") == stock,"opening confirmation does not deposit cargo")
	var time: float = game.simulation_time
	advance(game,1)
	expect(game.simulation_time == time,"no enemy or clock ticks while deciding")
	game.cancel_departure()
	expect(not game.paused and field.active,"cancelling restores running time and stays in the map")
	advance(game,0.2)
	expect(not game.departure_dialog.visible,"held outward key cannot immediately reopen a cancelled prompt")
	game.expedition_controls_override = {"axis":1}
	advance(game,0.2)
	game.expedition_controls_override = {"axis":-1}
	advance(game,0.3)
	expect(game.departure_dialog.visible,"stepping away and returning rearms the exit")
	game.confirm_departure()
	expect(game.cycle.phase == "dawn" and not field.active,"confirmed edge departure resolves the night")
	expect(game.inventory.amount("water") == stock+1,"actual cargo is credited once on confirmation")
	stock = game.inventory.amount("water")
	game.confirm_departure()
	expect(game.inventory.amount("water") == stock and game.upkeep.returns["street"] == 1,"stale confirmation cannot duplicate cargo or settlement")
	valid(game,"confirmed departure")
	game.free()

	game = campaign()
	game.end_day()
	game.start_expedition()
	field = game.expedition
	field.floor_level = 1
	field.player_y = 400
	field.player_x = field.right_edge(1)-1
	game.expedition_controls_override = {"axis":1}
	advance(game,0.1)
	expect(not game.departure_dialog.visible and field.active,"upstairs platform edge never extracts through a wall")
	field.floor_level = 0
	field.player_y = 620
	field.player_x = field.right_edge(0)-1
	advance(game,0.1)
	expect(game.departure_dialog.visible and game._departure_side == 1,"right ground edge opens the right-side confirmation")
	var saved := SaveSystem.capture(game)
	expect(SaveSystem.validate(saved).is_empty(),"paused exit remains a valid old-schema save")
	expect(SaveSystem.apply_state(game,saved).is_empty() and not game.departure_dialog.visible,"reload drops the transient dialog and never auto-accepts")
	game.confirm_departure()
	expect(field.active,"a discarded pre-load confirmation cannot extract")
	game.paused = true
	game.expedition_retreat()
	expect(game.departure_dialog.visible,"explicit T works at the right exit even while paused")
	game.cancel_departure()
	expect(game.paused and field.active,"cancellation preserves a deliberate pre-existing pause")
	game.paused = false
	game.expedition_controls_override = {"interact":true}
	advance(game,0.05)
	expect(game.departure_dialog.visible,"E explicitly offers departure from the right exit")
	game.cancel_departure()
	advance(game,0.1)
	expect(not game.departure_dialog.visible,"held E does not trap the player in repeated confirmations")
	field.player_x = 300
	game._offer_departure(-1)
	game.confirm_departure()
	expect(field.active,"neither side can extract from the interior")
	game.expedition_controls_override = null
	game.simulation_time = game.cycle.night_end-0.01
	advance(game,3)
	expect(game.cycle.phase == "dawn" and not game.departure_dialog.visible,"mandatory dawn route finishes without a cancellable dialog loop")
	game.free()

	game = campaign()
	game.end_day()
	game.start_expedition()
	game.expedition_controls_override = {"interact":true}
	advance(game,0.1)
	game.cancel_departure()
	game.simulation_time = game.cycle.night_end-0.01
	advance(game,0.1)
	expect(game.cycle.phase == "dawn","holding E after cancelling cannot prevent forced dawn extraction")
	game.free()

	for id in LocationCatalog.ALL_IDS:
		var region := ExpeditionState.new(id)
		region.begin(0,{},1)
		region.player_x = region.right_edge(0)
		expect(region.exit_side() == 1,"right exit follows actual width for "+id)

	game = campaign()
	actor = game.survivors[2]
	var slots := EquipmentArt.slots(actor)
	expect(slots[0]["kind"] == "knife" and slots[0]["ratio"] == 1,"presentation reads the actually assigned knife")
	game.expansion.grant("vest","chen")
	game.expansion.grant("coat","chen")
	game.expansion.sync(game)
	slots = EquipmentArt.slots(actor)
	expect(slots[1]["kind"] == "vest" and slots[2]["kind"] == "coat","armor and coat use independent equipment slots")
	actor.weapon_item["durability"] = 0
	slots = EquipmentArt.slots(actor)
	expect(slots[0]["broken"] and actor.weapon().is_empty(),"broken held weapon is visibly marked and provides no attack stats")
	actor.weapon_item = {}
	expect(EquipmentArt.slots(actor)[0]["kind"].is_empty(),"backpack tools cannot invent an equipped weapon")
	game.free()
	print("DEPARTURE EQUIPMENT RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
