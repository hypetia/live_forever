class_name EnemyMind
extends RefCounted
const ROLES := ['伏猎者','听风者','呼号者','守巢者']
const NAMES := {'street':'末班巡更人','clinic':'不肯下班的护士长','works':'炉边的焊面人','residential':'敲门的父亲','market':'守摊的红围裙','waterworks':'阀门看守','depot':'搬运队长','broadcast':'无声播音员','evac':'最后的摆渡人'}
const LORE := {
 'street':'巡更人的鞋底仍钉着铜片。每走完一段街，他会停下来听三声回音。关门遮住视线，再等他转身，能避开正面冲突。',
 'clinic':'护士长反复回到旧病房门口，听见奔跑会呼唤走廊里的感染者。她失去了语言，却保留了查房的路线。先关上隔门，别让一次惊动传遍整层。',
 'works':'焊面人护着早已熄灭的炉子。面罩使他的正面观察迟钝，但敲击声会让他反扑。隔着开窗投出声源，再从另一扇门绕开。',
 'residential':'门内的身影还在重复敲门的动作。踉跄撤退不是逃跑，它在寻找同伴。别追进未经窥视的房间。',
 'market':'红围裙守着空摊位，眼睛已混浊，却能分辨玻璃声。反复使用同一个诱饵会被识破；换一个声源位置，或者改走安静的门。',
 'waterworks':'阀门看守会回到设备旁。破窗会把它引向你；门闩和楼梯却能延缓追击。它守的不是宝物，而是感染前最后一个工作地点。',
 'depot':'搬运队长会沿楼梯寻找声音，也会利用你打通的另一条通路。听见远处的呼号，不代表它已经知道你在哪；收起脚步声，换楼层。',
 'broadcast':'无声播音员喉咙里只能挤出尖啸。同层感染者会响应，远处的只会调查声音。关门、打断它的抬头动作，或者在被看见前离开。',
 'evac':'摆渡人的口袋里是一张没有日期的船票。它靠着旧闸门等候，受伤时会缩回同伴身后。观察它的往返，再决定绕行还是清除。'}

static func make(id: String,index: int) -> Dictionary:
 var role:int={'street':1,'clinic':2,'works':3,'residential':0,'market':1,'waterworks':3,'depot':0,'broadcast':2,'evac':3}[id] if index==2 else (LocationCatalog.ALL_IDS.find(id)+index)%4
 return {'role':role,'call':0.0,'ignore':0.0,'lure_x':0.0,'lure_floor':0,'spooked':0.0,'last_hp':-1,'investigations':0,'search':{}}

static func record(field: ExpeditionState,enemy: Dictionary) -> Dictionary:
 var i:=field.enemies.find(enemy)
 return field.minds[i] if i>=0 and i<field.minds.size() else {}

static func vision(field: ExpeditionState,enemy: Dictionary) -> float:
 var m:=record(field,enemy)
 return .65 if m.get('role',0)==1 else 1.15 if m.get('role',0)==0 else 1.0

static func hearing(field: ExpeditionState,enemy: Dictionary) -> float:
 return 1.5 if record(field,enemy).get('role',0)==1 else 1.0

static func tick(field: ExpeditionState,enemy: Dictionary,delta: float) -> void:
 var m:=record(field,enemy)
 if m.is_empty():return
 for key in ['call','ignore','spooked']:m[key]=maxf(0,float(m[key])-delta)
 if m['last_hp']>=0 and enemy['hp']<m['last_hp']:m['spooked']=8.0
 m['last_hp']=enemy['hp']
 for lure in field.decoys:
  if lure['floor']==enemy['floor'] and absf(float(lure['x'])-float(enemy['x']))<38:
   if m['ignore']<=0 or absf(float(m['lure_x'])-float(lure['x']))>20:m['investigations']=mini(10000,int(m['investigations'])+1)
   m['ignore']=18.0;m['lure_x']=float(lure['x']);m['lure_floor']=int(lure['floor'])

static func ignores(field: ExpeditionState,enemy: Dictionary,lure: Dictionary) -> bool:
 var m:=record(field,enemy)
 return m.get('ignore',0)>0 and lure['floor']==m.get('lure_floor',0) and absf(float(lure['x'])-float(m.get('lure_x',0)))<65

static func observe(field: ExpeditionState,enemy: Dictionary,sees: bool,hears: bool,delta: float) -> void:
 var m:=record(field,enemy)
 if m.is_empty():return
 if m['role']==2 and sees and enemy['suspicion']>=65 and m['call']<=0:
  m['call']=14.0
  for other in field.enemies:
   if other==enemy or other['hp']<=0:continue
   if absf(float(other['x'])-float(enemy['x']))<650:
    record(field,other)['search'].clear()
    other['target']=enemy['x'];other['target_floor']=enemy['floor'];other['memory']=6.0
    other['suspicion']=maxf(other['suspicion'],65);other['mode']='investigate'
  field.combat_resolved.emit('howl',Vector2(enemy['x'],field.enemy_y(enemy)-70),0)

