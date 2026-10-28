class_name CampaignChronicle
extends RefCounted
var scenario := 'classic'
var arcs: Dictionary = {}
var intel: Array[String] = []
var trip_evidence: Array[String] = []
var work: Dictionary = {}
var last_day := 0
var meal_day := 0
var manual_defense := true

func sync(game: Node2D) -> void:
 for actor: Survivor in game.survivors:
  var id:=actor.person.persona
  if not arcs.has(id):arcs[id]={'stage':0,'choice':-1,'last_trip':1}
  if arcs[id]['stage']==1:
   var arc:Dictionary=ChronicleCatalog.ARCS[id]
   var field:ExpeditionState=game.regions[arc['map']]
   if not field.special_sites.has(int(arc['site'])):field.special_sites.append(int(arc['site']))

func apply_scenario(game: Node2D,id: String) -> void:
 scenario=id;arcs.clear();intel.clear();trip_evidence.clear();work.clear();last_day=0;meal_day=0;manual_defense=true
 var config:Dictionary=ChronicleCatalog.SCENARIOS[id]
 game.ensure_roster(config['roster'])
 game.people=PeopleSystem.new();game.people.sync_members(game.survivors)
 game.people.event_reported.connect(game._log)
 game.inventory.restore_validated(config['stock'],[])
 game.expansion.gear.clear();game.expansion.next_id=1
 for pair in config['weapons']:game.expansion.grant(pair[0],pair[1])
 for actor: Survivor in game.survivors:
  actor.metabolism=.4;actor.hunger=40;actor.fatigue=25;actor.person.thirst=20
 game.self_care.members.clear();game.self_care.sync(game)
 if id=='infirmary':
  for item in [['bed',0],['heater',1]]:game.cycle.builds.append({'slot':item[1],'type':item[0],'state':'complete','actor':-1,'elapsed':CampaignCycle.RECIPES[item[0]]['seconds']})
  game.expansion.use_night_heat=true
 sync(game);game.expansion.sync(game);game._props_signature='';game._sync_props()
 game._log('新战役：'+config['name']+'。初始物资、队伍与气候已按开局设定，不会在之后重复发放。')

func perk(id: String,key: String) -> float:
 if not arcs.has(id) or arcs[id]['stage']!=3:return 1.0
 return float(ChronicleCatalog.PERKS[id][arcs[id]['choice']].get(key,1.0))

func choice(game: Node2D,id: String,index: int) -> bool:
 sync(game)
 if game.cycle.phase!='day' or game.game_over or not arcs.has(id) or arcs[id]['stage']!=0 or not index in [0,1]:return false
 var actor:Survivor=_actor(game,id)
 if actor==null or actor.health<=0:return false
 var cost:Dictionary={'materials':2} if index==0 else {'meals':1}
 if not game.inventory.try_take(cost,'人物线选择：'+actor.display_name):return false
 arcs[id]['stage']=1;arcs[id]['choice']=index
 actor.person.morale=minf(100,actor.person.morale+(4 if index==0 else 8));actor.person.stress=maxf(0,actor.person.stress-6)
 game._log(actor.display_name+'：'+str(ChronicleCatalog.ARCS[id]['a' if index==0 else 'b']))
 return true

func site(game: Node2D,index: int) -> void:
 if not game.expedition.active:return
 var map:String=game.expedition.location_id
 if index==2 and not intel.has(map):
  intel.append(map);game._log('记录了'+str(EnemyMind.NAMES[map])+'的现场线索。F3感染档案可查看；不会自动改变敌人的位置或血量。')
 for id in arcs:
  var arc:Dictionary=ChronicleCatalog.ARCS[id]
  if arcs[id]['stage']==1 and arc['map']==map and arc['site']==index and not trip_evidence.has(id):trip_evidence.append(id)

