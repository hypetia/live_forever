extends "res://tests/test_tactical_campaign.gd"
const NEW_IDS := ['alice','conan','rick','tesla','pooh','mickey']
func ready_recruit(game: Node2D,id: String) -> Survivor:
 game.simulation_time=29*720
 game.upkeep.level=1
 game.people.last_day=ExpeditionState.day_at(game.simulation_time)
 game.inventory.deposit({'raw_food':100,'water':100,'medicine':100,'materials':100,'tools':10,'fuel':30,'meals':30},'explicit roster test provisions')
 expect(game.people.recruit(game,id),'ordinary arrival recruits '+id)
 return game.survivors.back()
func _run() -> void:
 expect(PeopleCatalog.DATA.size()==12,'twelve distinct recruitable identities')
 expect(PeopleCatalog.DATA['xu']['name']=='黑杰克' and PeopleCatalog.DATA['gu']['name']=='端木蓉','superseded medical references are gone')
 for id in NEW_IDS:
  var g:=fresh()
  expect(not g.people.offers(g).has(id),'new character is not available before arrival: '+id)
  g.simulation_time=(int(PeopleCatalog.DATA[id]['day'])-1)*720
  expect(g.people.offers(g).has(id),'arrival becomes available on advertised day: '+id)
  var actor:=ready_recruit(g,id)
  expect(actor.display_name==PeopleCatalog.DATA[id]['name'] and actor.speciality==PeopleCatalog.DATA[id]['role'],'identity and actual profession agree: '+id)
  expect(not CharacterAbilities.description(id).is_empty(),'new identity has a usable ability description: '+id)
  var arc:Dictionary=ChronicleCatalog.ARCS[id]
  expect(g.regions.has(arc['map']) and arc['site']>=0 and arc['site']<g.regions[arc['map']].sites.size(),'personal quest targets a real site: '+id)
  valid(g,'recruited '+id)
  var saved:=SaveSystem.capture(g)
  var target:=fresh()
  expect(SaveSystem.apply_state(target,saved).is_empty() and target.survivors.back().person.persona==id,'actual new recruit restores: '+id)
  target.free()
  var stock:Dictionary=g.inventory.snapshot()
  expect(not g.people.recruit(g,id) and stock==g.inventory.snapshot(),'duplicate join never costs supplies: '+id)
  g.end_day()
  g.cycle.roles.assign(['guard','guard','guard','scavenge'])
  g.cycle.loadout={}
  expect(g.cycle.capacity(g)==CampaignCycle.BAGS[id],'night capacity follows new character: '+id)
  expect(g.start_expedition(),'new character can actually depart: '+id)
  valid(g,'new identity in active expedition '+id)
  var saved_trip:=SaveSystem.capture(g)
  expect(SaveSystem.apply_state(g,saved_trip).is_empty(),'active expedition restores new identity '+id)
  g.expedition.player_x=90;g.expedition_retreat();g.confirm_departure();g.begin_day()
  expect(g.cycle.phase=='day','new character can return to base '+id)
  if id=='pooh':
   var target_actor:Survivor=g.survivors[0]
   actor.person.morale=40;target_actor.person.morale=40
   var food:int=g.inventory.amount('meals');var trust:int=g.people.relationship(actor.survivor_id,0)
   g.select_survivor(actor.survivor_id)
   expect(g.people.support(g,0),'Pooh performs actual paid mutual support')
   expect(actor.person.morale==54 and target_actor.person.morale==54 and g.people.relationship(actor.survivor_id,0)==trust+14,'Pooh boosts actual mood and trust by forty percent')
   expect(g.inventory.amount('meals')==food-1 and not g.people.support(g,0),'Pooh still pays food and respects mutual support cooldown')
  if id=='alice':
   actor.hunger=10;var baseline:Survivor=g.survivors[0];baseline.hunger=10
   SurvivalRules.tick(actor,10);SurvivalRules.tick(baseline,10)
   expect(is_equal_approx(actor.hunger-10,(baseline.hunger-10)*1.15),'Alice strong recovery has a real fifteen-percent appetite cost')
  if id=='tesla':
   actor.fatigue=10;var baseline:Survivor=g.survivors[0];baseline.fatigue=10
   SurvivalRules.tick(actor,10);SurvivalRules.tick(baseline,10)
   expect(is_equal_approx(actor.fatigue-10,(baseline.fatigue-10)*1.1),'Tesla workload has a real ten-percent fatigue cost')
  g.free()
  for choice in [0,1]:
   g=fresh();actor=ready_recruit(g,id)
   expect(g.chronicle.choice(g,id,choice),'new personal belief is selectable '+id+str(choice))
   expect(CharacterAbilities.factor(actor,'work')==float(CharacterAbilities.PROFILES[id].get('work',1)),'belief alone grants no unfinished perk '+id)
   # Declared evidence fixture: focus on each new finale and paid work; real search/return is covered by tactical tests.
   g.chronicle.arcs[id]['stage']=2
   actor.position=g.facility.work_position()
   var before:Dictionary=g.inventory.snapshot()
   expect(g.chronicle.start_work(g,id),'personal finale starts for '+id+str(choice))
   advance(g,3)
   expect(g.chronicle.arcs[id]['stage']==2 and g.inventory.snapshot()==before,'partial personal work grants no perk or debit '+id)
   advance(g,13)
   expect(g.chronicle.arcs[id]['stage']==3,'new personal finale finishes '+id+str(choice))
   for resource in arc['cost']:
    expect(g.inventory.amount(resource)==int(before[resource])-int(arc['cost'][resource]),'finale pays exact '+resource+' '+id)
   for key in ChronicleCatalog.PERKS[id][choice]:
    var expected:float=float(CharacterAbilities.PROFILES[id].get(key,1))*float(ChronicleCatalog.PERKS[id][choice][key])
    expect(is_equal_approx(CharacterAbilities.factor(actor,key),expected),'completed perk affects actual '+key+' '+id)
   valid(g,'completed new personal arc '+id+str(choice))
   g.free()
 var g:=fresh()
 for id in PeopleCatalog.CANDIDATES:
  if g.survivors.filter(func(a):return a.health>0).size()==5:
   var victim:Survivor=g.survivors.filter(func(a):return a.health>0)[0]
   g.scheduler.mark_dead(victim,'declared long-roster casualty fixture')
  ready_recruit(g,id)
  valid(g,'extended history through '+id)
 expect(g.survivors.size()==12 and g.people.deaths.size()==7,'all twelve identities fit persistent history without resurrection')
 g._process(0)
 expect(g.cards.filter(func(c):return c.visible).size()==5,'casualty history leaves only five live HUD cards')
 var saved:=SaveSystem.capture(g);var target:=fresh()
 expect(SaveSystem.apply_state(target,saved).is_empty() and target.survivors.size()==12,'full twelve-person history restores atomically')
 target.end_day();target.interface.refresh(true)
 expect(target.interface.role_options.filter(func(o):return o.visible).size()==5,'night planner keeps five visible live assignments after seven losses')
 for o in target.interface.role_options:
  if o.visible:expect(o.position.y+o.size.y<750,'expanded history cannot push living roles offscreen')
 valid(target,'night plan with full casualty history')
 target.free();g.free()
 print('ROSTER RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
