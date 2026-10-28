class_name CampFood
extends RefCounted
## All food and held ingredients are physical quantities; age survives transfer, cancellation and saves.
var lots:Array=[]
var cargo:Array=[]
var caches:Dictionary={}
var quality:Array=[]
var servings:Dictionary={}
var conditions:Dictionary={}
var jobs:Array=[]
var plots:Array=[]
var infrastructure:={'plots':0,'pantry':false,'trap':false,'filter':false}
var policy:={'emergency_food':true,'balanced':true,'harvest':true,'herbal':false}
var last_day:=0
var trap_day:=0
var spoiled:=0
var field_action:Dictionary={}
var rested:Dictionary={}
var supplements:Dictionary={}

func start(game: Node2D) -> void:
 lots.clear();cargo.clear();caches.clear();quality.clear();servings.clear();conditions.clear();jobs.clear();plots.clear()
 infrastructure={'plots':0,'pantry':false,'trap':false,'filter':false};policy={'emergency_food':true,'balanced':true,'harvest':true,'herbal':false};last_day=1;trap_day=0;spoiled=0;field_action.clear();rested.clear();supplements.clear()
 add({'meat':1,'vegetables':2,'cans':1,'drinks':1,'herbs':2,'seeds':2},1)
 sync_people(game);reconcile(game)

func sync_people(game: Node2D) -> void:
 for actor:Survivor in game.survivors:
  if not conditions.has(actor.person.persona):conditions[actor.person.persona]={'nutrition':70.0,'fever':0.0,'gut':0.0}

func amount(kind: String,source: Variant=null) -> int:
 if source==null:source=lots
 var total:=0
 for lot in source:
  if lot['kind']==kind:total+=int(lot['count'])
 return total

func add(items: Dictionary,day: int,target: Variant=null) -> void:
 if target==null:target=lots
 for kind in items:
  if int(items[kind])<=0:continue
  var born:=day if int(CampFoodCatalog.ITEMS[kind]['life'])>0 else 0
  var merged:=false
  for lot in target:
   if lot['kind']==kind and int(lot['born'])==born:lot['count']+=int(items[kind]);merged=true;break
  if not merged:target.append({'kind':kind,'count':int(items[kind]),'born':born})

func take(items: Dictionary,source: Variant=null) -> Array:
 if source==null:source=lots
 for kind in items:
  if amount(kind,source)<int(items[kind]):return []
 source.sort_custom(func(a,b):return int(a['born'])<int(b['born']))
 var held:Array=[]
 for kind in items:
  var needed:int=items[kind]
  for lot in source.duplicate():
   if lot['kind']!=kind or needed<=0:continue
   var n:=mini(needed,int(lot['count']));held.append({'kind':kind,'count':n,'born':int(lot['born'])});lot['count']-=n;needed-=n
   if lot['count']==0:source.erase(lot)
 return held

func refund(held: Array,target: Variant=null) -> void:
 if target==null:target=lots
 for lot in held:
  var merged:=false
  for current in target:
   if current['kind']==lot['kind'] and current['born']==lot['born']:current['count']+=int(lot['count']);merged=true;break
  if not merged:target.append(lot.duplicate())

func slots(source: Variant=null) -> int:
 if source==null:source=cargo
 var used:=0
 for kind in CampFoodCatalog.ITEMS:
  var n:=amount(kind,source)
  if is_same(source,cargo) and not field_action.is_empty():n+=amount(kind,field_action['held'])
  used+=ceili(n/float(CampFoodCatalog.ITEMS[kind]['stack']))
 return used

func entries(source: Array) -> Array[Dictionary]:
 var result:Array[Dictionary]=[]
 for kind in CampFoodCatalog.ITEMS:
  var left:=amount(kind,source);var limit:int=CampFoodCatalog.ITEMS[kind]['stack']
  while left>0:
   var n:=mini(left,limit);result.append({'kind':'provision','key':kind,'count':n,'limit':limit});left-=n
 return result

func cache_key(field: ExpeditionState,index: int) -> String:return field.location_id+':'+str(index)
func cache_has(field: ExpeditionState,index: int) -> bool:
 var key:=cache_key(field,index)
 if caches.has(key):return not caches[key].is_empty()
 return CampFoodCatalog.CACHE_LAYOUT[field.location_id].has(index)
func open_cache(game: Node2D) -> void:
 var f:ExpeditionState=game.expedition
 if not f.active or f.loot_site<0:return
 var key:=cache_key(f,f.loot_site)
 if caches.has(key):return
 caches[key]=[]
 add(CampFoodCatalog.CACHE_LAYOUT[f.location_id].get(f.loot_site,{}),ExpeditionState.day_at(game.simulation_time),caches[key])
