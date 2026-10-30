class_name GameUi
extends RefCounted
## One readable palette and typography scale for interactive panels.
const PANEL := Color("181b18")
const SURFACE := Color("262a24")
const BORDER := Color("53564b")
const TEXT := Color("e8e3d6")
const SECONDARY := Color("bcb9ab")
const MUTED := Color("929487")
const ACCENT := Color("d6b16c")
const SUCCESS := Color("a5b58b")
const WARNING := Color("d8ad64")
const DANGER := Color("dc9480")
const FONT := preload("res://assets/fonts/interface.otf")
static var _theme: Theme
static var _heading: FontVariation

static func box(background: Color = PANEL, border: Color = BORDER, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func button(node: Button) -> void:
	node.add_theme_font_override("font",FONT)
	node.add_theme_font_size_override("font_size",18)
	for entry in [["normal",SURFACE,BORDER],["hover",Color("35392f"),ACCENT],["pressed",Color("151810"),ACCENT],["disabled",Color("20231e"),Color("41463b")]]:
		node.add_theme_stylebox_override(entry[0],box(entry[1],entry[2]))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: node.add_theme_color_override(state,TEXT)
	node.add_theme_color_override("font_disabled_color",MUTED)
	node.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,ACCENT))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func theme() -> Theme:
	if _theme != null: return _theme
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 18
	for type in ["Label","RichTextLabel","Button","OptionButton","CheckBox","TabBar","PopupMenu","LineEdit"]:
		result.set_color("font_color",type,TEXT)
		result.set_color("font_hover_color",type,TEXT)
		result.set_color("font_disabled_color",type,MUTED)
		result.set_color("font_selected_color",type,ACCENT)
		result.set_color("font_unselected_color",type,SECONDARY)
	for type in ["Panel","PanelContainer","AcceptDialog","Window","TabContainer","PopupMenu"]: result.set_stylebox("panel",type,box())
	for type in ["Button","OptionButton","CheckBox"]:
		for entry in [["normal",SURFACE,BORDER],["hover",Color("35392f"),ACCENT],["pressed",Color("151810"),ACCENT],["disabled",Color("20231e"),Color("41463b")]]: result.set_stylebox(entry[0],type,box(entry[1],entry[2]))
	result.set_stylebox("tab_selected","TabBar",box(SURFACE,ACCENT))
	result.set_stylebox("tab_unselected","TabBar",box(PANEL,BORDER))
	result.set_stylebox("normal","LineEdit",box(SURFACE,BORDER))
	result.set_stylebox("focus","LineEdit",box(SURFACE,ACCENT))
	result.set_stylebox("background","ProgressBar",box(Color("11140f"),BORDER,3))
	result.set_stylebox("fill","ProgressBar",box(SUCCESS,SUCCESS,3))
	for state in ["normal","hover","pressed","disabled"]: result.set_stylebox(state,"CheckBox",box(Color.TRANSPARENT,Color.TRANSPARENT,0))
	result.set_stylebox("focus","CheckBox",StyleBoxEmpty.new())
	result.set_stylebox("panel","TooltipPanel",box(PANEL,BORDER,1))
	result.set_color("font_color","TooltipLabel",TEXT)
	for type in ["VScrollBar","HScrollBar"]:
		result.set_stylebox("scroll",type,box(Color("11140f"),Color.TRANSPARENT,0))
		result.set_stylebox("grabber",type,box(Color("565b4b"),Color.TRANSPARENT,1))
		result.set_stylebox("grabber_highlight",type,box(ACCENT,Color.TRANSPARENT,1))
	_theme = result
	return result

static func heading_font() -> Font:
	if _heading==null:
		_heading=FontVariation.new();_heading.base_font=FONT;_heading.variation_embolden=.55
	return _heading

static func primary(node: Button) -> void:
	for entry in [["normal",ACCENT],["hover",Color("e5c587")],["pressed",Color("b99555")]]:
		node.add_theme_stylebox_override(entry[0],box(entry[1],entry[1],1))
	for state in ["font_color","font_hover_color","font_pressed_color"]:node.add_theme_color_override(state,Color("171a14"))
	node.add_theme_font_override("font",heading_font())

static func tab(node: Button, active: bool) -> void:
	var normal:=box(Color("30342b") if active else Color.TRANSPARENT,ACCENT if active else BORDER,0)
	normal.border_width_top=0;normal.border_width_left=3 if active else 0;normal.border_width_right=0;normal.border_width_bottom=0
	node.add_theme_stylebox_override("normal",normal)
	node.add_theme_color_override("font_color",TEXT if active else SECONDARY)
	node.alignment=HORIZONTAL_ALIGNMENT_LEFT

static func line(parent: CanvasItem, from: Vector2, to: Vector2) -> void:
	parent.draw.connect(func():parent.draw_line(from,to,Color(.55,.57,.49,.26),1,true))

static func paper(parent: CanvasItem, bounds: Rect2) -> void:
	parent.draw.connect(func():
		for i in range(72):
			var x:=bounds.position.x+fposmod(i*97.13,bounds.size.x)
			var y:=bounds.position.y+fposmod(i*43.71,bounds.size.y)
			parent.draw_line(Vector2(x,y),Vector2(minf(bounds.end.x,x+9+fposmod(i*19,38)),y),Color(.8,.78,.67,.025),1)
	)

static func crew_button(ui: CampaignInterface,parent: Node,actor: Survivor,point: Vector2,dimensions: Vector2,action: Callable,active: bool) -> Button:
	var b:=ui.button(parent,"",point,dimensions,action)
	tab(b,active)
	b.draw.connect(func():ActorVisual.portrait(b,actor.person.persona,Rect2(9,6,35,dimensions.y-12)))
	ui.label(b,actor.display_name,Vector2(50,7),Vector2(dimensions.x-58,25),17 if dimensions.x<210 else 18)
	if dimensions.y>=60:ui.label(b,actor.speciality,Vector2(54,32),Vector2(dimensions.x-64,22),15,SECONDARY)
	b.tooltip_text=actor.display_name+" · "+actor.speciality
	return b
