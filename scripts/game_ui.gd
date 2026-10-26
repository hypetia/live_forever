class_name GameUi
extends RefCounted
## One readable palette and typography scale for interactive panels.
const PANEL := Color("192330")
const SURFACE := Color("253445")
const BORDER := Color("62758a")
const TEXT := Color("f1f4f8")
const SECONDARY := Color("c1cedc")
const MUTED := Color("a0afc0")
const ACCENT := Color("e6c48c")
const SUCCESS := Color("a6ddcd")
const WARNING := Color("f0bf85")
const DANGER := Color("f1a69b")
const FONT := preload("res://assets/fonts/interface.otf")
static var _theme: Theme

static func box(background: Color = PANEL, border: Color = BORDER, radius: int = 7) -> StyleBoxFlat:
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
	for entry in [["normal",SURFACE,BORDER],["hover",Color("354b60"),ACCENT],["pressed",Color("13212e"),ACCENT],["disabled",Color("1c2937"),Color("536478")]]:
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
		for entry in [["normal",SURFACE,BORDER],["hover",Color("354b60"),ACCENT],["pressed",Color("13212e"),ACCENT],["disabled",Color("1c2937"),Color("536478")]]: result.set_stylebox(entry[0],type,box(entry[1],entry[2]))
	result.set_stylebox("tab_selected","TabBar",box(SURFACE,ACCENT))
	result.set_stylebox("tab_unselected","TabBar",box(PANEL,BORDER))
	result.set_stylebox("normal","LineEdit",box(SURFACE,BORDER))
	result.set_stylebox("focus","LineEdit",box(SURFACE,ACCENT))
	result.set_stylebox("background","ProgressBar",box(Color("101925"),BORDER,3))
	result.set_stylebox("fill","ProgressBar",box(SUCCESS,SUCCESS,3))
	_theme = result
	return result