func cache_entries(game: Node2D) -> Array[Dictionary]:
 return entries(caches.get(cache_key(game.expedition,game.expedition.loot_site),[]))
func cargo_entries() -> Array[Dictionary]:return entries(cargo)
func room(game: Node2D,kind: String) -> int:
 var limit:int=CampFoodCatalog.ITEMS[kind]['stack'];var count:=amount(kind,cargo)+(amount(kind,field_action['held']) if not field_action.is_empty() else 0)
 return maxi(0,game.expedition.capacity-game.expedition.used_capacity())*limit+(limit-count%limit)%limit
func transfer(game: Node2D,kind: String,count: int,put: bool=false) -> int:
 var f:ExpeditionState=game.expedition
 if not f.active or f.loot_site<0 or not CampFoodCatalog.ITEMS.has(kind) or count<=0:return 0
 open_cache(game)
 var at:Array=caches[cache_key(f,f.loot_site)]
 var n:=mini(count,amount(kind,cargo if put else at))
 n=mini(n,cache_room(game,kind) if put else room(game,kind))
 if n<=0:return 0
 refund(take({kind:n},cargo if put else at),at if put else cargo)
 game.expansion.refresh_slots(f,game.survivors[f.actor_id]);return n
func returned(game: Node2D,safe: bool) -> void:
 if safe:
  if not field_action.is_empty():refund(field_action['held'],cargo)
  refund(cargo)
 cargo.clear();field_action.clear()

func position_for(game: Node2D,kind: String,target: int=-1) -> Vector2:
 var station:String=CampFoodCatalog.RECIPES[kind]['station']
 match station:
  'stove':return game.stove.work_position()
  'workbench':return game.facility.work_position()
  'table':return game.dining_table.work_position()
  'water':return game.water_store.position
  'bed':return game.bed.work_position()
  'patient':return game.survivors[target].position+Vector2(-42 if game.survivors[target].position.x>180 else 42,0)
  'exit':return Vector2(150,640)
  _:return Vector2(300,640)
func station(kind: String) -> String:
 var value:String=CampFoodCatalog.RECIPES[kind]['station']
 return value if value in ['stove','workbench','table','bed'] else ''
func reserves_station(id: String) -> bool:
 return jobs.any(func(job):return station(job['kind'])==id)
func busy(id: int) -> bool:return jobs.any(func(job):return int(job['actor'])==id)

func error(game: Node2D,kind: String,id: int,target: int=-1) -> String:
 if not CampFoodCatalog.RECIPES.has(kind) or id<0 or id>=game.survivors.size():return '行动或人物无效'
 if game.cycle.phase!='day' or game.game_over or game.survivors[id].health<=0:return '只能在白天安排活着的成员'
 var r:Dictionary=CampFoodCatalog.RECIPES[kind]
 var place:=station(kind)
 if not place.is_empty() and game.expansion.jobs.any(func(j):return FacilitySystem.station_for(j['kind'])==place and int(j['actor'])!=id):return '设备已有其他成员安排工作'
 if not place.is_empty() and game.camp.relations.reserves_station(place) and not game.camp.relations.busy(id):return '设备已有同伴活动'
 if int(game.facilities.levels['stove' if r['station']=='stove' else 'workbench'])<int(r.get('tier',1)):return '设施等级不足'
 if r.has('requires') and not infrastructure[r['requires']]:return '需要先建造对应设施'
 if r.has('build'):
  var key:String=r['build']
  if (key=='plots' and int(infrastructure[key])>=2) or (key!='plots' and infrastructure[key]):return '已经建造完成'
 if r.has('crop') and plots.size()+jobs.filter(func(j):return CampFoodCatalog.RECIPES[j['kind']].has('crop') and int(j['actor'])!=id).size()>=int(infrastructure['plots']):return '需要空的种植箱'
 if kind=='fertilize' and not plots.any(func(plot):return not plot['fed']):return '没有尚未施肥的作物'
 if kind=='harvest' and not plots.any(func(plot):return int(plot['ready'])<=ExpeditionState.day_at(game.simulation_time)):return '作物尚未成熟'
 if kind=='check_trap' and trap_day>=ExpeditionState.day_at(game.simulation_time):return '今天已经检查过陷阱'
 if jobs.any(func(job):return job['kind']==kind and (r.has('build') or r.has('crop') or kind in ['check_trap','harvest','fertilize'])):return '已有成员安排这项工作'
 if kind=='herbal_care':
  if game.survivors[id].speciality!='医护' or target<0 or target>=game.survivors.size() or target==id or game.survivors[target].health<=0:return '需要医护和另一位活着的伤员'
  if not game.survivors[target].route.is_empty() or game.survivors[target].manual_walking or not game.survivors[target].orders.is_empty() or game._external_busy(target):return '伤员需先停下当前行动'
  var condition:Dictionary=conditions[game.survivors[target].person.persona]
  if condition['fever']<10 and condition['gut']<10:return '没有需要调养的发热或肠胃病情'
 if kind=='recover' and reserves_station('bed'):return '病床已被占用'
 if r.has('world'):
  if jobs.any(func(j):return j['kind']==kind and int(j['actor'])!=id):return '已有成员安排这项工作'
  var world_error:String=game.camp.situation.job_error(game,kind)
  if not world_error.is_empty():return world_error
 if not game.inventory.can_take(r['cost']):return game.inventory.missing_text(r['cost'])
 for food in r['food']:
  if amount(food)<int(r['food'][food]):return '缺少'+str(CampFoodCatalog.ITEMS[food]['name'])
 if game.scheduler.navigation.route_between(game.survivors[id].position,position_for(game,kind,target)).is_empty():return '路线不通'
 return ''

