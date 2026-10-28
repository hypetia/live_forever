class_name SiegeState
extends RefCounted
signal enemy_hit(index: int,at: Vector2,direction: float,damage: int,lethal: bool)
## A paid, physical night defense in the actual occupied shelter. The normal
## dawn raid is replaced, never run a second time after this encounter.
var active := false
var resolved_day := 0
var day := 0
var elapsed := 0.0
var wave := 0
var next_wave := 5.0
var gate := 100.0
var window := 70.0
var gate_max := 100.0
var window_max := 70.0
var gate_open := false
var window_open := false
var participants: Array[int] = []
var enemies: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var strikes: Dictionary = {}
var actions: Dictionary = {}
var invulnerable: Dictionary = {}
var pending_lines: Array[String] = []
var ammo_spent := 0
var stock_lost := 0
var initial_condition := 100.0
var hit_marks: Array[Dictionary] = []

func should_begin(game: Node2D) -> bool:
 if active or resolved_day>=game.cycle.night_day or not game.chronicle.manual_defense or not game.residence.convoy.is_empty():return false
 return (game.cycle.seed+game.cycle.night_day*7919)%100<game.raid_chance(game.cycle.night_day)

func begin(game: Node2D,lines: Array) -> bool:
 if not should_begin(game):return false
 game._cancel_all_day_work()
 active=true;day=game.cycle.night_day;elapsed=0;wave=0;next_wave=5+4*int(game.residence.security["alarm"]);ammo_spent=0;stock_lost=0
 enemies.clear();participants.clear();cooldowns.clear();strikes.clear();actions.clear();invulnerable.clear();hit_marks.clear();pending_lines.clear()
 for line in lines:pending_lines.append(str(line))
 initial_condition=game.residence.condition
 gate_max=80+float(game.residence.security['gate'])*45+(40 if game.cycle.has_build('barricade') else 0)+float(ResidenceSystem.HOMES[game.residence.current]['defense'])*40
 window_max=60+float(game.residence.security['mesh'])*40+float(ResidenceSystem.HOMES[game.residence.current]['defense'])*30
 gate=gate_max*maxf(.2,game.residence.condition/100)*maxf(.4,game.upkeep.integrity/100);window=window_max*maxf(.2,game.residence.condition/100)*maxf(.4,game.upkeep.integrity/100);gate_open=false;window_open=false
 var best:=-1;var score:=-1.0
 for actor: Survivor in game.survivors:
  if actor.health<=0 or game.cycle.roles[actor.survivor_id]=='outpost':continue
  var id:=actor.survivor_id
  participants.append(id);cooldowns[str(id)]=0.0;invulnerable[str(id)]=0.0
  actor.state=Survivor.TaskState.IDLE;actor.route.clear();actor.activity.clear();actor.feedback='基地防守'
  # Preparation places guards at their real inside posts, before combat starts.
  # Existing residents retain their current position; no mid-fight teleport.
  if game.cycle.roles[id]=='guard':
   actor.route=game.scheduler.navigation.route_between(actor.position,Vector2(215,640));actor.state=Survivor.TaskState.RETURNING
  var value:float=actor.health+float(actor.weapon().get('damage',0))*2-actor.fatigue*.2
  if value>score:score=value;best=id
 if best<0:active=false;resolved_day=day;return false
 game.cycle.phase='siege';game.paused=true;game.context_open=false;game.placement=''
 game.select_survivor(best)
 game._log('尸群正在接近。空格开始防守：A/D与W/S移动，J攻击，E开关入口门，X开关窗，V就近修补，F近距离急救。守夜同伴会协战。')
 game.interface.refresh(true);game._refresh_hud()
 return true

