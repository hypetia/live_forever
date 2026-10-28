extends "res://tests/expansion_pilot.gd"
## Test-only player policy: all movement, construction, combat and consumption
## use normal commands. No health, inventory, position or progress overrides.
var style := 'quiet'
var siege_count := 0
var seen_siege_day := 0
var elective_person := ''

func setup(scene: Node2D) -> void:
 super.setup(scene)
 desired={'raw_food':14,'water':18,'fuel':18,'materials':24,'medicine':7,'tools':4,'meals':0}
 for actor:Survivor in game.survivors:
  if actor.person.persona in ['lin','he','gu']:elective_person=actor.person.persona;break
 if style=='cooperative':
  for a:Survivor in game.survivors:
   if a.speciality=='医护':game.self_care.set_cooperation(game,a,'medical',true)
   if a.person.persona in ['he','lin']:game.self_care.set_cooperation(game,a,'shared_cooking',true)

func tick(delta: float) -> void:
 if game.cycle.phase=='dawn' and game.expansion.endless:
  game.begin_day();phase_started=game.simulation_time;return
 if game.cycle.phase=='siege':
  _defend(delta)
  return
 super.tick(delta)

func _defend(delta: float) -> void:
 var s:SiegeState=game.siege
 if seen_siege_day!=s.day:seen_siege_day=s.day;siege_count+=1
 if game.paused:game.paused=false
 var best:=-1;var value:=-1.0
 for id in s.participants:
  var a:Survivor=game.survivors[id]
  if a.health<=0:continue
  var score:float=float(a.weapon().get('damage',0))*CharacterAbilities.factor(a,'melee')+a.health*.1
  if score>value:value=score;best=id
 if best<0:game.advance_simulation(delta);return
 game.select_survivor(best)
 var actor:Survivor=game.survivors[best]
 if s.actions.has(str(best)):game.advance_simulation(delta);return
 var nearest:Dictionary={};var distance:=INF
 for enemy in s.enemies:
  if enemy['hp']<=0 or enemy['escaped']:continue
  var d:float=actor.position.distance_to(Vector2(enemy['x'],enemy['y']))
  if d<distance:distance=d;nearest=enemy
 if actor.health<70 and game.inventory.amount('medicine')>0 and distance>130:
  if s.start_action(game,'self_heal',best):game.advance_simulation(delta);return
 if not nearest.is_empty():
  var point:=Vector2(nearest['x'],nearest['y'])
  if point.y>530 and point.x<150 and s.gate>0 and not s.gate_open:
   if actor.position.distance_to(Vector2(150,640))<85:s.toggle(game,'gate')
  if point.y<530 and point.x>915 and s.window>0 and not s.window_open:
   if actor.position.distance_to(Vector2(915,430))<85:s.toggle(game,'window')
  if distance<float(actor.weapon().get('reach',66))-4:
   s.attack(game,best)
   if not actor.route.is_empty():game.cancel_selected()
  elif actor.route.is_empty():
   var target:=point
   target.x=clampf(target.x+(-1 if target.x>actor.position.x else 1)*float(actor.weapon().get('reach',66))*.7,140,960)
   game.move_selected(target)
 game.advance_simulation(delta)

func _combat(controls: Dictionary) -> Dictionary:
 var f:ExpeditionState=game.expedition
 var actor:Survivor=game.survivors[f.actor_id]
 if actor.health<78 or actor.infection>=18:
  if f.bag['medicine']>0:game.expedition_medicine()
 var input:=controls.duplicate()
 if style=='quiet' and not returning:input['sneak']=true;input['sprint']=false
 var nearest:Dictionary={};var distance:=INF
 for enemy in f.enemies:
  if enemy['hp']<=0 or not f.interior.visible(f,float(enemy['x']),int(enemy['floor'])) or not f.enemy_can_reach(enemy):continue
  var d:=absf(float(enemy['x'])-f.player_x)
  if d<distance:distance=d;nearest=enemy
 if nearest.is_empty():return input
 var direction:=signf(float(nearest['x'])-f.player_x)
 var reach:float=actor.weapon().get('reach',75)
 if distance<reach-5 and f.climb_target==-1 and f.attack_obstruction(nearest,actor).is_empty():
  if f.facing!=direction:return {'axis':direction,'sneak':style=='quiet'}
  if f.attack_cooldown<=0:game.expedition_attack()
  input['axis']=0.0;input['interact']=false
 if distance<70 and nearest['mode']=='windup':input={'axis':-direction,'sprint':true}
 return input