func start_job(game: Node2D,kind: String,id: int=-1,target: int=-1,automatic: bool=false) -> bool:
 if id<0:id=game.selected_id
 var problem:=error(game,kind,id,target)
 if not problem.is_empty():
  if not automatic:game._log(problem)
  return false
 var actor:Survivor=game.survivors[id];var r:Dictionary=CampFoodCatalog.RECIPES[kind]
 if automatic and (actor.state!=Survivor.TaskState.IDLE or not actor.orders.is_empty() or not actor.route.is_empty() or game._external_busy(id) or game.simulation_time<float(game.self_care.members[actor.person.persona]['manual_until'])):return false
 if automatic and not KitchenPlan.can_pay(game,r['cost']):return false
 var route:Array[Vector2]=game.scheduler.navigation.route_between(actor.position,position_for(game,kind,target))
 if not automatic:game._cancel_external(id);game.scheduler.cancel(actor)
 if not game.inventory.try_take(r['cost'],r['name']):return false
 var held:=take(r['food'])
 jobs.append({'actor':id,'kind':kind,'target':target,'elapsed':0.0,'held':held,'health':actor.health,'automatic':automatic})
 actor.route=route;actor.state=Survivor.TaskState.RETURNING;actor.feedback='前往'+str(r['name'])
 game._log(actor.display_name+'开始'+str(r['name'])+'，到达现场后进行。')
 return true

func cancel(game: Node2D,id: int,refund_cost: bool=true) -> void:
 for job in jobs.duplicate():
  if int(job['actor'])!=id:continue
  if refund_cost:
   game.inventory.deposit(CampFoodCatalog.RECIPES[job['kind']]['cost'],'取消营地行动，退料');refund(job['held'])
  jobs.erase(job);game.survivors[id].feedback='空闲'

func tick_health(game: Node2D,delta: float) -> void:
 sync_people(game)
 for actor:Survivor in game.survivors:
  if actor.health<=0:continue
  var c:Dictionary=conditions[actor.person.persona]
  if c['gut']>=35:actor.person.thirst=minf(100,actor.person.thirst+delta*.02)
  if c['fever']>=40:actor.fatigue=minf(100,actor.fatigue+delta*.015)
  if c['nutrition']<25:actor.illness=minf(100,actor.illness+delta*.003)
  if c['fever']>=70 or c['gut']>=75:actor.health=maxf(0,actor.health-delta*.004)
  if actor.health<=0:
   game._cancel_external(actor.survivor_id,false);game.scheduler.mark_dead(actor,'疾病恶化')

