class_name GoalSystem
extends RefCounted

signal event_reported(message: String)
var stages := {"radio": 0, "clinic": 0, "network": 0}
var tracked := "radio"
var notes: Array[String] = []
var field_notes: Array[String] = []
var next_trade_day := 4
var trades := {"medicine": 0, "materials": 0, "convoy": 0}
var spent := {"materials": 0, "medicine": 0, "tools": 0, "water": 0, "fuel": 0, "raw_food": 0}


func found_site(location: String, index: int) -> void:
	var key := "%s:%d" % [location, index]
	if GoalCatalog.NOTE_IDS.has(key) and not notes.has(key) and not field_notes.has(key): field_notes.append(key)


func returned(cargo: Dictionary, loadout: Dictionary, survived: bool) -> void:
	var gained := 0
	for resource in cargo: gained += maxi(0, int(cargo[resource]) - int(loadout.get(resource, 0)))
	if survived and gained > 0:
		for key in field_notes:
			if not notes.has(key): notes.append(key)
		if not field_notes.is_empty(): event_reported.emit("带回了新的勘查记录。按O查看长期目标；记录不会占用额外背包格。")
	field_notes.clear()


func progress_error(game: Node2D, id: String) -> String:
	if not GoalCatalog.IDS.has(id): return "未知目标"
	if game.expedition.active: return "先带外出者回到基地"
	if game.game_over: return "队伍已经失守"
	var step := int(stages[id])
	if step >= 3: return "这条目标已完成，仍可继续生存"
	var definition: Dictionary = GoalCatalog.STAGES[id][step]
	if ExpeditionState.day_at(game.simulation_time) < int(definition["day"]): return "第%d天起可以继续" % definition["day"]
	if game.upkeep.level < int(definition["level"]): return "需要%d级据点" % definition["level"]
	if not definition["note"].is_empty() and not notes.has(definition["note"]): return "还缺带回基地的勘查记录：" + definition["hint"]
	if id == "network" and step == 0 and game.upkeep.returns.values().any(func(n): return n == 0): return "三处地点都要有一次净补给归来"
	if id == "network" and step == 2 and stages["radio"] < 3 and stages["clinic"] < 3: return "先完成通讯或救护路线"
	if id == "clinic" and step in [0, 2]:
		var cared := 0
		for actor: Survivor in game.survivors:
			for task in ["eat", "sleep", "heal"]: cared += int(actor.completed_by_task[task])
		if cared < (1 if step == 0 else 3): return "需要实际完成%d次基地照料（进食、休息或治疗）" % (1 if step == 0 else 3)
	if not game.inventory.can_take(definition["cost"]): return game.inventory.missing_text(definition["cost"])
	return ""


func advance(game: Node2D, id: String) -> bool:
	if not progress_error(game, id).is_empty(): return false
	var definition: Dictionary = GoalCatalog.STAGES[id][int(stages[id])]
	if not game.inventory.try_take(definition["cost"], "长期目标：" + definition["title"]): return false
	_record_cost(definition["cost"])
	stages[id] = int(stages[id]) + 1
	event_reported.emit("目标完成：%s · %s（%d/3）。%s" % [GoalCatalog.NAMES[id], definition["title"], stages[id], "这条路线已留下成果，队伍仍可继续生存。" if stages[id] == 3 else "按O查看下一阶段。"])
	return true


func trade_error(game: Node2D, id: String) -> String:
	if not GoalCatalog.TRADES.has(id): return "未知交换"
	if game.expedition.active: return "先带外出者回到基地"
	if game.game_over: return "队伍已经失守"
	if game.upkeep.level < 1: return "至少需要1级据点"
	if ExpeditionState.day_at(game.simulation_time) < next_trade_day: return "下一次接应：第%d天" % next_trade_day
	var definition: Dictionary = GoalCatalog.TRADES[id]
	if not definition["project"].is_empty() and stages[definition["project"]] < 3: return "先完成连接补给线"
	if not game.inventory.can_take(definition["cost"]): return game.inventory.missing_text(definition["cost"])
	return ""


func trade_output(game: Node2D, id: String) -> Dictionary:
	var output: Dictionary = GoalCatalog.TRADES[id]["output"].duplicate()
	var actor: Survivor = game.survivors[game.selected_id]
	if actor.health > 0 and actor.metabolism < 1 and actor.person.persona == "tang":
		output["water"] = int(output.get("water", 0)) + 1
		output["fuel"] = int(output.get("fuel", 0)) + 1
	return output