func trip_return(game: Node2D,survived: bool,returned_id: int=-1) -> void:
 if survived:
  for id in trip_evidence:
   if arcs.has(id) and arcs[id]['stage']==1:arcs[id]['stage']=2;game._log('人物线勘查完成：'+str(ChronicleCatalog.ARCS[id]['title']))
  if returned_id>=0:
   var actor:Survivor=game.survivors[returned_id]
   if arcs.has(actor.person.persona):arcs[actor.person.persona]['last_trip']=ExpeditionState.day_at(game.simulation_time)
 trip_evidence.clear()

func start_work(game: Node2D,id: String) -> bool:
 sync(game)
 var actor:Survivor=_actor(game,id)
 if actor==null or actor.health<=0 or game.cycle.phase!='day' or not work.is_empty() or arcs[id]['stage']!=2:return false
 var cost:Dictionary=ChronicleCatalog.ARCS[id]['cost']
 if not game.inventory.can_take(cost):return false
 var path:Array[Vector2]=game.scheduler.navigation.route_between(actor.position,game.facility.work_position())
 if path.is_empty():return false
 game._cancel_external(actor.survivor_id);game.scheduler.cancel(actor)
 actor.route=path;actor.state=Survivor.TaskState.RETURNING;actor.feedback='前往完成人物计划'
 work={'actor':actor.survivor_id,'id':id,'elapsed':0.0,'health':actor.health}
 return true

func tick_day(game: Node2D,delta: float) -> void:
 sync(game)
 var day:=ExpeditionState.day_at(game.simulation_time)
 if day!=last_day:
  last_day=day
  var courier:Survivor=_actor(game,'tang')
  if courier!=null and courier.health>0 and day-int(arcs['tang']['last_trip'])>=3:courier.person.morale=maxf(0,courier.person.morale-2)
 if work.is_empty():return
 var actor:Survivor=game.survivors[int(work['actor'])]
 if actor.health<float(work['health']) or actor.health<=0:cancel(game,actor.survivor_id);return
 if not actor.route.is_empty():return
 work['elapsed']=minf(12,float(work['elapsed'])+delta*actor.person.bonus('craft'))
 actor.activity={'kind':'personal','label':ChronicleCatalog.ARCS[work['id']]['work'],'progress':float(work['elapsed'])/12}
 if work['elapsed']<12:return
 var id:String=work['id']
 if game.inventory.try_take(ChronicleCatalog.ARCS[id]['cost'],'完成专属计划：'+actor.display_name):
  arcs[id]['stage']=3;actor.person.morale=minf(100,actor.person.morale+12);actor.person.stress=maxf(0,actor.person.stress-12)
  game._log(actor.display_name+'：'+str(ChronicleCatalog.ARCS[id]['after_a' if arcs[id]['choice']==0 else 'after_b']))
 else:game._log('专属计划因缺料中止，没有产生收益。')
 actor.activity.clear();work.clear()

func cancel(game: Node2D,id: int) -> void:
 if not work.is_empty() and int(work['actor'])==id:work.clear();game.survivors[id].activity.clear()

func job(game: Node2D,id: int,task: String) -> void:
 var actor:Survivor=game.survivors[id]
 if actor.person.persona=='lin' and task in ['craft','repair']:actor.person.stress=maxf(0,actor.person.stress-1)
 if actor.person.persona=='he' and task=='cook':actor.person.morale=minf(100,actor.person.morale+1)
 if actor.person.persona=='gu' and task=='heal':actor.person.stress=maxf(0,actor.person.stress-2)

func aid(game: Node2D,actor: Survivor) -> void:
 if actor.person.persona in ['xu','gu']:actor.person.morale=minf(100,actor.person.morale+3)

func shared_meal(game: Node2D) -> bool:
 var day:=ExpeditionState.day_at(game.simulation_time)
 var actor:Survivor=_actor(game,'he')
 if actor==null or actor.health<=0 or not arcs.has('he') or arcs['he']['stage']!=3 or game.cycle.phase!='day' or day==meal_day or game.expansion.jobs.any(func(job):return job['kind']=='picnic'):return false
 if not game.inventory.try_take({'meals':2},'厨师的公共餐桌'):return false
 meal_day=day
 for member: Survivor in game.survivors:
  if member.health>0:member.person.morale=minf(100,member.person.morale+6);member.person.stress=maxf(0,member.person.stress-8)
 return true

