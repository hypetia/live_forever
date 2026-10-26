class_name LocationCatalog
extends RefCounted
## Fixed original places. Each ExpeditionState owns a separate persistent world.

const IDS := ["street", "clinic", "works"]
const ALL_IDS := ["street", "clinic", "works", "residential", "market", "waterworks", "depot", "broadcast", "evac"]
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


const EXPANDED := {
	"residential": {
		"name": "积雪住宅",
		"summary": "楼内食物、布料与水；上层入口较早，空间狭窄。",
		"risk": "中等",
		"color": "363c43",
		"accent": "b4bec9",
		"width": 2300.0,
		"upper_left": 650.0,
		"ladder": 840.0,
		"sites": [
			{
				"name": "门房",
				"x": 320.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"water": 3,
					"materials": 2
				}
			},
			{
				"name": "厨房",
				"x": 950.0,
				"floor": 1,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"raw_food": 5,
					"fuel": 2
				}
			},
			{
				"name": "衣物柜",
				"x": 1370.0,
				"floor": 1,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"materials": 6
				}
			},
			{
				"name": "储藏室",
				"x": 1600.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"water": 4,
					"raw_food": 3
				}
			},
			{
				"name": "屋顶应急箱",
				"x": 2050.0,
				"floor": 1,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"medicine": 2,
					"tools": 1
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				1250,
				1370,
				0
			],
			[
				970,
				1090,
				1
			]
		],
		"guards": [
			[
				620,
				0,
				480,
				740,
				"walker"
			],
			[
				1420,
				1,
				1100,
				1700,
				"runner"
			],
			[
				1920,
				0,
				1740,
				2140,
				"walker"
			]
		],
		"extra": [
			1730,
			0,
			1470,
			2040,
			"runner"
		]
	},
	"market": {
		"name": "废弃集市",
		"summary": "电台标记的补给点；食物集中，感染者会沿摊位追踪声音。",
		"risk": "较高",
		"color": "343a2b",
		"accent": "d1af75",
		"width": 3000.0,
		"upper_left": 1500.0,
		"ladder": 1700.0,
		"sites": [
			{
				"name": "蔬果摊",
				"x": 350.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"raw_food": 5,
					"water": 2
				}
			},
			{
				"name": "罐头铺",
				"x": 900.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"raw_food": 6,
					"materials": 2
				}
			},
			{
				"name": "煤炭仓",
				"x": 1400.0,
				"floor": 0,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"fuel": 5
				}
			},
			{
				"name": "二楼商铺",
				"x": 1980.0,
				"floor": 1,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"water": 5,
					"medicine": 2
				}
			},
			{
				"name": "冷库",
				"x": 2700.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"raw_food": 7,
					"tools": 1
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				1950,
				2070,
				0
			],
			[
				1820,
				1940,
				1
			]
		],
		"guards": [
			[
				690,
				0,
				550,
				1100,
				"runner"
			],
			[
				2000,
				0,
				1700,
				2400,
				"brute"
			],
			[
				2300,
				1,
				1950,
				2750,
				"walker"
			]
		],
		"extra": [
			2430,
			0,
			2170,
			2740,
			"runner"
		]
	},
	"waterworks": {
		"name": "冻河净水厂",
		"summary": "净水滤芯在二楼控制室；地面冰冷，重型感染者把守。",
		"risk": "高",
		"color": "253b3d",
		"accent": "8fbeb6",
		"width": 3300.0,
		"upper_left": 1200.0,
		"ladder": 1450.0,
		"sites": [
			{
				"name": "门卫水箱",
				"x": 360.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"water": 6
				}
			},
			{
				"name": "药剂仓",
				"x": 1060.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"medicine": 3,
					"fuel": 3
				}
			},
			{
				"name": "维修平台",
				"x": 1770.0,
				"floor": 1,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"tools": 2,
					"materials": 4
				}
			},
			{
				"name": "控制室",
				"x": 2380.0,
				"floor": 1,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"water": 5,
					"materials": 3
				}
			},
			{
				"name": "蓄水池",
				"x": 3000.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"water": 8,
					"fuel": 2
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				2250,
				2370,
				0
			],
			[
				1520,
				1640,
				1
			]
		],
		"guards": [
			[
				840,
				0,
				650,
				1130,
				"walker"
			],
			[
				1990,
				0,
				1730,
				2250,
				"brute"
			],
			[
				2570,
				1,
				2100,
				3000,
				"runner"
			]
		],
		"extra": [
			2730,
			0,
			2470,
			3040,
			"runner"
		]
	},
	"depot": {
		"name": "北线货运站",
		"summary": "信标电池在调度楼。长距离暴露区，材料和燃料丰厚。",
		"risk": "高",
		"color": "3b3430",
		"accent": "c5a078",
		"width": 3800.0,
		"upper_left": 1850.0,
		"ladder": 2080.0,
		"sites": [
			{
				"name": "卸货区",
				"x": 390.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"materials": 5,
					"fuel": 3
				}
			},
			{
				"name": "油罐车",
				"x": 1130.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"fuel": 8
				}
			},
			{
				"name": "货车工具箱",
				"x": 1720.0,
				"floor": 0,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"tools": 3,
					"materials": 3
				}
			},
			{
				"name": "调度室",
				"x": 2730.0,
				"floor": 1,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"materials": 5,
					"medicine": 2
				}
			},
			{
				"name": "冷藏车",
				"x": 3460.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"raw_food": 6,
					"water": 5
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				2750,
				2870,
				0
			],
			[
				2170,
				2290,
				1
			]
		],
		"guards": [
			[
				900,
				0,
				650,
				1330,
				"runner"
			],
			[
				1950,
				0,
				1680,
				2300,
				"brute"
			],
			[
				3150,
				0,
				2810,
				3550,
				"brute"
			],
			[
				2860,
				1,
				2450,
				3550,
				"walker"
			]
		],
		"extra": [
			3230,
			0,
			2970,
			3540,
			"runner"
		]
	},
	"broadcast": {
		"name": "山顶广播站",
		"summary": "信标组件位于最远端机房；高处更冷，迅捷感染者游荡。",
		"risk": "极高",
		"color": "303043",
		"accent": "a6a9d1",
		"width": 3400.0,
		"upper_left": 1050.0,
		"ladder": 1330.0,
		"sites": [
			{
				"name": "山路补给箱",
				"x": 340.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"water": 4,
					"fuel": 3
				}
			},
			{
				"name": "值班室",
				"x": 1550.0,
				"floor": 1,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"raw_food": 4,
					"medicine": 3
				}
			},
			{
				"name": "电缆仓",
				"x": 2000.0,
				"floor": 0,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"materials": 7,
					"tools": 2
				}
			},
			{
				"name": "备用发电机",
				"x": 2590.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"fuel": 7
				}
			},
			{
				"name": "发射机房",
				"x": 3080.0,
				"floor": 1,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"tools": 2,
					"materials": 5
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				2350,
				2470,
				0
			],
			[
				1370,
				1490,
				1
			]
		],
		"guards": [
			[
				800,
				0,
				650,
				1110,
				"runner"
			],
			[
				1900,
				1,
				1700,
				2200,
				"runner"
			],
			[
				2760,
				1,
				2460,
				3180,
				"brute"
			],
			[
				2850,
				0,
				2400,
				3170,
				"walker"
			]
		],
		"extra": [
			2830,
			0,
			2570,
			3140,
			"runner"
		]
	},
	"evac": {
		"name": "南岸撤离码头",
		"summary": "最后一段路线：二楼信号室取回航路记录，务必活着返回入口。",
		"risk": "极高",
		"color": "26343a",
		"accent": "d1ba8e",
		"width": 4200.0,
		"upper_left": 2300.0,
		"ladder": 2550.0,
		"sites": [
			{
				"name": "渡口物资箱",
				"x": 360.0,
				"floor": 0,
				"seconds": 3.0,
				"locked": false,
				"items": {
					"water": 5,
					"raw_food": 4
				}
			},
			{
				"name": "船坞",
				"x": 1250.0,
				"floor": 0,
				"seconds": 4.0,
				"locked": false,
				"items": {
					"fuel": 7,
					"materials": 4
				}
			},
			{
				"name": "登船大厅",
				"x": 2100.0,
				"floor": 0,
				"seconds": 5.0,
				"locked": false,
				"items": {
					"medicine": 4,
					"water": 5
				}
			},
			{
				"name": "导航平台",
				"x": 3090.0,
				"floor": 1,
				"seconds": 3.0,
				"locked": true,
				"items": {
					"tools": 2,
					"fuel": 4
				}
			},
			{
				"name": "信号室",
				"x": 3850.0,
				"floor": 1,
				"seconds": 4.0,
				"locked": true,
				"items": {
					"medicine": 3,
					"raw_food": 4
				}
			}
		],
		"covers": [
			[
				480,
				580,
				0
			],
			[
				3150,
				3270,
				0
			],
			[
				2620,
				2740,
				1
			]
		],
		"guards": [
			[
				900,
				0,
				700,
				1400,
				"runner"
			],
			[
				1900,
				0,
				1640,
				2340,
				"brute"
			],
			[
				2910,
				0,
				2680,
				3400,
				"runner"
			],
			[
				3500,
				1,
				3200,
				3990,
				"brute"
			]
		],
		"extra": [
			3630,
			0,
			3370,
			3940,
			"runner"
		]
	}
}


static func area(id: String) -> Dictionary:
	return AREAS.get(id, EXPANDED.get(id, {}))


static func weather(day: int) -> Dictionary:
	match day % 4:
		2: return {"name": "细雨", "vision": 0.85, "hearing": 0.75, "hint": "雨声掩盖脚步，但搜索仍会引起注意。"}
		3: return {"name": "浓雾", "vision": 0.60, "hearing": 1.0, "hint": "视距缩短，听觉照常；不要依靠奔跑隐身。"}
		0: return {"name": "大风", "vision": 1.0, "hearing": 0.85, "hint": "风声略微掩盖动静，庇护所磨损更快。"}
		_: return {"name": "阴天", "vision": 1.0, "hearing": 1.0, "hint": "视线与听觉正常；先看巡逻方向。"}
