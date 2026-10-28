class_name CampFoodCatalog
extends RefCounted
## Independent physical food stacks; grain, cooked meals and clean water retain their existing stock.
const ITEMS := {
 'meat':{'name':'鲜肉','stack':3,'life':2,'color':'b77b70'},
 'vegetables':{'name':'蔬菜','stack':4,'life':4,'color':'8eab72'},
 'cans':{'name':'罐头','stack':3,'life':0,'color':'b4a47d'},
 'drinks':{'name':'饮料','stack':4,'life':0,'color':'8cb0b5'},
 'herbs':{'name':'草药','stack':4,'life':6,'color':'91a887'},
 'seeds':{'name':'种子','stack':6,'life':0,'color':'bfad78'},
 'compost':{'name':'堆肥','stack':8,'life':0,'color':'8d785d'},
 'dirty_water':{'name':'未净化水','stack':4,'life':0,'color':'8b9679'},
 'preserved':{'name':'肉干','stack':4,'life':14,'color':'a37a5c'},
}
const RECIPES := {
 'balanced':{'name':'肉菜杂粮饭','station':'stove','seconds':10.0,'cost':{'raw_food':1,'water':1,'fuel':1},'food':{'meat':1,'vegetables':1},'output':{'meals':3},'quality':'balanced','heat':true,'hint':'熟食3；每份营养+28，压力−3。厨师多做1份。'},
 'broth':{'name':'草药肉汤','station':'stove','seconds':9.0,'cost':{'water':2,'fuel':1},'food':{'meat':1,'herbs':1},'output':{'meals':2},'quality':'broth','heat':true,'hint':'熟食2；每份水分+12、营养+18、发热−6。不能治疗咬伤感染。'},
 'salad':{'name':'洗净蔬菜餐','station':'stove','seconds':6.0,'cost':{'water':1},'food':{'vegetables':2},'output':{'meals':2},'quality':'vegetable','heat':false,'hint':'不用燃料；熟食2，每份营养+20。需要清水洗净。'},
 'dry_meat':{'name':'制作肉干','station':'stove','seconds':10.0,'cost':{'fuel':1},'food':{'meat':2},'typed':{'preserved':2},'heat':true,'tier':2,'hint':'鲜肉2制成肉干2；可保存14天，适合储备。'},
 'boil_water':{'name':'煮沸饮水','station':'stove','seconds':8.0,'cost':{'fuel':1},'food':{'dirty_water':3},'output':{'water':3},'heat':true,'hint':'未净化水3、燃料1 → 清水3。不会把仓库现有清水变成污水。'},
 'filter_water':{'name':'过滤饮水','station':'water','seconds':8.0,'cost':{'materials':1},'food':{'dirty_water':4},'output':{'water':4},'requires':'filter','hint':'滤层材料1、未净化水4 → 清水4；需要沉淀过滤器。'},
 'planter':{'name':'建造种植箱','station':'workbench','seconds':18.0,'cost':{'materials':5,'tools':1},'food':{},'build':'plots','hint':'增加一块种植箱，最多2块；种植、成熟和收获分别进行。'},
 'pantry':{'name':'建造保鲜柜','station':'workbench','seconds':20.0,'cost':{'materials':6,'tools':1},'food':{},'build':'pantry','tier':2,'hint':'鲜肉保鲜延至4天、蔬菜7天、草药9天；不消耗日常燃料。'},
 'trap':{'name':'布置动物捕猎装置','station':'workbench','seconds':16.0,'cost':{'materials':4,'tools':1},'food':{},'build':'trap','hint':'每天可检查一次；用杂粮与维护材料捕猎小型动物，增加鲜肉来源。'},
 'check_trap':{'name':'检查动物陷阱','station':'exit','seconds':10.0,'cost':{'raw_food':1,'materials':1},'food':{},'requires':'trap','hint':'每天一次。消耗杂粮1、材料1，获得鲜肉2；补给荒时只有1份。'},
 'plant_veg':{'name':'种植蔬菜','station':'garden','seconds':10.0,'cost':{'water':2},'food':{'seeds':1},'crop':'vegetables','hint':'空种植箱、种子1、清水2；两天成熟，收获蔬菜3及种子1。'},
 'plant_herbs':{'name':'种植草药','station':'garden','seconds':10.0,'cost':{'water':2},'food':{'seeds':1},'crop':'herbs','hint':'两天成熟，收获草药2及种子1。'},
 'fertilize':{'name':'为作物施肥','station':'garden','seconds':5.0,'cost':{},'food':{'compost':1},'hint':'给尚未施肥的作物堆肥1，本次收获增加1份。'},
 'harvest':{'name':'收获作物','station':'garden','seconds':6.0,'cost':{},'food':{},'hint':'成熟后采收，种子回收1；按实际作物和施肥量产出。'},
 'extract_seeds':{'name':'筛选杂粮种子','station':'workbench','seconds':6.0,'cost':{'raw_food':1},'food':{},'typed':{'seeds':2},'hint':'杂粮1 → 种子2。'},
 'vegetable_side':{'name':'补充洗净蔬菜','station':'table','seconds':4.0,'cost':{'water':1},'food':{'vegetables':1},'consume':'vegetables','hint':'营养+18、饱腹+8。为已吃饱但饮食单一的成员补充蔬菜；自主补充每天最多一次，仍需清水清洗。'},
 'eat_can':{'name':'食用罐头','station':'table','seconds':4.0,'cost':{},'food':{'cans':1},'consume':'cans','hint':'饱腹+45、营养+8；水分−3。无需燃料。'},
 'eat_preserved':{'name':'食用肉干','station':'table','seconds':4.0,'cost':{},'food':{'preserved':1},'consume':'preserved','hint':'饱腹+35、营养+12；水分−5。'},
 'drink':{'name':'饮用饮料','station':'water','seconds':3.0,'cost':{},'food':{'drinks':1},'consume':'drinks','hint':'水分+55、精神+5；不会代替正餐。'},
 'unsafe_drink':{'name':'应急饮用未净化水','station':'water','seconds':3.0,'cost':{},'food':{'dirty_water':1},'consume':'dirty_water','hint':'水分+40，但肠胃病情+35。自理角色绝不会自动选择。'},
 'herbal_care':{'name':'草药调养同伴','station':'patient','seconds':6.0,'cost':{'water':1},'food':{'herbs':1},'hint':'医护走近伤员后调养；发热−25、肠胃病情−20，不治疗咬伤感染。'},
 'recover':{'name':'病床隔离休养','station':'bed','seconds':30.0,'cost':{},'food':{},'hint':'到达床位后逐步恢复精神、发热和肠胃；白天实际休养且夜间安排床位可减少同住传播，不代替食物和饮水。'},
 'lure_horde':{'name':'布置远处诱饵','station':'exit','seconds':12.0,'cost':{'fuel':2,'tools':1},'food':{},'world':'divert','hint':'迁移期把尸群引向机修厂：减轻基地压力，但机修厂会更危险。'},
 'settling_filter':{'name':'建造沉淀过滤器','station':'water','seconds':14.0,'cost':{'materials':4,'tools':1},'food':{},'world':'filter','hint':'永久解锁过滤饮水，并减轻水源警报期间的供水损失。'},
 'backup_power':{'name':'安装备用发电设备','station':'workbench','seconds':20.0,'cost':{'materials':5,'tools':1,'fuel':2},'food':{},'world':'generator','hint':'停电期间可选择每夜消耗燃料1维持净水和保鲜；需要主动开启。'},
 'supply_pact':{'name':'建立邻里补给协定','station':'exit','seconds':16.0,'cost':{'materials':6,'medicine':1},'food':{},'world':'pact','hint':'减轻补给荒；解锁每7天一次的物资交换。'},
 'caravan_trade':{'name':'交付邻里补给交换','station':'exit','seconds':12.0,'cost':{'materials':3,'fuel':1},'food':{},'world':'trade','hint':'每7天一次：材料3、燃料1换罐头2、种子1、草药1；米老鼠额外争取饮料1。'},
}
const CACHE_LAYOUT := {
 'street':{0:{'cans':2,'drinks':1},1:{'meat':2,'vegetables':2},3:{'herbs':1}},
 'clinic':{0:{'drinks':2},1:{'herbs':4,'cans':1}},
 'works':{0:{'cans':2,'seeds':1},2:{'dirty_water':3}},
 'residential':{0:{'vegetables':4},2:{'cans':2,'seeds':2}},
 'market':{0:{'meat':4,'vegetables':4},1:{'cans':3,'seeds':2}},
 'waterworks':{0:{'dirty_water':6},2:{'herbs':2}},
 'depot':{0:{'cans':4,'drinks':2},2:{'seeds':2}},
 'broadcast':{0:{'cans':2,'drinks':2},1:{'herbs':2}},
 'evac':{0:{'cans':3,'drinks':3}},
}
static func names(items: Dictionary) -> String:
 var parts:PackedStringArray=[]
 for id in items:parts.append('%s%d'%[ITEMS[id]['name'],items[id]])
 return '、'.join(parts)
