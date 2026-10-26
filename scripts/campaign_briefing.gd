class_name CampaignBriefing
extends CanvasLayer
## One optional briefing, not a permanent wall of text over the playable scene.
var game: Node2D
var opened := false
var paused_before := false
var window: Panel
var offer_buttons: Dictionary = {}
var claim_button: Button
var abandon_button: Button

func _ready() -> void:
	layer = 11

func toggle() -> void:
	if opened: close(); return
	if game.game_over or not game.cycle.phase in ["day","planning","scavenge","returning"]: return
	if game.interface.workshop_open: game.interface.close_workshop()
	if game.residence_view.opened: game.residence_view.close()
	if game.center.visible: game.center.close()
	paused_before = game.paused
	game.paused = true
	opened = true
	game.director.sync_day(game)
	render()

func close() -> void:
	if not opened: return
	opened = false
	if is_instance_valid(window): window.hide(); window.queue_free()
	game.paused = paused_before or game.game_over or game.cycle.phase in ["planning","dawn"]
	get_viewport().set_input_as_handled()

func render() -> void:
	if is_instance_valid(window): window.hide(); window.queue_free()
	offer_buttons.clear()
	claim_button = null
	abandon_button = null
	var ui: CampaignInterface = game.interface
	var d: CampaignDirector = game.director
	window = ui.panel(self,Vector2(25,20),Vector2(1390,860))
	ui.label(window,"街区动态",Vector2(28,22),Vector2(1000,44),30,GameUi.ACCENT)
	ui.button(window,"返回 U / Esc",Vector2(1155,22),Vector2(205,42),close)
	ui.label(window,"战役第%d天 · 本轮第%d—%d天 · 每轮可选一项，不接取不受惩罚" % [game.expansion.day(game),d.window(game)*3+1,d.window(game)*3+3],Vector2(28,80),Vector2(1320,31),18,GameUi.SECONDARY)
	var forecast := ui.panel(window,Vector2(28,127),Vector2(1330,94),GameUi.SURFACE)
	ui.label(forecast,game.night_forecast().replace(" · U查看街区动态",""),Vector2(20,13),Vector2(1010,29),21,GameUi.ACCENT)
	ui.button(forecast,"安防详情 Z",Vector2(1080,12),Vector2(225,38),func(): game.security_view.toggle())
	ui.label(forecast,"尸群活动随日期、营地噪声与安防变化；寒潮按日历到来。护甲、武器、守夜、取暖各有用途。",Vector2(20,52),Vector2(1290,29),18,GameUi.SECONDARY)
	if d.status in ["active","ready"]:
		_active(ui,d)
	else:
		var ids := d.offers(game)
		for index in range(ids.size()):
			var id: String = ids[index]
			var definition: Dictionary = CampaignDirector.CONTRACTS[id]
			var card := ui.panel(window,Vector2(28+index*452,248),Vector2(426,416),GameUi.SURFACE)
			ui.label(card,definition["name"],Vector2(20,20),Vector2(386,34),23,GameUi.TEXT)
			ui.label(card,"风险："+definition["risk"],Vector2(20,68),Vector2(386,55),18,GameUi.WARNING).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui.label(card,_objective(definition),Vector2(20,136),Vector2(386,128),18,GameUi.SECONDARY).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ui.label(card,"接应补给\n"+ShelterInventory.describe(definition["reward"]),Vector2(20,280),Vector2(386,65),19,GameUi.SUCCESS).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var take := ui.button(card,"接取此项",Vector2(20,359),Vector2(386,40),func(): d.accept(game,id); render())
			take.tooltip_text = d.accept_error(game,id)
			take.disabled = not take.tooltip_text.is_empty()
			offer_buttons[id] = take
		if d.accepted_window == d.window(game): ui.label(window,"本轮已接取过一项；下一轮开始后会有新机会。",Vector2(28,693),Vector2(1300,34),20,GameUi.WARNING)
		if d.status == "claimed": ui.label(window,"上次接应补给已入库，累计完成%d次。" % d.rewards_received,Vector2(28,740),Vector2(1300,34),18,GameUi.SUCCESS)
	ui.label(window,"升级厨房可接更大规模备餐；改良工作台解锁深区清障，精密武器台解锁射击委托。",Vector2(28,798),Vector2(1320,31),18,GameUi.SECONDARY)

func _active(ui: CampaignInterface, d: CampaignDirector) -> void:
	var definition: Dictionary = CampaignDirector.CONTRACTS[d.contract]
	var card := ui.panel(window,Vector2(28,248),Vector2(1330,510),GameUi.SURFACE)
	ui.label(card,definition["name"]+(" · 已达成" if d.status == "ready" else " · 进行中"),Vector2(24,20),Vector2(1260,40),26,GameUi.ACCENT)
	ui.label(card,_objective(definition),Vector2(24,83),Vector2(1255,85),20).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.label(card,"已完成 %d / %d%s · 第%d夜结束前" % [d.progress,definition["goal"],"；随身待带回%d" % d.trip_progress if d.trip_progress > 0 else "",d.deadline],Vector2(24,182),Vector2(1255,32),21,GameUi.SUCCESS)
	var bar := ProgressBar.new()
	bar.position = Vector2(24,230)
	bar.size = Vector2(1255,12)
	bar.show_percentage = false
	bar.max_value = definition["goal"]
	bar.value = d.progress
	card.add_child(bar)
	ui.label(card,"接应补给："+ShelterInventory.describe(definition["reward"]),Vector2(24,273),Vector2(1255,35),22,GameUi.SUCCESS)
	if not definition["cost"].is_empty(): ui.label(card,"交付："+ShelterInventory.describe(definition["cost"])+"；先为队伍留好食物。",Vector2(24,322),Vector2(1255,35),19,GameUi.WARNING)
	claim_button = ui.button(card,"接收补给",Vector2(24,411),Vector2(330,48),func(): d.claim(game); render())
	claim_button.disabled = d.status != "ready" or not game.cycle.phase in ["day","planning"] or not game.inventory.can_take(definition["cost"])
	claim_button.tooltip_text = "需交付："+ShelterInventory.describe(definition["cost"]) if not game.inventory.can_take(definition["cost"]) else "完成后只能领取一次。"
	abandon_button = ui.button(card,"放弃本轮委托",Vector2(939,411),Vector2(330,48),func(): d.abandon(game); render())
	abandon_button.disabled = not game.cycle.phase in ["day","planning"]
	abandon_button.tooltip_text = "放弃后本轮不能再接取；已有物资不会扣除。"

func _objective(definition: Dictionary) -> String:
	if definition["type"] == "survey":
		var area := LocationCatalog.area(definition["map"])
		var site: Dictionary = area["sites"][definition["site"]]
		return "%s · %s（%s）\n%s" % [area["name"],site["name"],"二楼" if site["floor"] == 1 else "地面",definition["hint"]]
	return definition["hint"]
