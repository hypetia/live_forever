extends "res://tests/visual_campaign.gd"
var output:=""

func capture(game: Node2D,name: String) -> void:
 game._process(0);game.queue_redraw();game.expedition_view.queue_redraw()
 await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(output.path_join(name+'.png'))

func _run() -> void:
 var args:=OS.get_cmdline_user_args();output=args[0] if not args.is_empty() else '/tmp/animation-polish-frames'
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 for a:Survivor in game.survivors:game.self_care.set_enabled(game,a,false)
 await process_frame;await process_frame
 # Actual day keyboard route, sampled once per real rendered frame.
 game.select_survivor(2)
 var actor:Survivor=game.survivors[2];var start:float=actor.position.x
 await held_key(KEY_D,true)
 for n in range(20):
  sim(game,1.0/30);await process_frame
  if n%4==0:await capture(game,'walk-%02d'%n)
 await held_key(KEY_D,false)
 check(actor.position.x>start+80 and actor.motion.phase>1,'day A/D movement drives the actual visible stride')
 for n in range(8):game.advance_simulation(1.0/60);await process_frame
 check(actor.motion.weight<.01,'releasing movement settles the displayed feet')
 # Injury fixture; all subsequent navigation/treatment/payments are real.
 var patient:Survivor=game.survivors[0];patient.health=55
 var medicine:int=game.inventory.amount('medicine')
 game.self_care.set_enabled(game,game.survivors[1],true);game.self_care.set_cooperation(game,game.survivors[1],'medical',true)
 var saw_patient:=false
 for n in range(80):
  sim(game,.1);await process_frame
  if game.survivors[1].activity.get('kind','')=='aid' and n%5==0:
   saw_patient=saw_patient or CharacterMotion.shelter_context(patient,game)['mode']=='patient'
   await capture(game,'medical-%03d'%n)
 check(saw_patient and game.inventory.amount('medicine')==medicine-1 and patient.health>=85,'rendered bedside care completes a real single paid treatment')
 check(game.selected_id==2,'two-person animation never steals player selection')
 game.free()
 game=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 # Arrival fixture follows the same paid recruitment used by the real game.
 game.simulation_time=17*720;game.people.last_day=18;game.upkeep.level=1
 check(game.people.recruit(game,'pooh') and game.people.recruit(game,'mickey'),'support pair joins through actual recruitment cost')
 game.self_care.sync(game)
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,false)
  a.position=Vector2([450,690,940,584,645][a.survivor_id],430)
 game.select_survivor(3)
 check(game.expansion.start_job(game,'picnic'),'actual table preparation starts')
 sim(game,3)
 check(CharacterMotion.shelter_context(game.survivors[3],game)['mode']=='share' and CharacterMotion.shelter_context(game.survivors[4],game)['mode']=='receive','host and idle companion render complementary sharing actions')
 await capture(game,'sharing')
 game.paused=true
 var frozen:=SaveSystem.capture(game);var phase:float=game.survivors[3].visual_time
 for n in range(8):await process_frame;RenderingServer.force_draw()
 check(SaveSystem.capture(game)==frozen and game.survivors[3].visual_time==phase,'paused animation preserves both simulation and display clocks')
 game.paused=false;sim(game,8)
 check(game.chronicle.meal_day==18,'sharing still completes using the existing daily limit')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'rendered interactions preserve a valid campaign')
 game.free()
 game=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.start_expedition()
 var f:ExpeditionState=game.expedition
 # Isolated contact fixture, actual weapon and hit resolution remain unchanged.
 for e in f.enemies:e['hp']=0;e['mode']='dead'
 var enemy:Dictionary=f.enemies[0];enemy['hp']=24;enemy['mode']='patrol';enemy['x']=680;enemy['floor']=0
 f.player_x=620;f.player_y=620;f.floor_level=0;f.facing=1
 for d in f.interior.doors:d['open']=true
 game.expedition_controls_override={}
 for n in range(45):
  if f.attack_cooldown<=0 and enemy['hp']>0:game.expedition_attack()
  sim(game,.05);await process_frame
  if n%4==0:await capture(game,'combat-%03d'%n)
 check(enemy['hp']==0 and game.expedition_view.combat_effects.marks.size()>0,'visible contact and death follow actual hits and blood events')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'animated combat remains saveable')
 game.free();await create_timer(.2).timeout
 print('ANIMATION POLISH VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
