class_name InteriorState
extends RefCounted
## Persistent physical partitions. Neither visibility nor collisions know a
## hidden actor's current position; room reveals are separate from live sight.
static var _layouts: Dictionary = {}
var enabled := true
var doors: Array[Dictionary] = []
var seen: Array[int] = []
var action: Dictionary = {}
var held := false
var held_kind := ""
var peeking := false

static func layout(id: String) -> Array[Dictionary]:
 if _layouts.has(id):return _layouts[id]
 # The two district locations use authored partitions: clinic ward / pharmacy
 # and pump hall / valve gallery, connected by the ordinary and service ladders.
 if id in ['clinic','waterworks']:
  var authored:Dictionary={'clinic':[[980.0,0],[1840.0,0],[1715.0,1],[2200.0,1]],'waterworks':[[1130.0,0],[2360.0,0],[2250.0,1]]}
  var rooms:Array[Dictionary]=[]
  for p:Array in authored[id]:rooms.append({'x':float(p[0]),'floor':int(p[1])})
  _layouts[id]=rooms;return rooms
 var map: Dictionary = LocationCatalog.area(id)
 var result: Array[Dictionary] = []
 for floor_id in range(2):
  var low: float = 90 if floor_id == 0 else float(map['upper_left'])
  var high: float = float(map['width'])-(100 if floor_id == 0 else 150)
  var counts: Array = {'street':[3,2],'clinic':[3,3],'works':[4,2],'residential':[4,3],'market':[2,2],'waterworks':[3,2],'depot':[3,2],'broadcast':[2,3],'evac':[2,2]}[id]
  var count: int = counts[floor_id]
  for n in range(1,count):
   var x := lerpf(low,high,float(n)/count)
   # Keep wall controls distinct from cabinets and ladder landings.
   for site in map['sites']:
    if site['floor']==floor_id and absf(x-float(site['x']))<105:x=float(site['x'])+115
   if absf(x-float(map['ladder']))<100:x+=115
   x=clampf(x,low+160,high-160)
   result.append({'x':x,'floor':floor_id})
 _layouts[id]=result
 return result

func setup(id: String, initially_open: bool = false) -> void:
 doors.clear();seen.clear();action.clear();held=false;peeking=false
 for point in layout(id):doors.append({'open':initially_open,'hp':60.0,'window':0})

func barrier(id: String, a: float, b: float, floor_id: int) -> int:
 if not enabled:return -1
 var points:=layout(id)
 var chosen:=-1;var nearest:=INF
 for n in range(doors.size()):
  if points[n]['floor']==floor_id and not doors[n]['open'] and doors[n]['hp']>0 and minf(a,b)<float(points[n]['x']) and maxf(a,b)>float(points[n]['x']):
   var distance:=absf(float(points[n]['x'])-a)
   if distance<nearest:chosen=n;nearest=distance
 return chosen

func stop_x(id: String, a: float, b: float, floor_id: int) -> float:
 if not enabled or is_equal_approx(a,b):return b
 var direction:=signf(b-a)
 var result:=b
 var points:=layout(id)
 for n in range(doors.size()):
  if points[n]['floor']!=floor_id or doors[n]['open'] or doors[n]['hp']<=0:continue
  var wall:=float(points[n]['x'])
  # Stop at the body boundary before crossing the wall. Old saves may start
  # inside that margin; do not push them backwards or trap them moving away.
  if direction>0 and a<wall and b>wall-18:
   result=minf(result,maxf(a,wall-18))
  elif direction<0 and a>wall and b<wall+18:
   result=maxf(result,minf(a,wall+18))
 return result

func clear_sight(id: String,a: float,b: float,floor_id: int) -> bool:
 if not enabled:return true
 var points:=layout(id)
 for n in range(doors.size()):
  if points[n]['floor']==floor_id and not doors[n]['open'] and doors[n]['hp']>0 and minf(a,b)<float(points[n]['x']) and maxf(a,b)>float(points[n]['x']) and doors[n]['window']==0:return false
 return true

func room(id: String,x: float,floor_id: int) -> int:
 var index:=floor_id*10
 for p in layout(id):
  if p['floor']==floor_id and x>float(p['x']):index+=1
 return index

func visible(field: ExpeditionState,x: float,floor_id: int) -> bool:
 if not enabled:return true
 if floor_id!=field.floor_level:return false
 if clear_sight(field.location_id,field.player_x,x,floor_id):return true
 if peeking:
  var n:=nearby(field)
  if n>=0 and layout(field.location_id)[n]['floor']==floor_id and absf(x-float(layout(field.location_id)[n]['x']))<230:return true
 return false

func nearby(field: ExpeditionState) -> int:
 if not enabled or field.climb_target!=-1:return -1
 var points:=layout(field.location_id)
 for n in range(points.size()):
  if points[n]['floor']==field.floor_level and absf(field.player_x-float(points[n]['x']))<62:return n
 return -1

