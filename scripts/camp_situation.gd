class_name CampSituation
extends RefCounted
## Seven-day fronts have a two-day warning, bounded effects and permanent counter-projects.
const TYPES := ['migration','water_alert','blackout','scarcity']
const INFO := {
 'migration':{'name':'尸群迁移','days':3,'hint':'基地夜袭概率+10%、压力+0.25。旧街和集市会出现额外感染者。可用远处诱饵改道，或安排两名守夜者协防。'},
 'water_alert':{'name':'水源警报','days':4,'hint':'新生产的清水减少，仓库清水保持安全。建造沉淀过滤器可减轻影响；储备、煮沸或过滤未净化水也能补给。'},
 'blackout':{'name':'区域停电','days':3,'hint':'基地电动净水泵停产，鲜肉和蔬菜每天多老化一天。备用设备开启后每夜燃料1可维持供电。重力供水不依赖电力。'},
 'scarcity':{'name':'补给荒','days':4,'hint':'普通地图新补入的杂粮减少，动物陷阱只产鲜肉1。种植、储备与补给协定提供替代来源。'},
}
var last_day:=0
var decision_index:=-1
var decision:=''
var resilience:={'filter':false,'generator':false,'pact':false}
var backup_on:=false
var powered_day:=0
var next_trade:=1
var applied:Dictionary={}
var recon_day:=0
var history:Array=[]

func forecast(day: int) -> Dictionary:
 var index:=maxi(0,floori((day-10)/7.0))
 var starts:=12+index*7
 var kind:String=TYPES[index%4]
 if day>starts+int(INFO[kind]['days'])-1:
  index+=1;starts=12+index*7;kind=TYPES[index%4]
 return {'index':index,'kind':kind,'starts':starts,'ends':starts+int(INFO[kind]['days'])-1,'active':day>=starts and day<=starts+int(INFO[kind]['days'])-1,'visible':day>=starts-2}

func active(day: int,kind: String) -> bool:
 var f:=forecast(day)
 return f['active'] and f['kind']==kind

func diverted(day: int) -> bool:
 return decision_index==int(forecast(day)['index']) and decision=='divert'

func raid_bonus(day: int,guards: int=0) -> float:
 if not active(day,'migration') or diverted(day):return 0
 return -.1 if guards>=2 else .25

func water_output(day: int,amount: int,gravity: bool=false) -> int:
 if not gravity and active(day,'blackout') and powered_day!=day:return 0
 if active(day,'water_alert'):return maxi(1,ceili(amount*(.8 if resilience['filter'] else .5)))
 return amount

func supply_factor(day: int) -> float:
 return .75 if active(day,'scarcity') and resilience['pact'] else .5 if active(day,'scarcity') else 1.0

func job_error(game: Node2D,kind: String) -> String:
 var day:int=game.expansion.day(game)
 var f:=forecast(day)
 if kind=='lure_horde' and (not f['visible'] or f['kind']!='migration' or diverted(day)):return '当前没有需要改道的迁移预警。'
 var key:String={'settling_filter':'filter','backup_power':'generator','supply_pact':'pact'}.get(kind,'')
 if not key.is_empty() and resilience[key]:return '这项设施或协定已经完成。'
 if kind=='caravan_trade' and (not resilience['pact'] or day<next_trade):return '需要补给协定，且每7天只能交换一次。'
 return ''

func complete(game: Node2D,kind: String,actor: Survivor) -> void:
 var day:int=game.expansion.day(game)
 match kind:
  'lure_horde':decision_index=forecast(day)['index'];decision='divert'
  'settling_filter':resilience['filter']=true;game.camp.food.infrastructure['filter']=true
  'backup_power':resilience['generator']=true
  'supply_pact':resilience['pact']=true
  'caravan_trade':
   next_trade=day+7
   game.camp.food.add({'cans':2,'seeds':1,'herbs':1},day)
   if actor.person.persona=='mickey':game.camp.food.add({'drinks':1},day)
 history.append({'day':day,'kind':kind});if history.size()>24:history.pop_front()

func reserve_power(game: Node2D) -> void:
 var night:int=game.cycle.night_day
 if powered_day==night:return
 if active(night,'blackout') and backup_on and resilience['generator'] and game.inventory.try_take({'fuel':1},'备用发电维持净水和保鲜'):powered_day=night

