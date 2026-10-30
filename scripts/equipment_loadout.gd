class_name EquipmentLoadout
extends CanvasLayer
## A physical-item loadout screen shared by the shelter, departure and field inspection.
const SLOT_NAMES := ["手持武器", "护甲", "衣物"]
const SLOT_KEYS := ["weapon", "armor", "coat"]
var game: Node2D
var root: Control
var window: Panel
var opened := false
var pause_before := false
var selected_actor := 0
var selected_slot := 0
var actor_buttons: Dictionary = {}
var slot_buttons: Array[Button] = []
var item_buttons: Dictionary = {}
var close_button: Button
var read_only := false

func _ready() -> void:
	layer = 18
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0,0,0,.78)
	root.add_child(shade)
	root.hide()

func open_for(actor_id: int = -1, slot: int = 0) -> void:
	if game.game_over or not game.cycle.phase in ["day","planning","scavenge","returning"]: return
	if game.departure_dialog.visible or game._loot_open: return
	if not opened:
		if game.interface.workshop_open: game.interface.close_workshop()
		if game.camp_view.opened: game.camp_view.close()
		if game.center.visible: game.center.close()
		pause_before = game.paused
	read_only = not game.cycle.phase in ["day","planning"]
	selected_actor = game.expedition.actor_id if read_only else game.selected_id if actor_id < 0 else actor_id
	if selected_actor < 0 or selected_actor >= game.survivors.size(): return
	selected_slot = clampi(slot,0,2)
	opened = true
	game.paused = true
	game.expedition_view.search_held = false
	root.show()
	refresh()

func close() -> void:
	if not opened: return
	opened = false
	root.hide()
	game.paused = pause_before or game.game_over or game.cycle.phase in ["planning","dawn"]
	game._refresh_hud()

func dismiss_loaded() -> void:
	opened = false
	if is_instance_valid(root): root.hide()

func refresh() -> void:
	if not opened: return
	if is_instance_valid(window):
		root.remove_child(window)
		window.queue_free()
	actor_buttons.clear(); slot_buttons.clear(); item_buttons.clear()
	var ui: CampaignInterface = game.interface
	window = ui.panel(root,Vector2(90,65),Vector2(1260,770))
	var actor: Survivor = game.survivors[selected_actor]
	ui.label(window,"装备",Vector2(28,20),Vector2(900,42),28,GameUi.TEXT)
	close_button = ui.button(window,"关闭 O / Esc",Vector2(1030,20),Vector2(200,40),close)
	GameUi.paper(window,Rect2(0,0,1260,770))
	GameUi.line(window,Vector2(254,83),Vector2(254,735))
	var y := 90
	for index in range(game.survivors.size()):
		var person: Survivor = game.survivors[index]
		if person.health <= 0 or (read_only and index != selected_actor): continue
		var b := GameUi.crew_button(ui,window,person,Vector2(20,y),Vector2(220,60),open_for.bind(index,selected_slot),index==selected_actor)
		actor_buttons[index] = b
		y += 72
	ui.label(window,actor.display_name+" · "+actor.speciality,Vector2(275,86),Vector2(920,34),23,game.GOLD)
	var slots := EquipmentArt.slots(actor)
	for index in range(3):
		var entry: Dictionary = slots[index]
		var b := ui.button(window,"",Vector2(275+index*310,135),Vector2(295,118),open_for.bind(selected_actor,index))
		GameUi.tab(b,index==selected_slot)
		b.draw.connect(func():
			EquipmentArt.icon(b,entry,Vector2(35,53))
			if not entry["kind"].is_empty():
				b.draw_rect(Rect2(18,103,259,4),Color("34453f"))
				b.draw_rect(Rect2(18,103,259*entry["ratio"],4),Color("c5ab75") if not entry["broken"] else Color("dc816b"))
		)
		ui.label(b,SLOT_NAMES[index],Vector2(68,10),Vector2(210,26),18,GameUi.SECONDARY)
		ui.label(b,entry["name"]+(" · 损坏" if entry["broken"] else ""),Vector2(68,40),Vector2(210,28),21)
		ui.label(b,"耐久 %d / %d"%[entry["durability"],entry["maximum"]] if not entry["kind"].is_empty() else "空栏位",Vector2(68,72),Vector2(210,24),17,GameUi.SECONDARY)
		b.tooltip_text = GearCatalog.describe(entry["kind"]) if not entry["kind"].is_empty() else entry["name"]
		slot_buttons.append(b)
	ui.label(window,"随身物品" if read_only else "装备库存",Vector2(275,283),Vector2(940,30),20,game.GOLD)
	GameUi.line(window,Vector2(275,326),Vector2(1205,326))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(275,340); scroll.size = Vector2(930,360)
	window.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",0)
	scroll.add_child(body)
	var count := 0
	for item in game.expansion.gear:
		if GearCatalog.ITEMS[item["kind"]]["slot"] != SLOT_KEYS[selected_slot]: continue
		if read_only and item["owner"] != actor.person.persona: continue
		var kind: String = item["kind"]
		var owned: bool = item["owner"] == actor.person.persona
		var location: String = "仓库" if str(item["owner"]).is_empty() else PeopleCatalog.DATA[item["owner"]]["name"]
		var row := Panel.new(); row.custom_minimum_size = Vector2(900,82); row.theme = GameUi.theme(); row.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); body.add_child(row)
		GameUi.line(row,Vector2(0,81),Vector2(900,81))
		ui.label(row,"%s · #%02d    耐久 %d/%d"%[GearCatalog.ITEMS[kind]["name"],item["id"],item["durability"],GearCatalog.ITEMS[kind]["durability"]],Vector2(18,10),Vector2(640,30),21,game.GOLD)
		ui.label(row,location+"  /  "+GearCatalog.describe(kind),Vector2(18,44),Vector2(640,30),17)
		var target := -1 if owned else selected_actor
		var b := ui.button(row,"已装备" if read_only else "卸下" if owned else "装备" if str(item["owner"]).is_empty() else "转交",Vector2(728,21),Vector2(154,40),assign.bind(int(item["id"]),target))
		b.disabled = read_only
		b.tooltip_text = "交给%s；原装备放回仓库。"%actor.display_name if not owned else "放回仓库。"
		item_buttons[int(item["id"])] = b
		count += 1
	if count == 0: ui.label(body,"暂无"+SLOT_NAMES[selected_slot],Vector2.ZERO,Vector2(880,44),21,GameUi.SECONDARY)
	ui.label(window,"外出期间无法更换装备" if read_only else "武器、护甲各占1格；衣物不占格。",Vector2(275,719),Vector2(940,30),17,GameUi.SECONDARY)

func assign(id: int, actor_id: int) -> void:
	if read_only or not opened: return
	if game.expansion.assign_gear(game,id,actor_id):
		game.interface.refresh()
		refresh()
