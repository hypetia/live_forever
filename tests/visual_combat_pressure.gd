extends "res://tests/visual_campaign.gd"
var output := "/tmp/combat-pressure-gui"

func move_mouse(point: Vector2) -> void:
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	await process_frame;await process_frame

func fresh_game() -> Node2D:
	var g: Node2D=load("res://scenes/campaign.tscn").instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false);return g

func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var g := fresh_game();await process_frame
	g.simulation_time=11160 # Declared day-16 visual fixture, without awarding any story progress.
	g.districts.regions["street"]["heat"]=50.0
	g.enter_night_planning();await process_frame
	check(RegionalThreats.brief(g,"street").contains("声源暴露") and RegionalThreats.tier(16,50)==3,"night map forecast exposes calendar and regional noise pressure")
	check(g.regions["street"].enemies.any(func(e):return e["kind"]=="brute"),"later patrol composition includes an actual heavy enemy")
	await picture(output+"/pressure-night-plan.png")
	g.cycle.roles.assign(["guard","bed","scavenge"])
	await keypress(KEY_ENTER)
	check(g.expedition.active,"real confirmation departs after reading the patrol forecast")
	var f: ExpeditionState=g.expedition
	var a: Survivor=g.survivors[f.actor_id]
	# Controlled combat fixtures expose the telegraph without bypassing its real hit/collision logic.
	for enemy in f.enemies:enemy["hp"]=0;enemy["mode"]="dead"
	for door in f.interior.doors:door["open"]=true
	var e: Dictionary=f.enemies[0]
	e.merge({"x":410.0,"floor":0,"home_floor":0,"target_floor":0,"hp":90,"kind":"brute","mode":"windup","timer":.8,"direction":-1.0,"target":350.0,"brace":0.0,"climb_target":-1,"climb_progress":0.0},true)
	f.player_x=350;f.player_y=620;f.floor_level=0;f.facing=1;f.invulnerable=0
	f.interior.observe(f);g._process(0)
	await picture(output+"/pressure-brute-windup.png")
	var sample_point := Vector2i(g.world_offset()+(Vector2(float(e["x"])-g.expedition_view._camera()-156,354))*g.world_scale())
	var previous_pixel := root.get_texture().get_image().get_pixelv(sample_point)
	await move_mouse(g.world_offset()+(Vector2(e["x"]-g.expedition_view._camera(),540))*g.world_scale())
	await picture(output+"/pressure-enemy-hint.png")
	check(root.get_texture().get_image().get_pixelv(sample_point)!=previous_pixel,"physical pointer hover draws the contextual enemy counter card")
	var hp: int=e["hp"]
	await keypress(KEY_J);sim(g,.22)
	check(e["hp"]<hp and e["mode"]=="windup","physical J damages the armored brute without cancelling its heavy windup")
	await picture(output+"/pressure-committed-hit.png")
	check(90-int(e["hp"])>0 and 90-int(e["hp"])<CharacterAbilities.melee_damage(a,18,false),"visible front armor reduces actual knife damage")
	await held_key(KEY_A,true);await held_key(KEY_SHIFT,true);sim(g,.7);await held_key(KEY_A,false);await held_key(KEY_SHIFT,false)
	check(a.health==100 and e["cooldown"]>0,"actual retreat key moves out of the indicated heavy attack range")
	# A runner commits to one point and can be dodged through its rear.
	e.merge({"x":500.0,"hp":30,"kind":"runner","mode":"windup","timer":.24,"direction":1.0,"target":620.0,"brace":0.0,"cooldown":0.0},true)
	f.player_x=620;f.player_y=620;f.facing=-1;f.attack_cooldown=0;f.attack_windup=0;f.interior.observe(f);g._process(0)
	await picture(output+"/pressure-runner-pounce.png")
	await held_key(KEY_A,true);await held_key(KEY_SHIFT,true);sim(g,.3);await held_key(KEY_A,false);await held_key(KEY_SHIFT,false)
	check(e["x"]>530 and a.health==100,"runner lunges physically while actual sprint input can avoid its committed bite")
	check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),"armored combat, dodge and pounce remain saveable")
	await keypress(KEY_F3)
	check(g.chronicle_view.opened and g.paused,"combat counter information remains accessible through the character/archive panel")
	await keypress(KEY_ESCAPE)
	await dispose_scene(g)
	g=fresh_game();g.simulation_time=1800;g.cycle.seed=43;g.enter_night_planning();g.cycle.roles.assign(["guard","bed","guard"])
	await keypress(KEY_ENTER)
	check(g.siege.active and g.paused,"scheduled base defense still starts with deliberate paused preparation")
	await keypress(KEY_SPACE);sim(g,6)
	check(g.siege.enemies.size()>0,"base threat appears through actual wave timing")
	var brute: Dictionary=g.siege.enemies[0]
	brute.merge({"x":260.0,"y":640.0,"floor":0,"entry":0,"kind":"brute","hp":90,"direction":1.0,"mode":"windup","timer":.8,"brace":1.0,"hurt":0.0},true)
	g.paused=true;g._process(0);g.siege_view.queue_redraw()
	await move_mouse(g.world_root.to_global(Vector2(260,565)))
	await picture(output+"/pressure-base-defense.png")
	check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),"base armor, steady-state tell and wave timing remain valid")
	await dispose_scene(g)
	print("COMBAT PRESSURE VISUAL RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
