class_name CampManagement
extends CanvasLayer
## One on-demand camp screen. No production or choice advances while the player reads.
var game:Node2D
var opened:=false
var pause_before:=false
var page:='situation'
var production_group:='kitchen'
var root:Control
var body:VBoxContainer
var actions:Dictionary={}
func _ready() -> void:
 layer=16;root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.7);root.add_child(shade)
 var window:=Panel.new();window.position=Vector2(170,80);window.size=Vector2(1100,730);window.theme=GameUi.theme();root.add_child(window)
 var row:=HBoxContainer.new();row.position=Vector2(20,15);row.size=Vector2(1060,44);window.add_child(row)
 for pair in [['situation','局势预告'],['food','粮仓与饮水'],['production','生产设施'],['health','营养与疾病'],['relations','同伴关系']]:
  var b:=Button.new();b.text=pair[1];b.custom_minimum_size=Vector2(170,42);b.focus_mode=Control.FOCUS_NONE;row.add_child(b);b.pressed.connect(func():page=pair[0];refresh())
 var close_button:=Button.new();close_button.text='返回 F5 / Esc';close_button.custom_minimum_size=Vector2(190,42);row.add_child(close_button);close_button.pressed.connect(close)
 var scroll:=ScrollContainer.new();scroll.position=Vector2(25,76);scroll.size=Vector2(1050,625);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;window.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override('separation',12);scroll.add_child(body);root.hide()
func text(value: String,size: int=19) -> Label:
 var node:=Label.new();node.text=value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.custom_minimum_size.x=1000;node.add_theme_font_size_override('font_size',size);body.add_child(node);return node
func button(id: String,value: String,callback: Callable,disabled: bool=false) -> Button:
 var node:=Button.new();node.text=value;node.custom_minimum_size=Vector2(1000,42);node.disabled=disabled;node.focus_mode=Control.FOCUS_NONE;body.add_child(node);node.pressed.connect(callback);actions[id]=node;return node
func check(value: String,current: bool,callback: Callable,disabled: bool=false) -> void:
 var node:=CheckBox.new();node.text=value;node.button_pressed=current;node.disabled=disabled;body.add_child(node);node.toggled.connect(callback)
func show_page(value: String) -> void:
 if not game.camp.enabled or game.game_over:return
 if not opened:
  if game.chronicle_view.opened:game.chronicle_view.close()
  if game.interface.workshop_open:game.interface.close_workshop()
  if game.briefing.opened:game.briefing.close()
  if game.residence_view.opened:game.residence_view.close()
  if game.center.visible:game.center.close()
  pause_before=game.paused
 page=value;opened=true;game.paused=true;root.show();refresh()
func close() -> void:
 if not opened:return
 opened=false;root.hide();game.paused=pause_before or game.game_over or game.cycle.phase in ['planning','dawn']
func dismiss_loaded() -> void:opened=false;if is_instance_valid(root):root.hide()
func start_food(kind: String,target: int=-1) -> void:
 if game.camp.food.start_job(game,kind,-1,target):close()
 else:refresh()