func trade(game: Node2D, id: String) -> bool:
	if not trade_error(game, id).is_empty(): return false
	var definition: Dictionary = GoalCatalog.TRADES[id]
	if not game.inventory.try_take(definition["cost"], "邻里互助：" + definition["title"]): return false
	var output := trade_output(game, id)
	game.inventory.deposit(output, "邻里互助接应补给")
	_record_cost(definition["cost"])
	trades[id] = int(trades[id]) + 1
	next_trade_day = ExpeditionState.day_at(game.simulation_time) + 2
	event_reported.emit("%s：支付%s，带回%s。所有互助共用两日间隔；仍需留足应急药品和维修材料。" % [definition["title"], ShelterInventory.describe(definition["cost"]), ShelterInventory.describe(output)])
	return true


func _record_cost(cost: Dictionary) -> void:
	for resource in cost: spent[resource] = int(spent[resource]) + int(cost[resource])


func hint() -> String:
	var step := int(stages[tracked])
	return "%s %d/3 · %s · O查看" % [GoalCatalog.NAMES[tracked], step, GoalCatalog.STAGES[tracked][step]["title"]] if step < 3 else "%s已完成 · O查看其他目标" % GoalCatalog.NAMES[tracked]


func snapshot() -> Dictionary:
	return {"stages": stages.duplicate(), "tracked": tracked, "notes": notes.duplicate(), "field_notes": field_notes.duplicate(), "next_trade_day": next_trade_day, "trades": trades.duplicate(), "spent": spent.duplicate()}


func restore_validated(data: Dictionary) -> void:
	for field in ["stages", "trades", "spent"]:
		var values := {}
		for key in data[field]: values[key] = int(data[field][key])
		set(field, values)
	tracked = data["tracked"]
	next_trade_day = int(data["next_trade_day"])
	notes.clear()
	field_notes.clear()
	for key in data["notes"]: notes.append(key)
	for key in data["field_notes"]: field_notes.append(key)


static func validate(data: Variant, seconds: float, expedition: Dictionary, location: String) -> String:
	if not CharacterState.keys(data, ["stages", "tracked", "notes", "field_notes", "next_trade_day", "trades", "spent"]): return "长期目标字段无效"
	if not CharacterState.keys(data["stages"], GoalCatalog.IDS) or not CharacterState.keys(data["trades"], GoalCatalog.TRADE_IDS) or not CharacterState.keys(data["spent"], ["materials", "medicine", "tools", "water", "fuel", "raw_food"]): return "目标或互助账目不完整"
	if not data["tracked"] is String or not GoalCatalog.IDS.has(data["tracked"]): return "追踪目标无效"
	for amount in data["stages"].values():
		if not CharacterState.integer(amount, 0, 3): return "目标阶段无效"
	for field in ["trades", "spent"]:
		for amount in data[field].values():
			if not CharacterState.integer(amount, 0, 100000000): return "互助数量无效"
	var expected_spent := {"materials": 0, "medicine": 0, "tools": 0, "water": 0, "fuel": 0, "raw_food": 0}
	for id in GoalCatalog.IDS:
		for index in range(int(data["stages"][id])):
			for resource in GoalCatalog.STAGES[id][index]["cost"]: expected_spent[resource] += GoalCatalog.STAGES[id][index]["cost"][resource]
	for id in GoalCatalog.TRADE_IDS:
		for resource in GoalCatalog.TRADES[id]["cost"]: expected_spent[resource] += GoalCatalog.TRADES[id]["cost"][resource] * data["trades"][id]
	for resource in expected_spent:
		if expected_spent[resource] != data["spent"][resource]: return "长期目标用料账目不一致"
	if not CharacterState.integer(data["next_trade_day"], 4, maxi(4, ExpeditionState.day_at(seconds) + 2)): return "互助日期无效"
	for field in ["notes", "field_notes"]:
		if not data[field] is Array or data[field].size() > GoalCatalog.NOTE_IDS.size(): return "勘查记录无效"
		var checked: Array = []
		for key in data[field]:
			if not key is String or not GoalCatalog.NOTE_IDS.has(key) or checked.has(key): return "勘查记录重复或未知"
			if field == "field_notes" and (not expedition["active"] or data["notes"].has(key) or key.get_slice(":", 0) != location): return "随身记录与外出地点不符"
			checked.append(key)
	return ""
