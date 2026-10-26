extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	if OS.get_cmdline_user_args().has("--no-film"):
		for child in game.get_children():
			if child is CanvasLayer and child.layer == 2: child.hide()
	for i in range(10): await process_frame
	var start := Time.get_ticks_msec()
	for i in range(120): await process_frame
	var elapsed := (Time.get_ticks_msec()-start)/1000.0
	print("HUD MEASURE ",JSON.stringify({"frames":120,"elapsed":elapsed,"fps":120/elapsed,"graphics":RenderingServer.get_video_adapter_name()}))
	game.free()
	await create_timer(0.12).timeout
	quit()
