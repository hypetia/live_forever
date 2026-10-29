class_name WorkshopView
extends RefCounted
## On-demand facility pages: recipes, tier benefits, storage and campaign devices.

static func render(ui: CampaignInterface) -> Panel:
	var game := ui.game
	ui.workshop_recipes.clear()
	ui.workshop_owner_choices.clear()
	ui.workshop_upgrade = null
	var window := ui.panel(ui.root,Vector2(25,20),Vector2(1390,860))
	ui.label(window,"设施与装备 · 已暂停",Vector2(25,17),Vector2(1080,40),27,game.GOLD)
	ui.button(window,"关闭 K / Esc",Vector2(1170,17),Vector2(190,40),ui.close_workshop)
	var living_row := 0
	for index in range(game.survivors.size()):
		var actor: Survivor = game.survivors[index]
		if actor.health <= 0: continue
		var choose := ui.button(window,("✓ " if game.selected_id == index else "")+actor.display_name,Vector2(25+living_row*150,72),Vector2(140,36),func(): game.select_survivor(index); ui._create_workshop())
		choose.disabled = actor.health <= 0
		living_row += 1
	var pages := [["workbench","工作台"],["kitchen","厨房"],["storage","装备仓库"],["campaign","战役设备"]]
	for index in range(pages.size()):
		var page: Array = pages[index]
		var tab := ui.button(window,("● " if ui.workshop_section == page[0] else "")+page[1],Vector2(25+index*335,123),Vector2(320,38),func(): ui.workshop_section = page[0]; ui._create_workshop())
		tab.modulate = Color("eed2a0") if ui.workshop_section == page[0] else Color.WHITE
	var station := "stove" if ui.workshop_section == "kitchen" else "workbench"
	if ui.workshop_section in ["workbench","kitchen"]:
		ui.workshop_summary = ui.label(window,game.facilities.title(station),Vector2(25,179),Vector2(900,32),23,game.GOLD)
		var benefit: String
		if station == "stove":
			benefit = "烹饪速度 +%d%% · 厨师额外增产\nLv.2：合炊 / 炖煮；Lv.3：大锅烩饭。" % roundi((game.facilities.rate(station)-1)*100)
		else:
			benefit = "制作速度 +%d%% · 修缮避难所只恢复房屋结构\nLv.2：铁矛 / 防咬背心 / 冬衣；Lv.3：手枪 / 弹药。" % roundi((game.facilities.rate(station)-1)*100)
		ui.label(window,benefit,Vector2(25,217),Vector2(960,56),16)
		var upgrade: String = game.facilities.next_upgrade(station)
		if not upgrade.is_empty():
			var recipe: Dictionary = FacilitySystem.RECIPES[upgrade]
			ui.workshop_upgrade = ui.button(window,"升级至 Lv.%d · %d秒" % [recipe["to"],recipe["seconds"]],Vector2(1030,178),Vector2(305,42),func(): _start(ui,upgrade))
			var error: String = game.facilities.job_error(game,upgrade)
			ui.workshop_upgrade.disabled = game.cycle.phase != "day" or not error.is_empty() or not game.inventory.can_take(recipe["cost"])
			ui.workshop_upgrade.tooltip_text = recipe["hint"]+"\n人物走到设施施工，完成才升级；取消或日落退料。\n"+error
			ui.label(window,ShelterInventory.describe(recipe["cost"]),Vector2(1030,225),Vector2(305,45),15,game.GOLD)
			for job in game.expansion.jobs:
				if job["kind"] == upgrade:
					ui.workshop_upgrade.text = "升级施工中 · %d%%" % roundi(100*float(job["elapsed"])/float(job["duration"]))
		else: ui.label(window,"已达到最高等级",Vector2(1030,188),Vector2(305,35),19,game.GOLD)
	elif ui.workshop_section == "storage":
		ui.label(window,"装备仓库 · 弹药%d发" % game.expansion.ammo,Vector2(25,183),Vector2(1200,35),23,game.GOLD)
		ui.label(window,"每件装备单独编号，在下拉框中指定保管人。维修材料2，恢复60耐久，低级工作台也可修理旧装备。",Vector2(25,227),Vector2(1280,32),16)
	else:
		ui.label(window,"第%d/35天 · %s" % [game.expansion.day(game),SurvivalExpansion.STAGES[game.expansion.stage]],Vector2(25,179),Vector2(1200,33),23,game.GOLD)
		ui.label(window,game.expansion.objective(game),Vector2(25,221),Vector2(1300,50),17)
	var scroll := ScrollContainer.new()
	ui.workshop_scroll = scroll
	scroll.position = Vector2(25,286)
	scroll.size = Vector2(1335,542)
	window.add_child(scroll)
	var body := Control.new()
	body.custom_minimum_size = Vector2(1300,1)
	scroll.add_child(body)
	var kinds: Array = []
	match ui.workshop_section:
		"workbench": kinds = ["craft","repair_shelter"]+GearCatalog.ITEMS.keys()
		"kitchen": kinds = ["cook","cook_batch","cook_stew","cook_pot"]
		"campaign": kinds = GearCatalog.PROJECTS.keys().filter(func(kind): return kind != "ammo")
		"storage":
			for index in range(game.expansion.gear.size()): _storage_card(ui,body,game.expansion.gear[index],index)
			if game.expansion.gear.is_empty(): ui.label(body,"暂无装备。到工作台制作，再在这里分配。",Vector2(15,20),Vector2(1200,40),18)
	if ui.workshop_section == "workbench": kinds.append("ammo")
	for index in range(kinds.size()): _recipe_card(ui,body,kinds[index],index)
	if ui.workshop_section == "campaign":
		var y := ceilf(kinds.size()/2.0)*180+12
		ui.button(body,"点燃炉火 · 燃料1",Vector2(0,y),Vector2(395,42),func(): game.expansion.ignite(game); ui._create_workshop())
		ui.button(body,"夜间取暖 "+("开" if game.expansion.use_night_heat else "关"),Vector2(420,y),Vector2(395,42),func(): game.expansion.use_night_heat = not game.expansion.use_night_heat; ui._create_workshop())
		ui.button(body,"净水泵 "+("开" if game.expansion.pump_on else "关"),Vector2(840,y),Vector2(395,42),func(): game.expansion.pump_on = not game.expansion.pump_on; ui._create_workshop())
		ui.label(body,"夜间取暖出发前扣燃料，每份烧8小时；净水泵每日燃料1换水3。",Vector2(0,y+57),Vector2(1250,40),15)
		body.custom_minimum_size.y = y+110
	else:
		var count: int = game.expansion.gear.size() if ui.workshop_section == "storage" else kinds.size()
		body.custom_minimum_size.y = maxf(180,ceilf(count/2.0)*180+10)
	return window