func refresh() -> void:
 actions.clear();body.get_parent().scroll_vertical=0
 for child in body.get_children():body.remove_child(child);child.queue_free()
 game.camp.food.sync_people(game);game.camp.relations.sync(game)
 var food:CampFood=game.camp.food;var society:CampRelations=game.camp.relations;var world:CampSituation=game.camp.situation
 var day:int=game.expansion.day(game);var selected:Survivor=game.survivors[game.selected_id]
 var daytime:bool=game.cycle.phase=='day' and selected.health>0
 text('营地 · 第%d天 · 当前安排：%s'%[day,selected.display_name],25)
 if page=='situation':
  var f:=world.forecast(day)
  if not f['visible']:text('当前没有临近的区域危机。第10天起可提前两天查看局势。')
  else:
   text(str(CampSituation.INFO[f['kind']]['name'])+(' · 正在发生' if f['active'] else ' · 提前预告'),24)
   text('第%d—%d天。%s'%[f['starts'],f['ends'],CampSituation.INFO[f['kind']]['hint']])
   if world.diverted(day):text('已布置远处诱饵：基地压力减轻，机修厂增加迁移感染者。')
   if world.recon_day==ExpeditionState.day_at(game.simulation_time):text('今天已经观察过尸群动向，基地防守压力略减。')
  text('预备方案',23)
  for kind in ['lure_horde','settling_filter','backup_power','supply_pact','caravan_trade']:recipe_button(kind)
  check('停电时启用备用设备 · 每夜燃料1',world.backup_on,func(value):world.backup_on=value,not world.resilience['generator'])
  text('迁移期安排两名守夜者也能减轻防守压力；需要从探索与休息中腾出人手。',18)
 elif page=='food':
  text('仓库：杂粮%d、熟食%d、清水%d。'%[game.inventory.amount('raw_food'),game.inventory.amount('meals'),game.inventory.amount('water')])
  text('独立食材与用品',23)
  var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override('h_separation',16);grid.add_theme_constant_override('v_separation',12);body.add_child(grid)
  for kind in CampFoodCatalog.ITEMS:
   var tile:=Button.new();tile.custom_minimum_size=Vector2(320,78);tile.mouse_default_cursor_shape=Control.CURSOR_ARROW;tile.focus_mode=Control.FOCUS_NONE;grid.add_child(tile)
   var length:int=food.life(kind,game);var remaining:=length
   for lot in food.lots:
    if lot['kind']==kind and length>0:remaining=mini(remaining,maxi(0,length-day+int(lot['born'])))
   tile.text='     %s × %d\n     %s'%[CampFoodCatalog.ITEMS[kind]['name'],food.amount(kind),'最早%d天后过期'%remaining if length>0 and food.amount(kind)>0 else '可长期储备' if length==0 else '尚无库存']
   tile.add_theme_font_size_override('font_size',18)
   tile.draw.connect(func():CampFoodCatalog.draw_icon(tile,kind,Vector2(30,37),25))
  text('肉和蔬菜需加工；过期鲜食转为堆肥。未净化水必须煮沸或过滤。独立食材在普通容器中搜刮、占背包格，安全回家后才入库。',18)
  for kind in ['vegetable_side','eat_can','eat_preserved','drink','unsafe_drink']:recipe_button(kind)
  check('无热饭可用时，允许基本自理角色食用罐头或肉干',food.policy['emergency_food'],func(value):food.policy['emergency_food']=value)
  check('营养不足时自行补充蔬菜；授权备餐者优先做营养餐、肉汤',food.policy['balanced'],func(value):food.policy['balanced']=value)
  if game.expedition.active:text('外出时在 I 背包中点击罐头、肉干或饮料使用；需要站稳2—4秒，移动或受伤会中断并退回。',18)
 elif page=='production':
  text('种植箱 %d / 2 · 保鲜柜%s · 动物陷阱%s · 沉淀过滤器%s'%[food.infrastructure['plots'],'已建' if food.infrastructure['pantry'] else '未建','已建' if food.infrastructure['trap'] else '未建','已建' if food.infrastructure['filter'] else '未建'])
  for plot in food.plots:text('%s · 第%d天成熟 · %s'%[CampFoodCatalog.ITEMS[plot['kind']]['name'],plot['ready'],'已施肥' if plot['fed'] else '未施肥'])
  var categories:=HBoxContainer.new();body.add_child(categories)
  for entry in [['kitchen','烹饪与储备'],['garden','种植与采集'],['water','饮水处理'],['building','建造设施']]:
   var pick:=Button.new();pick.text=entry[1];pick.custom_minimum_size=Vector2(245,42);pick.focus_mode=Control.FOCUS_NONE;categories.add_child(pick);actions['category:'+entry[0]]=pick;pick.pressed.connect(func():production_group=entry[0];refresh())
  var groups:Dictionary={'kitchen':['balanced','broth','salad','dry_meat'],'garden':['check_trap','extract_seeds','plant_veg','plant_herbs','fertilize','harvest'],'water':['boil_water','filter_water'],'building':['planter','pantry','trap']}
  for kind in groups[production_group]:recipe_button(kind)
  check('空闲时自行收获已成熟作物 · 不自行花料播种',food.policy['harvest'],func(value):food.policy['harvest']=value)
 elif page=='health':
  text('营养不足会增加患病风险；发热增加疲劳，肠胃病增加失水。咬伤感染与这两种疾病分别处理。',18)
  for actor:Survivor in game.survivors:
   if actor.health<=0:continue
   var c:Dictionary=food.conditions[actor.person.persona]
   text('%s · 营养%d / 发热%d / 肠胃%d · 疾病%d / 咬伤感染%d'%[actor.display_name,roundi(c['nutrition']),roundi(c['fever']),roundi(c['gut']),roundi(actor.illness),roundi(actor.infection)],21)
   button('recover:'+str(actor.survivor_id),'安排'+actor.display_name+'病床休养',func():if food.start_job(game,'recover',actor.survivor_id):close(),not daytime or not food.error(game,'recover',actor.survivor_id).is_empty())
   if actor!=selected:button('care:'+str(actor.survivor_id),'让'+selected.display_name+'用草药调养'+actor.display_name,func():start_food('herbal_care',actor.survivor_id),not daytime or not food.error(game,'herbal_care',game.selected_id,actor.survivor_id).is_empty())
  check('授权空闲医护用草药和清水调养发热、肠胃病情',food.policy['herbal'],func(value):food.policy['herbal']=value)
 elif page=='relations':
  text('共同工作、真正完成照护、交谈和共餐会改变信任。附近可信赖同伴可带来最高10%的工作效率帮助。',18)
  for actor:Survivor in game.survivors:
   if actor.health<=0:continue
   var id:=actor.person.persona;var duty:Dictionary=society.duties[id];var p:Dictionary=society.policies[id]
   text('%s · 连续守夜%d晚 · 当前%s'%[actor.display_name,duty['streak'],actor.status_text()],21)
   for pair in [['social','允许空闲时主动陪伴压力大的同伴'],['watch','允许在局势预警期主动望风'],['maintain','允许主动维护 · 每次材料1、每天最多一次']]:check(pair[1],p[pair[0]],func(value):p[pair[0]]=value)
   if actor!=selected:
    text('与'+selected.display_name+'的信任：%d'%game.people.relationship(actor.survivor_id,selected.survivor_id),18)
    button('talk:'+id,'让'+selected.display_name+'陪伴'+actor.display_name,func():if society.start(game,'talk',actor.survivor_id):close(),not daytime)
    button('meal:'+id,'与'+actor.display_name+'到餐桌共餐 · 熟食2',func():if society.start(game,'meal',actor.survivor_id):close(),not daytime or game.inventory.amount('meals')<2 or game.chronicle.meal_day>=ExpeditionState.day_at(game.simulation_time))
  if not society.dispute.is_empty():
   text('分工争议：'+game.survivors[int(society.dispute['left'])].display_name+'希望轮换守夜。',22)
   button('mediate','组织当面调解 · 相关成员都需空闲',func():if society.start(game,'mediate'):close(),not daytime)
   button('pledge','承诺下次轮换守夜 · 是否兑现会影响信任',func():society.pledge(game);refresh(),game.cycle.phase not in ['day','planning'])
  for memory in society.memories.slice(-5):text('第%d天 · %s：%s'%[memory['day'],PeopleCatalog.DATA[memory['owner']]['name'],{'talk':'陪伴交谈','meal':'共餐','mediate':'调解分工','watch':'观察尸群','maintain':'主动维护'}[memory['kind']]],18)
 if not food.jobs.is_empty():
  text('进行中的营地工作',22)
  for job in food.jobs:text(game.survivors[int(job['actor'])].display_name+' · '+str(CampFoodCatalog.RECIPES[job['kind']]['name'])+' · %d%%'%roundi(100*float(job['elapsed'])/float(CampFoodCatalog.RECIPES[job['kind']]['seconds'])),18)
func recipe_button(kind: String) -> void:
 var r:Dictionary=CampFoodCatalog.RECIPES[kind];var cost:PackedStringArray=[]
 if not r['cost'].is_empty():cost.append(ShelterInventory.describe(r['cost']))
 if not r['food'].is_empty():cost.append(CampFoodCatalog.names(r['food']))
 var reason:String=game.camp.food.error(game,kind,game.selected_id)
 var b:=button(kind,str(r['name'])+(' · '+' / '.join(cost) if not cost.is_empty() else ''),func():start_food(kind),not reason.is_empty())
 b.tooltip_text=reason if not reason.is_empty() else r['hint']
 text(str(r['hint']),17)
