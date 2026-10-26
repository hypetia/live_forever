extends SceneTree
const Pilot := preload("res://tests/residence_pilot.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://residence-journey.json"
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	var pilot := Pilot.new()
	pilot.setup(game)
	var last := 0
	var steps := 0
	var rows: Array = []
	var error := ""
	var goal := false
	while game.expansion.day(game) <= 25 and not game.game_over and steps < 600000:
		pilot.tick(1.0/30)
		steps += 1
		var day: int = game.expansion.day(game)
		if day > last:
			last = day
			var state := SaveSystem.capture(game)
			error = SaveSystem.validate(state)
			rows.append({"day":day,"alive":game.survivors.filter(func(a):return a.health>0).size(),"trips":pilot.trips,"stock":game.inventory.snapshot(),"home":game.residence.snapshot(),"error":error})
			print("HOME JOURNEY DAY %d · %s · stock %s · home %s · validation %s" % [day,str(game.survivors.map(func(a):return [a.health,a.hunger,a.fatigue])),str(game.inventory.snapshot()),JSON.stringify(game.residence.snapshot()),error])
			if not error.is_empty(): break
		goal = game.residence.current == "row" and game.residence.security["gate"] > 0
		if goal: break
	var result := {"day":last,"steps":steps,"trips":pilot.trips,"goal":goal,"records":rows,"snapshot":SaveSystem.capture(game),"validation":SaveSystem.validate(SaveSystem.capture(game)),"injected_supplies_health_positions_progress":false}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	var okay: bool = goal and result["validation"].is_empty() and game.survivors.all(func(a):return a.health>0)
	print("HOME JOURNEY ","PASS" if okay else "FAIL",": day ",last,"; trips ",pilot.trips,"; home ",game.residence.title())
	game.free()
	await create_timer(0.12).timeout
	quit(0 if okay else 1)
