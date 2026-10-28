extends "res://tests/test_tactical_campaign.gd"
## Boundary fixtures deliberately supply resources, move actors and isolate threats.
## The separate neighborhood journey proves reachability using ordinary play commands.
func district_trip(map_id: String="clinic",day: int=6) -> Node2D:
 var game:=fresh()
 game.simulation_time=(day-1)*720.0
 game.chronicle.manual_defense=false
 game.expansion.stage=2;game.expansion.collected.assign(['relay']);game.expansion.warm_nights=2
 game.inventory.deposit({'materials':30,'tools':8,'fuel':12,'medicine':4,'water':10},'declared neighborhood boundary fixture')
 game.end_day();game.choose_destination(map_id);game.cycle.roles.assign(['guard','bed','scavenge']);game.cycle.loadout={'materials':12,'tools':2,'fuel':4,'medicine':1,'water':2}
 expect(game.start_expedition(),'fixture departs through ordinary loadout validation')
 for enemy in game.expedition.enemies:enemy['hp']=0;enemy['mode']='dead'
 return game

func at(game: Node2D,id: String) -> void:
 var p:=NeighborhoodSystem.point(id)
 game.expedition.player_x=p.x;game.expedition.player_y=p.y;game.expedition.floor_level=NeighborhoodSystem.NODES[id]['floor'];game.expedition.climb_target=-1
 game.expedition_controls_override={}

func perform(game: Node2D,id: String) -> void:
 at(game,NeighborhoodSystem.ACTIONS[id]['node'])
 expect(game.neighborhood.start(game,id),'ordinary project starts: '+id+' / '+game.neighborhood.error(game,id,true))
 advance(game,float(NeighborhoodSystem.ACTIONS[id]['seconds'])+1)
 expect(game.neighborhood.work.is_empty(),'timed project completes: '+id)
 valid(game,'completed '+id)

