class_name BackpackStacks
extends RefCounted
## Physical units stay authoritative; slots are derived, never saved as duplicates.
const LIMITS := {"raw_food":4,"water":4,"fuel":4,"meals":4,"materials":8,"tools":1,"medicine":2}
const AMMO_LIMIT := 8

static func limit(resource: String, stacked: bool = true) -> int:
	return int(LIMITS.get(resource,1)) if stacked else 1

static func slots(items: Dictionary, stacked: bool = true) -> int:
	var total := 0
	for key in items: total += ceili(int(items[key])/float(limit(key,stacked)))
	return total

static func room(items: Dictionary, resource: String, capacity: int, extra: int = 0, stacked: bool = true) -> int:
	var used := slots(items,stacked)+extra
	if used > capacity: return 0
	var per_slot := limit(resource,stacked)
	var count := int(items.get(resource,0))
	var partial := (per_slot-count%per_slot)%per_slot
	return maxi(0,capacity-used)*per_slot+partial

static func entries(items: Dictionary, stacked: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ShelterInventory.NAMES:
		var remaining := int(items.get(key,0))
		while remaining > 0:
			var count := mini(remaining,limit(key,stacked))
			result.append({"kind":"resource","key":key,"count":count,"limit":limit(key,stacked)})
			remaining -= count
	return result

static func carried(field: ExpeditionState, actor: Survivor, parts: Array) -> Array[Dictionary]:
	var result := entries(field.bag,field.stacked)
	for item in [actor.weapon_item,actor.armor_item]:
		if not item.is_empty(): result.append({"kind":"gear","key":item["kind"],"count":1,"limit":1,"durability":item["durability"]})
	var rounds := field.reserve_ammo+field.magazine
	while rounds > 0:
		var count := mini(rounds,AMMO_LIMIT)
		result.append({"kind":"ammo","key":"ammo","count":count,"limit":AMMO_LIMIT})
		rounds -= count
	if field.carrying_person:
		for index in range(2):result.append({"kind":"rescue","key":"rescue","count":1,"limit":1})
	for key in parts: result.append({"kind":"part","key":key,"count":1,"limit":1})
	return result
