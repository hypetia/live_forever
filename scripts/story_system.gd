class_name StorySystem
extends RefCounted
## Optional authored moments and action-based guidance share the world save.

signal event_reported(message: String)
var next_poll := 0.0
var next_offer_day := 2
var pending: Dictionary = {}
var history: Array[Dictionary] = []
var guide: Array[String] = []
var guide_hidden := false


func note(action: String) -> void:
	if StoryCatalog.GUIDE_IDS.has(action) and not guide.has(action): guide.append(action)


func job_completed(task: String) -> void:
	if task in ["eat", "sleep"]: note(task)
	if task == "repair": note("maintain")


func guide_index() -> int:
	for index in range(StoryCatalog.GUIDE_IDS.size()):
		if not guide.has(StoryCatalog.GUIDE_IDS[index]): return index
	return -1


func hint(game: Node2D) -> String:
	if not pending.is_empty(): return "同伴想与你聊聊 · N故事与引导"
	if guide_hidden: return "N故事与引导 / P人物 / F6保存"
	if game.expedition.active:
		return "满包可点击丢弃；走回最左入口按T带回补给"
	var index := guide_index()
	return "引导%d/6：%s · 按N查看" % [index + 1, StoryCatalog.GUIDE_TITLES[index]] if index >= 0 else "新手目标已完成 · N故事与引导"


func tick(game: Node2D) -> void:
	if game.simulation_time + 0.000001 < next_poll: return
	next_poll = game.simulation_time + 1.0
	if game.upkeep.level > 0: note("maintain")
	if not pending.is_empty():
		if game.survivors[int(pending["actor"])].health <= 0 or game.survivors[int(pending["target"])].health <= 0:
			_finish(game, "lost", "未完成的谈话被记下。失去的同伴不会因此复活。")
		return
	var day := ExpeditionState.day_at(game.simulation_time)
	if game.expedition.active or game.game_over or day < next_offer_day: return
	for id in StoryCatalog.IDS:
		if history.any(func(entry): return entry["id"] == id): continue
		var pair := _eligible(game, id, day)
		if pair.is_empty(): continue
		pending = {"id": id, "actor": pair[0], "target": pair[1], "day": day}
		next_offer_day = day + 2
		event_reported.emit("%s · 同伴想与你聊聊。按N查看；不会自动扣料，没有限时惩罚。" % StoryCatalog.DATA[id]["title"])
		return


func _eligible(game: Node2D, id: String, day: int) -> Array:
	var definition: Dictionary = StoryCatalog.DATA[id]
	if day < int(definition["day"]): return []
	var living: Array = game.survivors.filter(func(a): return a.health > 0)
	if living.size() < 2: return []
	if id == "friction":
		for actor: Survivor in living:
			for other: Survivor in living:
				if actor.survivor_id < other.survivor_id and game.people.relationship(actor.survivor_id, other.survivor_id) <= 20 and (actor.person.stress >= 30 or other.person.stress >= 30): return [actor.survivor_id, other.survivor_id]
		return []
	if id == "remembrance":
		return [living[0].survivor_id, living[1].survivor_id] if not game.people.deaths.is_empty() else []
	for actor: Survivor in living:
		if actor.person.persona != definition["person"]: continue
		if actor.person.joined_day >= day: return []
		if id == "lin_radio" and actor.completed_by_task["craft"] == 0 and actor.completed_by_task["repair"] == 0: return []
		if id == "chen_lamp" and game.upkeep.returns.values().all(func(n): return n == 0): return []
		for other: Survivor in living:
			if actor != other: return [actor.survivor_id, other.survivor_id]
	return []


func choice_error(game: Node2D, paid: bool) -> String:
	if pending.is_empty(): return "目前没有待处理谈话"
	if game.expedition.active: return "请先带外出者回到基地"
	if game.game_over: return "队伍已经失守"
	if game.survivors[int(pending["actor"])].health <= 0 or game.survivors[int(pending["target"])].health <= 0: return "谈话中的同伴已不在，继续时间后会记下这件事"
	if paid and not game.inventory.can_take(StoryCatalog.DATA[pending["id"]]["cost"]): return "还缺" + game.inventory.missing_text(StoryCatalog.DATA[pending["id"]]["cost"])
	return ""