func _run() -> void:
 var game:=district_trip();var f:ExpeditionState=game.expedition;var n:NeighborhoodSystem=game.neighborhood
 expect(f.interior.barrier('clinic',2440,110,0)==1,'right-to-left routes encounter the nearest closed door rather than the first array entry')
 expect(f.interior.barrier('clinic',110,2440,0)==0,'left-to-right routes encounter the nearest closed door')
 at(game,'generator');var before_damage:Dictionary=f.bag.duplicate()
 n.start(game,'restore_cold');advance(game,1);game.survivors[2].health-=1;advance(game,.1)
 expect(n.work.is_empty() and f.bag==before_damage,'taking a real health loss cancels unpaid project work')
 at(game,'generator');n.start(game,'restore_cold');advance(game,1);game.expedition_retreat()
 expect(n.work.is_empty() and f.bag==before_damage,'T cancels project work before initiating physical return')
 game.cycle.return_requested=false
 expect(f.persistent_loot and not game.regions['street'].persistent_loot,'first district has explicit persistent scope; other maps retain their old supply rules')
 expect(n.clinic['first_day']==6 and n.clinic['seen'],'cold-chain warning starts on discovery rather than destroying supplies before first visit')
 at(game,'generator');var original:Dictionary=f.bag.duplicate()
 expect(n.start(game,'restore_cold'),'start actual unpaid cold-chain restoration')
 advance(game,2)
 expect(f.bag==original and n.clinic['mode']=='sealed','travel-independent work duration grants no early output and charges nothing early')
 var pending:=SaveSystem.capture(game)
 expect(SaveSystem.apply_state(game,pending).is_empty() and not n.work.is_empty(),'unfinished on-site project survives validated restore')
 game.expedition_controls_override={'axis':-1.0};advance(game,.1)
 expect(n.work.is_empty() and f.bag==original,'manual movement cancels unfinished work without spending')
 at(game,'generator');expect(n.start(game,'restore_cold'),'restart cancelled cold restoration');advance(game,13)
 expect(n.clinic['mode']=='running' and n.clinic['fuel']==2 and f.bag['materials']==original['materials']-4 and f.bag['tools']==original['tools']-1 and f.bag['fuel']==original['fuel']-2,'completed restoration pays exact carried ingredients and stores fuel on-site')
 valid(game,'cold restored')
 var stock:Dictionary=game.inventory.snapshot();var report:Array[String]=[]
 n.dawn(game,report)
 expect(n.clinic['cold']==6 and n.clinic['stock']==2 and n.clinic['fuel']==1,'one dawn converts a finite two original doses and consumes one local fuel')
 expect(game.inventory.snapshot()==stock,'uncollected rescued medicine does not teleport into base stock')
 n.dawn(game,report)
 expect(n.clinic['cold']==6 and n.clinic['stock']==2 and n.clinic['fuel']==1,'repeat dawn cannot duplicate production or charge fuel twice')
 perform(game,'take_med')
 expect(n.clinic['stock']==0 and f.bag['medicine']==3,'medicine is physically taken from coldstore into the carried bag')
 # A paid demolition must fit completely; no disappearing overflow or remote credit.
 var full:Dictionary=f.bag.duplicate();f.bag['tools']=8;game.expansion.refresh_slots(f,game.survivors[f.actor_id])
 expect(not n.error(game,'strip_cold').is_empty(),'dismantling rejects insufficient bag space')
 f.bag=full
 perform(game,'strip_cold')
 expect(n.clinic['mode']=='stripped' and n.clinic['cold']==0 and n.clinic['spoiled']==6,'demolition permanently sacrifices only unrescued cold medicine')
 expect(not n.start(game,'restore_cold') and not n.start(game,'strip_cold'),'demolished generator cannot be restored or farmed repeatedly')
 valid(game,'exclusive permanent cold choice');game.free()

 game=district_trip('waterworks');f=game.expedition;n=game.neighborhood
 perform(game,'restore_water');perform(game,'connect');perform(game,'route_home')
 stock=game.inventory.snapshot();report=[];n.dawn(game,report)
 expect(game.inventory.amount('water')==int(stock['water'])+3 and n.water['stock']==3,'gravity supply sends three real water home and retains three at the pool')
 n.dawn(game,report)
 expect(game.inventory.amount('water')==int(stock['water'])+3 and n.water['stock']==3,'repeated dawn cannot farm home deliveries')
 # Explicit calendar fixture isolates the forecast boundary; actual-journey test advances normal nights.
 game.simulation_time+=720;game.cycle.night_start+=720;game.cycle.night_end+=720;game.cycle.night_day+=1;n.dawn(game,report)
 game.simulation_time+=720;game.cycle.night_start+=720;game.cycle.night_end+=720;game.cycle.night_day+=1;n.dawn(game,report)
 expect(n.water['leak']==1 and report.any(func(line):return '下一夜' in line),'old fitting warns an entire settlement before reduced production')
 game.simulation_time+=720;game.cycle.night_start+=720;game.cycle.night_end+=720;game.cycle.night_day+=1;stock=game.inventory.snapshot();n.dawn(game,report)
 expect(n.water['leak']==2 and game.inventory.amount('water')==int(stock['water'])+1,'forecast leakage changes output and route yield instead of secretly deleting stock')
 perform(game,'repair_leak')
 expect(n.water['leak']==3,'repair permanently resolves this one aging fault')
 game.simulation_time+=720;game.cycle.night_start+=720;game.cycle.night_end+=720;game.cycle.night_day+=1;stock=game.inventory.snapshot();n.dawn(game,report)
 expect(n.water['leak']==3 and game.inventory.amount('water')==int(stock['water'])+3,'fixed output stays restored without an endless repair tax')
 perform(game,'route_clinic');stock=game.inventory.snapshot()
 game.simulation_time+=720;game.cycle.night_start+=720;game.cycle.night_end+=720;game.cycle.night_day+=1;n.dawn(game,report)
 expect(game.inventory.amount('water')==int(stock['water']),'clinic diversion really gives up direct home water delivery')
 perform(game,'take_water')
 expect(f.bag['water']>2 and n.water['stock']<18,'pool pickup observes produced stock and physical bag room')
 f.active=false;f.loot_site=-1
 for site in f.sites:site['contents'].clear()
 for e in f.enemies:e['hp']=0;e['mode']='dead'
 var empty:=f.sites.duplicate(true);f.refresh_for_day(20)
 expect(f.sites==empty and f.enemies.all(func(e):return e['hp']==0),'persistent district does not restock ordinary containers or resurrect every enemy on revisit')
 game.free()

 game=district_trip();f=game.expedition;n=game.neighborhood
 at(game,'patient');var count:int=game.survivors.size()
 expect(n.node_visible(game,'patient') and n.start(game,'rescue'),'named stranded member is physically available after the existing recruitment date')
 advance(game,9)
 expect(n.rescue['state']=='carried' and f.carrying_person and game.survivors.size()==count,'finishing bandaging creates a carried rescue, not an instant remote recruit')
 expect(f.extra_slots==3 and BackpackStacks.carried(f,game.survivors[2],[]).filter(func(e):return e['kind']=='rescue').size()==2,'carried person occupies exactly two visible inventory slots in addition to equipped knife')
 valid(game,'carried rescue')
 pending=SaveSystem.capture(game)
 expect(SaveSystem.apply_state(game,pending).is_empty() and f.carrying_person and f.extra_slots==3,'restore derives both carrying penalty and two-slot occupancy')
 for d in f.interior.doors:d['open']=true
 f.player_x=1000;f.player_y=620;f.floor_level=0
 var x:=f.player_x;f.tick(.1,game.survivors[2],{'axis':1.0})
 expect(f.player_x-x<19,'back carrying has an actual walking penalty')
 f.player_x=90;game.expedition_controls_override={};game.expedition_retreat();game.confirm_departure()
 expect(n.rescue['state']=='safe' and game.survivors.size()==count+1 and game.survivors.back().person.persona=='gu','only actual successful exit recruits the rescued physician')
 expect(game.people.relationship(2,3)==55 and not game.self_care.members['gu']['medical'],'rescue builds a remembered relationship without authorizing medicine spending')
 expect(n.memories.any(func(m):return m['kind']=='rescued'),'ordinary return credits cargo and records named rescue outcome')
 valid(game,'rescued survivor with complete night-role and relationship records')
 var saved:=SaveSystem.capture(game)
 expect(SaveSystem.apply_state(game,saved).is_empty() and game.survivors.size()==count+1,'restoring a completed rescue never recruits twice')
 # Memory changes target selection at comparable severity; critical needs take precedence.
 game.begin_day()
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,a.survivor_id==3);a.hunger=20;a.fatigue=20;a.person.thirst=20;a.health=100;a.injury=0
 game.survivors[0].health=65;game.survivors[2].health=67
 game.self_care.members['gu']['manual_until']=0
 game.self_care.set_cooperation(game,game.survivors[3],'medical',true);advance(game,1.1)
 expect(game.self_care.members['gu']['aid'].get('target',-1)==2,'authorized rescued doctor remembers the rescuer when injuries are close')
 game.cancel_selected();game.self_care.manual(game,3);game.self_care.members['gu']['manual_until']=0;game.survivors[0].health=15
 advance(game,1.1)
 expect(game.self_care.members['gu']['aid'].get('target',-1)==0,'critical injuries override personal gratitude')
 game.free()

 game=district_trip();f=game.expedition;n=game.neighborhood
 perform(game,'rescue');game.survivors[f.actor_id].health=0;f.tick(.01,game.survivors[f.actor_id],{})
 expect(n.rescue['state']=='lost' and game.survivors.size()==3,'death during extraction loses the rescue instead of granting an immortal companion')
 valid(game,'failed rescue');game.free()

 game=fresh();var store:=SaveSystem.new();store.path='res://tests/fixtures/v19_neighborhood_upgrade_campaign.json';var read:=store.read_state()
 expect(read['ok'] and SaveSystem.apply_state(game,read['data']).is_empty(),'actual published schema19 unfinished save migrates through the regular reader')
 expect(SaveSystem._same_items(game.inventory.snapshot(),read['data']['stock']) and game.neighborhood.work.is_empty(),'migration preserves inventory and never awards completed projects')
 valid(game,'actual schema19 migration')
 var pristine:=SaveSystem.capture(game)
 for key in ['cold','fuel','stock','target','rescue','work','memory','future']:
  var bad:Dictionary=pristine.duplicate(true)
  match key:
   'cold':bad['neighborhood']['clinic']['cold']=9
   'fuel':bad['neighborhood']['clinic']['fuel']=-1
   'stock':bad['neighborhood']['water']['stock']=INF
   'target':bad['neighborhood']['water']['target']='nowhere'
   'rescue':bad['neighborhood']['rescue']['state']='carried'
   'work':bad['neighborhood']['work']={'id':'restore_water','elapsed':1,'health':100}
   'memory':bad['neighborhood']['memories']=[{'day':1,'kind':'fake','actor':'lin','other':''}]
   'future':bad['neighborhood']['last_day']=99999
  expect(not SaveSystem.apply_state(game,bad).is_empty() and SaveSystem.capture(game)==pristine,'invalid '+key+' rejected before touching the live world')
 game.free()
 print('NEIGHBORHOOD RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