static func _recipe_card(ui: CampaignInterface, body: Control, kind: String, index: int) -> void:
	var game := ui.game
	var basic := kind in ["cook","craft","repair_shelter"]
	var task := "repair" if kind == "repair_shelter" else kind
	var recipe: Dictionary = TaskCatalog.TASKS[task] if basic else GearCatalog.recipe(kind)
	var actor: Survivor = game.survivors[game.selected_id]
	var name: String = recipe["label"] if basic else recipe["name"]
	var station := "stove" if kind == "cook" else FacilitySystem.station_for(kind)
	var minimum := int(FacilitySystem.RECIPES.get(kind,{}).get("minimum",FacilitySystem.REQUIREMENTS.get(kind,1)))
	var locked: bool = int(game.facilities.levels[station]) < minimum
	var card := ui.panel(body,Vector2((index%2)*650,(index/2)*180),Vector2(630,166),GameUi.SURFACE)
	card.draw.connect(func():
		if GearCatalog.ITEMS.has(kind):
			EquipmentArt.icon(card,{"kind":kind,"slot":GearCatalog.ITEMS[kind]["slot"],"broken":false},Vector2(33,33))
		else: HudIcons.draw(card,"meals" if station == "stove" else "tools",Vector2(33,33),25,game.GOLD)
	)
	ui.label(card,name,Vector2(65,15),Vector2(400,30),20,game.GOLD)
	ui.label(card,"Lv.%d" % minimum+(" · 未解锁" if locked else ""),Vector2(450,17),Vector2(165,28),14,game.GOLD)
	var output: Dictionary = CharacterAbilities.cooking_output(actor) if kind == "cook" else FacilitySystem.cooking_output(kind,actor) if kind in ["cook_batch","cook_stew","cook_pot"] else recipe.get("output",{})
	var line: String = ("每批：" if kind == "cook" else "")+ShelterInventory.describe(recipe["cost"])
	if not output.is_empty(): line += " → "+ShelterInventory.describe(output)
	ui.label(card,line,Vector2(16,56),Vector2(600,28),15)
	var hint: String = "结构+18，上限100；不是工作台升级。" if kind == "repair_shelter" else "人物走到设施开工，取消退料。" if basic else GearCatalog.describe(kind) if GearCatalog.ITEMS.has(kind) else FacilitySystem.RECIPES[kind]["hint"] if FacilitySystem.RECIPES.has(kind) else "用于手枪，射击会引来尸群。" if kind == "ammo" else "使用已带回的战役零件。"
	ui.label(card,hint,Vector2(16,87),Vector2(600,26),14)
	var duration: float = TaskCatalog.duration_for(task,actor) if basic else float(recipe["seconds"])
	var action := ui.button(card,("修缮" if kind == "repair_shelter" else "烹饪" if station == "stove" else "制作")+" · 约%.1f秒" % (duration/game.facilities.rate(station)),Vector2(425,120),Vector2(190,34),func(): _basic(ui,task) if basic else _start(ui,kind))
	ui.workshop_recipes[kind] = action
	var error: String = game.facilities.job_error(game,kind)
	if kind == "repair_shelter" and game.upkeep.integrity >= 100: error = "房屋结构已完整。"
	if kind in ["radio","pump","beacon"]:
		if game.expansion.stage != {"radio":0,"pump":2,"beacon":3}[kind] or not game.expansion.parts.has(recipe["part"]) or (kind == "beacon" and not game.expansion.parts.has("power_cell")): error = "需要对应阶段和已入库的战役零件。"
	action.disabled = game.cycle.phase != "day" or locked or not error.is_empty() or not game.inventory.can_take(recipe["cost"]) or actor.health <= 0
	action.tooltip_text = error if not error.is_empty() else "缺料："+game.inventory.missing_text(recipe["cost"]) if not game.inventory.can_take(recipe["cost"]) else "耗时随人物专长、状态和设施效率变化。"
	if kind == "cook":
		ui.label(card,"批数",Vector2(16,123),Vector2(52,27),14)
		ui.kitchen_batches = SpinBox.new()
		ui.kitchen_batches.position = Vector2(70,120)
		ui.kitchen_batches.size = Vector2(90,34)
		ui.kitchen_batches.min_value = 1
		ui.kitchen_batches.max_value = 3
		ui.kitchen_batches.value = 1
		card.add_child(ui.kitchen_batches)
	# A locked recipe keeps readable text; the state and button explain the gate.


