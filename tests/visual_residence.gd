extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/campaign.tscn").instantiate()
	game.persistence_enabled = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game._process(0)
	game.assign_task("craft")
	sim(game,20) # Obtain the gate tool through ordinary paid production.
	await click_at(game.compact.home_button.get_global_rect().get_center())
	check(game.residence_view.opened and game.paused,"visible home button opens a deliberately paused drawer")
	check(Rect2(0,0,1440,900).encloses(game.residence_view.window.get_global_rect()),"home drawer fits the logical viewport")
	check(game.residence_view.window.find_children("*","ScrollContainer",true,false).size() == 1,"long home projects scroll rather than cover the scene")
	var actions: Array[Node] = game.residence_view.window.find_children("*","Button",true,false)
	var gate: Button
	for action in actions:
		if action.text.begins_with("安排"):
			gate = action
			break
	check(is_instance_valid(gate) and not gate.disabled,"available gate recipe has an enabled actual button")
	await picture("res://docs/v13-home-planning.png")
	await click_at(gate.get_global_rect().get_center())
	check(not game.residence_view.opened and not game.paused,"committing home work closes drawer and restores the clock")
	check(game.expansion.jobs.size() == 1 and game.residence.security["gate"] == 0,"UI starts a paid construction job, not an instant bonus")
	sim(game,55)
	check(game.residence.security["gate"] == 1,"actual UI order walks and completes the gate")
	await picture("res://docs/v13-gate.png")
	check(not game.residence_view.opened and not game.log_label.visible,"finished security remains in the scene without a text dashboard")
	await keypress(KEY_H)
	check(game.residence_view.opened and game.paused,"H opens the same drawer")
	await keypress(KEY_ESCAPE)
	check(not game.residence_view.opened and not game.paused,"Esc returns to gameplay without opening another menu")
	game.select_survivor(2)
	await keypress(KEY_P)
	check(game.center.visible and game.center.person_text.text.contains("近战伤害+40%"),"person page exposes the actual specialist effect")
	await picture("res://docs/v13-character.png")
	game.center.close()
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/v13-home-journey.json"))
	check(SaveSystem.apply_state(game,SaveSystem.migrate_v14(SaveSystem.migrate_v13(SaveSystem.migrate_v12(SaveSystem.migrate_v11(SaveSystem.migrate_v10(SaveSystem.migrate_v9(report["snapshot"]))))))).is_empty(),"natural journey snapshot restores the actually acquired new home")
	game._process(0)
	check(game.residence.current == "row" and game.residence.security["gate"] == 1,"relocated home and rebuilt security are rendered from saved state")
	await picture("res://docs/v13-relocated.png")
	await keypress(KEY_H)
	check(game.residence_view.opened,"moved home still has an accessible drawer")
	await picture("res://docs/v13-relocated-details.png")
	await keypress(KEY_ESCAPE)
	check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),"GUI home actions keep the complete save valid")
	game.select_survivor(1)
	check(game.expansion.start_job(game,"guitar"),"relocated crew can repair a guitar using their genuinely gathered stock")
	sim(game,45)
	check(game.residence.guitar and game.expansion.start_job(game,"music"),"completed guitar enables a real performance")
	sim(game,10)
	check(game.survivors[1].activity.get("kind","") == "music" and game.survivors[1].position.distance_to(Vector2(584,430)) < 10,"performer physically reaches the upstairs guitar")
	check(game.game_audio.music.playing and game.game_audio.music.stream.get_length() > 6,"performance plays an original synthesized phrase through the actual audio node")
	await picture("res://docs/v13-music.png")
	game.paused = true
	game._process(0)
	check(not game.game_audio.music.playing,"pausing the game also stops the performance audio")
	game.game_audio.stop_audio()
	# Match the real quit path: let the mixer release stopped playback before freeing its owner.
	await create_timer(0.16).timeout
	await dispose_scene(game)
	print("RESIDENCE VISUAL RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
