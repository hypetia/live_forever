extends "res://tests/test_tactical_campaign.gd"
func battle() -> Node2D:
 var game:=fresh()
 game.simulation_time=1800;game.cycle.seed=43 # Declared third-night schedule fixture.
 game.enter_night_planning();game.cycle.roles.assign(['guard','guard','bed'])
 expect(game.start_expedition(),'all-stay night commits the same normal role and resource checks')
 expect(game.cycle.phase=='siege' and game.siege.active and game.paused,'scheduled night attack opens a real paused defense scene')
 return game
func fight(game: Node2D,seconds: float) -> void:
 for n in range(ceili(seconds*30)):
  if not game.siege.active:return
  var s:SiegeState=game.siege
  if game.paused:game.paused=false
  var actor:Survivor=game.survivors[game.selected_id]
  if s.gate>0 and not s.gate_open and actor.position.distance_to(Vector2(150,640))<85:s.toggle(game,'gate')
  var target:Dictionary={};var best:=INF
  for e in s.enemies:
   if e['hp']<=0 or e['escaped']:continue
   var d:float=actor.position.distance_to(Vector2(e['x'],e['y']))
   if d<best:best=d;target=e
  if not target.is_empty():
   if best<float(actor.weapon().get('reach',66))-2:s.attack(game,game.selected_id)
   elif actor.route.is_empty():
    var point:=Vector2(target['x'],target['y']);point.x=clampf(point.x+(1 if point.x<actor.position.x else -1)*45,140,960)
    game.move_selected(point)
  game.advance_simulation(1.0/30)
func _run() -> void:
 var game:=battle()
 valid(game,'initial real base defense')
 var start:=SaveSystem.capture(game);game.advance_simulation(3)
 expect(SaveSystem.capture(game)==start,'defense begins paused and cannot spend rounds or move before resuming')
 game.paused=false;game.advance_simulation(4)
 expect(game.siege.wave==0 and game.siege.enemies.is_empty(),'defenders receive the promised actual preparation time')
 game.advance_simulation(1.2)
 expect(game.siege.wave==1 and game.siege.enemies.size()==2,'first wave enters after a visible preparation interval')
 valid(game,'first defense wave')
 game.select_survivor(0);game.move_selected(Vector2(140,640));game.advance_simulation(5)
 expect(game.survivors[0].position.x>=150,'closed shelter entry blocks the actual controlled body')
 expect(game.siege.toggle(game,'gate'),'nearby player can explicitly open the shelter entry')
 fight(game,130)
 expect(game.survivors.all(func(a):return a.health>0),'the declared prepared defense can protect the whole original team')
 expect(not game.siege.active and game.cycle.phase=='dawn','physical defense resolves to ordinary dawn instead of an instant damage table')
 expect(game.siege.resolved_day==3 and game.cycle.report.any(func(s):return s.contains('亲自防守')),'morning records the actual wave, door, ammunition and stock results')
 valid(game,'finished physical raid')
 var before:=SaveSystem.capture(game);game._settle_night([])
 expect(SaveSystem.capture(game)==before,'a finished physical raid cannot also run the old abstract raid or grant a second night of rest')
 game.free()
 game=battle();game.paused=false;game.advance_simulation(5.1)
 # Declared damaged-gate fixture isolates repair payment and cancellation.
 game.siege.gate=25;game.select_survivor(0);game.move_selected(Vector2(190,640));game.advance_simulation(5)
 var mats:int=game.inventory.amount('materials')
 expect(game.siege.start_action(game,'repair',0),'a living defender at the real entry starts timed repair')
 game.advance_simulation(.5)
 expect(game.inventory.amount('materials')==mats,'repair does not consume before completion')
 valid(game,'unfinished physical repair')
 expect(SaveSystem.apply_state(game,SaveSystem.capture(game)).is_empty(),'active raid, monster routes and repair progress restore through the normal snapshot pipeline')
 game.siege.cancel(0);game.advance_simulation(.1)
 expect(game.inventory.amount('materials')==mats,'cancelling unfinished repair creates neither a charge nor a refund')
 game.free()
 game=battle();game.paused=false;game.advance_simulation(5.1);game.select_survivor(0)
 # An enemy between landings must not produce an off-stair destination for guards.
 game.siege.enemies[0]['x']=750.0;game.siege.enemies[0]['y']=535.0;game.siege.enemies[0]['route']=[]
 game.siege.enemies[1]['hp']=0
 game.survivors[1].route.clear();game.survivors[1].state=Survivor.TaskState.IDLE
 game.advance_simulation(.1)
 expect(game.survivors[1].route.all(func(p):return p.y in [430.0,640.0]),'guard interception of a climbing enemy uses real landings rather than off-stair offsets')
 valid(game,'guard pursues climbing enemy without an invalid save route')
 game.free()
 print('SIEGE RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
