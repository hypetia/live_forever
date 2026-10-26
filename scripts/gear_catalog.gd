class_name GearCatalog
extends RefCounted
## Original balance, not a transcription of another game's item data.
const ITEMS := {
	"knife": {"name": "猎刀", "slot": "weapon", "cost": {"materials": 2}, "seconds": 16.0, "damage": 18, "reach": 70.0, "cooldown": 0.7, "windup": 0.16, "durability": 60, "wear": 2},
	"bat": {"name": "钉棒", "slot": "weapon", "cost": {"materials": 3}, "seconds": 22.0, "damage": 26, "reach": 88.0, "cooldown": 1.0, "windup": 0.26, "durability": 96, "wear": 3},
	"spear": {"name": "铁矛", "slot": "weapon", "cost": {"materials": 4, "tools": 1}, "seconds": 28.0, "damage": 30, "reach": 125.0, "cooldown": 1.15, "windup": 0.3, "durability": 100, "wear": 3},
	"pistol": {"name": "修复手枪", "slot": "weapon", "cost": {"materials": 6, "tools": 2}, "seconds": 40.0, "damage": 32, "reach": 370.0, "cooldown": 0.65, "windup": 0.12, "durability": 100, "wear": 1, "magazine": 6},
	"padding": {"name": "夹层护甲", "slot": "armor", "cost": {"materials": 3, "fuel": 1}, "seconds": 24.0, "protection": 0.25, "warmth": 3.0, "durability": 80},
	"vest": {"name": "防咬背心", "slot": "armor", "cost": {"materials": 6, "tools": 1}, "seconds": 34.0, "protection": 0.5, "warmth": 1.0, "durability": 100},
	"coat": {"name": "厚冬衣", "slot": "coat", "cost": {"materials": 4, "fuel": 1}, "seconds": 28.0, "warmth": 16.0, "durability": 100},
}
const PROJECTS := {
	"ammo": {"name": "弹药8发", "cost": {"materials": 1, "fuel": 1}, "seconds": 18.0},
	"radio": {"name": "修复电台", "cost": {"materials": 4, "tools": 1}, "part": "relay", "seconds": 38.0},
	"pump": {"name": "修复净水泵", "cost": {"materials": 5, "tools": 1}, "part": "filter_core", "seconds": 42.0},
	"beacon": {"name": "组装撤离信标", "cost": {"materials": 6, "tools": 2}, "part": "beacon_core", "seconds": 48.0},
}
const PARTS := {
	"relay": {"name": "电台继电器", "map": "works", "site": 1},
	"filter_core": {"name": "净水滤芯", "map": "waterworks", "site": 3},
	"power_cell": {"name": "信标电池", "map": "depot", "site": 3},
	"beacon_core": {"name": "信标组件", "map": "broadcast", "site": 4},
	"route": {"name": "撤离航路记录", "map": "evac", "site": 4},
}

static func recipe(id: String) -> Dictionary:
	return ITEMS.get(id, PROJECTS.get(id, ResidenceSystem.PROJECTS.get(id, FacilitySystem.RECIPES.get(id, {}))))

static func describe(kind: String) -> String:
	var item: Dictionary = ITEMS[kind]
	if item["slot"] == "weapon": return "伤害%d / 距离%d / 间隔%.2f秒%s" % [item["damage"], item["reach"], item["cooldown"], " / 六发弹匣，L换弹" if item.has("magazine") else " / 命中磨损"]
	return "防咬%d%% / 保暖+%d℃" % [roundi(float(item.get("protection", 0)) * 100), item.get("warmth", 0)]