func hit(field: ExpeditionState,p: Vector2) -> int:
 if not enabled:return -1
 var points:=layout(field.location_id)
 for n in range(points.size()):
  if Rect2(float(points[n]['x'])-23,ExpeditionState.FLOOR_Y[points[n]['floor']]-125,80,130).has_point(p):return n
 return -1

func controls(field: ExpeditionState,actor: Survivor,delta: float,input: Dictionary) -> Dictionary:
 if not enabled:return input
 var result:=input.duplicate()
 peeking=bool(input.get('peek',false)) and nearby(field)>=0
 var index:=nearby(field)
 var press:=bool(input.get('interact',false)) or bool(input.get('window',false))
 var pressed_kind: String='window' if bool(input.get('window',false)) else 'door'
 if not press:held=false;held_kind=''
 elif pressed_kind!=held_kind:held=false;held_kind=pressed_kind
 if not action.is_empty():
  if press:held=true
  var n:int=action['door'];var kind:String=action['kind']
  if (action['quiet'] and field.bag['tools']<1) or actor.health<float(action['health']) or (kind!='vault' and (absf(float(input.get('axis',0)))>0 or int(input.get('climb',0))!=0)):
   if kind=='vault':field.player_x=float(action['from']) if float(action['elapsed'])<.5 else float(action['to'])
   action.clear();return result
  var duration:=1.2 if kind=='door' else 3.0 if kind=='window' else 1.0
  action['elapsed']=minf(duration,float(action['elapsed'])+delta*CharacterAbilities.factor(actor,'door'))
  if kind=='vault':
   field.player_x=lerpf(action['from'],action['to'],float(action['elapsed'])/duration)
  field.noise_burst=maxf(field.noise_burst,12 if kind=='door' or action['quiet'] else 80 if kind=='window' else 22)
  result['axis']=0.0;result['climb']=0;result['interact']=false
  field._reset_search()
  if action['elapsed']>=duration:
   if kind=='door':doors[n]['open']=not doors[n]['open']
   elif kind=='window':
    if action['quiet']:
     if field.bag['tools']<1:action.clear();return result
     field.bag['tools']-=1
    doors[n]['window']=1 if action['quiet'] else 2
   action.clear()
  return result
 if index>=0 and press and not held:
  held=true
  var kind: String='door'
  if bool(input.get('window',false)):kind='window' if doors[index]['window']==0 else 'vault'
  if kind=='door' and doors[index]['hp']<=0:return result
  var x:float=layout(field.location_id)[index]['x']
  var from:=field.player_x;var to:=x+(44 if from<x else -44)
  action={'door':index,'kind':kind,'elapsed':0.0,'health':actor.health,'from':from,'to':to,'quiet':kind=='window' and field.bag['tools']>0 and not bool(input.get('sprint',false))}
  field._reset_route();field._reset_search()
 if index>=0 and press:result['interact']=false
 if peeking:result['axis']=0.0;result['interact']=false
 return result

func enemy_move(field: ExpeditionState,enemy: Dictionary,to: float,delta: float) -> float:
 var a:float=enemy['x'];var n:=barrier(field.location_id,a,to,int(enemy['floor']))
 if n<0:return to
 var x:float=layout(field.location_id)[n]['x']
 if absf(a-x)>25:return x-signf(to-a)*24
 # Only a genuinely pursuing enemy attacks an obstruction. Random patrols
 # turn around, so a closed room never destroys itself before discovery.
 if not enemy['mode'] in ['chase','investigate']:enemy['direction']=-float(enemy['direction']);return a
 var damage:=22.0 if enemy['kind']=='brute' else 9.0
 doors[n]['hp']=maxf(0,float(doors[n]['hp'])-damage*delta)
 field.noise_burst=maxf(field.noise_burst,45)
 if doors[n]['hp']<=0:doors[n]['open']=true
 return a