func tick(game: Node2D,delta: float) -> void:
 sync_people(game)
 for job in jobs.duplicate():
  var actor:Survivor=game.survivors[int(job['actor'])];var kind:String=job['kind'];var r:Dictionary=CampFoodCatalog.RECIPES[kind]
  if actor.health<=0:game._cancel_external(actor.survivor_id,false);continue
  if actor.health<float(job['health']) and kind=='herbal_care':game._cancel_external(actor.survivor_id);continue
  if kind=='herbal_care':
   var patient:Survivor=game.survivors[int(job['target'])]
   if patient.health<=0 or not patient.route.is_empty() or patient.manual_walking:game._cancel_external(actor.survivor_id);continue
  if not actor.route.is_empty():continue
  var point:=position_for(game,kind,int(job['target']))
  if actor.position.distance_to(point)>12:game._cancel_external(actor.survivor_id);continue
  var place:=station(kind)
  if not place.is_empty() and (game.scheduler.facilities[place].occupant_id>=0 or game.expansion.reserves_station(game,place) or job!=jobs.filter(func(j):return station(j['kind'])==place)[0]):continue
  var duration:float=r['seconds']
  var rate:float=1.0 if kind in ['recover','eat_can','eat_preserved','drink','unsafe_drink'] else actor.effort_factor()*game.camp.relations.work_factor(game,actor)
  if r['station']=='stove':rate*=game.facilities.rate('stove')
  job['elapsed']=minf(duration,float(job['elapsed'])+delta*rate)
  actor.facing=1.0
  actor.activity={'kind':'sleep' if kind=='recover' else 'aid' if kind=='herbal_care' else 'eat' if r.get('consume','') in ['cans','preserved','vegetables'] else 'drink' if r.has('consume') else 'cook' if r.has('output') or r.get('heat',false) else 'build','label':r['name'],'progress':float(job['elapsed'])/duration}
  if kind=='recover':
   rested[actor.person.persona]=ExpeditionState.day_at(game.simulation_time)
   var c:Dictionary=conditions[actor.person.persona];c['fever']=maxf(0,c['fever']-delta*.25);c['gut']=maxf(0,c['gut']-delta*.15);actor.illness=maxf(0,actor.illness-delta*.1);actor.fatigue=maxf(0,actor.fatigue-delta*1.8)
  if float(job['elapsed'])>=duration:
   finish(game,job);jobs.erase(job);actor.activity.clear();actor.feedback='空闲';actor.state=Survivor.TaskState.IDLE

func finish(game: Node2D,job: Dictionary) -> void:
 var day:int=ExpeditionState.day_at(game.simulation_time);var kind:String=job['kind'];var r:Dictionary=CampFoodCatalog.RECIPES[kind];var actor:Survivor=game.survivors[int(job['actor'])]
 if r.has('output'):
  var output:Dictionary=r['output'].duplicate()
  if output.has('meals') and actor.person.persona=='he':output['meals']+=1
  game.inventory.deposit(output,r['name'])
  if r.has('quality'):quality.append({'kind':r['quality'],'count':int(output['meals']),'born':day})
 if r.has('typed'):add(r['typed'],day)
 if r.has('build'):
  var key:String=r['build']
  if key=='plots':infrastructure[key]+=1
  else:infrastructure[key]=true
 if r.has('crop'):plots.append({'kind':r['crop'],'planted':day,'ready':day+2,'fed':false})
 if kind=='fertilize':
  for plot in plots:
   if not plot['fed']:plot['fed']=true;break
 if kind=='harvest':
  for plot in plots:
   if int(plot['ready'])>day:continue
   var count: int=(3 if plot['kind']=='vegetables' else 2)+(1 if plot['fed'] else 0)
   add({plot['kind']:count,'seeds':1},day);plots.erase(plot);break
 if kind=='check_trap':trap_day=day;add({'meat':1 if game.camp.situation.active(game.expansion.day(game),'scarcity') else 2},day)
 if r.has('consume'):consume(game,actor,r['consume'])
 if kind=='herbal_care':
  treat(game.survivors[int(job['target'])],25,20)
  game.people.bonds[_pair(actor.survivor_id,int(job['target']))]=mini(100,game.people.relationship(actor.survivor_id,int(job['target']))+3)
 if r.has('world'):game.camp.situation.complete(game,kind,actor)
 if job['automatic'] and r.get('output',{}).has('meals'):game.self_care.finished(game,actor.survivor_id,'cook')
 game._log(str(r['name'])+'完成。')

func consume(game: Node2D,actor: Survivor,kind: String) -> void:
 var c:Dictionary=conditions[actor.person.persona]
 match kind:
  'vegetables':
   actor.hunger=maxf(0,actor.hunger-8);c['nutrition']=minf(100,c['nutrition']+18);supplements[actor.person.persona]=ExpeditionState.day_at(game.simulation_time)
  'cans':actor.hunger=maxf(0,actor.hunger-45);actor.person.thirst=minf(100,actor.person.thirst+3);c['nutrition']=minf(100,c['nutrition']+8)
  'preserved':actor.hunger=maxf(0,actor.hunger-35);actor.person.thirst=minf(100,actor.person.thirst+5);c['nutrition']=minf(100,c['nutrition']+12)
  'drinks':actor.person.thirst=maxf(0,actor.person.thirst-55);actor.fatigue=maxf(0,actor.fatigue-5)
  'dirty_water':actor.person.thirst=maxf(0,actor.person.thirst-40);c['gut']=minf(100,c['gut']+35);actor.illness=minf(100,actor.illness+8)