func resolve(game: Node2D, paid: bool) -> bool:
	if not choice_error(game, paid).is_empty(): return false
	var definition: Dictionary = StoryCatalog.DATA[pending["id"]]
	if paid and not game.inventory.try_take(definition["cost"], "同伴故事：" + definition["title"]): return false
	for index in [pending["actor"], pending["target"]]:
		var person: CharacterState = game.survivors[int(index)].person
		person.morale = minf(100, person.morale + (definition["morale"] if paid else 2))
		person.stress = maxf(0, person.stress + (definition["stress"] if paid else -3))
		person.trauma = maxf(0, person.trauma - (5 if paid else 1))
	var pair := "%d:%d" % [mini(pending["actor"], pending["target"]), maxi(pending["actor"], pending["target"])]
	game.people.bonds[pair] = mini(100, int(game.people.bonds[pair]) + (definition["trust"] if paid else 2))
	_finish(game, "a" if paid else "b", definition["result_a"] if paid else definition["result_b"])
	return true


func _finish(game: Node2D, outcome: String, text: String) -> void:
	history.append({"id": pending["id"], "actor": pending["actor"], "target": pending["target"], "day": ExpeditionState.day_at(game.simulation_time), "outcome": outcome})
	pending.clear()
	event_reported.emit(text)


func snapshot() -> Dictionary:
	return {"next_poll": next_poll, "next_offer_day": next_offer_day, "pending": pending.duplicate(), "history": history.duplicate(true), "guide": guide.duplicate(), "guide_hidden": guide_hidden}


func restore_validated(data: Dictionary) -> void:
	next_poll = float(data["next_poll"])
	next_offer_day = int(data["next_offer_day"])
	pending = data["pending"].duplicate()
	if not pending.is_empty():
		for field in ["actor", "target", "day"]: pending[field] = int(pending[field])
	history.clear()
	for entry in data["history"]:
		var normalized: Dictionary = entry.duplicate()
		for field in ["actor", "target", "day"]: normalized[field] = int(normalized[field])
		history.append(normalized)
	guide.clear()
	for action in data["guide"]: guide.append(action)
	guide_hidden = data["guide_hidden"]


static func validate(data: Variant, actors: Array, seconds: float) -> String:
	if not CharacterState.keys(data, ["next_poll", "next_offer_day", "pending", "history", "guide", "guide_hidden"]): return "故事与引导字段无效"
	var day := ExpeditionState.day_at(seconds)
	if not CharacterState.number(data["next_poll"], 0, seconds + 1.001) or not CharacterState.integer(data["next_offer_day"], 2, maxi(2, day + 2)): return "故事时钟无效"
	if not data["guide_hidden"] is bool or not data["guide"] is Array or data["guide"].size() > StoryCatalog.GUIDE_IDS.size(): return "新手引导无效"
	var seen: Array = []
	for action in data["guide"]:
		if not action is String or not StoryCatalog.GUIDE_IDS.has(action) or seen.has(action): return "引导目标重复或未知"
		seen.append(action)
	if not data["history"] is Array or data["history"].size() > StoryCatalog.IDS.size() or not data["pending"] is Dictionary: return "故事记录无效"
	seen.clear()
	var previous := 1
	for entry in data["history"]:
		var error := _entry_error(entry, actors, day, true)
		if not error.is_empty(): return error
		if seen.has(entry["id"]) or int(entry["day"]) < previous: return "故事记录重复或日期倒序"
		seen.append(entry["id"])
		previous = int(entry["day"])
	if not data["pending"].is_empty():
		var error := _entry_error(data["pending"], actors, day, false)
		if not error.is_empty(): return error
		if seen.has(data["pending"]["id"]) or int(data["pending"]["day"]) < previous or data["next_offer_day"] != int(data["pending"]["day"]) + 2: return "待处理故事已经完成或日期不符"
	return ""


static func _entry_error(entry: Variant, actors: Array, day: int, finished: bool) -> String:
	var fields := ["id", "actor", "target", "day"]
	if finished: fields.append("outcome")
	if not CharacterState.keys(entry, fields) or not entry["id"] is String or not StoryCatalog.DATA.has(entry["id"]): return "未知故事或字段无效"
	if not CharacterState.integer(entry["actor"], 0, actors.size() - 1) or not CharacterState.integer(entry["target"], 0, actors.size() - 1) or entry["actor"] == entry["target"]: return "故事参与者无效"
	var definition: Dictionary = StoryCatalog.DATA[entry["id"]]
	if not CharacterState.integer(entry["day"], definition["day"], day): return "故事日期无效"
	if not definition["person"].is_empty() and actors[int(entry["actor"])]["person"]["persona"] != definition["person"]: return "故事人物身份不符"
	for index in [entry["actor"], entry["target"]]:
		if int(actors[int(index)]["person"]["joined_day"]) > int(entry["day"]): return "故事日期早于成员加入"
	if finished and not entry["outcome"] in ["a", "b", "lost"]: return "故事选择无效"
	return ""
