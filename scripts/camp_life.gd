class_name CampLife
extends RefCounted
var enabled:=false
var food:=CampFood.new()
var relations:=CampRelations.new()
var situation:=CampSituation.new()
func start(game: Node2D) -> void:
 enabled=true;food=CampFood.new();relations=CampRelations.new();situation=CampSituation.new();food.start(game);relations.sync(game)
func busy(id: int) -> bool:return enabled and (food.busy(id) or relations.busy(id))
func reserves(station: String) -> bool:return enabled and (food.reserves_station(station) or relations.reserves_station(station))
func cancel(game: Node2D,id: int,refund: bool=true) -> void:
 if not enabled:return
 food.cancel(game,id,refund);relations.cancel(game,id,refund)
func tick(game: Node2D,delta: float) -> void:
 if not enabled:return
 food.tick(game,delta);relations.tick(game,delta);food.reconcile(game)
func plan(game: Node2D) -> void:
 if not enabled:return
 food.sync_people(game);relations.sync(game);food.plan(game);relations.plan(game)
func dawn(game: Node2D,report: Array) -> void:
 if not enabled:return
 situation.dawn(game,report);food.dawn(game,report);relations.night(game,report);food.reconcile(game)
func task_started(game: Node2D,id: int,task: String) -> void:
 if enabled and task=='eat':food.meal_started(game.survivors[id])
func task_finished(game: Node2D,id: int,task: String) -> void:
 if not enabled:return
 if task=='eat':food.meal_finished(game.survivors[id])
 if task=='heal':food.treat(game.survivors[id],25,20)
 food.reconcile(game)
func snapshot(game: Node2D) -> Dictionary:
 if not enabled:return {}
 food.sync_people(game);relations.sync(game);food.reconcile(game)
 return {'food':food.snapshot(),'relations':relations.snapshot(),'situation':situation.snapshot()}
func restore(data: Dictionary) -> void:
 enabled=not data.is_empty();food=CampFood.new();relations=CampRelations.new();situation=CampSituation.new()
 if enabled:food.restore(data['food']);relations.restore(data['relations']);situation.restore(data['situation'])
static func validate(data: Variant,world: Dictionary) -> String:
 if data is Dictionary and data.is_empty():return ''
 if world['campaign'].is_empty() or not CharacterState.keys(data,['food','relations','situation']):return '营地系统记录无效'
 var problem:=CampFood.validate(data['food'],world)
 if not problem.is_empty():return problem
 problem=CampSituation.validate(data['situation'],world)
 if not problem.is_empty():return problem
 return validate_relations(data['relations'],world,data['food'])