func _manage_expansion() -> void:
 var builder_id:=0
 for actor:Survivor in game.survivors:
  if actor.person.persona=='lin':builder_id=actor.survivor_id;break
 var builder:Survivor=game.survivors[builder_id]
 if builder.health<=0 or builder.hunger>=65 or builder.fatigue>=80 or game._external_busy(builder_id) or not builder.orders.is_empty():return
 game.select_survivor(builder_id)
 # Keep paid fighting tools usable before starting elective projects.
 for item in game.expansion.gear:
  if item['kind'] in ['spear','knife','bat','padding','vest'] and item['durability']<int(GearCatalog.ITEMS[item['kind']]['durability'])*.6 and game.facilities.levels['workbench']>=2 and game.inventory.amount('materials')>=4:
   if game.expansion.start_job(game,'repair',int(item['id'])):return
 if game.inventory.amount('tools')<2 and game.inventory.amount('materials')>=6:
  game.scheduler.submit(builder,'craft');return
 if game.facilities.levels['workbench']<2:
  if game.inventory.can_take(FacilitySystem.RECIPES['workbench_2']['cost']):game.expansion.start_job(game,'workbench_2')
  return
 if game.expansion.gear.filter(func(i):return i['kind']=='spear').size()<2:
  if game.inventory.can_take(GearCatalog.ITEMS['spear']['cost']):game.expansion.start_job(game,'spear')
  return
 if game.expansion.stage==0 and game.expansion.parts.has('relay'):game.expansion.start_job(game,'radio');return
 if not game.cycle.has_build('heater') and game.expansion.stage>=1:
  var slot:=-1
  for n in range(CampaignCycle.SLOTS.size()):
   if not game.cycle.builds.any(func(b):return b['slot']==n):slot=n;break
  if slot>=0:game.place_build('heater',slot)
  return
 if game.expansion.stage==2 and game.expansion.parts.has('filter_core'):game.expansion.start_job(game,'pump');return
 if game.expansion.stage==3 and game.expansion.parts.has('power_cell') and game.expansion.parts.has('beacon_core'):game.expansion.start_job(game,'beacon');return
 var armor_count:int=game.expansion.gear.filter(func(i):return i['kind']=='padding').size()
 if armor_count<game.survivors.size() and game.expansion.day(game)>=5:
  if game.inventory.can_take(GearCatalog.ITEMS['padding']['cost']):game.expansion.start_job(game,'padding')
  return
 var coats:int=game.expansion.gear.filter(func(i):return i['kind']=='coat').size()
 if coats<game.survivors.size() and game.expansion.day(game)>=7:
  if game.inventory.can_take(GearCatalog.ITEMS['coat']['cost']):game.expansion.start_job(game,'coat')
  return
 if style in ['fortify','cooperative']:
  for kind in ['gate','mesh','stakes','alarm']:
   if game.residence.security[kind]<1 and game.inventory.amount('materials')>=int(ResidenceSystem.PROJECTS[kind]['cost'].get('materials',0))+6:
    if game.expansion.start_job(game,kind):return
 if game.residence.condition<55 and game.inventory.amount('materials')>=5:
  if game.expansion.start_job(game,'maintain'):return
 if not elective_person.is_empty():
  var arc:Dictionary=game.chronicle.arcs[elective_person]
  if arc['stage']==0 and game.expansion.day(game)>=3 and game.inventory.amount('materials')>=8:game.chronicle.choice(game,elective_person,0)
  elif arc['stage']==2 and game.inventory.amount('materials')>=10 and game.chronicle.work.is_empty():
   if game.chronicle.start_work(game,elective_person):return
 if game.expansion.stage>=4 and game.expansion.day(game)>=26 and game.inventory.amount('meals')<game.survivors.filter(func(a):return a.health>0).size()+3 and game.inventory.can_take(TaskCatalog.TASKS['cook']['cost']):game.scheduler.submit(builder,'cook')

