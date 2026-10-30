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
var window:Panel
var page_title:Label
var page_buttons:Dictionary={}
var worker:OptionButton
func _ready() -> void:
 layer=16;root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.72);root.add_child(shade)
 var ui:CampaignInterface=game.interface
 window=ui.panel(root,Vector2(70,60),Vector2(1300,780));GameUi.paper(window,Rect2(0,0,1300,780))
 ui.label(window,'营地',Vector2(25,20),Vector2(185,42),28)
 page_title=ui.label(window,'',Vector2(240,22),Vector2(800,40),26)
 ui.button(window,'关闭 F5 / Esc',Vector2(1090,22),Vector2(185,38),close)
 GameUi.line(window,Vector2(220,88),Vector2(220,748))
 for index in range(5):
  var pair:Array=[['situation','概况'],['food','物资'],['production','生产'],['health','健康'],['relations','关系']][index]
  var b:=ui.button(window,pair[1],Vector2(20,102+index*55),Vector2(184,44),func():page=pair[0];refresh());page_buttons[pair[0]]=b
 ui.label(window,'执行角色',Vector2(25,544),Vector2(185,28),17,GameUi.SECONDARY)
 worker=OptionButton.new();worker.position=Vector2(24,584);worker.size=Vector2(182,40);window.add_child(worker)
 worker.item_selected.connect(func(row: int):game.select_survivor(worker.get_item_id(row));refresh())
 var portrait:=Control.new();portrait.position=Vector2(66,648);portrait.size=Vector2(90,90);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;window.add_child(portrait)
 portrait.draw.connect(func():ActorVisual.portrait(portrait,game.survivors[game.selected_id].person.persona,Rect2(0,0,90,90)))
 var scroll:=ScrollContainer.new();scroll.position=Vector2(240,90);scroll.size=Vector2(1030,650);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;window.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override('separation',14);scroll.add_child(body);root.hide()
func text(value: String,size: int=19) -> Label:
 var node:=Label.new();node.text=value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.custom_minimum_size.x=1000;node.add_theme_font_size_override('font_size',size);node.add_theme_color_override('font_color',GameUi.TEXT if size>=21 else GameUi.SECONDARY);node.add_theme_font_override('font',GameUi.heading_font() if size>=23 else GameUi.FONT);body.add_child(node);return node
func button(id: String,value: String,callback: Callable,disabled: bool=false) -> Button:
 var group:HBoxContainer
 if body.get_child_count()>0 and body.get_child(-1) is HBoxContainer and body.get_child(-1).has_meta('actions') and body.get_child(-1).get_child_count()<2:group=body.get_child(-1)
 else:
  group=HBoxContainer.new();group.set_meta('actions',true);group.add_theme_constant_override('separation',14);body.add_child(group)
 var node:=Button.new();node.text=value;node.custom_minimum_size=Vector2(340,40);node.disabled=disabled;node.focus_mode=Control.FOCUS_NONE;GameUi.button(node);group.add_child(node);node.pressed.connect(callback);actions[id]=node;return node