static func validate_relations(data: Variant,world: Dictionary,food: Dictionary) -> String:
 if not CharacterState.keys(data,CampRelations.new().snapshot().keys()):return '同伴关系字段无效'
 var day:=ExpeditionState.day_at(world['simulation_time']);var ids:Array=world['actors'].map(func(actor):return actor['person']['persona'])
 for key in ['policies','duties','talked','repaired']:
  if not CharacterState.keys(data[key],ids):return '同伴关系人数无效'
 for id in ids:
  if not CharacterState.keys(data['policies'][id],['social','watch','maintain']) or not CharacterState.keys(data['duties'][id],['streak','last']):return '性格行动授权无效'
  for value in data['policies'][id].values():
   if not value is bool:return '性格行动授权状态无效'
  if not CharacterState.integer(data['duties'][id]['streak'],0,day) or not data['duties'][id]['last'] in CampaignCycle.ROLES:return '轮值记录无效'
  for key in ['talked','repaired']:
   if not CharacterState.integer(data[key][id],0,day):return '协作日期无效'
 if not CharacterState.integer(data['last_night'],0,day) or not data['memories'] is Array or data['memories'].size()>24:return '共同经历无效'
 for row in data['memories']:
  if not CharacterState.keys(row,['day','kind','owner','others']) or not CharacterState.integer(row['day'],1,day) or not row['kind'] in ['talk','meal','mediate','watch','maintain'] or not row['owner'] in ids or not row['others'] is Array or row['others'].size()>3:return '共同经历内容无效'
  for member in row['others']:
   if not CharacterState.integer(member,0,ids.size()-1):return '共同经历人物无效'
 for key in ['dispute','promise']:
  if not data[key] is Dictionary:return '分工争议无效'
  if not data[key].is_empty():
   var expected:Array=['left','right','day','kind'] if key=='dispute' else ['left','right']
   if not CharacterState.keys(data[key],expected) or not CharacterState.integer(data[key]['left'],0,ids.size()-1) or not CharacterState.integer(data[key]['right'],0,ids.size()-1) or data[key]['left']==data[key]['right']:return '分工争议双方无效'
   if key=='dispute' and (not CharacterState.integer(data[key]['day'],1,day) or data[key]['kind']!='duty'):return '分工争议日期无效'
 var job:Variant=data['job']
 if not job is Dictionary:return '共同协作行动无效'
 if not job.is_empty():
  if not CharacterState.keys(job,['kind','owner','members','destinations','health','elapsed','automatic','meal_quality']) or not job['kind'] in ['talk','meal','mediate','watch','maintain'] or not CharacterState.integer(job['owner'],0,ids.size()-1) or not job['members'] is Array or job['members'].size()<1 or job['members'].size()>3 or not job['members'].has(int(job['owner'])) or not job['destinations'] is Array or job['destinations'].size()!=job['members'].size() or not job['health'] is Array or job['health'].size()!=job['members'].size() or not CharacterState.number(job['elapsed'],0,8) or not job['automatic'] is bool or world['campaign']['phase']!='day':return '共同协作状态无效'
  if not job['meal_quality'] is Array or job['meal_quality'].size()>2:return '共餐食物记录无效'
  var portions:=0
  for q in job['meal_quality']:
   if not CharacterState.keys(q,['kind','count','born']) or not q['kind'] in ['plain','balanced','broth','vegetable'] or not CharacterState.integer(q['count'],1,2) or not CharacterState.integer(q['born'],0,day):return '共餐食物品质无效'
   portions+=int(q['count'])
  if portions!=(2 if job['kind']=='meal' else 0):return '共餐份数无效'
  var seen:Array=[]
  for n in range(job['members'].size()):
   var member:Variant=job['members'][n]
   if not CharacterState.integer(member,0,ids.size()-1) or seen.has(int(member)) or not SaveSystem._point(job['destinations'][n]) or not CharacterState.number(job['health'][n],0,100):return '共同协作位置无效'
   seen.append(int(member));var actor:Dictionary=world['actors'][int(member)]
   if actor['health']<=0 or not actor['orders'].is_empty() or not actor['state'] in [Survivor.TaskState.IDLE,Survivor.TaskState.RETURNING] or food['jobs'].any(func(j):return j['actor']==member) or world['expansion']['jobs'].any(func(j):return j['actor']==member) or world['campaign']['actions'].any(func(j):return j['actor']==member):return '共同协作人员重复占用'
 return ''
static func cargo_slots_from(data: Variant) -> int:
 if not data is Dictionary or not data.get('food') is Dictionary or not data['food'].get('cargo') is Array:return 0
 var quantities:Dictionary={}
 var carried:Array=data['food']['cargo'].duplicate()
 if data['food'].get('field_action') is Dictionary and data['food']['field_action'].get('held') is Array:carried.append_array(data['food']['field_action']['held'])
 for lot in carried:
  if not lot is Dictionary or not lot.get('kind') is String or not CampFoodCatalog.ITEMS.has(lot['kind']) or not CharacterState.integer(lot.get('count'),1,1000000):return 0
  quantities[lot['kind']]=int(quantities.get(lot['kind'],0))+int(lot['count'])
 var count:=0
 for kind in quantities:count+=ceili(quantities[kind]/float(CampFoodCatalog.ITEMS[kind]['stack']))
 return count
