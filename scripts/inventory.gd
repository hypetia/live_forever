class_name ShelterInventory
extends RefCounted
## Validate every entry before mutating any stock. Snapshots are copies.

signal changed

## The internal tools key represents consumable components; reusable tools are gear.
const NAMES := {"raw_food": "杂粮", "water": "水", "fuel": "燃料", "meals": "熟食", "materials": "材料", "tools": "机械零件", "medicine": "药品"}
var _stock := {"raw_food": 4, "water": 4, "fuel": 3, "meals": 0, "materials": 8, "tools": 0, "medicine": 1}
var history: Array[Dictionary] = []


func amount(resource: String) -> int:
	return _stock.get(resource, 0)


func snapshot() -> Dictionary:
	return _stock.duplicate()


func restore_validated(stock: Dictionary, transactions: Array) -> void:
	# SaveSystem validates the entire scene before calling this method.
	_stock.clear()
	for resource in NAMES:
		_stock[resource] = int(stock[resource])
	history.clear()
	for transaction: Dictionary in transactions:
		var restored := transaction.duplicate(true)
		for resource in restored["items"]:
			restored["items"][resource] = int(restored["items"][resource])
		history.append(restored)
	changed.emit()


func _valid(items: Dictionary) -> bool:
	for resource in items:
		if not _stock.has(resource) or not items[resource] is int or items[resource] < 0:
			return false
	return true


func can_take(cost: Dictionary) -> bool:
	if not _valid(cost):
		return false
	for resource in cost:
		if _stock[resource] < cost[resource]:
			return false
	return true


func try_take(cost: Dictionary, reason: String) -> bool:
	if not can_take(cost):
		return false
	for resource in cost:
		_stock[resource] -= cost[resource]
	_record("debit", cost, reason)
	return true


func deposit(items: Dictionary, reason: String) -> bool:
	if not _valid(items):
		return false
	for resource in items:
		_stock[resource] += items[resource]
	_record("credit", items, reason)
	return true


func missing_text(cost: Dictionary) -> String:
	var missing: Array[String] = []
	for resource in cost:
		var shortage: int = cost[resource] - amount(resource)
		if shortage > 0:
			missing.append("%s缺%d" % [NAMES.get(resource, resource), shortage])
	return "、".join(missing)


static func describe(items: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in items:
		parts.append("%s×%d" % [NAMES.get(resource, resource), items[resource]])
	return "、".join(parts) if not parts.is_empty() else "无"


func _record(kind: String, items: Dictionary, reason: String) -> void:
	if items.is_empty():
		return
	history.append({"kind": kind, "items": items.duplicate(), "reason": reason})
	if history.size() > 32:
		history.pop_front()
	changed.emit()
