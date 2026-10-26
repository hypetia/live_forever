extends "res://tests/visual_people.gd"

const Policy := preload("res://tests/balance_bot.gd")


func _run() -> void:
	var scene: Node2D = load("res://scenes/shelter.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	await keypress(KEY_N)
	check(scene.center.visible and scene.center.tabs.current_tab == 6 and scene.paused, "N opens real paused guide and companion page")
	check(scene.center.guide_text.text.contains("认识队伍") and scene.center.guide_text.text.contains("喝一份水"), "all six objectives have concrete controls and survival advice")
	check(not scene.center.story_paid.visible and not scene.center.story_free.visible, "new run never invents an immediate narrative choice")
	await picture("res://docs/guide-preview.png")
	await dialog_click(scene.center, scene.center.guide_toggle)
	check(scene.story.guide_hidden and not scene.center.guide_toggle.button_pressed, "actual checkbox hides optional guidance")
	# The real shortcut between guide and profiles also records the first objective.
	await dialog_click(scene.center, scene.center.guide_people_button)
	check(scene.center.tabs.current_tab == 5 and scene.story.guide.has("people"), "actual guide button opens profile and completes its real objective")
	await keypress(KEY_ESCAPE)
	check(not scene.center.visible and not scene.paused, "closing guide restores original running state")
	# Two genuine simulated days of paid work/search/care earn this chapter.
	var policy := Policy.new()
	policy.handle_stories = false
	var report := policy.run(scene, 2)
	check(report["alive"] == 3 and report["save_error"].is_empty() and scene.story.pending.get("id") == "lin_radio", "workshop story is earned by actual survival and paid work without inventory or coordinate injection")
	await keypress(KEY_N)
	check(scene.center.story_text.text.contains("收音机") and scene.center.story_text.text.contains("心境+12"), "real story panel shows authored scene and consequences")
	check(scene.center.story_paid.text.contains("材料") and not scene.center.story_paid.disabled, "affordable paid branch states exact cost before click")
	await picture("res://docs/story-preview.png")
	var materials: int = scene.inventory.amount("materials")
	await dialog_click(scene.center, scene.center.story_paid)
	check(scene.story.pending.is_empty() and scene.story.history.size() == 1 and scene.story.history[0]["outcome"] == "a", "actual paid branch button records one irreversible story decision")
	check(scene.inventory.amount("materials") == materials - 2, "real narrative click debits its complete cost once")
	check(not scene.center.story_paid.visible and scene.center.story_history.text.contains("明天再调一次"), "resolved buttons disappear and actual outcome remains readable")
	await picture("res://docs/story-result.png")
	check(SaveSystem.validate(SaveSystem.capture(scene)).is_empty(), "story UI, guidance and final live world remain fully saveable")
	await keypress(KEY_ESCAPE)
	check(scene.tutorial_label.text.contains("O"), "completed guide hands the nonblocking HUD to the tracked optional objective")
	await dispose_scene(scene)
	await create_timer(0.12).timeout
	print("STORY VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
