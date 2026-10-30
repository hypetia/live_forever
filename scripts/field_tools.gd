class_name FieldTools
extends RefCounted
## Field equipment is separate from consumable mechanical components.
const WEAR := {"lock":8,"window":8,"route":12,"build":6,"repair":4}

static func can_use(actor: Survivor, purpose: String) -> bool:
	return usable(actor.tool_item,purpose)

static func usable(item: Dictionary,purpose: String) -> bool:
	return int(item.get("durability",0))>0 and (item.get("kind","")=="toolkit" or (purpose=="lock" and item.get("kind","")=="lockpick"))

static func spend(actor: Survivor,purpose: String) -> void:
	if not can_use(actor,purpose):return
	var item:Dictionary=actor.tool_item
	item["durability"]=maxi(0,int(item["durability"])-(1 if item["kind"]=="lockpick" else int(WEAR[purpose])))
	var game:Node=actor.get_parent().get_parent() if is_instance_valid(actor.get_parent()) else null
	if item["kind"]=="lockpick":
		if is_instance_valid(game) and "expansion" in game:game.expansion.gear.erase(item)
		actor.tool_item={}
	if is_instance_valid(game) and game.has_method("expansion_snapshot"):
		game.expansion.refresh_slots(game.expedition,actor)
		game.expedition_view.queue_redraw()
