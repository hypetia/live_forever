class_name CompactHud
extends CanvasLayer
## Quiet play HUD: four positive gauges, resource pictograms and contextual actions.
var game: Node2D
var root: Control
var menu_button: Button
var end_button: Button
var save_button: Button
var goal_button: Button
var home_button: Button
var temperature: Label
var toast: Label
var old_buttons: Array[Button] = []
var old_labels: Array[Label] = []
var resource_buttons: Dictionary = {}
var last_toast := ""
var toast_remaining := 0.0

func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var backdrop := Node2D.new()
	backdrop.z_index = -5
	root.add_child(backdrop)
	backdrop.draw.connect(func():
		for band in range(20):
			backdrop.draw_rect(Rect2(0,band*5,1440,5),Color(0.035,0.05,0.055,maxf(0,0.92-band*0.046)))
			backdrop.draw_rect(Rect2(0,900-band*7,1440,7),Color(0.03,0.045,0.05,maxf(0,0.9-band*0.045)))
	)
	for child in game.hud.get_children():
		if child is Label and child != game.clock_label and child != game.game_over_label and not game.context_nodes.has(child): old_labels.append(child)
		if child is Button:
			if game.context_nodes.has(child): continue
			if child == game.pause_button or child == game.speed_button: continue
			if "菜单" in child.text: menu_button = child
			elif "结束白天" in child.text: end_button = child
			else: old_buttons.append(child)
	for node in [game.clock_label,game.day_bar,game.pause_button,game.speed_button,menu_button,end_button]:
		if is_instance_valid(node): node.reparent(root)
	save_button = game.interface.button(root,"存",Vector2(1306,16),Vector2(36,32),func(): game.save_game())
	save_button.tooltip_text = "保存 F6 · 读取 F9"
	goal_button = game.interface.button(root,"目标",Vector2(1120,798),Vector2(82,36),game.interface.toggle_workshop)
	home_button = game.interface.button(root,"家",Vector2(309,16),Vector2(36,32),func(): game.residence_view.toggle())
	temperature = game.interface.label(root,"",Vector2(376,20),Vector2(175,28),17)
	temperature.mouse_filter = Control.MOUSE_FILTER_PASS
	toast = game.interface.label(root,"",Vector2(410,731),Vector2(620,30),15,Color("d2c6a5"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.clip_text = true
	for key in ShelterInventory.NAMES:
		var index := resource_buttons.size()
		var button: Button = game.interface.button(root,"",Vector2(574+index*86,14),Vector2(80,38),func(): game.open_center(1))
		button.tooltip_text = ShelterInventory.NAMES[key]
		button.add_theme_font_size_override("font_size",15)
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover",game._style(Color(0.2,0.25,0.22,0.4),Color(0,0,0,0)))
		resource_buttons[key] = button
		button.draw.connect(_resource_icon.bind(button,key))
	var atmosphere := CanvasLayer.new()
	atmosphere.layer = 2
	game.add_child(atmosphere)
	var film := ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment(){
 vec2 p=SCREEN_UV-vec2(0.5);
 float edge=smoothstep(0.08,0.38,dot(p,p*vec2(1.0,0.85)));
 COLOR=vec4(0.005,0.01,0.015,edge*0.35);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	film.material = material
	atmosphere.add_child(film)
	for button in [game.pause_button,game.speed_button,menu_button,save_button]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var box: StyleBoxFlat = game._style(Color(0.04,0.06,0.065,0.72),Color(0.35,0.39,0.35,0.35),3)
			box.content_margin_left = 4
			box.content_margin_right = 4
			box.content_margin_top = 3
			box.content_margin_bottom = 3
			button.add_theme_stylebox_override(state,box)
	refresh()

func _process(delta: float) -> void:
	toast_remaining = maxf(0,toast_remaining-delta)
	toast.visible = toast_remaining > 0 and game.cycle.phase in ["day","scavenge","returning"]
	queue_redraw_canvas()

func queue_redraw_canvas() -> void:
	for card in game.cards:
		if card is SurvivorCard and card.visible: card.queue_redraw()

func refresh() -> void:
	if not is_instance_valid(root):return
	var day: bool = game.cycle.phase == "day"
	var field: bool = game.expedition.active
	home_button.visible = day
	home_button.tooltip_text = game.residence.title() + " · 家园 H\n安防耐久%d / 噪声%d" % [roundi(game.residence.condition),roundi(game.residence.noise)]
	for node in [game.main_title,game.subtitle,game.upkeep_label,game.phase_label,game.stock_label,game.save_label,game.tutorial_label,game.log_label]: node.hide()
	for label in old_labels:
		if is_instance_valid(label): label.hide()
	for button in old_buttons:
		if is_instance_valid(button):button.hide()
	game.interface.climate_label.hide()
	game.clock_label.position = Vector2(34,15)
	game.clock_label.size = Vector2(280,32)
	game.clock_label.add_theme_font_size_override("font_size",23)
	var minute := int(CampaignCycle.minute(game.simulation_time))
	var current_day: int = game.cycle.night_day if field else ExpeditionState.day_at(game.simulation_time)
	game.clock_label.text = "%02d  /  %02d:%02d" % [current_day,minute/60,minute%60]
	game.clock_label.tooltip_text = "第%d天 · %s\n20:00日落，06:00天亮\n%s" % [current_day,"已暂停" if game.paused else "时间进行中",game.phase_label.text]
	game.clock_label.mouse_filter = Control.MOUSE_FILTER_PASS
	game.day_bar.position = Vector2(35,53)
	game.day_bar.size = Vector2(271,3)
	game.day_bar.tooltip_text = game.phase_label.text
	game.pause_button.position = Vector2(1216,16)
	game.pause_button.size = Vector2(36,32)
	game.pause_button.text = ">" if game.paused else "II"
	game.pause_button.tooltip_text = "继续 / 暂停 · 空格"
	game.speed_button.position = Vector2(1260,16)
	game.speed_button.size = Vector2(40,32)
	game.speed_button.text = "×%d" % int(game.speed)
	menu_button.position = Vector2(1350,16)
	menu_button.size = Vector2(58,32)
	menu_button.text = "菜单"
	menu_button.tooltip_text = "菜单 Esc · 人物 P · 地图 M"
	game.pause_button.size = Vector2(36,32)
	game.speed_button.size = Vector2(40,32)
	menu_button.size = Vector2(58,32)
	save_button.size = Vector2(36,32)
	var inside: float = game.expansion.outside(game)+game.residence.indoor_bonus()+(18 if game.expansion.heater_remaining>0 else 0)
	temperature.text = "%d℃" % (game.expansion.outside(game) if field else inside)
	temperature.tooltip_text = "室外%d℃ / 室内%d℃\n%s" % [game.expansion.outside(game),inside,"炉火剩余%d分钟" % int(game.expansion.heater_remaining*2) if game.expansion.heater_remaining>0 else "炉火熄灭"]
	temperature.add_theme_color_override("font_color",Color("a1bcc2") if inside<6 else Color("d0c5a9"))
	for key in resource_buttons:
		var button: Button = resource_buttons[key]
		button.text = "    %d" % (game.expedition.bag[key] if field else game.inventory.amount(key))
		button.tooltip_text = ("随身" if field else "据点") + ShelterInventory.NAMES[key]
		button.queue_redraw()
	var count: int = game.survivors.size()
	var width: float = minf(216,(1075.0-(count-1)*10)/count)
	for index in range(game.cards.size()):
		var card: Button = game.cards[index]
		if card.get_parent()!=root:card.reparent(root)
		card.position = Vector2(32+index*(width+10),790)
		card.size = Vector2(width,94)
		card.text = ""
		card.visible = day or (field and index == game.expedition.actor_id)
		if field:
			card.position = Vector2(32,790)
			card.size = Vector2(280,94)
		card.tooltip_text = game.survivors[index].display_name+"\n"+Vitals.summary(game.survivors[index])+"\n保暖+%d℃" % game.survivors[index].warmth()+"\n双击查看人物详情 P"
		card.tooltip_text += "\n"+game.self_care.summary(game.survivors[index])
		card.queue_redraw()
	game.interface.build_button.position = Vector2(1220,798)
	game.interface.build_button.size = Vector2(86,36)
	game.interface.build_button.text = "建造"
	game.interface.build_button.tooltip_text = "建设 B"
	game.interface.workshop_button.position = Vector2(1316,798)
	game.interface.workshop_button.size = Vector2(86,36)
	game.interface.workshop_button.text = "制作"
	game.interface.workshop_button.tooltip_text = "设施升级、厨房配方、装备与战役 K"
	end_button.position = Vector2(1218,846)
	end_button.size = Vector2(184,38)
	end_button.text = "结束白天"
	end_button.visible = day
	goal_button.visible = day
	goal_button.tooltip_text = game.expansion.objective(game)
	game.interface.placement_hint.position = Vector2(400,741)
	game.interface.placement_hint.size = Vector2(650,32)
	if not game.placement.is_empty():game.interface.placement_hint.text = CampaignCycle.RECIPES[game.placement]["name"]+" · 点击放置"
	var latest: String = game.logs[0] if not game.logs.is_empty() else ""
	if latest != last_toast:
		last_toast = latest
		# Work orders and tutorials do not become a permanent subtitle track.
		if "死亡" in latest or "丢失" in latest or "建成" in latest or "无法" in latest or "不足" in latest or "存档" in latest or "保存" in latest or "失败" in latest:
			toast.text = latest.substr(latest.find("   ")+3).left(44)
			toast_remaining = 3.5
	queue_redraw_canvas()

func _resource_icon(button: Button, key: String) -> void:
	HudIcons.draw(button,key,Vector2(14,19),17,Color("a7ac97"))
