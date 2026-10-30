class_name ChronicleView
extends CanvasLayer
var game: Node2D
var opened := false
var window: Panel
var root: Control
var body: VBoxContainer
var page := 'people'
var rendered_page := ''
var pause_before := false
var page_buttons: Dictionary = {}
var person_buttons: Dictionary = {}
var choice_buttons: Array[Button] = []
var selected_persona := ""

func _ready() -> void:
 layer=14
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.65);root.add_child(shade)
 var ui:CampaignInterface=game.interface
 window=ui.panel(root,Vector2(70,60),Vector2(1300,780));GameUi.paper(window,Rect2(0,0,1300,780))
 ui.label(window,'档案',Vector2(25,20),Vector2(180,42),28)
 ui.button(window,'关闭 Esc',Vector2(1110,22),Vector2(160,38),close)
 GameUi.line(window,Vector2(220,88),Vector2(220,748))
 var pages:Array=[['starts','新建战役 F2'],['people','人物 F3'],['infected','感染档案'],['cooperate','协作 F4']]
 for index in range(pages.size()):
  var pair:Array=pages[index]
  page_buttons[pair[0]]=ui.button(window,pair[1],Vector2(20,102+index*55),Vector2(184,44),func():page=pair[0];refresh())
 var scroll:=ScrollContainer.new();scroll.position=Vector2(240,90);scroll.size=Vector2(1030,650);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;window.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override('separation',14);scroll.add_child(body)
 root.hide()

func text(value: String,size: int=19) -> Label:
 var l:=Label.new();l.text=value;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x=1000;l.add_theme_font_override('font',Survivor.FONT);l.add_theme_font_size_override('font_size',size);l.add_theme_color_override('font_color',GameUi.TEXT);body.add_child(l);return l
func button(label: String,action: Callable,disabled: bool=false) -> Button:
 var b:=Button.new();b.text=label;b.custom_minimum_size=Vector2(1000,42);b.focus_mode=Control.FOCUS_NONE;b.disabled=disabled;body.add_child(b);b.pressed.connect(action);return b
func show_page(value: String) -> void:
 if not opened:pause_before=game.paused
 page=value;opened=true;game.paused=true;root.show();refresh()
func close() -> void:
 opened=false;root.hide();game.paused=pause_before or game.game_over
func close_loaded() -> void:
 opened=false
 if is_instance_valid(root):root.hide()
