extends "res://tests/test_cooperation_motion.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var phase:String=args[0];var path:String=args[1];var game:Node2D
 if phase=='aid_write':
  game=care();advance(game,.1)
  expect(game.self_care.members['xu']['action']=='aid' and game.inventory.amount('medicine')==2,'save a real unpaid medical approach')
 elif phase=='room_write':
  game=trip(false);var f:ExpeditionState=game.expedition;var e:Dictionary=f.enemies[0]
  e['x']=600;e['floor']=0;e['target']=600;e['target_floor']=0;e['memory']=5;e['mode']='investigate'
  EnemyMind.investigate(f,e,.1,false)
  expect(not f.minds[0]['search'].is_empty(),'save an actual last-known-position investigation')
 else:
  game=fresh();game.persistence_enabled=true;game.save_store.path=path
  expect(game.load_game(),'normal loader reads this new-process save')
  expect(game.paused,'new process resumes paused')
  game.paused=false
  if phase=='aid_finish':
   expect(game.self_care.members['xu']['action']=='aid' and game.inventory.amount('medicine')==2,'approach and medical authorization survive a process boundary')
   advance(game,20)
   expect(game.inventory.amount('medicine')==1 and game.survivors[0].health>=85 and game.selected_id==2,'continued physical treatment pays once and preserves player selection')
  elif phase=='room_finish':
   var f:ExpeditionState=game.expedition;var remembered:Array=f.minds[0]['search']['destinations'].duplicate()
   expect(not remembered.is_empty(),'room investigation plan survives a process boundary')
   game.expedition_controls_override={'sneak':true}
   advance(game,7)
   game.expedition_controls_override=null
   expect(f.minds[0]['search'].is_empty() and f.enemies[0]['mode']=='patrol','restored investigation uses its remaining budget and returns to patrol')
 valid(game,'cooperation process '+phase)
 game.save_store.path=path
 expect(game.save_store.write_state(game)['ok'],'normal atomic writer commits '+phase)
 game.free();await create_timer(.1).timeout
 print('COOPERATION PROCESS '+phase+': '+str(checks)+' checks, '+str(failures)+' failures');quit(1 if failures else 0)
