class_name GoalCatalog
extends RefCounted
## Optional projects spend real surplus; completion never ends the campaign.

const IDS := ["radio", "clinic", "network"]
const NAMES := {"radio": "恢复通讯", "clinic": "建立救护点", "network": "连接补给线"}
const STAGES := {
	"radio": [
		{"title": "找回线路图", "hint": "搜查北堤机修厂二楼的维修工具台，并带着净补给返回。", "cost": {}, "note": "works:1", "level": 0, "day": 1},
		{"title": "架起天线", "hint": "据点达到2级，用备件、工具和燃料架起天线。", "cost": {"materials": 8, "tools": 2, "fuel": 2}, "note": "", "level": 2, "day": 1},
		{"title": "发出第一声呼叫", "hint": "第10天起，带回河湾旧街仓库工具柜的勘查记录，再接通电源。", "cost": {"materials": 6, "fuel": 3}, "note": "street:4", "level": 2, "day": 10},
	],
	"clinic": [
		{"title": "查清救护物资", "hint": "搜查雨杉诊所二楼的处置室药架，带回净补给；队伍完成过一次进食、休息或治疗。", "cost": {}, "note": "clinic:2", "level": 0, "day": 1},
		{"title": "备好救护角", "hint": "据点达到1级，留出真正的药品、饮水和材料。", "cost": {"materials": 4, "medicine": 4, "water": 2}, "note": "", "level": 1, "day": 1},
		{"title": "接上邻街救护站", "hint": "第12天起，队伍累计完成三次基地照料（进食、休息或治疗），送出救护补给。", "cost": {"medicine": 6, "raw_food": 4}, "note": "", "level": 1, "day": 12},
	],
	"network": [
		{"title": "走通三个街区", "hint": "分别从旧街、诊所和机修厂带回净补给。原装备往返不算。", "cost": {}, "note": "", "level": 0, "day": 1},
		{"title": "备好接应物资", "hint": "据点达到2级，准备工具、饮水和修路材料。", "cost": {"materials": 6, "tools": 1, "water": 2}, "note": "", "level": 2, "day": 1},
		{"title": "约定下一次接应", "hint": "第14天起，据点达到3级，并完成通讯或救护路线，再送出第一批接应物资。", "cost": {"materials": 6, "medicine": 3}, "note": "", "level": 3, "day": 14},
	],
}
const TRADE_IDS := ["medicine", "materials", "convoy"]
const TRADES := {
	"medicine": {"title": "药品换口粮", "cost": {"medicine": 2}, "output": {"raw_food": 3, "water": 2}, "project": ""},
	"materials": {"title": "备件换补给", "cost": {"materials": 4}, "output": {"water": 3, "fuel": 1}, "project": ""},
	"convoy": {"title": "补给线接应", "cost": {"materials": 4, "medicine": 2}, "output": {"raw_food": 4, "water": 3, "fuel": 2}, "project": "network"},
}
const NOTE_IDS := ["works:1", "street:4", "clinic:2"]
