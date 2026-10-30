class_name DistrictView
extends CanvasLayer
## A spatial strategic map, opened on demand; field play stays unobstructed.
const POSITIONS := [Vector2(65,180),Vector2(330,160),Vector2(595,205),Vector2(80,370),Vector2(345,355),Vector2(610,390),Vector2(75,570),Vector2(335,555),Vector2(610,585)]
var game: Node2D
var opened := false
var paused_before := false
var selected := "street"
var window: Panel
var backdrop: ColorRect
var map_buttons: Dictionary = {}
var target_button: Button
var travel_button: Button
var detail: Label

func _ready() -> void: layer = 13

func toggle() -> void:
	if opened: close();return
	if game.game_over or game._loot_open or game.departure_dialog.visible or game.expedition_view.equipment_dialog.visible: return
	if game.briefing.opened: game.briefing.close()
	if game.security_view.opened: game.security_view.close()
	if game.residence_view.opened: game.residence_view.close()
	if game.interface.workshop_open: game.interface.close_workshop()
	if game.center.visible: game.center.close()
	paused_before = game.paused;game.paused = true;opened = true
	selected = game.expedition.location_id if game.expedition.active else game.districts.target
	render()

func dismiss_loaded() -> void:
	opened = false
	for node in [window,backdrop]:
		if is_instance_valid(node): node.hide();node.queue_free()
	window = null;backdrop = null;map_buttons.clear()
	target_button = null;travel_button = null;detail = null

func close() -> void:
	if not opened: return
	dismiss_loaded()
	game.paused = paused_before or game.game_over or game.cycle.phase in ["planning","dawn"]
	get_viewport().set_input_as_handled()

func render() -> void:
	if is_instance_valid(window): window.hide();window.queue_free()
	if not is_instance_valid(backdrop):
		backdrop = ColorRect.new();backdrop.size = Vector2(1440,900);backdrop.color = Color(.02,.04,.06,.86)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP;add_child(backdrop)
	var ui: CampaignInterface = game.interface
	window = ui.panel(self,Vector2(25,20),Vector2(1390,860))
	ui.label(window,"街区与补给前哨",Vector2(30,20),Vector2(970,44),30,GameUi.TEXT)
	ui.button(window,"返回 Y / Esc",Vector2(1150,22),Vector2(210,42),close)
	ui.label(window,"枪声留下压力 · 轮值占用人手和燃料 · 修整与清理需要回到现场",Vector2(30,78),Vector2(1300,30),18,GameUi.SECONDARY)
	var chart := Control.new();chart.mouse_filter = Control.MOUSE_FILTER_IGNORE;window.add_child(chart)
	chart.draw.connect(func():
		var connections := [[0,1],[1,2],[0,3],[1,4],[2,5],[3,4],[4,5],[3,6],[4,7],[5,8],[6,7],[7,8]]
		for pair in connections:
			chart.draw_line(POSITIONS[pair[0]]+Vector2(105,60),POSITIONS[pair[1]]+Vector2(105,60),Color("3c5a5a"),3,true)
		chart.draw_polyline(PackedVector2Array([Vector2(870,145),Vector2(855,350),Vector2(880,540),Vector2(850,756)]),Color("476d80"),12,true)
	)
	map_buttons.clear()
	for index in range(LocationCatalog.ALL_IDS.size()):
		var id: String = LocationCatalog.ALL_IDS[index]
		var r: Dictionary = game.districts.regions[id]
		var unlocked: bool = game.expansion.unlocked(game,id)
		var button := ui.button(window,LocationCatalog.area(id)["name"]+"\n"+("轮值目标" if game.districts.target == id and r["built"] else "补给前哨" if r["built"] else "未建立" if unlocked else "未开放"),POSITIONS[index],Vector2(210,128),func(): selected=id;render())
		button.modulate = Color.WHITE if unlocked else Color(.64,.68,.72)
		button.add_theme_font_size_override("font_size",18)
		if id == selected: button.add_theme_stylebox_override("normal",GameUi.box(GameUi.SURFACE,GameUi.ACCENT))
		button.tooltip_text = "压力%d / 前哨耐久%d\n%s" % [roundi(r["heat"]),roundi(r["condition"]),game.regions[id].condition_name()]
		button.draw.connect(func():
			button.draw_rect(Rect2(16,102,178,5),Color("273d42"))
			button.draw_rect(Rect2(16,102,178*float(r["heat"])/100,5),GameUi.WARNING if r["heat"] >= 45 else Color("6f9b91"))
			button.draw_rect(Rect2(16,114,178,4),Color("273d42"))
			if r["built"]: button.draw_rect(Rect2(16,114,178*float(r["condition"])/100,4),GameUi.SUCCESS)
		)
		map_buttons[id] = button
	var r: Dictionary = game.districts.regions[selected]
	ui.label(window,LocationCatalog.area(selected)["name"],Vector2(918,157),Vector2(425,38),27,GameUi.ACCENT)
	ui.label(window,game.regions[selected].condition_name(),Vector2(918,207),Vector2(425,30),20,GameUi.SECONDARY)
	var actor_id: int = game.districts.operator(game)
	if actor_id < 0: actor_id = game.selected_id
	var actor: Survivor = game.survivors[actor_id]
	var risk: int = game.districts.shift_risk(actor,selected)
	var location: Dictionary = LocationCatalog.area(selected)["sites"][DistrictSystem.POINTS[selected]]
	var lines := "压力  %d / 100\n前哨  %s\n\n现场位置：%s · %s\n轮值参考：%s\n消耗燃料1 · 精神−45\n枪械另需弹药2；装备会磨损\n回收：%s\n遇险估计：%d%%\n\n枪声与动静积累压力。\n换区、清理和低噪声行动可缓解。" % [roundi(r["heat"]),("耐久%d%%" % roundi(r["condition"])) if r["built"] else "尚未建立",location["name"],"楼上" if location["floor"] == 1 else "地面",actor.display_name,ShelterInventory.describe(game.districts.shift_yield(actor,selected)),risk]
	if game.neighborhood.enabled and selected in NeighborhoodSystem.MAPS:
		lines="压力%d / 前哨耐久%d\n\n" % [roundi(r["heat"]),roundi(r["condition"])]+game.neighborhood.summary(selected)+"\n\n现场施工：点击设备或靠近按E。\n压力35以上可能有远端迁入者。\n轮值仍须人手、燃料与维护。"
	detail = ui.label(window,lines,Vector2(918,260),Vector2(425,367),18,GameUi.TEXT)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_button = ui.button(window,"设为轮值目标",Vector2(918,651),Vector2(425,44),func(): game.districts.select_target(game,selected);game.interface.refresh();render())
	target_button.disabled = not r["built"] or not game.cycle.phase in ["day","planning"]
	target_button.tooltip_text = "在夜间分工给一人安排“前哨轮值”，其余人仍需安排守夜或休息。"
	travel_button = ui.button(window,"今晚搜刮此区",Vector2(918,708),Vector2(425,44),func(): game.choose_destination(selected);game.interface.refresh();render())
	travel_button.disabled = game.cycle.phase != "planning" or not game.expansion.unlocked(game,selected)
	ui.label(window,"前哨施工：材料5、工具1。先到现场排除近处感染者；轮值会磨损前哨，失修后需维修。",Vector2(30,794),Vector2(1310,34),18,GameUi.SECONDARY)
