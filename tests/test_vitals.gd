extends "res://tests/test_campaign.gd"

func _run() -> void:
	var game := campaign()
	var actor: Survivor = game.survivors[0]
	for raw in [0.0,25.0,50.0,75.0,100.0]:
		actor.hunger = raw
		actor.fatigue = raw
		actor.person.thirst = raw
		for key in ["fullness","hydration","vigor"]:
			expect(Vitals.value(actor,key) == roundi(100-raw), "deficit maps to positive 100 baseline: " + key)
	actor.health = 100
	expect(Vitals.value(actor,"health") == 100,"full health uses the same positive maximum")
	actor.hunger = 50
	actor.fatigue = 50
	actor.person.thirst = 50
	var before := SaveSystem.capture(game)
	game._refresh_hud()
	expect(SaveSystem.capture(game) == before,"display conversion never rewrites gameplay or saved needs")
	expect(game.detail_label.text.contains("饱腹50") and game.detail_label.text.contains("精神50"),"day detail uses positive satiety and vigor")
	expect(game.cards[0].tooltip_text.contains("水分  50 / 100"),"portrait hover exposes exact positive hydration")
	game.inventory.deposit({"meals":1},"meal behavior fixture")
	game.select_survivor(0)
	game.assign_task("eat")
	advance(game,15)
	expect(Vitals.value(actor,"fullness") > 90,"real eating fills the positive gauge")
	actor.fatigue = 80
	game.assign_task("sleep")
	advance(game,30)
	expect(Vitals.value(actor,"vigor") > 70,"real sleep fills the positive vigor gauge")
	actor.person.thirst = 70
	var water: int = game.inventory.amount("water")
	game.begin_drink()
	advance(game,20)
	expect(Vitals.value(actor,"hydration") > 70 and game.inventory.amount("water") == water-1,"physical drink consumes water and fills gauge")
	valid(game,"positive presentation keeps resulting save valid")
	var store := SaveSystem.new()
	store.path = "res://tests/fixtures/v7_campaign_active.json"
	var data: Dictionary = store.read_state()["data"]
	expect(SaveSystem.apply_state(game,data).is_empty(),"real old save imports without a needs-schema rewrite")
	for index in range(game.survivors.size()):
		var member: Survivor = game.survivors[index]
		expect(member.hunger == data["actors"][index]["hunger"] and member.fatigue == data["actors"][index]["fatigue"] and member.person.thirst == data["actors"][index]["person"]["thirst"],"old saved deficits retain their exact physiological values")
		expect(Vitals.value(member,"fullness") == roundi(100-data["actors"][index]["hunger"]),"old save receives correct positive presentation")
	game.free()
	print("VITALS RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
