class_name BackpackGrid
extends Control
## A cell represents one bounded stack; quantities remain in the simulation.
const COLUMNS := 4
var cells: Array[Button] = []
var first_resources: Dictionary = {}
var items: Array[Dictionary] = []
var signature := ""
var resource_hint := "点击转移1份；Shift点击转移本格"
var activated: Callable
var available: Callable

func _init() -> void:
	theme = GameUi.theme()

func render(entries: Array[Dictionary], capacity: int) -> void:
	var token := JSON.stringify(entries)+":"+str(capacity)
	if token != signature:
		signature = token
		items = entries.duplicate(true)
		for cell in cells: cell.hide(); cell.queue_free()
		cells.clear(); first_resources.clear()
		for index in range(maxi(capacity,entries.size())):
			var entry: Dictionary = entries[index] if index < entries.size() else {}
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(104,84)
			cell.size = Vector2(104,84)
			cell.position = Vector2((index%COLUMNS)*114,(index/COLUMNS)*92)
			cell.focus_mode = Control.FOCUS_NONE
			GameUi.button(cell)
			add_child(cell)
			cells.append(cell)
			cell.draw.connect(_icon.bind(cell,entry))
			if entry.is_empty():
				cell.tooltip_text = "空格"
				continue
			if entry["kind"] == "resource" and not first_resources.has(entry["key"]): first_resources[entry["key"]] = cell
			var name: String = ShelterInventory.NAMES.get(entry["key"],GearCatalog.ITEMS.get(entry["key"],GearCatalog.PARTS.get(entry["key"],{})).get("name","弹药"))
			if entry["kind"]=="rescue": name="背负伤员 · 占用2格，抵达出口后加入队伍"
			cell.tooltip_text = "%s · 本格%d / %d" % [name,entry["count"],entry["limit"]]
			if entry["kind"] == "resource": cell.tooltip_text += "\n"+resource_hint
			elif entry["kind"] == "gear": cell.tooltip_text += "\n随身装备 · 耐久%d · 不能放入物资容器" % entry["durability"]
			elif entry["kind"] == "ammo": cell.tooltip_text += "\n包括弹匣中的子弹"
			var count := Label.new()
			count.position = Vector2(6,56); count.size = Vector2(90,25)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.text = "%d/%d" % [entry["count"],entry["limit"]]
			count.add_theme_font_size_override("font_size",19)
			cell.add_child(count)
			cell.pressed.connect(func():
				if activated.is_valid(): activated.call(entry,int(entry["count"]) if Input.is_physical_key_pressed(KEY_SHIFT) else 1)
			)
	custom_minimum_size = Vector2(COLUMNS*104+(COLUMNS-1)*10,maxi(0,ceili(cells.size()/float(COLUMNS))*92-8))
	size = custom_minimum_size
	for index in range(cells.size()):
		cells[index].disabled = index >= entries.size() or not available.is_valid() or not bool(available.call(entries[index]))
		cells[index].queue_redraw()

func _icon(cell: Button, entry: Dictionary) -> void:
	if entry.is_empty(): return
	var point := Vector2(52,29)
	var color := GameUi.MUTED if cell.disabled else GameUi.ACCENT
	match str(entry["kind"]):
		"resource": HudIcons.draw(cell,entry["key"],point,27,color)
		"gear": EquipmentArt.icon(cell,{"slot":GearCatalog.ITEMS[entry["key"]]["slot"],"kind":entry["key"],"broken":entry["durability"] <= 0},point)
		"ammo":
			for x in [-9,0,9]:
				cell.draw_rect(Rect2(point+Vector2(x-2,-7),Vector2(5,17)),color)
				cell.draw_circle(point+Vector2(x+0.5,-7),2.5,color)
		"rescue": HudIcons.draw(cell,"medicine",point,27,color)
		"part":
			cell.draw_arc(point,11,0,TAU,24,color,3,true)
			for index in range(8):
				var direction := Vector2.from_angle(index*TAU/8)
				cell.draw_line(point+direction*10,point+direction*16,color,4,true)
