class_name CampRelations
extends RefCounted
## Preferences produce bounded, visible choices. Player orders always cancel voluntary work.
const STYLES := {'lin':'inventor','xu':'healer','chen':'guardian','he':'provider','gu':'healer','tang':'survivor','alice':'guardian','conan':'observer','rick':'leader','tesla':'inventor','pooh':'comfort','mickey':'diplomat'}
var policies:Dictionary={}
var duties:Dictionary={}
var talked:Dictionary={}
var repaired:Dictionary={}
var job:Dictionary={}
var dispute:Dictionary={}
var promise:Dictionary={}
var memories:Array=[]
var last_night:=0

func sync(game: Node2D) -> void:
 for actor:Survivor in game.survivors:
  var id:=actor.person.persona
  if not policies.has(id):policies[id]={'social':true,'watch':STYLES[id] in ['guardian','observer'],'maintain':false}
  if not duties.has(id):duties[id]={'streak':0,'last':'floor'}
  if not talked.has(id):talked[id]=0
  if not repaired.has(id):repaired[id]=0
func day(game: Node2D) -> int:return ExpeditionState.day_at(game.simulation_time)
func idle(game: Node2D,actor: Survivor) -> bool:
 return actor.health>35 and actor.infection<50 and actor.illness<60 and actor.hunger<65 and actor.person.thirst<65 and actor.fatigue<70 and game.self_care._idle(game,actor)
func busy(id: int) -> bool:return not job.is_empty() and job['members'].has(id)
func reserves_station(station: String) -> bool:return not job.is_empty() and ((station=='table' and job['kind'] in ['meal','mediate']) or (station=='workbench' and job['kind']=='maintain'))
func work_factor(game: Node2D,actor: Survivor) -> float:
 var bonus:=1.0
 for other:Survivor in game.survivors:
  if other==actor or other.health<=0 or absf(other.position.y-actor.position.y)>25 or absf(other.position.x-actor.position.x)>160:continue
  var trust:int=game.people.relationship(actor.survivor_id,other.survivor_id)
  if trust>=80:bonus=maxf(bonus,1.1)
  elif trust>=60:bonus=maxf(bonus,1.05)
 if bonus==1 and actor.person.stress>=65:
  for other:Survivor in game.survivors:
   if other!=actor and other.health>0 and other.position.distance_to(actor.position)<160 and game.people.relationship(actor.survivor_id,other.survivor_id)<20:return .95
 return bonus

func start(game: Node2D,kind: String,target: int=-1,owner: int=-1,automatic: bool=false) -> bool:
 if owner<0:owner=game.selected_id
 if game.cycle.phase!='day' or game.game_over or not job.is_empty() or not kind in ['talk','meal','mediate','watch','maintain']:return false
 var actor:Survivor=game.survivors[owner]
 if actor.health<=0:return false
 if kind=='talk' and int(talked[actor.person.persona])>=day(game):return false
 if automatic and not idle(game,actor):return false
 var members:Array=[owner]
 if kind in ['talk','meal']:
  if target<0 or target>=game.survivors.size() or target==owner:return false
  members.append(target)
 if kind=='mediate':
  if dispute.is_empty():return false
  for id in [int(dispute['left']),int(dispute['right'])]:
   if not members.has(id):members.append(id)
 if kind in ['meal','mediate'] and game.camp.food.reserves_station('table'):return false
 if kind=='maintain' and (game.camp.food.reserves_station('workbench') or game.expansion.jobs.any(func(j):return FacilitySystem.station_for(j['kind'])=='workbench' and int(j['actor'])!=owner)):return false
 if kind=='maintain' and (game.residence.condition>=70 or SelfCareSystem.available(game,'materials')<1):return false
 if kind=='watch' and game.camp.situation.recon_day>=day(game):return false
 for id in members:
  var member:Survivor=game.survivors[id]
  if id!=owner and (not member.orders.is_empty() or not member.route.is_empty() or member.manual_walking or game._external_busy(id) or member.health<=0):return false
 var cost:Dictionary={'meals':2} if kind=='meal' else {'materials':1} if kind=='maintain' else {}
 if not game.inventory.can_take(cost) or (kind=='meal' and game.chronicle.meal_day>=day(game)):return false
 var destinations:Array=[]
 for n in range(members.size()):
  var point:Vector2=Vector2(150,640) if kind=='watch' else game.facility.work_position() if kind=='maintain' else Vector2(525+n*60,430) if kind in ['meal','mediate'] else game.survivors[target].position+Vector2(-42 if actor.position.x<=game.survivors[target].position.x else 42,0) if n==0 else game.survivors[target].position
  if game.scheduler.navigation.route_between(game.survivors[members[n]].position,point).is_empty():return false
  destinations.append([point.x,point.y])
 if not automatic:game._cancel_external(owner);game.scheduler.cancel(actor)
 game.camp.food.reconcile(game)
 if not game.inventory.try_take(cost,'同伴协作：'+kind):return false
 var health:Array=[]
 for n in range(members.size()):
  var member:Survivor=game.survivors[members[n]];health.append(member.health)
  member.route=game.scheduler.navigation.route_between(member.position,Vector2(destinations[n][0],destinations[n][1]));member.state=Survivor.TaskState.RETURNING;member.feedback='前往同伴协作'
 job={'kind':kind,'owner':owner,'members':members,'destinations':destinations,'health':health,'elapsed':0.0,'automatic':automatic,'meal_quality':game.camp.food.take_quality(2) if kind=='meal' else []}
 return true