func treat(actor: Survivor,fever: float,gut: float) -> void:
 if not conditions.has(actor.person.persona):return
 conditions[actor.person.persona]['fever']=maxf(0,conditions[actor.person.persona]['fever']-fever);conditions[actor.person.persona]['gut']=maxf(0,conditions[actor.person.persona]['gut']-gut)
func _pair(a: int,b: int) -> String:return '%d:%d'%[mini(a,b),maxi(a,b)]

func take_quality(count: int) -> Array:
 quality.sort_custom(func(a,b):return int(a['born'])<int(b['born']))
 var result:Array=[]
 for q in quality.duplicate():
  if count<=0:break
  var n:=mini(count,int(q['count']));result.append({'kind':q['kind'],'count':n,'born':q['born']});count-=n;q['count']-=n
  if q['count']==0:quality.erase(q)
 return result
func meal_started(actor: Survivor) -> void:
 var portion:=take_quality(1)
 if not portion.is_empty():servings[str(actor.survivor_id)]=portion[0]
func meal_cancelled(id: int,refund_portion: bool=true) -> void:
 var key:=str(id)
 if not servings.has(key):return
 if refund_portion:quality.push_front(servings[key].duplicate())
 servings.erase(key)
func meal_finished(actor: Survivor) -> void:
 sync_condition(actor)
 var key:=str(actor.survivor_id)
 var kind:String=servings.get(key,{}).get('kind','plain');servings.erase(key)
 nourish(actor,kind)
func nourish(actor: Survivor,kind: String) -> void:
 sync_condition(actor)
 var c:Dictionary=conditions[actor.person.persona]
 c['nutrition']=minf(100,c['nutrition']+({'balanced':28,'broth':18,'vegetable':20}.get(kind,8)))
 if kind=='broth':actor.person.thirst=maxf(0,actor.person.thirst-12);c['fever']=maxf(0,c['fever']-6)
 if kind=='balanced':actor.person.stress=maxf(0,actor.person.stress-3)
func sync_condition(actor: Survivor) -> void:
 if not conditions.has(actor.person.persona):conditions[actor.person.persona]={'nutrition':70.0,'fever':0.0,'gut':0.0}
func reconcile(game: Node2D) -> void:
 var n:=0
 for q in quality:n+=int(q['count'])
 var lost:=maxi(0,n-game.inventory.amount('meals'))
 for q in quality.duplicate():
  var n_loss:=mini(lost,int(q['count']));q['count']-=n_loss;lost-=n_loss
  if q['count']==0:quality.erase(q)
 if n<game.inventory.amount('meals'):quality.append({'kind':'plain','count':game.inventory.amount('meals')-n,'born':ExpeditionState.day_at(game.simulation_time)})

func life(kind: String,game: Node2D) -> int:
 var n:int=CampFoodCatalog.ITEMS[kind]['life']
 if infrastructure['pantry'] and kind in ['meat','vegetables','herbs']:n+=2 if kind=='meat' else 3
 return n
func dawn(game: Node2D,report: Array) -> void:
 var day:=ExpeditionState.day_at(game.simulation_time)
 if day<=last_day:return
 sync_people(game)
 var passed:=day-last_day;last_day=day
 var night:int=game.cycle.night_day
 var extra:=1 if game.camp.situation.active(night,'blackout') and game.camp.situation.powered_day!=night else 0
 reconcile(game)
 var stale_meals:=0
 for q in quality.duplicate():
  if day-int(q['born'])>= (3 if infrastructure['pantry'] else 2):
   var count:=mini(int(q['count']),game.inventory.amount('meals'))
   if count>0:game.inventory.try_take({'meals':count},'熟食过期');rot_meals(game,count,day);stale_meals+=count
   quality.erase(q)
 if stale_meals>0:report.append('熟食过期%d份，已转成堆肥。'%stale_meals)
 var rot:=0
 for source in [lots,cargo]+caches.values():
  for lot in source.duplicate():
   var length:=life(lot['kind'],game)
   if length<=0:continue
   if extra>0:lot['born']=maxi(0,int(lot['born'])-extra)
   if day-int(lot['born'])>=length:
    var count:int=lot['count'];source.erase(lot)
    if is_same(source,lots):rot+=count
    add({'compost':count},day,source)
 spoiled+=rot
 if rot>0:report.append('鲜食腐坏%d份，转成堆肥；保鲜柜和肉干可减少损耗。'%rot)
 if (day%4)==2:add({'dirty_water':2},day);report.append('收集到未净化雨水2，需处理后饮用。')
 var contagious:Array=game.survivors.filter(func(a):return a.health>0 and role(game,a.survivor_id) not in ['scavenge','outpost'] and conditions[a.person.persona]['fever']>=50 and not isolated(game,a.survivor_id))
 for actor:Survivor in game.survivors:
  if actor.health<=0:continue
  var c:Dictionary=conditions[actor.person.persona]
  c['nutrition']=maxf(0,c['nutrition']-6*passed)
  if c['nutrition']<25:c['fever']=minf(100,c['fever']+2*passed);actor.illness=minf(100,actor.illness+passed)
  var sources:=0
  for other:Survivor in contagious:
   if other!=actor:sources+=1
  if sources>0 and role(game,actor.survivor_id) not in ['scavenge','outpost'] and not isolated(game,actor.survivor_id):c['fever']=minf(100,c['fever']+sources*2)
 report.append('【营养与疾病】F5可查看食材保鲜、营养、发热和肠胃病情；咬伤感染仍需药品。')
