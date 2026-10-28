extends "res://tests/test_tactical_campaign.gd"
const NEW_IDS := ['lara','joel','ellie','jill','liu','wick']
func ready_recruit(game: Node2D,id: String) -> Survivor:
 game.simulation_time=29*720
 game.upkeep.level=1
 game.people.last_day=ExpeditionState.day_at(game.simulation_time)
 game.inventory.deposit({'raw_food':100,'water':100,'medicine':100,'materials':100,'tools':10,'fuel':30,'meals':30},'explicit roster test provisions')
 expect(game.people.recruit(game,id),'ordinary arrival recruits '+id)
 return game.survivors.back()
func _run() -> void:
 expect(PeopleCatalog.DATA.size()==12,'twelve distinct recruitable identities')
 expect(PeopleCatalog.DATA['xu']['name']=='克里斯' and PeopleCatalog.DATA['gu']['name']=='灰原哀','superseded medical references are gone')
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
  if id=='joel':
   var listener:Survivor=g.survivors[0];listener.person.morale=40;listener.person.stress=50
   g.residence.finish(g,'music',actor)
   expect(is_equal_approx(listener.person.morale,48) and is_equal_approx(listener.person.stress,35.6),'Joel guitar bonus changes actual companion mood')
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