func waves() -> int:return 3 if day>=18 else 2
func _spawn(game: Node2D) -> void:
 wave+=1
 var count:=3 if day>=14 else 2
 for n in range(count):
  var kind: String='runner' if (day+wave+n)%4==0 else 'brute' if day>=10 and n==count-1 else 'walker'
  var upper:bool=n==1 and (wave%2==0 or window<gate*.7)
  var floor_id:=1 if upper else 0
  enemies.append({'x':970.0 if upper else 105.0,'y':430.0 if upper else 640.0,'floor':floor_id,'entry':floor_id,'hp':int(EnemyCatalog.stats(kind)['health']),'kind':kind,'direction':-1.0 if upper else 1.0,'mode':'approach','timer':0.0,'target':-1,'route':[],'hurt':0.0,'escaped':false,'trapped':false})
 next_wave=elapsed+22
 game._log('第%d批尸群进入视野，注意门和二层窗。' % wave)

func toggle(game: Node2D,which: String) -> bool:
 if not active or game.paused or not participants.has(game.selected_id):return false
 var actor:Survivor=game.survivors[game.selected_id]
 var point:=Vector2(150,640) if which=='gate' else Vector2(915,430)
 if actor.position.distance_to(point)>85:return false
 if which=='gate':
  if gate<=0:return false
  gate_open=not gate_open
 else:
  if window<=0:return false
  window_open=not window_open
 return true

func attack(game: Node2D,id: int) -> bool:
 if not active or game.paused or not participants.has(id) or game.survivors[id].health<=0:return false
 var key:=str(id);var actor:Survivor=game.survivors[id]
 if cooldowns.get(key,0)>0 or strikes.has(key) or actions.has(key):return false
 var weapon:Dictionary=actor.weapon();var ranged:=weapon.has('magazine')
 if ranged and game.expansion.ammo<=0:return false
 var best:=-1;var distance:=float(weapon.get('reach',66))
 for n in range(enemies.size()):
  var e:Dictionary=enemies[n]
  if e['hp']<=0 or e['escaped'] or absf(float(e['y'])-actor.position.y)>28:continue
  var d:=absf(float(e['x'])-actor.position.x)
  if d<distance and _clear(game,actor.position,Vector2(e['x'],e['y']),ranged):distance=d;best=n
 if best<0:return false
 var e:Dictionary=enemies[best];actor.facing=1.0 if e['x']>actor.position.x else -1.0
 strikes[key]={'enemy':best,'remaining':float(weapon.get('windup',.18)),'origin':actor.position.x,'floor':game.scheduler.navigation.floor_at(actor.position),'facing':actor.facing}
 cooldowns[key]=float(weapon.get('cooldown',1.1))
 return true

func _clear(game: Node2D,a: Vector2,b: Vector2,ranged: bool) -> bool:
 if a.y>530 and minf(a.x,b.x)<150 and maxf(a.x,b.x)>150 and gate>0 and not gate_open:return ranged and game.residence.security['gate']>0
 if a.y<530 and minf(a.x,b.x)<915 and maxf(a.x,b.x)>915 and window>0 and not window_open:return ranged and game.residence.security['mesh']>0
 return true

func start_action(game: Node2D,kind: String,id: int) -> bool:
 if not active or game.paused or not participants.has(id):return false
 var actor:Survivor=game.survivors[id];var key:=str(id)
 if actor.health<=0 or actions.has(key) or strikes.has(key):return false
 var target:=id
 if kind in ['heal','self_heal']:
  if (kind=='heal' and actor.speciality!='医护') or game.inventory.amount('medicine')<1:return false
  var worst:=0.0
  target=-1
  for member_id in ([id] if kind=='self_heal' else participants):
   var member:Survivor=game.survivors[member_id]
   var need:float=100-member.health+member.injury*.2+member.infection*.2+member.illness*.1
   if member.health>0 and need>worst and actor.position.distance_to(member.position)<110:worst=need;target=member_id
  if target<0:return false
 elif gate>=gate_max or game.inventory.amount('materials')<1 or actor.position.distance_to(Vector2(150,640))>85:return false
 actions[key]={'kind':kind,'target':target,'elapsed':0.0,'health':actor.health}
 return true