func role(game: Node2D,id: int) -> String:return game.cycle.roles[id] if id<game.cycle.roles.size() else 'floor'
func isolated(game: Node2D,id: int) -> bool:
 return role(game,id)=='bed' and int(rested.get(game.survivors[id].person.persona,0))>=game.cycle.night_day
func rot_meals(_game: Node2D,count: int,day: int) -> void:
 spoiled+=count;add({'compost':count},day)

func plan(game: Node2D) -> void:
 for actor:Survivor in game.survivors:
  if not game.self_care._idle(game,actor):continue
  var id:=actor.survivor_id;var c:Dictionary=conditions[actor.person.persona]
  if policy['emergency_food'] and actor.hunger>=65 and SelfCareSystem.available(game,'meals')==0 and not KitchenPlan.pending(game):
   var kind:='eat_can' if amount('cans')>0 else 'eat_preserved' if amount('preserved')>0 else ''
   if not kind.is_empty() and (actor.hunger>=90 or not KitchenPlan.can_pay(game,TaskCatalog.TASKS['cook']['cost'])):
    if start_job(game,kind,id,-1,true):continue
  if actor.person.thirst>=65 and SelfCareSystem.available(game,'water')==0 and amount('drinks')>0:
   if start_job(game,'drink',id,-1,true):continue
  if actor.hunger>=65 or actor.person.thirst>=65 or actor.fatigue>=70:continue
  if policy['balanced'] and c['nutrition']<40 and int(supplements.get(actor.person.persona,0))<ExpeditionState.day_at(game.simulation_time):
   if start_job(game,'vegetable_side',id,-1,true):continue
  if policy['harvest'] and plots.any(func(plot):return int(plot['ready'])<=ExpeditionState.day_at(game.simulation_time)) and not jobs.any(func(job):return job['kind']=='harvest'):
   if start_job(game,'harvest',id,-1,true):continue
  if policy['herbal'] and actor.speciality=='医护':
   for patient:Survivor in game.survivors:
    if patient==actor or patient.health<=0:continue
    var condition:Dictionary=conditions[patient.person.persona]
    if maxf(condition['fever'],condition['gut'])>=30 and not jobs.any(func(job):return job['kind']=='herbal_care' and job['target']==patient.survivor_id):
     if start_job(game,'herbal_care',id,patient.survivor_id,true):break

func plan_shared(game: Node2D,actor: Survivor) -> bool:
 sync_people(game)
 if not policy['balanced'] or KitchenPlan.hungry(game)<2:return false
 var ill:=false;var low:=false
 for other:Survivor in game.survivors:
  if other.health>0 and other.hunger>=65:
   var c:Dictionary=conditions[other.person.persona];ill=ill or c['fever']>=25;low=low or c['nutrition']<50
 for kind in (['broth','balanced','salad'] if ill else ['balanced','salad'] if low else []):
  if error(game,kind,actor.survivor_id).is_empty() and start_job(game,kind,actor.survivor_id,-1,true):return true
 return false

func use_cargo(game: Node2D,kind: String) -> bool:
 var f:ExpeditionState=game.expedition
 if not f.active or game.paused or not field_action.is_empty() or not kind in ['cans','drinks','preserved'] or amount(kind,cargo)<1 or f.moving or f.climb_target!=-1 or f.attack_windup>0:return false
 var held:=take({kind:1},cargo)
 field_action={'kind':kind,'held':held,'elapsed':0.0,'x':f.player_x,'floor':f.floor_level,'health':game.survivors[f.actor_id].health}
 f._reset_search();game.expansion.refresh_slots(f,game.survivors[f.actor_id]);return true
