class_name CampaignPanels
extends RefCounted
## One optional screen at a time, with a single pause/return convention.

static func views(game: Node2D) -> Array:
	return [game.equipment_view,game.camp_view,game.chronicle_view,game.neighborhood_view,game.district_view,game.security_view,game.briefing,game.residence_view]

static func current(game: Node2D) -> Object:
	for view in views(game):
		if is_instance_valid(view) and view.opened: return view
	return game.interface if is_instance_valid(game.interface) and game.interface.workshop_open else null

static func close_all(game: Node2D) -> void:
	if game.center.visible:game.center.close()
	for view in views(game):
		if is_instance_valid(view) and view.opened: view.close()
	if game.interface.workshop_open: game.interface.close_workshop()
	if game._loot_open:game.close_loot()
	game.interface.build_open=false
	if is_instance_valid(game.interface.build_panel): game.interface.build_panel.hide()
	if game.expedition_view.bag_open:game.expedition_view.toggle_bag()
	game.context_open=false
	if game.game_over or game.cycle.phase in ["planning","dawn"]:game.paused=true

static func resume(game: Node2D) -> void:
	close_all(game)
	if not game.game_over and game.cycle.phase in ["day","scavenge","returning","siege"]: game.paused=false
	game._refresh_hud()

static func blocked(game: Node2D) -> bool:
	for dialog in [game.load_dialog,game.new_dialog,game.exit_dialog,game.prep_dialog,game.end_day_dialog,game.departure_dialog,game.expedition_view.equipment_dialog]:
		if is_instance_valid(dialog) and dialog.visible:return true
	return game.game_over or game.center.visible or game._loot_open

static func handle(game: Node2D,event: InputEvent) -> bool:
	# Field inventory stays live; dismiss it without issuing a cancel/move order.
	var dismiss_mouse:bool=event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT
	var dismiss_key:bool=event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE
	if not game.departure_dialog.visible and not game.expedition_view.equipment_dialog.visible:
		if game._loot_open and (dismiss_mouse or dismiss_key):game.close_loot();return true
		if game.expedition_view.bag_open and (dismiss_mouse or dismiss_key):game.expedition_view.toggle_bag();return true
	if blocked(game):return false
	var active:=current(game)
	if event is InputEventMouseButton and event.pressed and active!=null:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			close_all(game);return true
		var window:Panel=game.interface.workshop_panel if active==game.interface else active.window
		if event.button_index==MOUSE_BUTTON_LEFT and is_instance_valid(window) and not window.get_global_rect().has_point(event.position):
			close_all(game);return true
	if not event is InputEventKey or not event.pressed or event.echo:return false
	var key:int=event.physical_keycode
	if active!=null and key in [KEY_ESCAPE,KEY_SPACE]:
		if key==KEY_SPACE:resume(game)
		else:close_all(game)
		return true
	if not game.cycle.phase in ["day","planning","scavenge","returning"]:return false
	# Never turn a popup's Enter / arrows into world commands.
	if key not in [KEY_B,KEY_K,KEY_O,KEY_H,KEY_F5,KEY_F2,KEY_F3,KEY_F4,KEY_U,KEY_Y,KEY_Z]:return false
	if key in [KEY_B,KEY_K,KEY_H] and not game.cycle.phase in ["day","planning"]:return false
	if key==KEY_B and game.cycle.phase!="day":return false
	if key==KEY_F5 and not game.camp.enabled:return false
	if key in [KEY_B,KEY_K]:
		var section:="construction" if key==KEY_B else "workbench"
		if active==game.interface and (key==KEY_K or game.interface.workshop_section==section):close_all(game)
		else:game.interface.open_workshop(section)
	elif key==KEY_O:
		if active==game.equipment_view:close_all(game)
		else:game.equipment_view.open_for()
	elif key==KEY_H:game.residence_view.toggle()
	elif key==KEY_F5:
		if active==game.camp_view:close_all(game)
		else:game.camp_view.show_page("situation")
	elif key in [KEY_F2,KEY_F3,KEY_F4]:game.chronicle_view.show_page("starts" if key==KEY_F2 else "people" if key==KEY_F3 else "cooperate")
	elif key==KEY_U:game.briefing.toggle()
	elif key==KEY_Y:game.district_view.toggle()
	elif key==KEY_Z:game.security_view.toggle()
	return true