func _actor(game: Node2D,id: String) -> Survivor:
 for actor: Survivor in game.survivors:
  if actor.person.persona==id:return actor
 return null

func snapshot(game: Node2D) -> Dictionary:
 sync(game)
 return {'scenario':scenario,'arcs':arcs.duplicate(true),'intel':intel.duplicate(),'trip_evidence':trip_evidence.duplicate(),'work':work.duplicate(true),'last_day':last_day,'meal_day':meal_day,'manual_defense':manual_defense}
func restore(data: Dictionary) -> void:
 if data.is_empty():scenario='classic';arcs.clear();intel.clear();trip_evidence.clear();work.clear();last_day=0;meal_day=0;manual_defense=true;return
 scenario=data['scenario'];arcs=data['arcs'].duplicate(true);work=data['work'].duplicate(true);last_day=int(data['last_day']);meal_day=int(data['meal_day']);manual_defense=data['manual_defense'];intel.clear();trip_evidence.clear()
 for id in data['intel']:intel.append(id)
 for id in data['trip_evidence']:trip_evidence.append(id)

static func validate(data: Variant,world: Dictionary) -> String:
 if world['campaign'].is_empty():return '' if data is Dictionary and data.is_empty() else '基础场景不含人物志'
 if not CharacterState.keys(data,['scenario','arcs','intel','trip_evidence','work','last_day','meal_day','manual_defense']) or not ChronicleCatalog.SCENARIOS.has(data['scenario']) or not data['manual_defense'] is bool or not data['arcs'] is Dictionary or data['arcs'].size()!=world['actors'].size():return '人物志记录无效'
 var day:=ExpeditionState.day_at(world['simulation_time'])
 if not CharacterState.integer(data['last_day'],0,day) or not CharacterState.integer(data['meal_day'],0,day):return '人物志时钟无效'
 for actor in world['actors']:
  var id:String=actor['person']['persona']
  if not data['arcs'].has(id) or not CharacterState.keys(data['arcs'][id],['stage','choice','last_trip']):return '个人线身份无效'
  var a:Dictionary=data['arcs'][id]
  if not CharacterState.integer(a['stage'],0,3) or not CharacterState.integer(a['choice'],-1,1) or (a['stage']==0)!=(a['choice']==-1) or not CharacterState.integer(a['last_trip'],1,day):return '个人线阶段无效'
 if not data['intel'] is Array or data['intel'].size()>9 or not data['trip_evidence'] is Array or data['trip_evidence'].size()>PeopleCatalog.MAX_HISTORY:return '勘查记录容量无效'
 var unique:Array=[]
 for id in data['intel']:
  if not id in LocationCatalog.ALL_IDS or unique.has(id):return '感染档案重复或未知'
  unique.append(id)
 unique.clear()
 for id in data['trip_evidence']:
  if not data['arcs'].has(id) or data['arcs'][id]['stage']!=1 or not world['expedition']['active'] or unique.has(id):return '人物线现场证据无效'
  unique.append(id)
 var work:Variant=data['work']
 if not work is Dictionary:return '人物计划无效'
 if not work.is_empty():
  if not CharacterState.keys(work,['actor','id','elapsed','health']) or world['campaign']['phase']!='day' or not CharacterState.integer(work['actor'],0,world['actors'].size()-1) or not data['arcs'].has(work['id']) or data['arcs'][work['id']]['stage']!=2 or not CharacterState.number(work['elapsed'],0,12-.00000001) or not CharacterState.number(work['health'],0,100):return '人物计划进度无效'
  var actor:Dictionary=world['actors'][int(work['actor'])]
  if actor['person']['persona']!=work['id'] or actor['health']<=0 or not actor['orders'].is_empty() or not int(actor['state']) in [Survivor.TaskState.IDLE,Survivor.TaskState.RETURNING]:return '人物计划人员无效'
 return ''