func tick_field(game: Node2D,delta: float) -> void:
 if field_action.is_empty():return
 var f:ExpeditionState=game.expedition;var actor:Survivor=game.survivors[f.actor_id]
 if f.moving or f.climb_target!=-1 or f.attack_windup>0 or actor.health<float(field_action['health']) or absf(f.player_x-float(field_action['x']))>1:
  refund(field_action['held'],cargo);field_action.clear();game.expansion.refresh_slots(f,actor);return
 var duration:=2.0 if field_action['kind']=='drinks' else 4.0
 field_action['elapsed']=minf(duration,float(field_action['elapsed'])+delta)
 if float(field_action['elapsed'])>=duration:
  consume(game,actor,field_action['kind']);field_action.clear();game.expansion.refresh_slots(f,actor)
func snapshot() -> Dictionary:
 return {'lots':lots.duplicate(true),'cargo':cargo.duplicate(true),'caches':caches.duplicate(true),'quality':quality.duplicate(true),'servings':servings.duplicate(true),'conditions':conditions.duplicate(true),'jobs':jobs.duplicate(true),'plots':plots.duplicate(true),'infrastructure':infrastructure.duplicate(),'policy':policy.duplicate(),'last_day':last_day,'trap_day':trap_day,'spoiled':spoiled,'field_action':field_action.duplicate(true),'rested':rested.duplicate(),'supplements':supplements.duplicate()}
func restore(data: Dictionary) -> void:
 for key in data:set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
static func valid_lots(value: Variant,day: int,maximum: int=128) -> bool:
 if not value is Array or value.size()>maximum:return false
 for lot in value:
  if not CharacterState.keys(lot,['kind','count','born']) or not lot['kind'] is String or not CampFoodCatalog.ITEMS.has(lot['kind']) or not CharacterState.integer(lot['count'],1,1000000) or not CharacterState.integer(lot['born'],0,day):return false
 return true
