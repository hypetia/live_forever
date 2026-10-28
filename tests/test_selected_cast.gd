extends "res://tests/test_roster_expansion.gd"
func setup(id: String) -> Node2D:
 var g:=fresh()
 ready_recruit(g,id)
 g.self_care.sync(g)
 for a:Survivor in g.survivors:g.self_care.set_enabled(g,a,false)
 return g
func _run() -> void:
 var expected_names:= ['阿笠博士','黑杰克','里昂','小当家','端木蓉','詹姆斯·邦德','爱丽丝','柯南','瑞克','特斯拉','小熊维尼','米老鼠']
 expect(PeopleCatalog.DATA.values().map(func(d):return d['name'])==expected_names,'the twelve selected identities match the user roster exactly')
 var g:=setup('mickey');var m:Survivor=g.survivors.back();g.select_survivor(m.survivor_id)
 for id in GoalCatalog.TRADE_IDS:
  var q:Dictionary=g.goals.trade_output(g,id)
  expect(q['water']==GoalCatalog.TRADES[id]['output']['water']+2 and q['fuel']==int(GoalCatalog.TRADES[id]['output'].get('fuel',0))+1,'Mickey quote includes exact negotiation specialty '+id)
 var stock:Dictionary=g.inventory.snapshot();var q:Dictionary=g.goals.trade_output(g,'materials')
 expect(g.goals.trade(g,'materials'),'Mickey commits the displayed trade')
 expect(g.inventory.amount('materials')==int(stock['materials'])-4 and g.inventory.amount('water')==int(stock['water'])+q['water'] and g.inventory.amount('fuel')==int(stock['fuel'])+q['fuel'],'Mickey pays full input and receives exactly the quote')
 var after:=SaveSystem.capture(g)
 expect(not g.goals.trade(g,'medicine') and SaveSystem.capture(g)==after,'changing trade category cannot bypass the two-day cooldown')
 valid(g,'negotiated actual trade');g.free()
 g=setup('pooh');var p:Survivor=g.survivors.back();var patient:Survivor=g.survivors[0]
 g.select_survivor(p.survivor_id);p.person.morale=40;patient.person.morale=40;patient.person.stress=60;patient.person.trauma=30
 expect(g.people.support(g,0),'Pooh performs a paid comforting meal')
 expect(patient.person.morale==54 and patient.person.stress==30 and patient.person.trauma==18,'Pooh comfort changes actual mood, stress and trauma')
 after=SaveSystem.capture(g)
 expect(not g.people.support(g,1) and SaveSystem.capture(g)==after,'Pooh cannot farm comfort by switching recipients')
 valid(g,'Pooh comfort and cooldown');g.free()
 g=setup('pooh');p=g.survivors.back();patient=g.survivors[0]
 p.position=SurvivalExpansion.job_position('picnic');patient.position=p.position+Vector2(80,0)
 g.survivors[1].position=Vector2(180,640);g.survivors[2].position=Vector2(950,430)
 for a:Survivor in g.survivors:a.person.morale=40;a.person.stress=60;a.person.trauma=20;a.hunger=30;a.person.thirst=30
 stock=g.inventory.snapshot();g.select_survivor(p.survivor_id)
 expect(g.expansion.start_job(g,'picnic'),'Pooh starts the real eight-second table activity')
 expect(g.inventory.amount('meals')==int(stock['meals'])-1 and g.inventory.amount('water')==int(stock['water'])-1,'picnic reserves its real food and water')
 advance(g,3)
 expect(g.chronicle.meal_day==0 and patient.person.morale<41 and CharacterMotion.shelter_context(p,g)['mode']=='share','partial preparation shows the sharing pose without granting benefits')
 var midway:=SaveSystem.capture(g);var b:=fresh()
 expect(SaveSystem.apply_state(b,midway).is_empty(),'paid midpoint restores without losing ingredients or granting the effect')
 advance(g,6);advance(b,6)
 expect(g.expansion.jobs.is_empty() and g.chronicle.meal_day==ExpeditionState.day_at(g.simulation_time),'only completed preparation consumes the daily group-meal opportunity')
 expect(patient.person.morale>44 and patient.person.stress<53 and patient.person.trauma<19 and patient.hunger<25 and patient.person.thirst<25,'nearby companion receives bounded comfort and a small shared portion')
 expect(g.survivors[1].person.morale<41 and g.survivors[2].person.morale<41 and g.survivors[1].hunger>30,'different floor and distant companions receive no remote picnic effect')
 expect(SaveSystem.capture(g)==SaveSystem.capture(b),'midpoint save and uninterrupted picnic produce identical state')
 after=SaveSystem.capture(g)
 expect(not g.expansion.start_job(g,'picnic') and g.inventory.snapshot()==after['stock'] and g.expansion.jobs.is_empty() and g.chronicle.meal_day==after['chronicle']['meal_day'],'completed picnic cannot repeat that day')
 valid(g,'completed physical picnic');valid(b,'restored physical picnic');g.free();b.free()
 g=setup('pooh');p=g.survivors.back();g.select_survivor(p.survivor_id);stock=g.inventory.snapshot()
 expect(g.expansion.start_job(g,'picnic'),'Pooh starts walking to the table')
 advance(g,1)
 expect(g.chronicle.meal_day==0,'walking to the table grants no daily benefit')
 g.expansion.cancel(g,p.survivor_id)
 expect(g.inventory.snapshot()==stock and g.chronicle.meal_day==0,'cancelling before completion refunds exact ingredients and preserves the daily opportunity')
 g.select_survivor(0);after=SaveSystem.capture(g)
 expect(not g.expansion.start_job(g,'picnic') and g.inventory.snapshot()==after['stock'] and g.expansion.jobs.is_empty(),'another character cannot claim Pooh special activity')
 g.free()
 g=setup('tesla');var engineer:Survivor=g.survivors.back();g.select_survivor(engineer.survivor_id);engineer.position=SurvivalExpansion.job_position('bat')
 expect(g.expansion.start_job(g,'bat'),'Tesla starts a real equipment project')
 advance(g,4)
 expect(float(g.expansion.jobs[0]['elapsed'])>4.8,'Tesla engineering factor advances actual equipment work faster')
 valid(g,'Tesla actual work');g.free()
 g=setup('rick');var shooter:Survivor=g.survivors.back();g.expansion.grant('pistol','rick');g.expansion.sync(g)
 g.end_day();g.cycle.roles.assign(['guard','guard','guard','scavenge']);g.cycle.loadout={};g.expansion.ammo=24;g.expansion.ammo_loadout=8
 expect(g.start_expedition(),'Rick departs with a real loaded pistol')
 # Isolated firing geometry, same live hit resolution used in ordinary exploration.
 var f:ExpeditionState=g.expedition;f.player_x=800;f.player_y=620;f.floor_level=0;f.facing=1
 for e in f.enemies:e['hp']=0;e['mode']='dead'
 var enemy:Dictionary=f.enemies[0];enemy['hp']=200;enemy['mode']='patrol';enemy['x']=850.0;enemy['floor']=0;enemy['climb_target']=-1
 for d in f.interior.doors:d['open']=true
 var hp:int=enemy['hp'];var magazine:int=f.magazine
 expect(f.attack(shooter),'Rick actually fires the equipped pistol')
 f._resolve_attack(shooter)
 expect(hp-int(enemy['hp'])==roundi(int(GearCatalog.ITEMS['pistol']['damage'])*1.25) and f.magazine==magazine-1,'actual ranged hit applies Rick bonus and consumes exactly one cartridge')
 g.free()
 print('SELECTED CAST RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
