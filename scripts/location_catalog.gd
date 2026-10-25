class_name LocationCatalog
extends RefCounted
## Fixed original places. Each ExpeditionState owns a separate persistent world.

const IDS := ["street", "clinic", "works"]
const STREET_SITES := [
	{"name": "街口杂物箱", "x": 300.0, "floor": 0, "seconds": 2.0, "locked": false, "items": {"raw_food": 2, "water": 1}},
	{"name": "小卖部货架", "x": 760.0, "floor": 0, "seconds": 3.0, "locked": false, "items": {"raw_food": 3, "water": 2}},
	{"name": "油料柜", "x": 1200.0, "floor": 0, "seconds": 4.0, "locked": true, "items": {"fuel": 3, "materials": 2}},
	{"name": "楼梯间药箱", "x": 1620.0, "floor": 1, "seconds": 3.0, "locked": false, "items": {"medicine": 2}},
	{"name": "仓库工具柜", "x": 2080.0, "floor": 0, "seconds": 5.0, "locked": true, "items": {"materials": 4, "fuel": 2}},
	{"name": "病房药柜", "x": 2240.0, "floor": 1, "seconds": 4.0, "locked": false, "items": {"medicine": 3, "raw_food": 1}},
]
const AREAS := {
	"street": {
		"name": "河湾旧街", "summary": "食物与水较多，适合首次外出；油料柜需要破锁。", "risk": "较低", "color": "273330", "accent": "bd9b64",
		"width": 2600.0, "upper_left": 1250.0, "ladder": 1480.0,
		"sites": STREET_SITES,
		"covers": [[420, 525, 0], [980, 1120, 0], [1680, 1785, 1]],
		"guards": [[900.0, 0, 650.0, 1080.0], [1900.0, 0, 1690.0, 2190.0], [1840.0, 1, 1720.0, 2370.0]],
		"extra": [1320.0, 0, 1110.0, 1440.0],
	},
	"clinic": {
		"name": "雨杉诊所", "summary": "药品集中在二楼；楼梯较近，走廊巡逻密集。", "risk": "中等", "color": "29383e", "accent": "8fb8b8",
		"width": 2600.0, "upper_left": 1050.0, "ladder": 1280.0,
		"sites": [
			{"name": "门诊饮水箱", "x": 360.0, "floor": 0, "seconds": 3.0, "locked": false, "items": {"water": 3}},
			{"name": "分诊储物柜", "x": 830.0, "floor": 0, "seconds": 4.0, "locked": false, "items": {"medicine": 1, "materials": 2}},
			{"name": "处置室药架", "x": 1450.0, "floor": 1, "seconds": 4.0, "locked": false, "items": {"medicine": 3}},
			{"name": "配药室锁柜", "x": 2000.0, "floor": 1, "seconds": 5.0, "locked": true, "items": {"medicine": 4, "tools": 1}},
			{"name": "值班室", "x": 2290.0, "floor": 0, "seconds": 4.0, "locked": false, "items": {"raw_food": 2, "fuel": 2}},
			{"name": "病房储物箱", "x": 2350.0, "floor": 1, "seconds": 5.0, "locked": false, "items": {"water": 2, "materials": 3}},
		],
		"covers": [[500, 620, 0], [1500, 1640, 0], [1590, 1710, 1], [2180, 2280, 1]],
		"guards": [[990.0, 0, 690.0, 1500.0], [1750.0, 1, 1420.0, 1980.0], [2300.0, 1, 2070.0, 2430.0]],
		"extra": [1980.0, 0, 1770.0, 2340.0],
	},
	"works": {
		"name": "北堤机修厂", "summary": "材料、燃料与工具丰富；厂区更长，地面巡逻较多。", "risk": "较高", "color": "3c332c", "accent": "c59d72",
		"width": 3000.0, "upper_left": 900.0, "ladder": 1120.0,
		"sites": [
			{"name": "收发室", "x": 340.0, "floor": 0, "seconds": 3.0, "locked": false, "items": {"materials": 3, "fuel": 1}},
			{"name": "维修工具台", "x": 1380.0, "floor": 1, "seconds": 4.0, "locked": false, "items": {"tools": 2, "materials": 2}},
			{"name": "油桶区", "x": 1720.0, "floor": 0, "seconds": 5.0, "locked": true, "items": {"fuel": 5, "materials": 2}},
			{"name": "工人休息室", "x": 2040.0, "floor": 1, "seconds": 4.0, "locked": false, "items": {"raw_food": 2, "water": 3}},
			{"name": "备件仓", "x": 2570.0, "floor": 0, "seconds": 5.0, "locked": true, "items": {"materials": 6, "tools": 1}},
			{"name": "应急柜", "x": 2770.0, "floor": 1, "seconds": 4.0, "locked": false, "items": {"medicine": 2, "fuel": 2}},
		],
		"covers": [[470, 590, 0], [1210, 1350, 0], [2160, 2320, 0], [1550, 1690, 1], [2390, 2500, 1]],
		"guards": [[850.0, 0, 660.0, 1060.0], [1940.0, 0, 1620.0, 2220.0], [2650.0, 0, 2370.0, 2880.0], [2200.0, 1, 1750.0, 2760.0]],
		"extra": [1440.0, 1, 1240.0, 1700.0],
	},
}


static func area(id: String) -> Dictionary:
	return AREAS[id]


static func weather(day: int) -> Dictionary:
	match day % 4:
		2: return {"name": "细雨", "vision": 0.85, "hearing": 0.75, "hint": "雨声掩盖脚步，但搜索仍会引起注意。"}
		3: return {"name": "浓雾", "vision": 0.60, "hearing": 1.0, "hint": "视距缩短，听觉照常；不要依靠奔跑隐身。"}
		0: return {"name": "大风", "vision": 1.0, "hearing": 0.85, "hint": "风声略微掩盖动静，庇护所磨损更快。"}
		_: return {"name": "阴天", "vision": 1.0, "hearing": 1.0, "hint": "视线与听觉正常；先看巡逻方向。"}