static func validate(data: Variant,world: Dictionary) -> String:
 if not CharacterState.keys(data,CampFood.new().snapshot().keys()):return '营地食物字段无效'
 var day:=ExpeditionState.day_at(world['simulation_time'])
 for key in ['lots','cargo']:
  if not valid_lots(data[key],day):return '食物数量或保鲜日期无效'
 if not data['caches'] is Dictionary or data['caches'].size()>60:return '独立物资地点过多'
 for key in data['caches']:
  if not key is String or key.get_slice_count(':')!=2 or not key.get_slice(':',0) in LocationCatalog.ALL_IDS or not key.get_slice(':',1).is_valid_int():return '独立物资地点无效'
  var index:=int(key.get_slice(':',1))
  if index<0 or index>=LocationCatalog.area(key.get_slice(':',0))['sites'].size() or not valid_lots(data['caches'][key],day):return '物资容器或内容无效'
 if not CharacterState.keys(data['infrastructure'],['plots','pantry','trap','filter']) or not CharacterState.integer(data['infrastructure']['plots'],0,2):return '生产设施无效'
 for key in ['pantry','trap','filter']:
  if not data['infrastructure'][key] is bool:return '生产设施状态无效'
 if not CharacterState.keys(data['policy'],['emergency_food','balanced','harvest','herbal']):return '生产授权无效'
 for value in data['policy'].values():
  if not value is bool:return '生产授权状态无效'
 for key in ['last_day','trap_day']:
  if not CharacterState.integer(data[key],0,day):return '生产日期无效'
 if not CharacterState.integer(data['spoiled'],0,100000000) or not data['plots'] is Array or data['plots'].size()>data['infrastructure']['plots']:return '种植容量无效'
 for plot in data['plots']:
  if not CharacterState.keys(plot,['kind','planted','ready','fed']) or not plot['kind'] in ['vegetables','herbs'] or not CharacterState.integer(plot['planted'],1,day) or plot['ready']!=plot['planted']+2 or not plot['fed'] is bool:return '种植记录无效'
 if not data['conditions'] is Dictionary or data['conditions'].size()!=world['actors'].size():return '病情人数无效'
 for actor in world['actors']:
  var id:String=actor['person']['persona']
  if not data['conditions'].has(id) or not CharacterState.keys(data['conditions'][id],['nutrition','fever','gut']):return '营养与病情字段无效'
  for value in data['conditions'][id].values():
   if not CharacterState.number(value,0,100):return '营养与病情数值无效'
 for map_key in ['rested','supplements']:
  if not data[map_key] is Dictionary:return '休养或配餐记录无效'
  for id in data[map_key]:
   if not data['conditions'].has(id) or not CharacterState.integer(data[map_key][id],1,day):return '休养或配餐日期无效'
 if not data['quality'] is Array or data['quality'].size()>128 or not data['servings'] is Dictionary or data['servings'].size()>5:return '餐食品质记录无效'
 var total:=0
 for q in data['quality']+data['servings'].values():
  if not CharacterState.keys(q,['kind','count','born']) or not q['kind'] in ['plain','balanced','broth','vegetable'] or not CharacterState.integer(q['count'],1,1000000) or not CharacterState.integer(q['born'],0,day):return '餐食品质或数量无效'
 for q in data['quality']:total+=int(q['count'])
 if total>int(world['stock']['meals']):return '品质餐食超出实际库存'
 for key in data['servings']:
  if not key is String or not key.is_valid_int() or not CharacterState.integer(int(key),0,world['actors'].size()-1):return '用餐人无效'
  var actor:Dictionary=world['actors'][int(key)]
  if actor['orders']!=['eat'] or actor['state']!=Survivor.TaskState.WORKING or actor['held_cost']!={'meals':1} or data['servings'][key]['count']!=1:return '品质餐食缺少真实用餐'
 if not data['jobs'] is Array or data['jobs'].size()>5:return '营地工作过多'
 var owners:Array=[]
 for job in data['jobs']:
  if not CharacterState.keys(job,['actor','kind','target','elapsed','held','health','automatic']) or not job['kind'] is String or not CampFoodCatalog.RECIPES.has(job['kind']) or not CharacterState.integer(job['actor'],0,world['actors'].size()-1) or owners.has(int(job['actor'])):return '营地工作人员无效'
  owners.append(int(job['actor']))
  var place:String=CampFoodCatalog.RECIPES[job['kind']]['station']
  if place in ['stove','workbench','bed','table'] and world['expansion']['jobs'].any(func(j):return FacilitySystem.station_for(j['kind'])==place):return '生产设备被两个系统重复预留'
  var r:Dictionary=CampFoodCatalog.RECIPES[job['kind']];var actor:Dictionary=world['actors'][int(job['actor'])]
  if world['campaign']['phase']!='day' or actor['health']<=0 or not actor['orders'].is_empty() or not actor['state'] in [Survivor.TaskState.IDLE,Survivor.TaskState.RETURNING] or not job['automatic'] is bool or not CharacterState.number(job['elapsed'],0,r['seconds']) or not CharacterState.number(job['health'],0,100) or not valid_lots(job['held'],day):return '营地工作状态无效'
  var paid:Dictionary={}
  for lot in job['held']:paid[lot['kind']]=int(paid.get(lot['kind'],0))+int(lot['count'])
  if not SaveSystem._same_items(paid,r['food']):return '营地工作原料不符'
  if not CharacterState.integer(job['target'],-1,world['actors'].size()-1) or (job['kind']=='herbal_care' and (job['target']==job['actor'] or job['target']<0 or PeopleCatalog.DATA[actor['person']['persona']]['role']!='医护')):return '调养目标无效'
  if world['expansion']['jobs'].any(func(work):return work['actor']==job['actor']) or world['campaign']['actions'].any(func(work):return work['actor']==job['actor']):return '营地工作人员重复占用'
 var action:Variant=data['field_action']
 if not action is Dictionary:return '外出食用行动无效'
 if not action.is_empty():
  if not CharacterState.keys(action,['kind','held','elapsed','x','floor','health']) or not world['expedition']['active'] or not action['kind'] in ['cans','drinks','preserved'] or not valid_lots(action['held'],day,1) or action['held'].size()!=1 or action['held'][0]['kind']!=action['kind'] or action['held'][0]['count']!=1 or not CharacterState.number(action['elapsed'],0,2 if action['kind']=='drinks' else 4) or not CharacterState.number(action['x'],90,4200) or not CharacterState.integer(action['floor'],0,1) or not CharacterState.number(action['health'],0,100):return '外出食用记录无效'
 if not world['expedition']['active'] and (not data['cargo'].is_empty() or not action.is_empty()):return '未外出却保留独立物资'
 return ''
func cache_room(game: Node2D,kind: String) -> int:
 var f:ExpeditionState=game.expedition
 if f.loot_site<0:return 0
 var cache:Array=caches.get(cache_key(f,f.loot_site),[]);var limit:int=CampFoodCatalog.ITEMS[kind]['stack'];var count:=amount(kind,cache)
 return maxi(0,16-BackpackStacks.slots(f.sites[f.loot_site]['contents'])-slots(cache))*limit+(limit-count%limit)%limit
func sync_sites(game: Node2D) -> void:
 for id in LocationCatalog.ALL_IDS:
  var f:ExpeditionState=game.regions[id]
  for index in CampFoodCatalog.CACHE_LAYOUT[id]:
   if cache_has(f,int(index)) and not f.special_sites.has(int(index)):f.special_sites.append(int(index))
