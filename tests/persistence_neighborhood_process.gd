extends "res://tests/test_neighborhood.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var phase:String=args[0];var path:String=args[1];var game:Node2D
 if phase=='work_write':
  game=district_trip();at(game,'generator');game.neighborhood.start(game,'restore_cold');advance(game,3)
  expect(game.neighborhood.clinic['mode']=='sealed' and not game.neighborhood.work.is_empty(),'write unfinished paid-on-completion field project')
 elif phase=='carry_write':
  game=district_trip();perform(game,'rescue')
  expect(game.expedition.carrying_person and game.survivors.size()==3,'write actual carried rescue before extraction')
 else:
  game=fresh();game.persistence_enabled=true;game.save_store.path=path
  expect(game.load_game() and game.paused,'ordinary loader reads new-process save and pauses')
  game.paused=false;game.expedition_controls_override={}
  if phase=='work_finish':
   expect(game.neighborhood.work['elapsed']>=2.9 and game.neighborhood.clinic['mode']=='sealed','project retains elapsed work without granting output on load')
   var bag:Dictionary=game.expedition.bag.duplicate();advance(game,11)
   expect(game.neighborhood.work.is_empty() and game.neighborhood.clinic['mode']=='running' and game.expedition.bag['materials']==int(bag['materials'])-4,'restored physical project completes once and pays carried ingredients once')
  elif phase=='work_verify':
   var bag:Dictionary=game.expedition.bag.duplicate();advance(game,1)
   expect(game.neighborhood.clinic['mode']=='running' and game.expedition.bag==bag,'another process cannot repeat completed construction or payment')
  elif phase=='carry_return':
   expect(game.expedition.carrying_person and game.expedition.extra_slots==3,'new process restores back-carry penalty and visible slot reservation')
   game.expedition_controls_override=null;game.expedition_retreat()
   for i in range(9000):
    game.advance_simulation(1.0/60)
    if game.departure_dialog.visible:game.confirm_departure();break
   expect(game.neighborhood.rescue['state']=='safe' and game.survivors.size()==4,'real route from the patient through doors leads to one rescued recruit')
  elif phase=='carry_verify':
   expect(game.neighborhood.rescue['state']=='safe' and game.survivors.size()==4 and not game.expedition.carrying_person,'completed rescue stays complete without duplicate members')
 valid(game,'neighborhood process '+phase)
 game.save_store.path=path;expect(game.save_store.write_state(game)['ok'],'normal atomic writer saves '+phase)
 game.free();await create_timer(.1).timeout
 print('NEIGHBORHOOD PROCESS '+phase+': %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