func cancel(game: Node2D,id: int,refund: bool=true) -> void:
 if not busy(id):return
 var old:=job.duplicate(true);job.clear()
 if refund:
  if old['kind']=='meal':game.camp.food.quality.append_array(old['meal_quality'])
  game.inventory.deposit({'meals':2} if old['kind']=='meal' else {'materials':1} if old['kind']=='maintain' else {},'取消同伴协作，退还未使用物资')
 for member_id in old['members']:
  var actor:Survivor=game.survivors[int(member_id)];actor.activity.clear();actor.feedback='空闲'
  if actor.orders.is_empty() and actor.state==Survivor.TaskState.RETURNING:
   if actor.position.y in [430.0,640.0]:actor.route.clear();actor.state=Survivor.TaskState.IDLE
   else:
    var landing:=ShelterNavigation.TOP_STAIR if game.scheduler.navigation.floor_at(actor.position)==1 else ShelterNavigation.BOTTOM_STAIR
    actor.route=game.scheduler.navigation.route_between(actor.position,landing)

func tick(game: Node2D,delta: float) -> void:
 if job.is_empty():return
 for n in range(job['members'].size()):
  var actor:Survivor=game.survivors[int(job['members'][n])]
  if actor.health<=0 or actor.health<float(job['health'][n]) or not actor.orders.is_empty() or actor.manual_walking:
   cancel(game,int(job['owner']),actor.health>0);return
  if job['automatic'] and (actor.hunger>=90 or actor.person.thirst>=90 or actor.fatigue>=98):cancel(game,int(job['owner']));return
 for n in range(job['members'].size()):
  var actor:Survivor=game.survivors[int(job['members'][n])];var p:Array=job['destinations'][n]
  if not actor.route.is_empty() or actor.position.distance_to(Vector2(p[0],p[1]))>12:return
 if reserves_station('table') and (game.dining_table.occupant_id>=0 or game.camp.food.reserves_station('table')):return
 if reserves_station('workbench') and game.facility.occupant_id>=0:return
 job['elapsed']=minf(8,float(job['elapsed'])+delta)
 for n in range(job['members'].size()):
  var actor:Survivor=game.survivors[int(job['members'][n])]
  if job['members'].size()>1:
   var partner:Survivor=game.survivors[int(job['members'][1 if n==0 else 0])];actor.facing=1 if partner.position.x>actor.position.x else -1
  actor.activity={'kind':'eat' if job['kind']=='meal' else 'build' if job['kind']=='maintain' else 'talk','label':{'talk':'陪伴交谈','meal':'同伴共餐','mediate':'当面调解','watch':'观察尸群动向','maintain':'主动维护营地'}[job['kind']],'progress':float(job['elapsed'])/8}
 if float(job['elapsed'])>=8:finish(game)

func finish(game: Node2D) -> void:
 var old:=job.duplicate(true);var owner:Survivor=game.survivors[int(old['owner'])];var kind:String=old['kind'];job.clear()
 if kind=='watch':game.camp.situation.recon_day=day(game)
 elif kind=='maintain':
  game.residence.condition=minf(100,game.residence.condition+(12 if STYLES[owner.person.persona]=='inventor' else 8));repaired[owner.person.persona]=day(game)
 else:
  var strength:=1.5 if STYLES[owner.person.persona]=='comfort' else 1.25 if STYLES[owner.person.persona] in ['diplomat','leader'] else 1.0
  for id in old['members']:
   var actor:Survivor=game.survivors[int(id)];actor.person.stress=maxf(0,actor.person.stress-(10 if kind=='meal' else 6)*strength);actor.person.morale=minf(100,actor.person.morale+4*strength);talked[actor.person.persona]=day(game)
   if kind=='meal':
    actor.hunger=maxf(0,actor.hunger-35)
    var portion:String='plain'
    if not old['meal_quality'].is_empty():
     portion=old['meal_quality'][0]['kind'];old['meal_quality'][0]['count']-=1
     if old['meal_quality'][0]['count']==0:old['meal_quality'].pop_front()
    game.camp.food.nourish(actor,portion)
  for a in old['members']:
   for b in old['members']:
    if a>=b:continue
    var pair:='%d:%d'%[a,b];game.people.bonds[pair]=mini(100,game.people.relationship(a,b)+(6 if kind=='meal' else 4 if kind=='mediate' else 2))
  if kind=='meal':game.chronicle.meal_day=day(game)
  if kind=='mediate':dispute.clear()
 for id in old['members']:
  game.survivors[int(id)].activity.clear();game.survivors[int(id)].feedback='空闲';game.survivors[int(id)].state=Survivor.TaskState.IDLE
 memories.append({'day':day(game),'kind':kind,'owner':owner.person.persona,'others':old['members'].duplicate()});if memories.size()>24:memories.pop_front()
 game._log(owner.display_name+{'talk':'陪同伴聊了一会儿。','meal':'和同伴完成了共餐。','mediate':'完成了当面调解，紧张关系有所缓和。','watch':'观察到今晚尸群动向，防守压力略减。','maintain':'完成了主动维护。'}[kind])