func draw(canvas: Node2D,field: ExpeditionState,camera: float) -> void:
 if not enabled:return
 var points:=layout(field.location_id)
 var widths: Dictionary={0:[90.0,float(field.area()['width'])-100],1:[field.upper_left(),float(field.area()['width'])-150]}
 for floor_id in range(2):
  var cuts:Array=widths[floor_id].duplicate()
  for p in points:
   if p['floor']==floor_id:cuts.append(float(p['x']))
  cuts.sort()
  for n in range(cuts.size()-1):
   var middle:float=(float(cuts[n])+float(cuts[n+1]))*.5
   if not visible(field,middle,floor_id):
    var known:=seen.has(room(field.location_id,middle,floor_id))
    canvas.draw_rect(Rect2(float(cuts[n])-camera,ExpeditionState.FLOOR_Y[floor_id]-188,float(cuts[n+1])-float(cuts[n]),188),Color(.025,.032,.037,.72 if known else .97))
 for n in range(doors.size()):
  var p:=Vector2(float(points[n]['x'])-camera,ExpeditionState.FLOOR_Y[points[n]['floor']])
  var color:=Color('b8c6ad') if nearby(field)==n else Color('69746b')
  canvas.draw_rect(Rect2(p+Vector2(-7,-190),Vector2(14,68)),Color('38443f'))
  canvas.draw_rect(Rect2(p+Vector2(-6,-122),Vector2(12 if doors[n]['open'] else 20,122)),Color('343c38') if doors[n]['open'] else Color('796947'))
  canvas.draw_line(p+Vector2(-12,-126),p+Vector2(17,-126),color,3)
  canvas.draw_circle(p+Vector2(10,-57),3,color)
  canvas.draw_rect(Rect2(p+Vector2(24,-125),Vector2(40,57)),Color('21353e'),true)
  canvas.draw_rect(Rect2(p+Vector2(24,-125),Vector2(40,57)),color,false,2)
  if doors[n]['window']==0:canvas.draw_line(p+Vector2(25,-122),p+Vector2(62,-70),Color('869c9d'),2)
  else:canvas.draw_line(p+Vector2(24,-68),p+Vector2(64,-68),Color('bcaa79'),3)
  if doors[n]['window']==2:
   for shard in range(4):canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(21+shard*10,-1),p+Vector2(28+shard*10,-1),p+Vector2(25+shard*10,-6)]),Color('8da2a2'))
  if doors[n]['hp']<60 and not doors[n]['open']:
   canvas.draw_line(p+Vector2(-15,-140),p+Vector2(15,-140),Color('302d29'),4)
   canvas.draw_line(p+Vector2(-15,-140),p+Vector2(-15+30*float(doors[n]['hp'])/60,-140),Color('ce9270'),3)
 if not action.is_empty():
  var duration:=1.2 if action['kind']=='door' else 3.0 if action['kind']=='window' else 1.0
  var p:=Vector2(field.player_x-camera,field.player_y-101)
  canvas.draw_arc(p,16,-PI/2,-PI/2+TAU*float(action['elapsed'])/duration,30,Color('d9c48e'),3,true)

func observe(field: ExpeditionState) -> void:
 if not enabled:return
 var id:=room(field.location_id,field.player_x,field.floor_level)
 if not seen.has(id):seen.append(id)

func snapshot() -> Dictionary:return {'enabled':enabled,'doors':doors.duplicate(true),'seen':seen.duplicate(),'action':action.duplicate(true)}
func restore(data: Dictionary) -> void:
 enabled=data['enabled'];doors.clear();seen.clear();action=data['action'].duplicate(true);held=false;peeking=false
 for d in data['doors']:doors.append(d.duplicate())
 for n in data['seen']:seen.append(int(n))

static func validate(data: Variant,id: String,field: Dictionary) -> String:
 if not field['bag'] is Dictionary:return '房间行动的背包无效'
 if not CharacterState.keys(data,['enabled','doors','seen','action']) or not data['enabled'] is bool or not data['doors'] is Array or data['doors'].size()!=layout(id).size() or not data['seen'] is Array or data['seen'].size()>8 or not data['action'] is Dictionary:return '房间记录无效'
 for d in data['doors']:
  if not CharacterState.keys(d,['open','hp','window']) or not d['open'] is bool or not CharacterState.number(d['hp'],0,60) or not CharacterState.integer(d['window'],0,2) or (d['hp']==0 and not d['open']):return '门窗状态无效'
 var seen:Array=[]
 for n in data['seen']:
  if not CharacterState.integer(n,0,12) or not int(n) in [0,1,2,3,10,11,12] or seen.has(int(n)):return '房间探索记录无效'
  seen.append(int(n))
 var a:Dictionary=data['action']
 if not a.is_empty():
  if not CharacterState.keys(a,['door','kind','elapsed','health','from','to','quiet']) or not field['active'] or not CharacterState.integer(a['door'],0,layout(id).size()-1) or not a['kind'] in ['door','window','vault']:return '门窗行动无效'
  var point:Dictionary=layout(id)[int(a['door'])]
  var duration:=1.2 if a['kind']=='door' else 3.0 if a['kind']=='window' else 1.0
  if not a['quiet'] is bool or (a['quiet'] and (a['kind']!='window' or field['bag'].get('tools',0)<1)):return '静拆窗口缺少工具'
  if point['floor']!=field['floor'] or field['climb_target']!=-1 or absf(float(field['player_x'])-float(point['x']))>64 or not CharacterState.number(a['elapsed'],0,duration-.00000001) or not CharacterState.number(a['health'],0,100):return '门窗行动位置或工时无效'
  if not CharacterState.number(a['from'],float(point['x'])-64,float(point['x'])+64) or not CharacterState.number(a['to'],float(point['x'])-64,float(point['x'])+64):return '翻窗路线无效'
 return ''

func cancel(field: ExpeditionState) -> void:
 if not action.is_empty() and action['kind']=='vault':field.player_x=float(action['from']) if float(action['elapsed'])<.5 else float(action['to'])
 action.clear()