func dawn(game: Node2D,report: Array) -> void:
 var day:int=game.expansion.day(game)
 if day<=last_day:return
 last_day=day
 if powered_day==game.cycle.night_day:report.append('备用设备已消耗燃料1，维持昨夜净水和保鲜。')
 var f:=forecast(day)
 if f['visible']:
  report.append('【局势】%s · 第%d—%d天：%s'%[INFO[f['kind']]['name'],f['starts'],f['ends'],INFO[f['kind']]['hint']])
 if active(day,'water_alert') and not resilience['filter']:
  # Unsafe intake is stored separately; existing drinking water is never tainted.
  game.camp.food.add({'dirty_water':2},day)

func prepare_trip(game: Node2D) -> void:
 var day:int=game.expansion.day(game);var field:ExpeditionState=game.expedition
 var key:=str(day)+':'+field.location_id
 if applied.has(key):return
 applied[key]=true
 if applied.size()>90:applied.erase(applied.keys()[0])
 if active(day,'scarcity') and not field.persistent_loot:
  for site in field.sites:site['contents']['raw_food']=floori(int(site['contents']['raw_food'])*supply_factor(day))
 if not active(day,'migration'):return
 var areas:Array=['works'] if diverted(day) else ['street','market']
 if not areas.has(field.location_id):return
 # Add one real patrol before departure, with ordinary stats and independent memory.
 if field.migration_extra>0:return
 field.migration_extra=1
 var e:Dictionary=field.enemies.back().duplicate(true)
 e['kind']='runner';e['hp']=EnemyCatalog.stats('runner')['health'];e['mode']='patrol';e['memory']=0.0;e['timer']=0.0;e['cooldown']=0.0;e['brace']=0.0;e['climb_target']=-1;e['climb_progress']=0.0
 e['x']=float(e['max'])-30;e['target']=e['x'];e['direction']=-1.0
 field.enemies.append(e);field.minds.append(EnemyMind.make(field.location_id,field.enemies.size()-1))
 game._log('迁移中的感染者进入了这片区域；没有提高敌人的生命或伤害。')

func snapshot() -> Dictionary:
 return {'last_day':last_day,'decision_index':decision_index,'decision':decision,'resilience':resilience.duplicate(),'backup_on':backup_on,'powered_day':powered_day,'next_trade':next_trade,'applied':applied.duplicate(),'recon_day':recon_day,'history':history.duplicate(true)}
func restore(data: Dictionary) -> void:
 for key in data:set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
static func validate(data: Variant,world: Dictionary) -> String:
 if not CharacterState.keys(data,CampSituation.new().snapshot().keys()):return '局势记录不完整'
 var day:=ExpeditionState.day_at(world['simulation_time'])
 for key in ['last_day','powered_day','recon_day']:
  if not CharacterState.integer(data[key],0,day):return '局势日期无效'
 if not CharacterState.integer(data['decision_index'],-1,10000000) or not data['decision'] in ['','divert'] or (data['decision']=='')!=(data['decision_index']==-1):return '局势决策无效'
 if not CharacterState.keys(data['resilience'],['filter','generator','pact']) or not data['backup_on'] is bool:return '应对设施无效'
 for value in data['resilience'].values():
  if not value is bool:return '应对设施状态无效'
 if data['backup_on'] and not data['resilience']['generator']:return '备用电源尚未建造'
 if not CharacterState.integer(data['next_trade'],1,day+7) or not data['applied'] is Dictionary or data['applied'].size()>90 or not data['history'] is Array or data['history'].size()>24:return '局势账目无效'
 for key in data['applied']:
  if not key is String or key.get_slice_count(':')!=2 or not key.get_slice(':',0).is_valid_int() or not CharacterState.integer(int(key.get_slice(':',0)),1,day) or not key.get_slice(':',1) in LocationCatalog.ALL_IDS or data['applied'][key]!=true:return '局势地点记录无效'
 for row in data['history']:
  if not CharacterState.keys(row,['day','kind']) or not CharacterState.integer(row['day'],1,day) or not row['kind'] in ['lure_horde','settling_filter','backup_power','supply_pact','caravan_trade']:return '局势行动记录无效'
 return ''