func cancel(id: int) -> void:actions.erase(str(id))

func tick(game: Node2D,delta: float) -> void:
 if not active:return
 elapsed+=delta
 for mark in hit_marks:mark['time']=float(mark['time'])-delta
 hit_marks=hit_marks.filter(func(m):return m['time']>0)
 for key in cooldowns:cooldowns[key]=maxf(0,float(cooldowns[key])-delta);invulnerable[key]=maxf(0,float(invulnerable.get(key,0))-delta)
 for key in actions.keys():
  var a:Dictionary=actions[key];var actor:Survivor=game.survivors[int(key)]
  if actor.health<float(a['health']) or actor.health<=0 or not actor.route.is_empty() or actor.manual_walking:actions.erase(key);actor.activity.clear();continue
  a['elapsed']=float(a['elapsed'])+delta*(1.5 if actor.person.persona=='lin' and a['kind']=='repair' else 1.0)
  actor.activity={'kind':a['kind'],'label':'修补入口' if a['kind']=='repair' else '战地急救','progress':minf(1,float(a['elapsed'])/2.5)}
  if a['elapsed']<2.5:continue
  if a['kind']=='repair':
   if gate<gate_max and actor.position.distance_to(Vector2(150,640))<85 and game.inventory.try_take({'materials':1},'防守现场修补'):gate=minf(gate_max,gate+30)
  else:
   var target:Survivor=game.survivors[int(a['target'])]
   if target.health>0 and (target.health<100 or target.injury>0 or target.infection>0 or target.illness>0) and actor.position.distance_to(target.position)<110 and game.inventory.try_take({'medicine':1},'防守现场急救'):
    target.health=minf(100,target.health+(35 if actor.person.persona=='xu' else 25)*CharacterAbilities.factor(actor,'siege_heal'));target.injury=maxf(0,target.injury-(40 if actor.person.persona=='gu' else 25));target.infection=maxf(0,target.infection-(25 if actor.person.persona=='gu' else 15));target.illness=maxf(0,target.illness-(15 if actor.person.persona=='gu' else 0));game.chronicle.aid(game,actor)
  actor.activity.clear();actions.erase(key)
 for key in strikes.keys():
  var s:Dictionary=strikes[key];s['remaining']=maxf(0,float(s['remaining'])-delta)
  if s['remaining']>0:continue
  var actor:Survivor=game.survivors[int(key)];var e:Dictionary=enemies[int(s['enemy'])];var weapon:Dictionary=actor.weapon();var ranged:=weapon.has('magazine')
  if actor.health>0 and e['hp']>0 and not e['escaped']:
   if ranged:
    if game.expansion.ammo<=0:strikes.erase(key);continue
    game.expansion.ammo-=1;ammo_spent+=1;game.residence.noise=minf(100,game.residence.noise+2)
   var clear:bool=absf(actor.position.y-float(e['y']))<28 and absf(actor.position.x-float(e['x']))<float(weapon.get('reach',66))+5 and (float(e['x'])-actor.position.x)*float(s['facing'])>=-10 and _clear(game,actor.position,Vector2(e['x'],e['y']),ranged)
   if clear:
    game.game_audio.combat_cue('hit')
    var damage:=CharacterAbilities.melee_damage(actor,int(weapon.get('damage',0)),false) if not ranged and not weapon.is_empty() else int(weapon.get('damage',0))
    e['hp']=maxi(0,int(e['hp'])-damage);e['hurt']=.25;e['timer']=maxf(float(e['timer']),.3)
    if e['mode']=='windup':e['mode']='hunt'
    if damage==0 and (is_equal_approx(float(e['y']),430) or is_equal_approx(float(e['y']),640)):
     e['x']=clampf(float(e['x'])+float(s['facing'])*18,100,970);e['route'].clear()
    if damage>0:enemy_hit.emit(int(s['enemy']),Vector2(e['x'],e['y']),float(s['facing']),damage,e['hp']<=0)
    hit_marks.append({'x':float(e['x']),'y':float(e['y'])-35,'time':.45,'blood':damage>0})
   if not actor.weapon_item.is_empty():actor.weapon_item['durability']=maxi(0,int(actor.weapon_item['durability'])-int(weapon.get('wear',1)))
  strikes.erase(key)
 if wave>0 and wave<waves() and enemies.all(func(e):return e['hp']<=0 or e['escaped']):next_wave=minf(next_wave,elapsed+3)
 if elapsed<180 and wave<waves() and elapsed>=next_wave:_spawn(game)
 for e in enemies:
  if e['hp']<=0 or e['escaped']:continue
  e['hurt']=maxf(0,float(e['hurt'])-delta)
  if e['hurt']>0:continue
  if elapsed>=180:
   var exit:=Vector2(105,640) if e['entry']==0 else Vector2(965,430)
   _walk(game,e,exit,95,delta)
   if Vector2(e['x'],e['y']).distance_to(exit)<8:e['escaped']=true
   continue
  var point:=Vector2(e['x'],e['y'])
  var outside:bool=(e['entry']==0 and point.y>530 and point.x<150 and gate>0 and not gate_open) or (e['entry']==1 and point.y<530 and point.x>915 and window>0 and not window_open)
  if outside:
   for id in participants:
    var defender:Survivor=game.survivors[id]
    if defender.health>0 and point.distance_to(defender.position)<85 and _clear(game,point,defender.position,false):outside=false;break
  if outside:
   if game.residence.security['stakes']>0 and not e['trapped']:e['hp']=maxi(0,int(e['hp'])-16);e['trapped']=true;e['hurt']=.4
   var damage:=12.0 if e['kind']=='brute' else 5.0
   if e['entry']==0:gate=maxf(0,gate-delta*damage)
   else:window=maxf(0,window-delta*damage)
   e['mode']='breach';continue
  var target:=-1;var distance:=INF
  for id in participants:
   var actor:Survivor=game.survivors[id]
   if actor.health<=0:continue
   var path: Array[Vector2]=game.scheduler.navigation.route_between(point,actor.position);var total:=0.0;var last:=point
   for step in path:total+=last.distance_to(step);last=step
   if total<distance:distance=total;target=id
  if target<0:continue
  var actor:Survivor=game.survivors[target];e['target']=target
  if e['mode']=='windup':
   e['timer']=maxf(0,float(e['timer'])-delta)
   if e['timer']<=0:
    if point.distance_to(actor.position)<58 and (actor.position.x-point.x)*float(e['direction'])>=-10 and invulnerable.get(str(target),0)<=0 and _clear(game,point,actor.position,false):
     var reduction:=1-actor.protection();var damage:=roundi(float(EnemyCatalog.stats(e['kind'])['damage'])*.8*reduction)
     actor.health=maxf(0,actor.health-damage);actor.injury=minf(100,actor.injury+8*reduction);actor.infection=minf(100,actor.infection+4*reduction);actor.person.stress=minf(100,actor.person.stress+5)
     if not actor.armor_item.is_empty():actor.armor_item['durability']=maxi(0,int(actor.armor_item['durability'])-5)
     game.game_audio.combat_cue('hurt')
     invulnerable[str(target)]=1.2;hit_marks.append({'x':actor.position.x,'y':actor.position.y-40,'time':.45,'blood':true})
     if actor.health<=0:game.scheduler.mark_dead(actor,'基地防守中负伤');actions.erase(str(target));strikes.erase(str(target))
    e['mode']='hunt';e['timer']=1.0
   continue
  e['timer']=maxf(0,float(e['timer'])-delta)
  if point.distance_to(actor.position)<45 and e['timer']<=0 and _clear(game,point,actor.position,false):e['mode']='windup';e['direction']=1.0 if actor.position.x>point.x else -1.0;e['timer']=float(EnemyCatalog.stats(e['kind'])['windup']);continue
  if point.y>530 and absf(point.x-485)<40 and distance>240 and e['timer']<=0:
   for resource in ['water','raw_food','materials']:
    if game.inventory.try_take({resource:1},'尸群突破后破坏储藏物资'):stock_lost+=1;break
   e['timer']=3.0
  _walk(game,e,actor.position,float(EnemyCatalog.stats(e['kind'])['chase_speed'])*.7,delta)
 for id in participants:
  var actor:Survivor=game.survivors[id]
  if actor.health<=0 or id==game.selected_id:continue
  var near:=false
  for e in enemies:
   if e['hp']>0 and not e['escaped'] and actor.position.distance_to(Vector2(e['x'],e['y']))<float(actor.weapon().get('reach',66)):near=true;break
  if near:attack(game,id)
  elif game.cycle.roles[id]=='guard' and actor.route.is_empty() and not actions.has(str(id)):
   var chosen:Dictionary={};var distance:=INF
   for e in enemies:
    if e['hp']<=0 or e['escaped']:continue
    var target:=Vector2(e['x'],e['y'])
    if not _clear(game,actor.position,target,false):continue
    var d:float=actor.position.distance_to(target)
    if d<distance:distance=d;chosen=e
   if not chosen.is_empty():
    var target:=Vector2(chosen['x'],chosen['y'])
    if target.y not in [430.0,640.0]:target=ShelterNavigation.TOP_STAIR if game.scheduler.navigation.floor_at(target)==1 else ShelterNavigation.BOTTOM_STAIR
    target.x=clampf(target.x+(-1 if target.x>actor.position.x else 1)*float(actor.weapon().get('reach',66))*.65,140,960)
    actor.route=game.scheduler.navigation.route_between(actor.position,target)
    if not actor.route.is_empty():actor.state=Survivor.TaskState.RETURNING
 if (wave>=waves() or elapsed>=180) and enemies.all(func(e):return e['hp']<=0 or e['escaped']):finish(game)
 elif participants.all(func(id):return game.survivors[id].health<=0):finish(game)
 game.self_care.sync(game)

