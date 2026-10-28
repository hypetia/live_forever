extends "res://tests/visual_campaign.gd"
func frame(game: Node2D,path: String) -> void:
 game._process(0);game.queue_redraw();game.expedition_view.queue_redraw()
 await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(path)
func _run() -> void:
 var output:=ProjectSettings.globalize_path('user://motion-frames')
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:output=args[0]
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 await process_frame;await process_frame
 for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.size=size
  for n in range(4):await process_frame
  await keypress(KEY_F4)
  check(game.chronicle_view.opened and game.chronicle_view.page=='cooperate' and game.paused,'F4 opens the actual cooperation policy page at '+str(size))
  check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(game.chronicle_view.window.get_global_rect()),'cooperation window fits at '+str(size))
  await keypress(KEY_ESCAPE)
 root.size=Vector2i(1440,900);await keypress(KEY_F4)
 var toggles:Array=[]
 for child in game.chronicle_view.body.get_children():
  if child is CheckBox:toggles.append(child)
 check(toggles.size()==6 and toggles[1].disabled and not toggles[3].disabled,'only actual medical specialists can authorize autonomous aid')
 await click_at(toggles[0].get_global_rect().get_center())
 check(game.self_care.members['lin']['shared_cooking'] and not game.self_care.members['xu']['shared_cooking'],'a real policy checkbox changes only its own resident')
 await picture('res://docs/v22-cooperation.png');await keypress(KEY_ESCAPE)
 # Declared injury fixture. Subsequent walking, timed care and payment are real.
 for a: Survivor in game.survivors:game.self_care.set_enabled(game,a,a.survivor_id==1)
 game.self_care.set_cooperation(game,game.survivors[1],'medical',true);game.survivors[0].health=55
 game.select_survivor(2);var med:int=game.inventory.amount('medicine')
 for n in range(48):
  sim(game,.16);await frame(game,output.path_join('aid-%03d.png'%n))
 check(game.inventory.amount('medicine')==med-1 and game.survivors[0].health>=85 and game.selected_id==2,'visible autonomous care completes one real paid treatment without selecting the medic')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'rendered paid care stays saveable')
 game.paused=true;var before:=SaveSystem.capture(game)
 for n in range(5):await process_frame;RenderingServer.force_draw()
 check(SaveSystem.capture(game)==before,'rendering joint animation while paused changes no saved simulation state')
 game.free()
 game=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.start_expedition()
 var f:ExpeditionState=game.expedition
 # Explicit combat display fixture: one real full-health enemy, no injected gear.
 for i in range(1,f.enemies.size()):f.enemies[i]['hp']=0;f.enemies[i]['mode']='dead'
 var e:Dictionary=f.enemies[0];f.player_x=620;e['x']=680;e['floor']=0;e['direction']=-1;e['mode']='patrol'
 for d in f.interior.doors:d['open']=true
 for n in range(60):
  if f.attack_cooldown<=0:game.expedition_attack()
  game.expedition_controls_override={};sim(game,.06);game.expedition_controls_override=null
  await frame(game,output.path_join('combat-%03d.png'%n))
 check(e['hp']==0 and game.expedition_view.combat_effects.marks.size()>0,'actual strikes kill the displayed enemy and leave hit-driven blood marks')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'animated combat preserves valid physical state')
 await picture('res://docs/v22-combat.png')
 game.free();await create_timer(.1).timeout
 print('COOPERATION MOTION VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