func check(value: String,current: bool,callback: Callable,disabled: bool=false) -> void:
 var node:=CheckBox.new();node.focus_mode=Control.FOCUS_NONE;node.text=value;node.button_pressed=current;node.disabled=disabled;body.add_child(node);node.toggled.connect(callback)
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
 for key in page_buttons:GameUi.tab(page_buttons[key],page==key)
 page_title.text={'situation':'营地概况','food':'物资储备','production':'生产','health':'健康','relations':'同伴关系'}[page]
 worker.disabled=game.cycle.phase!="day"
 worker.clear()
 for index in range(game.survivors.size()):
  if game.survivors[index].health<=0:continue
  worker.add_item(game.survivors[index].display_name,index)
  if index==game.selected_id:worker.select(worker.item_count-1)
 window.queue_redraw()
 for child in window.get_children():
  if child is Control:child.queue_redraw()
 for child in body.get_children():body.remove_child(child);child.queue_free()
 game.camp.food.sync_people(game);game.camp.relations.sync(game)
 var food:CampFood=game.camp.food;var society:CampRelations=game.camp.relations;var world:CampSituation=game.camp.situation
 var day:int=game.expansion.day(game);var selected:Survivor=game.survivors[game.selected_id]
 var daytime:bool=game.cycle.phase=='day' and selected.health>0
 text('第%d天'%day,17)
 if page=='situation':
  var f:=world.forecast(day)
  if not f['visible']:text('暂无区域警报')
  else:
   text(str(CampSituation.INFO[f['kind']]['name'])+(' · 正在发生' if f['active'] else ' · 提前预告'),24)
   text('第%d—%d天。%s'%[f['starts'],f['ends'],CampSituation.INFO[f['kind']]['hint']])
   if world.diverted(day):text('已布置远处诱饵：基地压力减轻，机修厂增加迁移感染者。')
   if world.recon_day==ExpeditionState.day_at(game.simulation_time):text('已完成警戒侦察')
  text('应对措施',23)
  for kind in ['lure_horde','settling_filter','backup_power','supply_pact','caravan_trade']:recipe_button(kind)
  check('停电时启用备用设备 · 每夜燃料1',world.backup_on,func(value):world.backup_on=value,not world.resilience['generator'])
  text('尸群迁移期间，两名守夜者可减轻防守压力。',18)
 elif page=='food':
  text('仓库：杂粮%d、熟食%d、清水%d。'%[game.inventory.amount('raw_food'),game.inventory.amount('meals'),game.inventory.amount('water')])
  text('食材与用品',23)
  var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override('h_separation',16);grid.add_theme_constant_override('v_separation',12);body.add_child(grid)
  for kind in CampFoodCatalog.ITEMS:
   var tile:=Button.new();tile.custom_minimum_size=Vector2(320,78);tile.mouse_default_cursor_shape=Control.CURSOR_ARROW;tile.focus_mode=Control.FOCUS_NONE;grid.add_child(tile)
   var length:int=food.life(kind,game);var remaining:=length
   for lot in food.lots:
    if lot['kind']==kind and length>0:remaining=mini(remaining,maxi(0,length-day+int(lot['born'])))
   tile.text='     %s × %d\n     %s'%[CampFoodCatalog.ITEMS[kind]['name'],food.amount(kind),'最早%d天后过期'%remaining if length>0 and food.amount(kind)>0 else '可长期储备' if length==0 else '尚无库存']
   tile.add_theme_font_size_override('font_size',18)
   tile.draw.connect(func():CampFoodCatalog.draw_icon(tile,kind,Vector2(30,37),25))
  text('鲜食过期后转为堆肥。未净化水需煮沸或过滤。',18)
  for kind in ['vegetable_side','eat_can','eat_preserved','drink','unsafe_drink']:recipe_button(kind)
  check('缺少熟食时食用罐头、肉干',food.policy['emergency_food'],func(value):food.policy['emergency_food']=value)
  check('营养不足时补充蔬菜；备餐优先营养餐',food.policy['balanced'],func(value):food.policy['balanced']=value)
  if game.expedition.active:text('外出时在 I 背包中点击罐头、肉干或饮料使用；需要站稳2—4秒，移动或受伤会中断并退回。',18)
 elif page=='production':
  text('种植箱 %d / 2 · 保鲜柜%s · 动物陷阱%s · 沉淀过滤器%s'%[food.infrastructure['plots'],'已建' if food.infrastructure['pantry'] else '未建','已建' if food.infrastructure['trap'] else '未建','已建' if food.infrastructure['filter'] else '未建'])
  for plot in food.plots:text('%s · 第%d天成熟 · %s'%[CampFoodCatalog.ITEMS[plot['kind']]['name'],plot['ready'],'已施肥' if plot['fed'] else '未施肥'])
  var categories:=HBoxContainer.new();body.add_child(categories)
  for entry in [['kitchen','烹饪与储备'],['garden','种植与采集'],['water','饮水处理'],['building','建造设施']]:
   var pick:=Button.new();pick.text=entry[1];pick.custom_minimum_size=Vector2(245,42);pick.focus_mode=Control.FOCUS_NONE;categories.add_child(pick);actions['category:'+entry[0]]=pick;pick.pressed.connect(func():production_group=entry[0];refresh())
  var groups:Dictionary={'kitchen':['balanced','broth','salad','dry_meat'],'garden':['check_trap','extract_seeds','plant_veg','plant_herbs','fertilize','harvest'],'water':['boil_water','filter_water'],'building':['planter','pantry','trap']}
  for kind in groups[production_group]:recipe_button(kind)
  check('自动收获成熟作物',food.policy['harvest'],func(value):food.policy['harvest']=value)
 elif page=='health':
  text('营养不足会增加患病风险。发热、肠胃病与咬伤感染分别治疗。',18)
  for actor:Survivor in game.survivors:
   if actor.health<=0:continue
   var c:Dictionary=food.conditions[actor.person.persona]
   var card:=Panel.new();card.custom_minimum_size=Vector2(1000,96);card.add_theme_stylebox_override('panel',GameUi.box(GameUi.SURFACE.darkened(.25),Color.TRANSPARENT,1));body.add_child(card)
   card.draw.connect(func():ActorVisual.portrait(card,actor.person.persona,Rect2(12,10,48,76)))
   game.interface.label(card,actor.display_name,Vector2(76,20),Vector2(170,30),21)
   var values:Array=[['营养',c['nutrition']],['发热',c['fever']],['肠胃',c['gut']],['疾病',actor.illness],['咬伤感染',actor.infection]]
   for index in range(values.size()):
    game.interface.label(card,values[index][0],Vector2(270+index*142,12),Vector2(130,26),16,GameUi.SECONDARY)
    var value:=roundi(float(values[index][1]))
    var color:Color=GameUi.TEXT if index==0 or value<20 else GameUi.WARNING if value<50 else GameUi.DANGER
    game.interface.label(card,str(value),Vector2(270+index*142,48),Vector2(130,34),25,color)
   button('recover:'+str(actor.survivor_id),'卧床休养',func():if food.start_job(game,'recover',actor.survivor_id):close(),not daytime or not food.error(game,'recover',actor.survivor_id).is_empty())
   if actor!=selected:button('care:'+str(actor.survivor_id),'草药护理 '+actor.display_name,func():start_food('herbal_care',actor.survivor_id),not daytime or not food.error(game,'herbal_care',game.selected_id,actor.survivor_id).is_empty())
  check('授权空闲医护用草药和清水调养发热、肠胃病情',food.policy['herbal'],func(value):food.policy['herbal']=value)
 elif page=='relations':
  text('共同工作、照护、交谈和共餐可增进信任。同伴协作效率最高+10%。',18)
  for actor:Survivor in game.survivors:
   if actor.health<=0:continue
   var id:=actor.person.persona;var duty:Dictionary=society.duties[id];var p:Dictionary=society.policies[id]
   text('%s · 连续守夜%d晚 · 当前%s'%[actor.display_name,duty['streak'],actor.status_text()],21)
   for pair in [['social','主动陪伴'],['watch','主动警戒'],['maintain','主动维护（材料1 / 天）']]:check(pair[1],p[pair[0]],func(value):p[pair[0]]=value)
   if actor!=selected:
    text('与'+selected.display_name+'的信任：%d'%game.people.relationship(actor.survivor_id,selected.survivor_id),18)
    button('talk:'+id,'陪伴 '+actor.display_name,func():if society.start(game,'talk',actor.survivor_id):close(),not daytime)
    button('meal:'+id,'与'+actor.display_name+'共餐 · 熟食2',func():if society.start(game,'meal',actor.survivor_id):close(),not daytime or game.inventory.amount('meals')<2 or game.chronicle.meal_day>=ExpeditionState.day_at(game.simulation_time))
  if not society.dispute.is_empty():
   text('分工争议：'+game.survivors[int(society.dispute['left'])].display_name+'希望轮换守夜。',22)
   button('mediate','组织当面调解 · 相关成员都需空闲',func():if society.start(game,'mediate'):close(),not daytime)
   button('pledge','承诺下次轮换守夜 · 是否兑现会影响信任',func():society.pledge(game);refresh(),game.cycle.phase not in ['day','planning'])
  for memory in society.memories.slice(-5):text('第%d天 · %s：%s'%[memory['day'],PeopleCatalog.DATA[memory['owner']]['name'],{'talk':'陪伴交谈','meal':'共餐','mediate':'调解分工','watch':'观察尸群','maintain':'主动维护'}[memory['kind']]],18)
 if not food.jobs.is_empty():
  text('进行中',22)
  for job in food.jobs:text(game.survivors[int(job['actor'])].display_name+' · '+str(CampFoodCatalog.RECIPES[job['kind']]['name'])+' · %d%%'%roundi(100*float(job['elapsed'])/float(CampFoodCatalog.RECIPES[job['kind']]['seconds'])),18)
