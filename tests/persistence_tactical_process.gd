extends "res://tests/test_siege.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var phase:String=args[0];var path:String=args[1]
 var game:Node2D
 if phase=='write':
  game=trip();var f:ExpeditionState=game.expedition;f.player_x=float(InteriorState.layout('street')[0]['x'])-30
  for n in range(40):f.tick(.02,game.survivors[2],{'window':true})
  expect(f.interior.action.get('kind')=='window' and f.bag['tools']==1,'unfinished quiet opening pays nothing')
 elif phase=='raid':
  game=battle();game.paused=false;game.advance_simulation(5.2)
  expect(game.siege.wave==1 and game.siege.enemies.size()==2,'physical wave exists before process exit')
 else:
  game=fresh();var store:=SaveSystem.new();store.path=path;var read:=store.read_state()
  expect(read['ok'],'normal checksummed save reads in a new process')
  if read['ok']:expect(SaveSystem.apply_state(game,read['data']).is_empty(),'normal save restores before continuing')
  if phase=='read':
   var f:ExpeditionState=game.expedition
   expect(f.interior.action.get('kind')=='window' and f.bag['tools']==1,'unfinished opening survives process boundary')
   for n in range(200):f.tick(.02,game.survivors[2],{'window':true})
   expect(f.interior.doors[0]['window']==1 and f.bag['tools']==0,'resumed quiet opening consumes exactly one real tool')
   f.tick(.02,game.survivors[2],{})
   for n in range(15):f.tick(.02,game.survivors[2],{'window':true})
   expect(f.interior.action.get('kind')=='vault','mid-vault is persisted rather than teleporting to completion')
  elif phase=='vault':
   var f:ExpeditionState=game.expedition
   expect(f.interior.action.get('kind')=='vault','interrupted vault restores its route and timer')
   for n in range(100):f.tick(.02,game.survivors[2],{'window':true})
   expect(f.player_x>float(InteriorState.layout('street')[0]['x']) and f.bag['tools']==0,'resumed vault lands on the other side without a second charge')
  elif phase=='finish':
   expect(game.siege.active and game.siege.wave==1 and game.cycle.phase=='siege','active battle survives process restart')
   game.select_survivor(0);game.paused=false;game.move_selected(Vector2(140,640));game.advance_simulation(8)
   fight(game,160)
   expect(not game.siege.active and game.cycle.phase=='dawn','resumed enemies resolve through real movement and combat')
  elif phase=='verify':
   expect(not game.siege.active and game.siege.resolved_day==3 and game.cycle.phase=='dawn','finished battle remains finished after another process restart')
   var before:=SaveSystem.capture(game);game._settle_night([])
   expect(SaveSystem.capture(game)==before,'restoring the finished raid cannot settle or charge it twice')
 valid(game,'cross-process '+phase)
 var store:=SaveSystem.new();store.path=path
 expect(store.write_state(game)['ok'],'normal atomic save writes '+phase)
 game.free();await create_timer(.1).timeout
 print('TACTICAL PROCESS '+phase+': '+str(checks)+' checks, '+str(failures)+' failures');quit(1 if failures else 0)