func _walk(game: Node2D,e: Dictionary,to: Vector2,speed: float,delta: float) -> void:
 var point:=Vector2(e['x'],e['y'])
 if to.y not in [430.0,640.0]:to=ShelterNavigation.TOP_STAIR if game.scheduler.navigation.floor_at(to)==1 else ShelterNavigation.BOTTOM_STAIR
 var path: Array=e['route']
 var on_floor:bool=is_equal_approx(point.y,430) or is_equal_approx(point.y,640)
 if path.is_empty() or (on_floor and Vector2(path[-1][0],path[-1][1]).distance_to(to)>60):
  path.clear()
  for step: Vector2 in game.scheduler.navigation.route_between(point,to):path.append([step.x,step.y])
 var travel:=speed*delta
 while not path.is_empty() and travel>0:
  var target:=Vector2(path[0][0],path[0][1]);var distance:=point.distance_to(target)
  if distance<=travel:point=target;path.pop_front();travel-=distance
  else:point=point.move_toward(target,travel);travel=0
 var old:=Vector2(e['x'],e['y'])
 var blocked:=_blocked(game,old,point)
 if blocked!=point:
  path.clear();point=blocked
  var damage:float=(12 if e['kind']=='brute' else 5)*delta
  if point.y>530:gate=maxf(0,gate-damage)
  else:window=maxf(0,window-damage)
 if absf(point.x-old.x)>.001:e['direction']=signf(point.x-old.x)
 e['x']=point.x;e['y']=point.y;e['floor']=game.scheduler.navigation.floor_at(point)

