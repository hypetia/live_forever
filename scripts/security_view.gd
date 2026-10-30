class_name SecurityView
extends CanvasLayer
## Read-only inspection. Historical values come from saved dawn reports.
var game: Node2D
var opened := false
var paused_before := false
var window: Panel
var backdrop: ColorRect
var last_night := false
var rows: Array[Dictionary] = []
var total_value := 0.0

func _ready() -> void:
	layer = 12

func toggle() -> void:
	if opened: close(); return
	if game.game_over: return
	paused_before = game.paused
	game.paused = true
	opened = true
	last_night = game.cycle.phase == "dawn"
	render()

func dismiss_loaded() -> void:
	opened = false
	if is_instance_valid(window): window.hide(); window.queue_free()
	window = null
	if is_instance_valid(backdrop): backdrop.hide(); backdrop.queue_free()
	backdrop = null

func close() -> void:
	if not opened: return
	dismiss_loaded()
	game.paused = paused_before or game.game_over or game.cycle.phase in ["planning","dawn"]
	get_viewport().set_input_as_handled()

func render() -> void:
	if is_instance_valid(window): window.hide(); window.queue_free()
	if not is_instance_valid(backdrop):
		backdrop = ColorRect.new()
		backdrop.size = Vector2(1440,900)
		backdrop.color = Color(0.02,0.04,0.06,0.78)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(backdrop)
	var ui: CampaignInterface = game.interface
	window = ui.panel(self,Vector2(70,55),Vector2(1300,790))
	ui.label(window,"夜间安防",Vector2(30,20),Vector2(900,44),30,GameUi.TEXT)
	ui.button(window,"返回 Z / Esc",Vector2(1060,22),Vector2(210,42),close)
	ui.button(window,"当前防备",Vector2(30,83),Vector2(225,42),func(): last_night=false; render())
	ui.button(window,"上次纪要",Vector2(270,83),Vector2(225,42),func(): last_night=true; render())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30,146)
	scroll.size = Vector2(1240,606)
	window.add_child(scroll)
	var body := Control.new()
	body.custom_minimum_size = Vector2(1200,600)
	scroll.add_child(body)
	if last_night:
		var y := 0.0
		for line in game.cycle.report:
			if not line.begins_with("【安防】"): continue
			ui.label(body,line.trim_prefix("【安防】"),Vector2(10,y),Vector2(1170,91),21,GameUi.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			y += 105
		if y == 0:
			ui.label(body,"暂无防守记录",Vector2(10,20),Vector2(1170,60),21,GameUi.SECONDARY).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.y = maxf(600,y)
		return
	var convoy: bool = not game.residence.convoy.is_empty()
	var night: int = game.cycle.night_day if game.cycle.phase != "day" else ExpeditionState.day_at(game.simulation_time)
	var threat: float = 1.5+minf(1,night*0.025) if convoy else game.raid_threat(night)
	rows = DefenseAssessment.components(game,true)
	total_value = DefenseAssessment.total(rows)
	var heading := "护送力量 %.2f / 路线威胁 %.2f" if convoy else "防守力量 %.2f / 袭击强度 %.2f"
	ui.label(body,heading % [total_value,threat],Vector2(10,0),Vector2(1180,36),25,GameUi.SUCCESS if total_value >= threat else GameUi.WARNING)
	var chance: int = game.raid_chance(night)
	var hint := "全员随车队行军；营地隔断、安防不参与护送。" if convoy else "第%d夜 · 遇袭概率%d%% · 耐久%d%% · 暴露噪声%d" % [night,chance,roundi(game.residence.condition),roundi(game.residence.noise)]
	ui.label(body,hint,Vector2(10,49),Vector2(1180,36),18,GameUi.SECONDARY)
	ui.label(body,"守夜人员在夜间准备中安排。" if game.cycle.phase == "day" else "设施状态与上次防守记录。" if game.cycle.phase == "dawn" else "防守能力受角色状态、专长和装备影响。",Vector2(10,91),Vector2(1180,32),18,GameUi.SECONDARY)
	var y := 145.0
	for row in rows:
		var card := ui.panel(body,Vector2(0,y),Vector2(1190,76),GameUi.SURFACE)
		ui.label(card,row["name"],Vector2(15,9),Vector2(330,29),20,GameUi.TEXT)
		ui.label(card,row["hint"],Vector2(15,40),Vector2(1120,27),17,GameUi.SECONDARY)
		var bar := ProgressBar.new()
		bar.position=Vector2(375,14)
		bar.size=Vector2(620,14)
		bar.max_value=maxf(threat,total_value)
		bar.value=float(row["value"])
		bar.show_percentage=false
		card.add_child(bar)
		ui.label(card,"+%.2f" % row["value"],Vector2(1030,6),Vector2(140,33),23,GameUi.ACCENT)
		y += 87
	ui.label(body,"预警设施需要有人守夜才有效；门窗、尖桩的贡献随耐久下降。维护安防与修缮房屋是两项工作。",Vector2(10,y+5),Vector2(1170,65),18,GameUi.WARNING).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.y=y+100
