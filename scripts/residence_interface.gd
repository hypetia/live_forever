class_name ResidenceInterface
extends CanvasLayer
## An explicit drawer keeps the playable scene quiet.
var game: Node2D
var opened := false
var paused_before := false
var window: Panel

func _ready() -> void:
	layer = 10

func toggle() -> void:
	if opened: close(); return
	if not game.cycle.phase in ["day", "planning"] or game.game_over: return
	if game.interface.workshop_open: game.interface.close_workshop()
	if game.center.visible: game.center.close()
	paused_before = game.paused
	game.paused = true
	opened = true
	render()

func close() -> void:
	if not opened: return
	opened = false
	if is_instance_valid(window): window.hide(); window.queue_free()
	if game.cycle.phase == "day": game.paused = paused_before
	game.interface.refresh(true)

func render() -> void:
	if is_instance_valid(window): window.hide(); window.queue_free()
	var ui: CampaignInterface = game.interface
	window = ui.panel(self, Vector2(25, 20), Vector2(1390, 860))
	ui.label(window, game.residence.title() + " · 家园与迁居", Vector2(25,17), Vector2(1120,42), 27,game.GOLD)
	ui.button(window,"关闭 H / Esc",Vector2(1175,17),Vector2(185,42),close)
	ui.label(window,"安防耐久%d / 100 · 暴露噪声%d · 室内基础保温+%d℃" % [roundi(game.residence.condition),roundi(game.residence.noise),game.residence.indoor_bonus()],Vector2(25,77),Vector2(1000,30),18)
	ui.button(window,"检查安防 Z",Vector2(1080,76),Vector2(280,38),func(): game.security_view.toggle())
	ui.label(window,"守夜配合门窗、预警和阻挡设施。加固会损耗；制造与音乐留下噪声，可能吸引尸群。",Vector2(25,118),Vector2(1300,30),15)
	for index in range(game.survivors.size()):
		var actor: Survivor = game.survivors[index]
		var choose := ui.button(window,("✓ " if game.selected_id == index else "") + actor.display_name,Vector2(25+index*155,166),Vector2(145,36),func(): game.select_survivor(index); render())
		choose.disabled = actor.health <= 0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(25,225)
	scroll.size = Vector2(1335,600)
	window.add_child(scroll)
	var body := Control.new()
	body.custom_minimum_size = Vector2(1300,1)
	scroll.add_child(body)
	var y := 0.0
	ui.label(body,"安防与休闲 · 到工作台准备，完成才生效",Vector2(0,y),Vector2(1200,30),21,game.GOLD)
	y += 45
	for kind in ["gate","mesh","alarm","stakes","maintain","guitar","music"]:
		y = project_row(body,kind,y)
	y += 22
	ui.label(body,"迁居 · 实地勘察、清理、打包、整夜转移",Vector2(0,y),Vector2(1280,32),21,game.GOLD)
	y += 42
	var warning := ui.label(body,"库存、装备、吉他与战役设备可带走；床、炉、收集器、隔断和安防拆解，仅回收部分材料。新址等级归零。\n运输补给为全队打包（熟食5、水10、燃料2、工具1），行军会受冷、消耗精神，也可能遇袭；迁居后至少休整5天。",Vector2(0,y),Vector2(1280,62),15)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 82
	if not game.residence.convoy.is_empty():
		ui.label(body,"已备好车队 → " + ResidenceSystem.HOMES[game.residence.convoy]["name"] + "；结束白天后全员出发。",Vector2(0,y),Vector2(960,35),18,game.GOLD)
		ui.button(body,"取消并退运输补给",Vector2(1030,y),Vector2(250,38),func(): game.residence.cancel_convoy(game); render())
		y += 55
	for id in ResidenceSystem.HOMES:
		var data: Dictionary = ResidenceSystem.HOMES[id]
		var state := "现居地" if id == game.residence.current else "已清理" if game.residence.cleared.has(id) else "清理工具已备好" if game.residence.prepared.has(id) else "已勘察" if game.residence.surveyed.has(id) else "待实地勘察"
		ui.label(body,data["name"] + " · " + state,Vector2(0,y),Vector2(1280,35),21,game.GOLD)
		y += 39
		ui.label(body,data["hint"] + " 基础保温+%d℃，袭击概率修正%+d%%。" % [data["warmth"],data["risk"]],Vector2(0,y),Vector2(1280,29),15)
		y += 34
		if id != "shelter":
			var field: ExpeditionState = game.regions[data["map"]]
			ui.label(body,"勘察位置：" + field.area()["name"] + " / " + field.site_definitions()[int(data["site"])]["name"] + "；搜索容器后点击勘察，活着返回。",Vector2(0,y),Vector2(1280,29),14)
			y += 36
			y = project_row(body,"clear_"+id,y)
		y = project_row(body,"pack_"+id,y)
		y += 18
	body.custom_minimum_size.y = y + 20

func project_row(parent: Control, kind: String, y: float) -> float:
	var ui: CampaignInterface = game.interface
	var recipe: Dictionary = ResidenceSystem.PROJECTS[kind]
	var extra := " · %d级" % game.residence.security[kind] if game.residence.security.has(kind) else ""
	ui.label(parent,recipe["name"] + extra + " · " + ShelterInventory.describe(recipe["cost"]),Vector2(0,y),Vector2(1030,30),17)
	ui.label(parent,recipe["hint"],Vector2(0,y+30),Vector2(1030,29),14)
	var error: String = game.residence.job_error(game,kind)
	var action := ui.button(parent,"安排 · %d秒" % recipe["seconds"],Vector2(1080,y+4),Vector2(200,40),func():
		if game.expansion.start_job(game,kind): close()
		else: render()
	)
	action.tooltip_text = error if not error.is_empty() else recipe["hint"]
	action.disabled = not error.is_empty() or not game.inventory.can_take(recipe["cost"])
	return y + 76