func plan(game: Node2D) -> void:
 sync(game)
 if not job.is_empty():return
 var candidates:Array=game.survivors.duplicate()
 candidates.sort_custom(func(a,b):return ['comfort','diplomat','leader','healer','guardian','provider','observer','inventor','survivor'].find(STYLES[a.person.persona])<['comfort','diplomat','leader','healer','guardian','provider','observer','inventor','survivor'].find(STYLES[b.person.persona]))
 for actor:Survivor in candidates:
  if not idle(game,actor):continue
  var p:Dictionary=policies[actor.person.persona]
  if p['social'] and int(talked[actor.person.persona])<day(game):
   var target:=-1;var score:=-INF
   for other:Survivor in game.survivors:
    if other==actor or not idle(game,other) or int(talked[other.person.persona])>=day(game):continue
    if other.person.stress<35 and other.person.morale>=45 and other.person.trauma<15:continue
    var value:float=other.person.stress+(60-other.person.morale)+other.person.trauma*.3+game.people.relationship(actor.survivor_id,other.survivor_id)*.1
    if STYLES[actor.person.persona] in ['guardian','healer']:value+=other.injury*.3
    if value>score:score=value;target=other.survivor_id
   if target>=0 and start(game,'talk',target,actor.survivor_id,true):return
  if p['watch'] and game.camp.situation.forecast(game.expansion.day(game))['visible'] and game.camp.situation.recon_day<day(game):
   if start(game,'watch',-1,actor.survivor_id,true):return
  if p['maintain'] and int(repaired[actor.person.persona])<day(game) and game.residence.condition<55:
   if start(game,'maintain',-1,actor.survivor_id,true):return

func night(game: Node2D,report: Array) -> void:
 sync(game)
 if game.cycle.night_day<=last_night:return
 last_night=game.cycle.night_day
 for pending in [dispute,promise]:
  if not pending.is_empty() and (game.survivors[int(pending['left'])].health<=0 or game.survivors[int(pending['right'])].health<=0):pending.clear()
 for actor:Survivor in game.survivors:
  if actor.health<=0:continue
  var id:=actor.person.persona;var role:String=game.cycle.roles[actor.survivor_id];var d:Dictionary=duties[id]
  d['streak']=int(d['streak'])+1 if role=='guard' else 0;d['last']=role
  if role=='guard' and int(d['streak'])>=3:
   actor.person.stress=minf(100,actor.person.stress+(1 if STYLES[id]=='guardian' else 3))
   if dispute.is_empty() and actor.fatigue>=70:
    for other:Survivor in game.survivors:
     if other!=actor and other.health>0 and game.cycle.roles[other.survivor_id] in ['bed','floor']:
      dispute={'left':actor.survivor_id,'right':other.survivor_id,'day':day(game),'kind':'duty'};break
 if not promise.is_empty():
  var left:int=promise['left'];var right:int=promise['right']
  var honored:bool=game.cycle.roles[left]!='guard' and game.cycle.roles[right]=='guard'
  var pair:='%d:%d'%[mini(left,right),maxi(left,right)];game.people.bonds[pair]=clampi(game.people.relationship(left,right)+(8 if honored else -4),0,100)
  report.append('【承诺】守夜轮换'+('兑现，双方更信任彼此。' if honored else '未兑现，双方信任下降。'));promise.clear()
 if not dispute.is_empty():report.append('【关系】'+game.survivors[int(dispute['left'])].display_name+'连续守夜，认为分工不均；F5可调解或承诺轮换。')
func pledge(game: Node2D) -> bool:
 if dispute.is_empty() or not promise.is_empty() or game.cycle.phase not in ['day','planning']:return false
 promise={'left':int(dispute['left']),'right':int(dispute['right'])};dispute.clear();return true

func snapshot() -> Dictionary:
 return {'policies':policies.duplicate(true),'duties':duties.duplicate(true),'talked':talked.duplicate(),'repaired':repaired.duplicate(),'job':job.duplicate(true),'dispute':dispute.duplicate(),'promise':promise.duplicate(),'memories':memories.duplicate(true),'last_night':last_night}
func restore(data: Dictionary) -> void:
 for key in data:set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
