extends "res://tests/test_shelter.gd"
func fresh() -> Node2D:
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate()
 game.persistence_enabled=false;root.add_child(game);game.set_process(false);return game
func valid(game: Node2D,label: String) -> void:
 var error:=SaveSystem.validate(SaveSystem.capture(game));expect(error.is_empty(),label+': '+error)
func trip(clear: bool = true) -> Node2D:
 var game:=fresh();game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.cycle.loadout={'tools':1}
 expect(game.start_expedition(),'ordinary first-night departure commits the actual carried tool')
 if clear:
  for e in game.expedition.enemies:e['hp']=0;e['mode']='dead'
 return game
func _run() -> void:
 for id in ChronicleCatalog.SCENARIOS:
  var game:=fresh();game.next_scenario=id;game.start_new_game()
  expect(game.survivors.map(func(a):return a.person.persona)==ChronicleCatalog.SCENARIOS[id]['roster'],id+' has its own actual roster')
  expect(game.inventory.snapshot()==ChronicleCatalog.SCENARIOS[id]['stock'],id+' starts with exactly the announced stock')
  valid(game,id+' fresh scenario')
  var before:=SaveSystem.capture(game)
  expect(SaveSystem.apply_state(game,before).is_empty() and game.chronicle.scenario==id,id+' restores without re-granting starting items')
  expect(game.inventory.snapshot()==before['stock'],id+' has no load-time supply duplication')
  game.free()
 var game:=trip();var f:ExpeditionState=game.expedition;var actor:Survivor=game.survivors[2]
 var first:Dictionary=InteriorState.layout('street')[0];var x:float=first['x']
 f.player_x=x-24;f.floor_level=0;f.player_y=620
 f.tick(.05,actor,{'axis':1.0,'sprint':true})
 expect(f.player_x<x and not f.interior.doors[0]['open'],'closed doorway physically stops movement')
 expect(not f.interior.clear_sight('street',x-30,x+40,0),'closed wall blocks sight')
 f.tick(.1,actor,{'peek':true})
 expect(f.interior.visible(f,x+80,0),'leaning near the door reveals a bounded adjacent view')
 f.tick(.01,actor,{})
 expect(not f.interior.visible(f,x+80,0),'releasing peek does not grant permanent live x-ray vision')
 for n in range(100):f.tick(.02,actor,{'interact':true})
 expect(f.interior.doors[0]['open'],'held use completes a physical door opening')
 var open:bool=f.interior.doors[0]['open']
 for n in range(100):f.tick(.02,actor,{'interact':true})
 expect(f.interior.doors[0]['open']==open,'holding use cannot repeatedly toggle the same door')
 f.tick(.01,actor,{})
 for n in range(100):f.tick(.02,actor,{'interact':true})
 expect(not f.interior.doors[0]['open'],'release and use again closes the real door')
 valid(game,'closed physical door snapshot')
 for n in range(200):f.tick(.02,actor,{'window':true})
 expect(f.interior.doors[0]['window']==1 and f.bag['tools']==0,'quiet window opening consumes one actual tool on completion')
 f.tick(.01,actor,{})
 var from:=f.player_x
 for n in range(80):f.tick(.02,actor,{'window':true})
 expect(f.player_x>x and from<x,'vaulting physically interpolates to the opposite side of the wall')
 valid(game,'completed window crossing')
 var before_stock:Dictionary=game.inventory.snapshot()
 game.expedition_retreat()
 for n in range(4000):
  game.advance_simulation(.02)
  if game.departure_dialog.visible:game.confirm_departure();break
 expect(game.cycle.phase=='dawn','T return traverses and opens closed intervening doors rather than getting stuck')
 expect(game.inventory.amount('tools')==before_stock['tools'],'spent opening tool is not refunded on return')
 valid(game,'return with room history')
 game.free()
 game=trip();f=game.expedition;actor=game.survivors[2];x=InteriorState.layout('street')[0]['x'];f.player_x=x-30
 for n in range(180):f.tick(.02,actor,{'window':true,'sprint':true})
 expect(f.interior.doors[0]['window']==2 and f.bag['tools']==1,'force-breaking a window preserves the tool and records broken glass')
 expect(f.noise_burst>40,'breaking glass creates actual hearing noise')
 valid(game,'loud window route')
 game.free()
 # Brain rules are tested with explicit stable stand-ins, not as a balance proof.
 game=trip(false);f=game.expedition;actor=game.survivors[2]
 f.enemies[1]['x']=1100.0
 for d in f.interior.doors:d['open']=true
 var e:Dictionary=f.enemies[0]
 e['x']=700;e['floor']=0;e['direction']=-1;e['suspicion']=90;f.player_x=620;f.minds[0]['role']=2
 f.tick(.05,actor,{})
 expect(f.minds[0]['call']>13,'a caller visibly commits to a bounded alarm cooldown')
 expect(f.enemies[1]['memory']>0 and f.enemies[1]['target']!=f.player_x,'nearby allies investigate the caller position rather than learning hidden player coordinates')
 e['x']=1000;e['mode']='patrol';e['suspicion']=0;f.player_x=600
 f.decoys.assign([{'x':1005.0,'floor':0,'remaining':15.0}])
 f.tick(.02,actor,{})
 expect(f.minds[0]['investigations']==1 and EnemyMind.ignores(f,e,f.decoys[0]),'investigated lure position is remembered and can be rejected')
 valid(game,'persistent distinct enemy minds')
 game.free()
 # Personal choices require physical successful reconnaissance and paid work.
 game=fresh();var material:int=game.inventory.amount('materials')
 expect(game.chronicle.choice(game,'lin',0),'living engineer chooses a concrete personal approach')
 expect(game.inventory.amount('materials')==material-2 and not game.chronicle.choice(game,'lin',0),'choice cost is paid once')
 game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.start_expedition()
 game.expedition=game.expedition # Evidence callback is separately bound to the active field.
 game.chronicle.arcs['lin']['stage']=2 # Declared completion-of-recon fixture for the construction half.
 game.expedition.player_x=90;game.expedition_retreat();game.confirm_departure();game.begin_day()
 expect(game.chronicle.start_work(game,'lin'),'personal finale starts an actual trip to the workbench')
 expect(game.chronicle.arcs['lin']['stage']==2,'starting a personal project does not immediately grant its perk')
 valid(game,'walking personal project')
 advance(game,35)
 expect(game.chronicle.arcs['lin']['stage']==3 and CharacterAbilities.factor(game.survivors[0],'work')>1,'completed work pays its recipe and unlocks the chosen gameplay perk')
 valid(game,'finished character arc')
 var pristine:=SaveSystem.capture(game)
 for change in ['scenario','stage','future','role','health','window','seen','work','siege']:
  var bad:Dictionary=pristine.duplicate(true)
  match change:
   'scenario':bad['chronicle']['scenario']='unknown'
   'stage':bad['chronicle']['arcs']['lin']['stage']=4
   'future':bad['chronicle']['arcs']['lin']['last_trip']=99999
   'role':bad['expedition']['minds'][0]['role']=99
   'health':bad['expedition']['interior']['doors'][0]['hp']=INF
   'window':bad['expedition']['interior']['doors'][0]['window']=4
   'seen':bad['expedition']['interior']['seen']=[0,0]
   'work':bad['chronicle']['work']={'actor':99,'id':'lin','elapsed':1,'health':100}
   'siege':bad['siege']['gate']=-1
  expect(not SaveSystem.apply_state(game,bad).is_empty() and SaveSystem.capture(game)==pristine,'invalid '+change+' is rejected before any mutation')
 var legacy:=SaveSystem.new();legacy.path='res://tests/fixtures/v17_autonomous_drink_campaign.json'
 var read:Dictionary=legacy.read_state()
 expect(read['ok'] and SaveSystem.apply_state(game,read['data']).is_empty(),'authentic published schema17 unfinished self-care migrates')
 if read['ok']:
  expect(SaveSystem._same_items(game.inventory.snapshot(),read['data']['stock']) and JSON.stringify(game.self_care.members)==JSON.stringify(read['data']['self_care']['members']),'migration retains actual supplies and pending autonomy')
  expect(game.regions.values().all(func(field):return field.interior.doors.all(func(d):return d['open'])),'old saves preserve previously traversable paths instead of closing doors around actors')
 valid(game,'authentic schema17 migration')
 game.free()
 print('TACTICAL RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