static func retreat(field: ExpeditionState,enemy: Dictionary,delta: float) -> bool:
 var m:=record(field,enemy)
 if m.get('spooked',0)<=0 or enemy['kind']=='brute' or enemy['hp']>float(EnemyCatalog.stats(enemy['kind'])['health'])*.4:return false
 for other in field.enemies:
  if other!=enemy and other['hp']>0 and other['floor']==enemy['floor'] and absf(float(other['x'])-float(enemy['x']))>120:
   field._enemy_route(enemy,float(other['x']),int(other['floor']),65,delta)
   return true
 return false

static func patrol(field: ExpeditionState,enemy: Dictionary,to: float,delta: float) -> float:
 var role:int=record(field,enemy).get('role',0)
 if role==0 and fposmod(field.elapsed,7)<3:return float(enemy['x'])
 if role==1 and fposmod(field.elapsed,5)<1.5:
  enemy['direction']=1.0 if int(field.elapsed)%2 else -1.0
  return float(enemy['x'])
 if role==3:to=move_toward(float(enemy['x']),(float(enemy['min'])+float(enemy['max']))*.5,22*delta)
 return field.interior.enemy_move(field,enemy,to,delta)

static func label(field: ExpeditionState,index: int) -> String:
 return (str(NAMES[field.location_id])+' · ' if index==2 else '')+str(ROLES[field.minds[index]['role']])

static func validate(data: Variant,enemies: Variant,id: String='street') -> String:
 if not data is Array or not enemies is Array or data.size()!=enemies.size():return '感染者行为记录数量无效'
 for m in data:
  if not CharacterState.keys(m,['role','call','ignore','lure_x','lure_floor','spooked','last_hp','investigations','search']):return '感染者行为字段无效'
  if not CharacterState.integer(m['role'],0,3) or not CharacterState.number(m['call'],0,14) or not CharacterState.number(m['ignore'],0,18) or not CharacterState.number(m['lure_x'],0,10000) or not CharacterState.integer(m['lure_floor'],0,1) or not CharacterState.number(m['spooked'],0,8) or not CharacterState.integer(m['last_hp'],-1,90) or not CharacterState.integer(m['investigations'],0,10000):return '感染者行为状态无效'
  var search: Variant = m['search']
  if not search is Dictionary:return '调查计划无效'
  if not search.is_empty():
   if not CharacterState.keys(search,['x','floor','time','step','wait','destinations']) or not CharacterState.integer(search['floor'],0,1) or not CharacterState.number(search['time'],0,6) or not CharacterState.number(search['wait'],0,1.1) or not search['destinations'] is Array or search['destinations'].is_empty() or search['destinations'].size()>3 or not CharacterState.integer(search['step'],0,search['destinations'].size()-1):return '调查阶段无效'
   var map: Dictionary = LocationCatalog.area(id)
   var low: float = 90 if search['floor']==0 else map['upper_left']
   var high: float = float(map['width'])-(100 if search['floor']==0 else 150)
   if not CharacterState.number(search['x'],low,high):return '调查记忆越界'
   for x in search['destinations']:
    if not CharacterState.number(x,low,high) or absf(float(x)-float(search['x']))>240:return '调查路线越界'
 return ''

static func investigate(field: ExpeditionState,enemy: Dictionary,delta: float,sensed: bool) -> bool:
 var mind:=record(field,enemy)
 if mind.is_empty():return false
 if sensed or enemy['hp']<=0:
  mind['search'].clear();return false
 if not enemy['mode'] in ['chase','investigate']:return false
 var search: Dictionary = mind['search']
 if search.is_empty():
  if enemy['memory']<=0 or enemy['floor']!=enemy['target_floor'] or enemy['climb_target']!=-1 or absf(float(enemy['x'])-float(enemy['target']))>30:return false
  var floor_id: int = enemy['floor'];var x: float = enemy['target']
  var low: float = 90 if floor_id==0 else field.upper_left();var high: float = field.right_edge(floor_id)
  var destinations: Array = []
  for offset in [float(enemy['direction'])*120,-float(enemy['direction'])*120]:destinations.append(clampf(x+offset,low,high))
  for wall in InteriorState.layout(field.location_id):
   if wall['floor']==floor_id and absf(float(wall['x'])-x)<150:
    destinations.append(clampf(float(wall['x'])+(70 if float(wall['x'])>x else -70),low,high));break
  search.merge({'x':x,'floor':floor_id,'time':6.0,'step':0,'wait':1.1,'destinations':destinations})
  enemy['memory']=6.1;enemy['mode']='investigate'
 search['time']=maxf(0,float(search['time'])-delta)
 if search['time']<=0:
  search.clear();enemy['memory']=0.0;enemy['suspicion']=0.0;enemy['mode']='patrol';return false
 if search['wait']>0:
  search['wait']=maxf(0,float(search['wait'])-delta)
  enemy['direction']=1.0 if search['wait']>.55 else -1.0
  return true
 var destination: float = search['destinations'][int(search['step'])]
 enemy['target']=destination;enemy['target_floor']=search['floor']
 if absf(float(enemy['x'])-destination)<20:
  if int(search['step'])<search['destinations'].size()-1:search['step']=int(search['step'])+1;search['wait']=.8
  else:search['time']=minf(float(search['time']),.8);search['wait']=.8
 else:field._enemy_route(enemy,destination,int(search['floor']),48,delta)
 return true