func _blocked(game: Node2D,old: Vector2,p: Vector2) -> Vector2:
 if absf(old.y-p.y)>.01:return p
 if old.y>530 and gate>0 and not gate_open and minf(old.x,p.x)<150 and maxf(old.x,p.x)>150:p.x=168 if old.x>=150 else 132
 if old.y<530 and window>0 and not window_open and minf(old.x,p.x)<915 and maxf(old.x,p.x)>915:p.x=897 if old.x<=915 else 933
 return p

func constrain(game: Node2D,before: Array) -> void:
 for actor: Survivor in game.survivors:
  if actor.health<=0:continue
  var point:=_blocked(game,before[actor.survivor_id],actor.position)
  if point!=actor.position:
   actor.position=point;actor.route.clear();actor.state=Survivor.TaskState.IDLE

func finish(game: Node2D) -> void:
 if not active:return
 active=false;resolved_day=day;strikes.clear();actions.clear()
 var condition:=minf(initial_condition,(gate/gate_max+window/window_max)*50)
 if game.residence.security['stakes']>0:condition=maxf(0,condition-6)
 game.residence.condition=condition
 game.upkeep.integrity=maxf(0,game.upkeep.integrity-minf(20,((gate_max-gate)+(window_max-window))/25))
 for id in participants:
  var actor:Survivor=game.survivors[id];actor.activity.clear()
  if actor.health>0:actor.fatigue=minf(100,actor.fatigue+elapsed/12)
 var lines:Array=pending_lines.duplicate()
 lines.append('【亲自防守】抵挡%d批尸群，入口%d%%／窗%d%%，安防耐久%d，耗弹%d，储藏损失%d。' % [wave,roundi(gate/gate_max*100),roundi(window/window_max*100),roundi(condition),ammo_spent,stock_lost])
 game._cancel_all_day_work();game._settle_night(lines)