func recipe_button(kind: String) -> void:
 var r:Dictionary=CampFoodCatalog.RECIPES[kind];var cost:PackedStringArray=[]
 if not r['cost'].is_empty():cost.append(ShelterInventory.describe(r['cost']))
 if not r['food'].is_empty():cost.append(CampFoodCatalog.names(r['food']))
 var reason:String=game.camp.food.error(game,kind,game.selected_id)
 var card:=Panel.new();card.custom_minimum_size=Vector2(1000,84);card.add_theme_stylebox_override('panel',GameUi.box(GameUi.SURFACE.darkened(.25),Color.TRANSPARENT,1));body.add_child(card)
 var ui:CampaignInterface=game.interface
 ui.label(card,r['name'],Vector2(74,9),Vector2(730,29),20)
 ui.label(card,' / '.join(cost) if not cost.is_empty() else '无材料消耗',Vector2(74,42),Vector2(730,25),16,GameUi.SECONDARY)
 var action: String='建造' if r.has('build') else '制作' if r.has('output') or r.has('typed') else '执行'
 var b:=ui.button(card,action,Vector2(846,22),Vector2(136,40),func():start_food(kind));b.disabled=not reason.is_empty();b.tooltip_text=str(r['hint'])+('\n'+reason if not reason.is_empty() else '');actions[kind]=b
 card.tooltip_text=str(r['hint'])
 card.draw.connect(func():
  if r.has('build'):FacilityArt.prop(card,{'plots':7,'pantry':4,'trap':3,'filter':6}.get(r['build'],12),Rect2(10,12,52,60))
  else:
   var icon: String=r.get('crop','')
   if icon.is_empty() and not r['food'].is_empty():icon=r['food'].keys()[0]
   if icon.is_empty():HudIcons.draw(card,'meals' if r['station']=='stove' else 'tools',Vector2(36,41),26,GameUi.ACCENT)
   else:CampFoodCatalog.draw_icon(card,icon,Vector2(36,41),26)
 )