func _select_night() -> void:
 part_target=''
 var destination: String='street'
 for key in GearCatalog.PARTS:
  var map:String=GearCatalog.PARTS[key]['map']
  if not game.expansion.collected.has(key) and game.expansion.unlocked(game,map):part_target=key;destination=map;break
 if part_target.is_empty():
  var best:=-1.0
  for map in LocationCatalog.ALL_IDS:
   if not game.expansion.unlocked(game,map):continue
   var f:ExpeditionState=game.regions[map];f.refresh_for_day(game.cycle.night_day)
   var score:=0.0
   for site in f.sites:
    for key in site['contents']:score+=minf(float(site['contents'][key]),maxf(0,float(desired[key])-game.inventory.amount(key)))*float(weights.get(key,1))
   if score>best:best=score;destination=map
 if part_target.is_empty() and not elective_person.is_empty():
  var arc:Dictionary=game.chronicle.arcs[elective_person]
  if arc['stage']==1:destination=ChronicleCatalog.ARCS[elective_person]['map']
 destination=_preferred_destination(destination)
 game.choose_destination(destination)
 var scout:=-1;var best:=-INF
 for actor:Survivor in game.survivors:
  if actor.health<=35:continue
  var score:float=actor.health-actor.fatigue*.4-actor.infection*.3+(25 if actor.person.persona=='chen' else 15 if actor.person.persona=='tang' else 8 if actor.person.persona=='lin' else 0)
  if score>best:best=score;scout=actor.survivor_id
 if scout<0:
  game.cycle.roles.assign(['guard','bed','floor']);game.start_expedition();return
 game.cycle.roles.clear()
 for actor in game.survivors:game.cycle.roles.append('floor' if actor.health>0 else 'dead')
 game.cycle.roles[scout]='scavenge'
 var guard:=-1;best=-INF
 for actor:Survivor in game.survivors:
  if actor.health<=0 or actor.survivor_id==scout:continue
  var score:float=float(actor.weapon().get('damage',0))*CharacterAbilities.factor(actor,'melee')+actor.health*.3-actor.fatigue*.3
  if score>best:guard=actor.survivor_id;best=score
 if guard>=0:game.cycle.roles[guard]='guard'
 var beds:int=game.cycle.bed_count()
 for actor:Survivor in game.survivors:
  if actor.health>0 and game.cycle.roles[actor.survivor_id]=='floor' and beds>0:game.cycle.roles[actor.survivor_id]='bed';beds-=1
 # Equip through the same inventory UI API, not by changing actor stats.
 var spears:Array=game.expansion.gear.filter(func(i):return i['kind']=='spear' and i['durability']>0)
 for n in range(spears.size()):
  var target_id:int=scout if n==0 else guard
  if target_id>=0 and spears[n]['owner']!=game.survivors[target_id].person.persona:game.expansion.equip(game,int(spears[n]['id']),target_id)
 var armor:Array=game.expansion.gear.filter(func(i):return i['kind']=='padding')
 for n in range(armor.size()):
  var target_id:int=(scout+n)%game.survivors.size()
  if armor[n]['owner']!=game.survivors[target_id].person.persona:game.expansion.equip(game,int(armor[n]['id']),target_id)
 var coats:Array=game.expansion.gear.filter(func(i):return i['kind']=='coat')
 for n in range(coats.size()):
  var target_id:int=(scout+n)%game.survivors.size()
  if coats[n]['owner']!=game.survivors[target_id].person.persona:game.expansion.equip(game,int(coats[n]['id']),target_id)
 game.cycle.loadout.clear()
 if game.inventory.amount('medicine')>0:game.cycle.loadout['medicine']=1
 _extra_loadout()
 game.expansion.use_night_heat=game.expansion.outside(game)<0
 if game.start_expedition():target=-1;returning=false;visited.clear()

func _next_site(field: ExpeditionState) -> int:
 if not elective_person.is_empty():
  var arc:Dictionary=game.chronicle.arcs[elective_person]
  var definition:Dictionary=ChronicleCatalog.ARCS[elective_person]
  if arc['stage']==1 and definition['map']==field.location_id and not visited.has(int(definition['site'])) and field.elapsed<175:return int(definition['site'])
 return super._next_site(field)

func _manage_needs() -> void:
 if style!='cooperative':super._manage_needs();return
 for actor: Survivor in game.survivors:
  if actor.health<=0 or game._external_busy(actor.survivor_id) or not actor.orders.is_empty():continue
  if actor.hunger>=55:
   if game.inventory.amount('meals')>0:game.scheduler.submit(actor,'eat')
   elif not game.survivors.any(func(a):return a.orders.has('cook')) and game.inventory.can_take(TaskCatalog.TASKS['cook']['cost']):game.scheduler.submit(actor,'cook');game.scheduler.submit(actor,'eat')
  elif actor.health<80 or actor.infection>=20 or actor.illness>=30:
   var medic_available: bool = game.survivors.any(func(m):return m!=actor and m.health>70 and m.speciality=='医护' and game.self_care.members[m.person.persona]['medical'] and game.simulation_time-m.person.last_aid>=180 and game.simulation_time-actor.person.last_aid>=180)
   var eligible: bool = actor.health<=70 or actor.injury>=35 or actor.infection>=25 or actor.illness>=35
   if (not medic_available or not eligible) and game.inventory.amount('medicine')>0:game.scheduler.submit(actor,'heal')
 if game.upkeep.pending_event>=0:game.upkeep.resolve_event(game.inventory.can_take(ShelterProgress.EVENT_COSTS[game.upkeep.pending_event]) and game.inventory.amount('materials')>=8,game.inventory)
 if game.upkeep.integrity<30 and game.inventory.amount('materials')>=4:policy._order('repair')

# Optional normal-command policy hooks for district-specific journeys.
func _preferred_destination(destination: String) -> String:
 return destination

func _extra_loadout() -> void:
 pass
