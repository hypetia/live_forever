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

func _ready() -> void:
 layer=14
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.65);root.add_child(shade)
 window=Panel.new();window.position=Vector2(170,100);window.size=Vector2(1100,690);window.theme=GameUi.theme();window.add_theme_stylebox_override('panel',GameUi.box(GameUi.PANEL));root.add_child(window)
 var row:=HBoxContainer.new();row.position=Vector2(24,15);row.size=Vector2(1050,44);window.add_child(row)
 for pair in [['starts','开局与分工 F2'],['people','人物志 F3'],['infected','感染档案'],['cooperate','同伴分工 F4']]:
  var b:=Button.new();b.text=pair[1];b.custom_minimum_size=Vector2(203,40);b.focus_mode=Control.FOCUS_NONE;row.add_child(b);b.pressed.connect(func():page=pair[0];refresh())
 var close_button:=Button.new();close_button.text='返回 Esc';close_button.custom_minimum_size=Vector2(185,40);row.add_child(close_button);close_button.pressed.connect(close)
 var scroll:=ScrollContainer.new();scroll.position=Vector2(25,73);scroll.size=Vector2(1050,590);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;window.add_child(scroll)
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
 if page!=rendered_page:body.get_parent().scroll_vertical=0
 rendered_page=page
 for child in body.get_children():body.remove_child(child);child.queue_free()
 game.chronicle.sync(game)
 if page=='starts':
  text('选择一段不同的求生开端',27)
  text('三个开局有独立队伍、物资、装备与气候。选择后仍需确认替换当前战役；取消不会改变存档。')
  for id in ChronicleCatalog.SCENARIOS:
   var c:Dictionary=ChronicleCatalog.SCENARIOS[id];var names:Array=[]
   for person in c['roster']:names.append(PeopleCatalog.DATA[person]['name'])
   text(c['name']+' · '+ ' / '.join(names),23);text(c['hint']+'\n初始库存：'+ShelterInventory.describe(c['stock']))
   button('开始「'+c['name']+'」',func():
    game.next_scenario=id;close();game._dialog_pause_before=game.paused;game.paused=true;game.new_dialog.dialog_text='以「'+c['name']+'」替换当前战役？\n队伍、物资、地图和剧情将重新开始。';game.new_dialog.popup_centered())
  var b:=CheckBox.new();b.text='夜袭亲自参战（关闭后使用原有战术结算）';b.button_pressed=game.chronicle.manual_defense;b.disabled=game.cycle.phase!='day';body.add_child(b);b.toggled.connect(func(value: bool):game.chronicle.manual_defense=value)
 elif page=='cooperate':
  text('让每个人知道自己能帮什么忙',27)
  text('先满足自己的急迫需要，再空闲协作。以下两项默认关闭，完成实际操作才产生收益；医护与伤员均有180秒医疗冷却。')
  for actor: Survivor in game.survivors:
   var record: Dictionary = game.self_care.members[actor.person.persona]
   text(actor.display_name+' · '+actor.speciality,23)
   var disabled: bool = game.cycle.phase!='day' or actor.health<=0 or not game.self_care.enabled(actor)
   for pair in [['shared_cooking','主动为队伍备餐（含本人）· 消耗生食、水和燃料'],['medical','空闲时走近伤员护理 · 完成4秒治疗后消耗药品1']]:
    var toggle:=CheckBox.new();toggle.text=pair[1];toggle.button_pressed=record[pair[0]];toggle.disabled=disabled or (pair[0]=='medical' and actor.speciality!='医护');body.add_child(toggle)
    toggle.toggled.connect(func(value: bool):game.self_care.set_cooperation(game,actor,pair[0],value))
  text('手动命令始终优先。伤员移动、医护受伤、缺药或日落会取消未完成护理；不会远程回血。多人授权备餐时优先厨师，按缺饭人数利用升级配方；已有饭菜在做就等待，并给口渴者留饮水。')
 elif page=='roster':
  text('角色图鉴 · 12名候选／每局3人开局／最多5人在队',25)
  text('这里可提前比较全部角色。加入需要一级据点及生食2、水2、药品1；到访不等于自动入队。已故成员不会复活。')
  button('返回人物志',func():page='people';refresh())
  var offers: Array = game.people.offers(game)
  var living: int = game.survivors.filter(func(a):return a.health>0).size()
  for id in PeopleCatalog.DATA:
   var info: Dictionary = PeopleCatalog.DATA[id]
   var resident: Survivor = game.chronicle._actor(game,id)
   var status: String = ('在队' if resident.health>0 else '已故') if resident!=null else ('可接纳' if offers.has(id) else '第%d天起到访' % maxi(3,int(info['day'])))
   if game.neighborhood.enabled and game.neighborhood.rescue['id']==id and game.neighborhood.rescue['state']=='lost':status='救援失败，无法加入'
   text(info['name']+' · '+info['role']+' · '+status,23)
   text(info['reference']+'\n'+info['bio']+'\n'+CharacterAbilities.description(id)+'\n背包%d格' % CampaignCycle.BAGS[id],18)
   if resident==null:
    button('接纳 '+info['name']+' · 生食2 / 水2 / 药品1',func():game.people.recruit(game,id);refresh();game._refresh_hud(),not offers.has(id) or living>=PeopleCatalog.MAX_LIVING or game.upkeep.level<1 or game.cycle.phase!='day' or game.game_over or not game.inventory.can_take(PeopleCatalog.RECRUIT_COST))
 elif page=='people':
  if game.neighborhood.enabled:
   text('共同经历：街区会记住你们',23)
   if game.neighborhood.memories.is_empty():text('在诊所与水厂采取行动后，这里记录持续的变化。')
   for memory in game.neighborhood.memories.slice(-6):
    var kind:String=memory['kind']
    var title:String=NeighborhoodSystem.ACTIONS[kind]['name'] if NeighborhoodSystem.ACTIONS.has(kind) else {'rescued':'成功背回同伴','rescue_lost':'未能完成救援','network':'恢复街区医疗与稳定供水'}[kind]
    text('第%d天 · %s：%s%s' % [memory['day'],PeopleCatalog.DATA[memory['actor']]['name'],title,(' · '+PeopleCatalog.DATA[memory['other']]['name']) if not memory['other'].is_empty() else ''],18)
   if game.neighborhood.rescue['state']=='safe' and not game.neighborhood.rescue['carrier'].is_empty():text('救援记忆：获救医护在伤情接近时优先照护救援者；急重伤仍优先。需要F4明确授权。',18)
  button('全部角色图鉴 · 12人及加入条件',func():page='roster';refresh())
  button('同伴分工与协作 F4',func():page='cooperate';refresh())
  var pooh: Survivor = game.chronicle._actor(game,'pooh')
  if pooh!=null and pooh.health>0:
   text('维尼的小点心：到餐桌分享给附近同伴',22)
   text(ResidenceSystem.PROJECTS['picnic']['hint'],18)
   button('让维尼分享点心 · 熟食1 / 水1',func():
    game.select_survivor(pooh.survivor_id)
    if game.expansion.start_job(game,'picnic'):close()
    else:refresh(),game.cycle.phase!='day' or game.game_over or game.chronicle.meal_day==ExpeditionState.day_at(game.simulation_time) or not game.inventory.can_take({'meals':1,'water':1}) or not game.residence.convoy.is_empty() or game.expansion.jobs.any(func(job):return ResidenceSystem.PROJECTS.has(job['kind'])))
  text('不是代号：每个人都带着一段未完的过去',26)
  text('选择一条信念，亲自勘查目标并生还，再让本人回到工作台完成专属计划。没有限时惩罚，也不会自动扣料。')
  for actor:Survivor in game.survivors:
   var id:=actor.person.persona;var a:Dictionary=ChronicleCatalog.ARCS[id];var r:Dictionary=game.chronicle.arcs[id]
   text(actor.display_name+' · '+a['title']+(' · 已故' if actor.health<=0 else ''),23)
   text('角色原型：'+PeopleCatalog.DATA[id]['reference'],18)
   text(a['text']+'\n性格：'+a['trait']+'\n'+CharacterAbilities.description(id))
   var disabled:bool=game.cycle.phase!='day' or actor.health<=0
   if r['stage']==0:
    button(a['a']+' · 材料2',func():game.chronicle.choice(game,id,0);refresh(),disabled or not game.inventory.can_take({'materials':2}))
    button(a['b']+' · 熟食1',func():game.chronicle.choice(game,id,1);refresh(),disabled or not game.inventory.can_take({'meals':1}))
   elif r['stage']==1:text('进行中：'+a['goal'])
   elif r['stage']==2:button(a['work']+' · '+ShelterInventory.describe(a['cost'])+' · 本人现场工作12秒',func():
    if game.chronicle.start_work(game,id):close(),disabled or not game.inventory.can_take(a['cost']) or not game.chronicle.work.is_empty())
   else:text('已完成：'+a['after_a' if r['choice']==0 else 'after_b']+'\n专属能力：'+str(ChronicleCatalog.PERK_TEXT[id][r['choice']]))
  if game.chronicle.arcs.has('he') and game.chronicle.arcs['he']['stage']==3:button('公共餐桌 · 熟食2，全员心境+6／压力−8，每日一次',func():game.chronicle.shared_meal(game);refresh(),game.cycle.phase!='day' or not game.inventory.can_take({'meals':2}) or game.chronicle.meal_day==ExpeditionState.day_at(game.simulation_time))
 else:
  text('感染者交战要点',27)
  for kind in EnemyCatalog.TYPES:text(EnemyCatalog.TYPES[kind]['name']+'：'+EnemyCatalog.TYPES[kind]['hint'])
  text('金色小环表示受击后稳身：仍会受伤，但不能连续打断。近战动作有短暂的移动减速；精神不足会延长再次出手的间隔。',18)
  text('那些仍在重复过去的感染者',27)
  text('每张地图的第三处现场记录可以揭示当地感染者的过去。伏猎者会等待，听风者听觉敏锐，呼号者会引同类调查，守巢者会回到旧岗位；受重伤者会尝试向同伴退却。相同位置的诱饵会被逐渐识破。')
  for id in LocationCatalog.ALL_IDS:
   text(EnemyMind.NAMES[id]+' · '+LocationCatalog.area(id)['name'],23)
   text(EnemyMind.LORE[id] if game.chronicle.intel.has(id) else '未取得现场记录。需要亲自搜索并观察，无法从菜单提前得知。')
