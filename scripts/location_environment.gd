class_name LocationEnvironment
extends RefCounted
## Original map identities and physical route/surface rules. No borrowed assets.
# Rooms are cutaways with open doorways; only the explicit low covers obstruct combat.
const MAPS := {
 "street": {"route":2250.0,"route_kind":"escape","route_name":"后巷消防梯","tool_time":3.0,"force_time":10.0,"conditions":["雨后旧街","碎玻璃街面"],"containers":["crate","shelf","barrel","cabinet","toolbox","cabinet"],"rooms":[[160,1010,0,"shop"],[1250,1830,1,"flat"],[1830,2480,1,"store"]],"zones":[[620,840,0,"water",0],[940,1160,0,"glass",1],[1940,2150,1,"glass",-1]]},
 "clinic": {"route":2110.0,"route_kind":"escape","route_name":"病房外消防梯","tool_time":3.0,"force_time":11.0,"conditions":["漏水门诊","破窗病房"],"containers":["tank","cabinet","shelf","cabinet","locker","cabinet"],"rooms":[[160,1010,0,"waiting"],[1050,1790,1,"ward"],[1790,2480,1,"pharmacy"],[1500,2480,0,"ward"]],"zones":[[690,980,0,"water",0],[1310,1540,1,"glass",1],[1840,2060,1,"glass",-1]]},
 "works": {"route":2440.0,"route_kind":"service","route_name":"维修栈梯","tool_time":4.0,"force_time":12.0,"conditions":["停机积油","散落铁屑"],"containers":["locker","toolbox","barrel","locker","shelf","cabinet"],"rooms":[[160,870,0,"workshop"],[900,1830,1,"office"],[1830,2880,1,"canteen"],[1190,2880,0,"machine"]],"zones":[[1130,1430,0,"oil",0],[1830,2160,0,"metal",1],[2470,2710,0,"metal",-1]]},
 "residential": {"route":1960.0,"route_kind":"escape","route_name":"天井消防梯","tool_time":3.0,"force_time":10.0,"conditions":["天井积雪","破窗寒屋"],"containers":["locker","shelf","locker","crate","cabinet"],"rooms":[[160,620,0,"hall"],[650,1190,1,"kitchen"],[1190,1680,1,"flat"],[1680,2180,1,"bedroom"],[1150,2180,0,"flat"]],"zones":[[550,810,0,"snow",0],[1460,1730,1,"glass",1],[1770,2000,0,"snow",-1]]},
 "market": {"route":2460.0,"route_kind":"shutter","route_name":"后仓货梯","tool_time":4.0,"force_time":12.0,"conditions":["雨后集市","倾倒货架"],"containers":["stall","shelf","barrel","shelf","freezer"],"rooms":[[160,1100,0,"stalls"],[1500,2280,1,"store"],[2280,2880,1,"store"],[2380,2880,0,"coldroom"]],"zones":[[570,830,0,"water",0],[1110,1410,0,"glass",1],[1720,2010,0,"metal",-1]]},
 "waterworks": {"route":2780.0,"route_kind":"service","route_name":"管线检修梯","tool_time":4.0,"force_time":13.0,"conditions":["管线渗漏","冰封阀门"],"containers":["tank","cabinet","toolbox","console","tank"],"rooms":[[160,1100,0,"pump"],[1200,2080,1,"pipe"],[2080,3180,1,"control"],[1500,3180,0,"pump"]],"zones":[[670,1020,0,"water",0],[1440,1780,0,"snow",1],[2220,2580,0,"water",-1]]},
 "depot": {"route":3200.0,"route_kind":"service","route_name":"货场检修梯","tool_time":4.0,"force_time":13.0,"conditions":["雨后铁轨","散落货物"],"containers":["crate","barrel","toolbox","console","freezer"],"rooms":[[1850,2640,1,"office"],[2640,3680,1,"control"],[160,650,0,"store"]],"zones":[[670,1050,0,"water",0],[1420,1780,0,"metal",1],[2390,2810,0,"metal",-1]]},
 "broadcast": {"route":2870.0,"route_kind":"escape","route_name":"天线维护梯","tool_time":4.0,"force_time":13.0,"conditions":["山路积雪","机房碎玻璃"],"containers":["crate","locker","shelf","barrel","console"],"rooms":[[1050,1840,1,"office"],[1840,2480,1,"server"],[2480,3280,1,"server"],[1720,2800,0,"generator"]],"zones":[[560,920,0,"snow",0],[1690,1930,1,"glass",1],[2660,3000,1,"metal",-1]]},
 "evac": {"route":3590.0,"route_kind":"shutter","route_name":"码头应急梯","tool_time":5.0,"force_time":14.0,"conditions":["涨潮湿码头","散落缆绳"],"containers":["crate","barrel","locker","toolbox","console"],"rooms":[[1540,2280,0,"waiting"],[2300,3180,1,"control"],[3180,4080,1,"control"],[160,700,0,"store"]],"zones":[[750,1160,0,"water",0],[1450,1810,0,"metal",1],[2720,3070,0,"water",-1]]}
}
const SURFACES := {
 "glass":{"pace":0.92,"noise":1.75,"quiet":1.12,"color":"a4b8b7"},
 "water":{"pace":0.70,"noise":1.45,"quiet":1.08,"color":"628d9b"},
 "oil":{"pace":0.78,"noise":1.1,"quiet":1.0,"color":"7c7658"},
 "metal":{"pace":0.90,"noise":1.65,"quiet":1.1,"color":"a7987b"},
 "snow":{"pace":0.82,"noise":0.65,"quiet":0.65,"color":"b4c3c9"}
}
static func profile(id: String) -> Dictionary:
 return MAPS[id]
static func zones(id: String, condition: int) -> Array:
 return MAPS[id]["zones"].filter(func(z: Array): return int(z[4]) == -1 or int(z[4]) == condition)
static func surface(id: String, condition: int, x: float, level: int) -> Dictionary:
 for z: Array in zones(id,condition):
  if level == int(z[2]) and x >= float(z[0]) and x <= float(z[1]): return SURFACES[z[3]]
 return {"pace":1.0,"noise":1.0,"quiet":1.0}
static func route_seconds(id: String, tool: bool) -> float:
 return float(MAPS[id]["tool_time"] if tool else MAPS[id]["force_time"])
static func route_hint(id: String) -> String:
 var p: Dictionary = MAPS[id]
 return "%s：工具1件 / %.0f秒；徒手清障%.0f秒、动静大。" % [p["route_name"],p["tool_time"],p["force_time"]]

const BRIEFS := {
 "street":"食物与水 · 街面积水 / 碎玻璃",
 "clinic":"药品 · 漏水门诊 / 破窗病房",
 "works":"材料燃料 · 油污 / 金属杂物",
 "residential":"食物布料 · 积雪 / 狭窄房间",
 "market":"食物集中 · 连片摊位 / 后仓货梯",
 "waterworks":"水与滤芯 · 涉水慢行 / 管线检修梯",
 "depot":"燃料电池 · 暴露铁轨 / 货场检修梯",
 "broadcast":"信标组件 · 积雪山路 / 维护梯",
 "evac":"航路记录 · 湿滑船坞 / 码头应急梯"
}