func snapshot() -> Dictionary:
 return {'active':active,'resolved_day':resolved_day,'day':day,'elapsed':elapsed,'wave':wave,'next_wave':next_wave,'gate':gate,'window':window,'gate_max':gate_max,'window_max':window_max,'gate_open':gate_open,'window_open':window_open,'participants':participants.duplicate(),'enemies':enemies.duplicate(true),'cooldowns':cooldowns.duplicate(),'strikes':strikes.duplicate(true),'actions':actions.duplicate(true),'invulnerable':invulnerable.duplicate(),'pending_lines':pending_lines.duplicate(),'ammo_spent':ammo_spent,'stock_lost':stock_lost,'initial_condition':initial_condition}

func restore(d: Dictionary) -> void:
 if d.is_empty():d=SiegeState.new().snapshot()
 for key in ['active','resolved_day','day','elapsed','wave','next_wave','gate','window','gate_max','window_max','gate_open','window_open','ammo_spent','stock_lost','initial_condition']:set(key,d[key])
 participants.clear();enemies.clear();pending_lines.clear();hit_marks.clear()
 for id in d['participants']:participants.append(int(id))
 for e in d['enemies']:enemies.append(e.duplicate(true))
 for line in d['pending_lines']:pending_lines.append(line)
 cooldowns=d['cooldowns'].duplicate();strikes=d['strikes'].duplicate(true);actions=d['actions'].duplicate(true);invulnerable=d['invulnerable'].duplicate()

