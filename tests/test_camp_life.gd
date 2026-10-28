extends "res://tests/test_tactical_campaign.gd"
# Explicitly funded unit fixtures below are separate from the no-grant campaign runs.
func camp() -> Node2D:
 var g:=fresh()
 for a:Survivor in g.survivors:g.self_care.set_enabled(g,a,false)
 g.inventory.deposit({'raw_food':40,'water':40,'fuel':40,'materials':60,'tools':12,'medicine':8},'declared integration fixture')
 g.camp.food.add({'meat':8,'vegetables':8,'herbs':8,'seeds':6,'dirty_water':12,'compost':4},1)
 return g
func work(g: Node2D,kind: String,id: int=0,target: int=-1) -> void:
 expect(g.camp.food.start_job(g,kind,id,target),'start '+kind)
 advance(g,55)
 expect(not g.camp.food.busy(id),'physical completion '+kind)
 valid(g,'completed '+kind)
func date(g: Node2D,day: int) -> void:
 g.simulation_time=(day-1)*720.0
 g.cycle.night_day=maxi(1,day-1)
func _run() -> void:
 var g:=camp();var food:CampFood=g.camp.food
 expect(g.camp.enabled,'new campaigns enable integrated camp systems');valid(g,'initial camp')
 var stock:Dictionary=g.inventory.snapshot();var meat:=food.amount('meat');var veg:=food.amount('vegetables')
 expect(food.start_job(g,'balanced',0),'paid balanced meal starts')
 expect(g.inventory.amount('meals')==stock['meals'] and food.amount('meat')==meat-1 and food.amount('vegetables')==veg-1,'held ingredients, no early output')
 valid(g,'walking paid food job')
 expect(not g.expansion.start_job(g,'cook_batch',-1,1),'other cooking controller cannot reserve the occupied stove')
 var saved:=SaveSystem.capture(g);var restored:=fresh()
 expect(SaveSystem.apply_state(restored,saved).is_empty(),'restore physical paid production')
 advance(g,55);advance(restored,55)
 expect(g.inventory.amount('meals')==int(stock['meals'])+3,'exact balanced output')
 expect(SaveSystem.capture(g)==SaveSystem.capture(restored),'save midpoint does not duplicate ingredients or output');restored.free()
 stock=g.inventory.snapshot();meat=food.amount('meat');expect(food.start_job(g,'broth',0),'start cancellable broth')
 g._cancel_external(0);g._cancel_external(0)
 expect(g.inventory.snapshot()==stock and food.amount('meat')==meat,'repeated cancellation refunds once')
 expect(g.survivors[0].status_text()=='空闲','cancelled camp work clears stale walking status')
 valid(g,'cancelled food production')
 work(g,'planter');expect(food.infrastructure['plots']==1,'garden constructed after work')
 work(g,'plant_veg');expect(food.plots.size()==1 and not food.error(g,'harvest',0).is_empty(),'growing crop cannot be harvested early')
 work(g,'fertilize');expect(food.plots[0]['fed'],'one compost applied')
 date(g,3);veg=food.amount('vegetables');work(g,'harvest');expect(food.amount('vegetables')==veg+4 and food.plots.is_empty(),'fertilized harvest yields four vegetables and clears plot')
 expect(not food.start_job(g,'harvest',0),'harvest cannot repeat')
 work(g,'trap');work(g,'check_trap');expect(not food.start_job(g,'check_trap',0),'trap checks limited to once per day')
 work(g,'settling_filter');expect(food.infrastructure['filter'] and g.camp.situation.resilience['filter'],'filter unlocks both production and crisis protection')
 var water:int=g.inventory.amount('water');work(g,'filter_water');expect(g.inventory.amount('water')==water+4,'dirty water turns into exactly four safe units')
 var patient:Survivor=g.survivors[0];food.conditions[patient.person.persona]['fever']=60;food.conditions[patient.person.persona]['gut']=55;patient.infection=35
 expect(not food.start_job(g,'herbal_care',2,0),'nonmedic cannot perform herbal care')
 work(g,'herbal_care',1,0);expect(food.conditions[patient.person.persona]['fever']==35 and food.conditions[patient.person.persona]['gut']==35 and patient.infection>=35,'herbs reduce disease without curing bite infection')
 patient.infection=0;work(g,'recover',0);expect(food.conditions[patient.person.persona]['fever']<30 and food.rested[patient.person.persona]==3,'bed recovery progresses only at physical bed')
 g.cycle.night_day=3;g.cycle.roles.assign(['bed','floor','scavenge']);expect(food.isolated(g,0),'actual daytime recovery plus night bed provides isolation')
 g.cycle.roles[0]='guard';expect(not food.isolated(g,0),'guard duty is not isolation')
 g.free()
 # Age survives refunds; only actual stocked food rots, and compost has a use.
 g=camp();food=g.camp.food;food.lots.clear();food.add({'meat':2,'vegetables':2},1)
 var held:=food.take({'meat':1});food.add({'meat':1},2);food.refund(held)
 expect(food.take({'meat':1})[0]['born']==1,'refunded old food is consumed before newer food')
 date(g,3);var report:Array[String]=[];food.dawn(g,report)
 expect(food.amount('meat')==1 and food.amount('compost')>=1,'perishable food rots by original age')
 expect(g.inventory.amount('meals')==0 and food.spoiled>0,'two-day cooked food actually expires')
 var compost:=food.amount('compost');food.dawn(g,report);expect(food.amount('compost')==compost,'repeated dawn cannot repeat decay')
 valid(g,'aged food snapshot');g.free()
 # Relationships require attendance and real completed actions.
 g=camp();var society:CampRelations=g.camp.relations;var trust:int=g.people.relationship(0,1)
 expect(society.start(g,'talk',1,0),'start physical companion talk')
 expect(g.people.relationship(0,1)==trust,'starting conversation grants no early trust');valid(g,'walking companions')
 advance(g,55);expect(society.job.is_empty() and g.people.relationship(0,1)==trust+2,'arrived companions finish conversation and gain trust')
 var meals:int=g.inventory.amount('meals');expect(society.start(g,'meal',1,0),'group meal reserves two actual portions')
 expect(g.inventory.amount('meals')==meals-2,'shared meal has real cost')
 g._cancel_external(1);expect(society.job.is_empty() and g.inventory.amount('meals')==meals,'manual intervention cancels both partners and refunds')
 expect(society.start(g,'meal',1,0),'restart shared meal');advance(g,40)
 expect(g.chronicle.meal_day==1 and g.people.relationship(0,1)==trust+8,'completed shared meal raises trust and records daily limit')
 expect(not society.start(g,'meal',1,0),'daily shared meal cannot be farmed')
 g.people.bonds['0:1']=90;g.survivors[0].position=Vector2(500,430);g.survivors[1].position=Vector2(580,430)
 expect(is_equal_approx(society.work_factor(g,g.survivors[0]),1.1),'trusted nearby partner gives bounded work benefit')
 g.survivors[1].position=Vector2(580,640);expect(society.work_factor(g,g.survivors[0])==1,'different floor cannot grant proximity benefit')
 g.cycle.roles.assign(['guard','bed','scavenge']);g.survivors[0].fatigue=80
 for night in range(1,4):date(g,night+1);g.cycle.night_day=night;society.night(g,report)
 expect(not society.dispute.is_empty(),'three exhausting guard shifts create concrete duty dispute')
 expect(society.pledge(g),'player can make a concrete rotation promise');trust=g.people.relationship(0,1)
 date(g,5);g.cycle.night_day=4;g.cycle.roles.assign(['bed','guard','scavenge']);society.night(g,report)
 expect(g.people.relationship(0,1)==mini(100,trust+8) and society.promise.is_empty(),'actual next-night role rotation honors promise once')
 valid(g,'resolved duty dispute');g.free()
 # Forecasts and project counters change systems, with bounded once-only accounting.
 g=camp();var world:CampSituation=g.camp.situation
 expect(not world.forecast(9)['visible'] and world.forecast(10)['visible'],'migration has two-day warning')
 expect(world.active(12,'migration') and not world.active(15,'migration'),'migration lasts three days')
 expect(world.raid_bonus(12,1)==.25 and world.raid_bonus(12,2)==-.1,'two guards provide a real alternate response')
 date(g,10);work(g,'lure_horde');expect(world.diverted(12) and world.raid_bonus(12)==0,'physical lure redirects migration pressure')
 date(g,19);expect(world.water_output(19,6)==3,'water alert halves new production')
 work(g,'settling_filter');expect(world.water_output(19,6)==5,'permanent filtering mitigates water alert')
 date(g,26);expect(world.water_output(26,3)==0 and world.water_output(26,6,true)==6,'blackout stops electric pump but not gravity water')
 work(g,'backup_power');world.backup_on=true;g.cycle.night_day=26
 var fuel:int=g.inventory.amount('fuel');world.reserve_power(g);world.reserve_power(g)
 expect(world.powered_day==26 and g.inventory.amount('fuel')==fuel-1 and world.water_output(26,3)==3,'backup fuel paid once before pump resolution')
 date(g,33);expect(world.supply_factor(33)==.5,'scarcity reduces replenished grain')
 work(g,'supply_pact');expect(world.supply_factor(33)==.75,'supply pact softens scarcity')
 var before_cans:int=g.camp.food.amount('cans');work(g,'caravan_trade')
 expect(g.camp.food.amount('cans')==before_cans+2,'completed supply trade deposits exactly two real cans')
 expect(not g.camp.food.start_job(g,'caravan_trade',0),'supply trade has actual seven-day cooldown')
 valid(g,'prepared late-game camp');g.free()
 # Field stacks retain reservations even during interrupted eating.
 g=trip();food=g.camp.food;var field:ExpeditionState=g.expedition
 food.add({'cans':3,'drinks':4},1,food.cargo);g.expansion.refresh_slots(field,g.survivors[field.actor_id])
 expect(food.slots()==2,'typed food uses per-item stack limits')
 expect(food.use_cargo(g,'cans') and food.slots()==2,'eating from a partly full stack reserves existing slot')
 valid(g,'held field food reservation');field.moving=true;food.tick_field(g,.1);field.moving=false
 expect(food.amount('cans',food.cargo)==3 and food.field_action.is_empty(),'movement refunds held food and cancels action')
 expect(food.use_cargo(g,'drinks'),'start real field drink');var thirst:float=g.survivors[field.actor_id].person.thirst
 food.tick_field(g,1);expect(g.survivors[field.actor_id].person.thirst==thirst,'field use has no early effect');food.tick_field(g,1)
 expect(food.amount('drinks',food.cargo)==3,'completed field use consumes exactly one drink');valid(g,'field food completed')
 field.loot_site=0;food.open_cache(g);var before:=food.amount('cans');var got:=food.transfer(g,'cans',99)
 expect(got==2 and food.amount('cans')==before,'loot enters carried stacks rather than home stock')
 var key:=food.cache_key(field,0);food.caches[key].clear();food.open_cache(g);expect(food.caches[key].is_empty(),'empty cache remains empty after reopen')
 food.returned(g,true);expect(food.amount('cans')==before+5 and food.cargo.is_empty(),'only safe return deposits physical typed cargo')
 g.free()
 # Parallel plant orders must reserve capacity rather than overfill it on completion.
 g=camp();food=g.camp.food;food.infrastructure['plots']=1
 expect(food.start_job(g,'plant_veg',0),'first crop reserves the empty plot')
 expect(not food.start_job(g,'plant_herbs',1),'second crop cannot overbook one plot')
 g._cancel_external(0);expect(food.start_job(g,'plant_herbs',1),'cancelling planting frees the reserved plot')
 valid(g,'reserved plot job');g.free()
 # Food conditions have distinct causes and treatments; unsafe intake is never automatic.
 g=camp();food=g.camp.food;patient=g.survivors[0];patient.person.thirst=80;patient.infection=20
 work(g,'unsafe_drink');expect(food.conditions[patient.person.persona]['gut']==35 and patient.person.thirst<50 and patient.infection>=20,'unsafe water trades thirst relief for real intestinal illness')
 food.conditions[patient.person.persona]['fever']=60;food.conditions[g.survivors[1].person.persona]['fever']=0;food.conditions[g.survivors[2].person.persona]['fever']=0
 g.cycle.roles.assign(['bed','floor','scavenge']);date(g,2);food.dawn(g,report)
 expect(food.conditions[g.survivors[1].person.persona]['fever']==2 and food.conditions[g.survivors[2].person.persona]['fever']==0,'only exposed home companions receive bounded fever exposure')
 food.rested[patient.person.persona]=2;date(g,3);g.cycle.roles.assign(['bed','floor','scavenge']);food.dawn(g,report)
 expect(food.conditions[g.survivors[1].person.persona]['fever']==2,'actual recovery plus sleeping separately prevents the next exposure')
 valid(g,'distinct disease and isolation');g.free()
 # Autonomy uses the same paid recipe, preserves player selection and respects override.
 g=camp();food=g.camp.food;g.inventory.try_take({'meals':g.inventory.amount('meals')},'declared hungry fixture');food.quality.clear()
 for a:Survivor in g.survivors:
  g.self_care.set_enabled(g,a,true);a.hunger=85;food.conditions[a.person.persona]['nutrition']=30
 g.self_care.set_cooperation(g,g.survivors[0],'shared_cooking',true);g.select_survivor(2);advance(g,.3)
 expect(food.jobs.size()==1 and food.jobs[0]['kind']=='balanced' and g.selected_id==2,'authorized hungry household chooses nutritional cooking without stealing selection')
 valid(g,'autonomous nutritional cooking');g.select_survivor(0);g.assign_task('craft')
 expect(food.jobs.is_empty() and g.survivors[0].orders==['craft'],'manual work cancels and replaces voluntary food production')
 valid(g,'manual autonomy override');g.free()
 # A real extra patrol has ordinary stats, an independent mind, valid save and no duplication.
 g=camp();date(g,12);g.end_day();g.cycle.roles.assign(['guard','bed','scavenge']);expect(g.start_expedition(),'depart during actual migration')
 field=g.expedition;expect(field.migration_extra==1 and field.enemies.size()==field.minds.size(),'migration adds a real enemy and matching independent memory')
 var patrols:=field.enemies.size();g.camp.situation.prepare_trip(g);expect(field.enemies.size()==patrols,'reprocessing departure cannot duplicate migration patrol')
 valid(g,'migration patrol campaign');saved=SaveSystem.capture(g)
 for change in ['food','held','crop','weather','social']:
  var bad:Dictionary=saved.duplicate(true)
  match change:
   'food':bad['camp']['food']['lots'][0]['count']=-1
   'held':bad['camp']['food']['field_action']={'kind':'cans'}
   'crop':bad['camp']['food']['plots']=[{'kind':'meat','planted':12,'ready':14,'fed':false}]
   'weather':bad['camp']['situation']['powered_day']=99999
   'social':bad['camp']['relations']['duties']['lin']['streak']=-1
  expect(not SaveSystem.apply_state(g,bad).is_empty() and SaveSystem.capture(g)==saved,'invalid '+change+' camp data is rejected atomically')
 g.free()
 g=camp();food=g.camp.food;patient=g.survivors[0];patient.hunger=20;food.conditions[patient.person.persona]['nutrition']=30
 g.self_care.set_enabled(g,patient,true);advance(g,25)
 expect(food.conditions[patient.person.persona]['nutrition']==48 and int(food.supplements.get(patient.person.persona,0))==1,'already-fed malnourished actor autonomously supplements real vegetables')
 var consumed:=food.amount('vegetables');food.conditions[patient.person.persona]['nutrition']=30;advance(g,20)
 expect(food.amount('vegetables')==consumed,'autonomous side dish is limited to once per day')
 valid(g,'nutritional supplementation');g.free()
 g=camp();patient=g.survivors[0];patient.health=.00001;g.camp.food.conditions[patient.person.persona]['fever']=90
 advance(g,.02);expect(patient.health==0 and patient.state==Survivor.TaskState.DEAD,'lethal disease immediately clears actual actor state')
 valid(g,'disease death snapshot');g.free()
 print('CAMP LIFE RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
