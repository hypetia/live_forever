extends SceneTree

const Policy := preload("res://tests/balance_bot.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "three"
	var days := int(args[1]) if args.size() > 1 else 14
	var destination := args[2] if args.size() > 2 else "user://balance_report.json"
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	var bot := Policy.new()
	var report := bot.run(scene, days, mode == "five", mode != "no_supply", mode != "no_care")
	var file := FileAccess.open(destination, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BALANCE REPORT: %s · elapsed %.2f days · alive %d · peak %d · trips %d · repairs %d · level %d · stock %s · save %s · wall %.2fs" % [mode, report["days_elapsed"], report["alive"], report["peak_people"], report["trips"], report["repairs"], report["level"], report["stock"], report["save_error"], report["wall_seconds"]])
	scene.free()
	quit(0 if report["save_error"].is_empty() else 1)
