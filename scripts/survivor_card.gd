class_name SurvivorCard
extends Button
var game: Node2D
var member_id := 0
var normal_frame: StyleBoxFlat
var selected_frame: StyleBoxFlat

func _ready() -> void:
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	normal_frame = game._style(Color(0.065,0.077,0.075,0.93),Color("333c38"),3)
	selected_frame = game._style(Color(0.065,0.077,0.075,0.93),Color("9b9071"),3)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			game.select_survivor(member_id)
			game.open_center(5)
	)

func _draw() -> void:
	if not is_instance_valid(game) or member_id >= game.survivors.size(): return
	var actor: Survivor = game.survivors[member_id]
	var selected: bool = game.selected_id == member_id
	var font := Survivor.FONT
	draw_style_box(selected_frame if selected else normal_frame, Rect2(Vector2.ZERO,size))
	# Hand-drawn bust, cropped by the card rather than a block of statistics.
	draw_rect(Rect2(8,8,42,size.y-16),Color("1b2426"))
	draw_colored_polygon(PackedVector2Array([Vector2(10,68),Vector2(14,45),Vector2(26,39),Vector2(42,44),Vector2(49,68)]),actor.tint.darkened(0.12))
	draw_line(Vector2(17,48),Vector2(13,69),actor.tint.darkened(0.4),6,true)
	draw_rect(Rect2(25,34,8,13),Color("9d876e"))
	draw_circle(Vector2(28,29),12,Color("bca68a"))
	draw_arc(Vector2(27,28),12,PI,TAU,16,Color("303431"),6,true)
	draw_colored_polygon(PackedVector2Array([Vector2(30,24),Vector2(40,32),Vector2(36,37),Vector2(29,38)]),Color(0.2,0.22,0.2,0.25))
	draw_line(Vector2(26,30),Vector2(31,30),Color("55554b"),1,true)
	draw_string(font,Vector2(61,24),actor.display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ded9c9"))
	draw_string(font,Vector2(size.x-18,20),str(member_id+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("7e887b"))
	PersonalityArt.face(self,actor.person.persona,Vector2(28,29),1.05)
	var col_width := (size.x - 70) / 2
	for index in range(Vitals.KEYS.size()):
		var key: String = Vitals.KEYS[index]
		var pos := Vector2(66 + (index % 2) * col_width,39 + (index / 2) * 17)
		var value := Vitals.value(actor,key)
		var color: Color = Color("d5836c") if value <= 20 else Vitals.COLORS[key]
		HudIcons.draw(self,key,pos,11,color)
		draw_rect(Rect2(pos+Vector2(10,-2),Vector2(col_width-24,4)),Color("303936"))
		draw_rect(Rect2(pos+Vector2(10,-2),Vector2((col_width-24)*value/100.0,4)),color)
	var status := actor.status_text().split(" · ")[0].left(11)
	if actor.health <= 0: status = "已故"
	draw_string(font,Vector2(61,79),status,HORIZONTAL_ALIGNMENT_LEFT,size.x-67,11,Color("a9b09d"))
	if actor.injury >= 30 or actor.infection >= 20 or actor.illness >= 30:
		HudIcons.draw(self,"medicine",Vector2(41,17),10,Color("ce927b"))


func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new()
	label.text = for_text
	label.add_theme_font_override("font",Survivor.FONT)
	label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",Color("ddd9c9"))
	return label