static func _basic(ui: CampaignInterface, task: String) -> void:
	var count := int(ui.kitchen_batches.value) if task == "cook" else 1
	ui.game.select_task(task)
	ui.game.batch_count.value = count
	ui.game.assign_selected()
	ui.game.context_open = false
	ui.close_workshop()
	ui.game._refresh_hud()


static func _start(ui: CampaignInterface, kind: String) -> void:
	if ui.game.expansion.start_job(ui.game,kind): ui.close_workshop()
	else: ui._create_workshop()


static func _storage_card(ui: CampaignInterface, body: Control, item: Dictionary, index: int) -> void:
	var game := ui.game
	var kind: String = item["kind"]
	var card := ui.panel(body,Vector2((index%2)*650,(index/2)*180),Vector2(630,166),GameUi.SURFACE)
	card.draw.connect(func(): EquipmentArt.icon(card,{"kind":kind,"slot":GearCatalog.ITEMS[kind]["slot"],"broken":item["durability"] <= 0},Vector2(35,32)))
	ui.label(card,GearCatalog.ITEMS[kind]["name"]+" · #%02d" % int(item["id"]),Vector2(65,15),Vector2(530,30),20,game.GOLD)
	ui.label(card,"耐久%d/%d · %s" % [item["durability"],GearCatalog.ITEMS[kind]["durability"],"仓库" if item["owner"] == "" else PeopleCatalog.DATA[item["owner"]]["name"]],Vector2(16,57),Vector2(590,30),17)
	ui.label(card,GearCatalog.describe(kind),Vector2(16,92),Vector2(600,25),14)
	var owner_choice := OptionButton.new()
	owner_choice.position = Vector2(16,122); owner_choice.size = Vector2(270,32)
	owner_choice.add_item("仓库（未装备）",0)
	for actor_id in range(game.survivors.size()):
		var actor: Survivor = game.survivors[actor_id]
		if actor.health <= 0: continue
		owner_choice.add_item(actor.display_name,actor_id+1)
		if item["owner"] == actor.person.persona: owner_choice.select(owner_choice.item_count-1)
	owner_choice.item_selected.connect(func(row: int):
		game.expansion.assign_gear(game,int(item["id"]),owner_choice.get_item_id(row)-1)
		ui._create_workshop()
	)
	owner_choice.disabled = not game.cycle.phase in ["day","planning"]
	card.add_child(owner_choice)
	ui.workshop_owner_choices[int(item["id"])] = owner_choice
	var repair := ui.button(card,"维修 · 材料2",Vector2(316,122),Vector2(300,32),func():
		if game.expansion.start_job(game,"repair",int(item["id"])): ui.close_workshop()
		else: ui._create_workshop()
	)
	repair.disabled = game.cycle.phase != "day" or item["durability"] >= GearCatalog.ITEMS[kind]["durability"] or not game.inventory.can_take({"materials":2})