func refresh() -> void:
 for key in page_buttons:GameUi.tab(page_buttons[key],page==key or (page=="roster" and key=="people"))
 if page!=rendered_page:body.get_parent().scroll_vertical=0
 rendered_page=page
 for child in body.get_children():body.remove_child(child);child.queue_free()
 game.chronicle.sync(game)
 person_buttons.clear();choice_buttons.clear()
 if page=='starts':
  text('新建战役',27)
  text('选择开局后确认创建战役。现有战役将被替换。')
  for id in ChronicleCatalog.SCENARIOS:
   var c:Dictionary=ChronicleCatalog.SCENARIOS[id];var names:Array=[]
   for person in c['roster']:names.append(PeopleCatalog.DATA[person]['name'])
   text(c['name']+' · '+ ' / '.join(names),23);text(c['hint']+'\n初始库存：'+ShelterInventory.describe(c['stock']))
   button('开始「'+c['name']+'」',func():
    game.next_scenario=id;close();game._dialog_pause_before=game.paused;game.paused=true;game.new_dialog.dialog_text='以「'+c['name']+'」替换当前战役？\n队伍、物资、地图和剧情将重新开始。';game.new_dialog.popup_centered())
  var b:=CheckBox.new();b.text='夜袭亲自参战（关闭后使用原有战术结算）';b.button_pressed=game.chronicle.manual_defense;b.disabled=game.cycle.phase!='day';body.add_child(b);b.toggled.connect(func(value: bool):game.chronicle.manual_defense=value)
 elif page=='cooperate':
  text('协作安排',27)
  text('协作在空闲时进行，手动命令与紧急需求优先。')
  for actor: Survivor in game.survivors:
   var record: Dictionary = game.self_care.members[actor.person.persona]
   text(actor.display_name+' · '+actor.speciality,23)
   var disabled: bool = game.cycle.phase!='day' or actor.health<=0 or not game.self_care.enabled(actor)
   for pair in [['shared_cooking','主动为队伍备餐（含本人）· 消耗杂粮、水和燃料'],['medical','空闲时走近伤员护理 · 完成4秒治疗后消耗药品1']]:
    var toggle:=CheckBox.new();toggle.text=pair[1];toggle.button_pressed=record[pair[0]];toggle.disabled=disabled or (pair[0]=='medical' and actor.speciality!='医护');body.add_child(toggle)
    toggle.toggled.connect(func(value: bool):game.self_care.set_cooperation(game,actor,pair[0],value))
  text('伤员移动、医护受伤或日落会中断护理。备餐优先安排厨师，并预留饮水。')
 elif page=='roster':
  text('角色图鉴 · 12名候选／每局3人开局／最多5人在队',25)
  text('接纳条件：一级据点、杂粮2、水2、药品1。队伍上限5人。')
  button('返回人物志',func():page='people';refresh())
  var offers: Array = game.people.offers(game)
  var living: int = game.survivors.filter(func(a):return a.health>0).size()
  for id in PeopleCatalog.DATA:
   var info: Dictionary = PeopleCatalog.DATA[id]
   var resident: Survivor = game.chronicle._actor(game,id)
   var status: String = ('在队' if resident.health>0 else '已故') if resident!=null else ('可接纳' if offers.has(id) else '第%d天起到访' % maxi(3,int(info['day'])))
   if game.neighborhood.enabled and game.neighborhood.rescue['id']==id and game.neighborhood.rescue['state']=='lost':status='救援失败，无法加入'
   profile(id,status)
   if resident==null:
    button('接纳 '+info['name']+' · 杂粮2 / 水2 / 药品1',func():game.people.recruit(game,id);refresh();game._refresh_hud(),not offers.has(id) or living>=PeopleCatalog.MAX_LIVING or game.upkeep.level<1 or game.cycle.phase!='day' or game.game_over or not game.inventory.can_take(PeopleCatalog.RECRUIT_COST))
 elif page=='people':
  if not game.survivors.any(func(actor):return actor.person.persona==selected_persona):selected_persona=game.survivors[0].person.persona
  var crew:=HBoxContainer.new();crew.add_theme_constant_override('separation',5);body.add_child(crew)
  for member:Survivor in game.survivors:
   var choose:=GameUi.crew_button(game.interface,crew,member,Vector2.ZERO,Vector2(195,60),func():selected_persona=member.person.persona;refresh();body.get_parent().scroll_vertical=0,member.person.persona==selected_persona)
   choose.custom_minimum_size=Vector2(195,60);person_buttons[member.person.persona]=choose
  var links:=HBoxContainer.new();links.add_theme_constant_override('separation',12);body.add_child(links)
  game.interface.button(links,'角色图鉴',Vector2.ZERO,Vector2(170,38),func():page='roster';refresh()).custom_minimum_size=Vector2(170,38)
  game.interface.button(links,'协作设置 F4',Vector2.ZERO,Vector2(170,38),func():page='cooperate';refresh()).custom_minimum_size=Vector2(170,38)
  var actor:Survivor=game.chronicle._actor(game,selected_persona)
  var id:String=actor.person.persona
  profile(id,'已故' if actor.health<=0 else actor.speciality)
  var a:Dictionary=ChronicleCatalog.ARCS[id];var r:Dictionary=game.chronicle.arcs[id]
  text(a['title'],23)
  text(a['goal'],17)
  var disabled:bool=game.cycle.phase!='day' or actor.health<=0
  if r['stage']==0:
   var left:=button(a['a']+' · 材料2',func():game.chronicle.choice(game,id,0);refresh(),disabled or not game.inventory.can_take({'materials':2}))
   var right:=button(a['b']+' · 熟食1',func():game.chronicle.choice(game,id,1);refresh(),disabled or not game.inventory.can_take({'meals':1}))
   left.tooltip_text=ChronicleCatalog.PERK_TEXT[id][0];right.tooltip_text=ChronicleCatalog.PERK_TEXT[id][1];choice_buttons.assign([left,right])
  elif r['stage']==1:text('勘查中：'+a['goal'])
  elif r['stage']==2:button('实施计划 · '+ShelterInventory.describe(a['cost']),func():
   if game.chronicle.start_work(game,id):close(),disabled or not game.chronicle.work.is_empty() or not game.inventory.can_take(a['cost']))
  else:text('已完成：'+a['after_a' if r['choice']==0 else 'after_b']+'\n'+str(ChronicleCatalog.PERK_TEXT[id][r['choice']]))
  if id=='pooh' and actor.health>0:
   button('分享点心 · 熟食1 / 水1',func():
    game.select_survivor(actor.survivor_id)
    if game.expansion.start_job(game,'picnic'):close()
    else:refresh(),game.cycle.phase!='day' or game.game_over or game.chronicle.meal_day==ExpeditionState.day_at(game.simulation_time) or not game.inventory.can_take({'meals':1,'water':1}) or not game.residence.convoy.is_empty() or game.expansion.jobs.any(func(job):return ResidenceSystem.PROJECTS.has(job['kind'])))
  if game.chronicle.arcs.has('he') and game.chronicle.arcs['he']['stage']==3:button('公共餐桌 · 熟食2',func():game.chronicle.shared_meal(game);refresh(),game.cycle.phase!='day' or not game.inventory.can_take({'meals':2}) or game.chronicle.meal_day==ExpeditionState.day_at(game.simulation_time))
  if game.neighborhood.enabled and not game.neighborhood.memories.is_empty():
   text('共同经历',23)
   for memory in game.neighborhood.memories.slice(-6):
    var kind:String=memory['kind']
    var title:String=NeighborhoodSystem.ACTIONS[kind]['name'] if NeighborhoodSystem.ACTIONS.has(kind) else {'rescued':'救援成功','rescue_lost':'救援失败','network':'恢复医疗与供水'}[kind]
    text('第%d天 · %s：%s'%[memory['day'],PeopleCatalog.DATA[memory['actor']]['name'],title],18)

 else:
  text('感染者交战要点',27)
  for kind in EnemyCatalog.TYPES:text(EnemyCatalog.TYPES[kind]['name']+'：'+EnemyCatalog.TYPES[kind]['hint'])
  text('金色小环表示受击后稳身：仍会受伤，但不能连续打断。近战动作有短暂的移动减速；精神不足会延长再次出手的间隔。',18)
  text('感染档案',27)
  text('每张地图的第三处现场记录可以揭示当地感染者的过去。伏猎者会等待，听风者听觉敏锐，呼号者会引同类调查，守巢者会回到旧岗位；受重伤者会尝试向同伴退却。相同位置的诱饵会被逐渐识破。')
  for id in LocationCatalog.ALL_IDS:
   text(EnemyMind.NAMES[id]+' · '+LocationCatalog.area(id)['name'],23)
   text(EnemyMind.LORE[id] if game.chronicle.intel.has(id) else '尚未取得现场记录')

func profile(id: String,status: String) -> Panel:
 var info:Dictionary=PeopleCatalog.DATA[id]
 var card:=Panel.new();card.custom_minimum_size=Vector2(1000,186);card.add_theme_stylebox_override('panel',GameUi.box(GameUi.SURFACE.darkened(.25),Color.TRANSPARENT,1));body.add_child(card)
 card.tooltip_text=info['bio']+'\n'+ChronicleCatalog.ARCS[id]['text']+'\n性格：'+ChronicleCatalog.ARCS[id]['trait']
 card.draw.connect(func():ActorVisual.portrait(card,id,Rect2(14,10,106,166)))
 var ui:CampaignInterface=game.interface
 ui.label(card,info['name']+' · '+status,Vector2(144,10),Vector2(650,35),25)
 ui.label(card,'背包 %d 格'%CampaignCycle.BAGS[id],Vector2(826,16),Vector2(164,28),17,GameUi.SECONDARY)
 var reference:=ui.label(card,'角色原型：'+info['reference'],Vector2(144,54),Vector2(836,44),17,GameUi.SECONDARY);reference.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var ability:=ui.label(card,CharacterAbilities.description(id),Vector2(144,106),Vector2(836,68),18);ability.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return card