static func validate(d: Variant,world: Dictionary) -> String:
 if world['campaign'].is_empty():return '' if d is Dictionary and d.is_empty() else '基础场景不含防守现场'
 var keys: Array=SiegeState.new().snapshot().keys()
 if not CharacterState.keys(d,keys) or not d['active'] is bool or not d['gate_open'] is bool or not d['window_open'] is bool:return '防守记录字段无效'
 if d['active']!=(world['campaign']['phase']=='siege'):return '防守现场与昼夜阶段不符'
 var day:=ExpeditionState.day_at(world['simulation_time'])
 for k in ['resolved_day','day']:
  if not CharacterState.integer(d[k],0,day):return '防守日期无效'
 for k in ['elapsed','next_wave']:
  if not CharacterState.number(d[k],0,1000):return '防守时间无效'
 if not CharacterState.integer(d['wave'],0,3) or not CharacterState.number(d['gate_max'],80,300) or not CharacterState.number(d['window_max'],60,220) or not CharacterState.number(d['gate'],0,d['gate_max']) or not CharacterState.number(d['window'],0,d['window_max']) or not CharacterState.number(d['initial_condition'],0,100):return '防守门窗状态无效'
 if not CharacterState.integer(d['ammo_spent'],0,100000) or not CharacterState.integer(d['stock_lost'],0,100000) or not d['participants'] is Array or d['participants'].size()>5 or not d['enemies'] is Array or d['enemies'].size()>9:return '防守数量无效'
 if d['active'] and not d['participants'].has(world['selected_id']):return '未选择有效防守者'
 var checked:Array=[]
 for id in d['participants']:
  if not CharacterState.integer(id,0,world['actors'].size()-1) or checked.has(int(id)):return '防守队员无效'
  checked.append(int(id))
 for e in d['enemies']:
  if not CharacterState.keys(e,['x','y','floor','entry','hp','kind','direction','mode','timer','target','route','hurt','escaped','trapped']) or not e['direction'] in [-1.0,1.0] or not e['kind'] in EnemyCatalog.TYPES or not CharacterState.integer(e['hp'],0,EnemyCatalog.stats(e['kind'])['health']) or not e['mode'] in ['approach','breach','hunt','windup'] or not e['escaped'] is bool or not e['trapped'] is bool:return '防守敌人状态无效'
  if not CharacterState.number(e['x'],90,980) or not CharacterState.number(e['y'],430,640) or not CharacterState.integer(e['floor'],0,1) or not CharacterState.integer(e['entry'],0,1) or not CharacterState.number(e['timer'],0,3) or not CharacterState.number(e['hurt'],0,.45) or not CharacterState.integer(e['target'],-1,world['actors'].size()-1) or not e['route'] is Array or e['route'].size()>6:return '防守敌人路径无效'
  var previous: Array=[e['x'],e['y']]
  for point in e['route']:
   if not point is Array or point.size()!=2 or not CharacterState.number(point[0],90,980) or not CharacterState.number(point[1],430,640) or not SaveSystem._segment(previous,point):return '防守敌人路线穿墙'
   previous=point
 for k in ['cooldowns','invulnerable','strikes','actions']:
  if not d[k] is Dictionary or d[k].size()>5:return '防守行动数量无效'
  for id in d[k]:
   if not str(id).is_valid_int() or not int(id) in checked:return '防守行动人员无效'
 for value in d['cooldowns'].values():
  if not CharacterState.number(value,0,3):return '防守攻击冷却无效'
 for value in d['invulnerable'].values():
  if not CharacterState.number(value,0,1.2):return '防守受击保护无效'
 for a in d['actions'].values():
  if not CharacterState.keys(a,['kind','target','elapsed','health']) or not a['kind'] in ['heal','self_heal','repair'] or not CharacterState.integer(a['target'],0,world['actors'].size()-1) or not CharacterState.number(a['elapsed'],0,2.5) or not CharacterState.number(a['health'],0,100):return '防守救护或修补无效'
 for s in d['strikes'].values():
  if not CharacterState.keys(s,['enemy','remaining','origin','floor','facing']) or not CharacterState.integer(s['enemy'],0,d['enemies'].size()-1) or not CharacterState.number(s['remaining'],0,.4) or not CharacterState.number(s['origin'],100,980) or not CharacterState.integer(s['floor'],0,1) or not s['facing'] in [-1.0,1.0]:return '防守出手状态无效'
 if not d['pending_lines'] is Array or d['pending_lines'].size()>16:return '防守报告容量无效'
 for line in d['pending_lines']:
  if not line is String or line.length()>1000:return '防守报告无效'
 if not d['active'] and (not d['strikes'].is_empty() or not d['actions'].is_empty()):return '结束防守仍保留出手'
 return ''