static func draw_icon(c: CanvasItem,kind: String,at: Vector2,size: float=24) -> void:
 var color:=Color(ITEMS[kind]['color']);var scale:=size/24.0
 match kind:
  'meat':
   c.draw_circle(at,13*scale,color);c.draw_circle(at+Vector2(4,0)*scale,6*scale,Color('d4c5a9'));c.draw_line(at+Vector2(-8,-5)*scale,at+Vector2(-2,5)*scale,Color('d9aba0'),3*scale,true)
  'vegetables','herbs':
   for side in [-1,0,1]:c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,10)*scale,at+Vector2(side*13-5,-12)*scale,at+Vector2(side*13+6,-7)*scale]),color)
   c.draw_line(at+Vector2(0,14)*scale,at+Vector2(0,-9)*scale,Color('c0bd86'),2*scale,true)
  'cans':
   c.draw_rect(Rect2(at+Vector2(-11,-14)*scale,Vector2(22,27)*scale),color);c.draw_line(at+Vector2(-11,-11)*scale,at+Vector2(11,-11)*scale,Color('d1cbb5'),3*scale,true);c.draw_rect(Rect2(at+Vector2(-9,-4)*scale,Vector2(18,11)*scale),Color('7b8e7d'))
  'drinks','dirty_water':
   c.draw_rect(Rect2(at+Vector2(-4,-17)*scale,Vector2(8,7)*scale),color);c.draw_rect(Rect2(at+Vector2(-9,-10)*scale,Vector2(18,25)*scale),color);c.draw_line(at+Vector2(-7,0)*scale,at+Vector2(7,0)*scale,Color('d0d4b9'),3*scale,true)
  'preserved':
   for n in range(3):c.draw_line(at+Vector2(-10+n*9,-12)*scale,at+Vector2(-13+n*9,12)*scale,color,5*scale,true)
  'seeds':
   for n in range(6):c.draw_circle(at+Vector2((n%3-1)*9,(n/3)*11-6)*scale,3*scale,color)
  _:
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-15,10)*scale,at+Vector2(-5,-6)*scale,at+Vector2(4,-10)*scale,at+Vector2(15,10)*scale]),color)
