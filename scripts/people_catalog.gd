class_name PeopleCatalog
extends RefCounted

const ORIGINALS := ["lin", "xu", "chen"]
const CANDIDATES := ["he", "gu", "tang"]
const MAX_LIVING := 5
const MAX_HISTORY := 6
const RECRUIT_COST := {"raw_food": 2, "water": 2, "medicine": 1}
const DATA := {
	"lin": {"name": "墨衡「钉钟人」", "role": "工匠", "tint": "9da88a", "bio": "隔离城最后的报时匠。执着、骄傲，失眠时仍在校准一只不会再响的钟。", "traits": "细致：工艺经验+20%；执拗：精神15以下时额外积累压力。", "day": 1},
	"xu": {"name": "闻人灯「白鸦」", "role": "医护", "tint": "9aaeb3", "bio": "签过封锁令的医生。说话克制，善于安抚，却不肯让最后一份急救药离开视线。", "traits": "镇静：失去队友时压力增量较低；牵挂：队伍受伤时更容易担忧。", "day": 1},
	"chen": {"name": "祁烬「灰犬」", "role": "搜寻者", "tint": "b39a86", "bio": "离开封锁队的追踪者。寡言、负罪，擅长反猎杀；巨响会让他想起不愿提及的夜晚。", "traits": "警觉：搜索+20%、脚步声−20%；独行超过两分钟后会缓慢积累压力。", "day": 1},
	"he": {"name": "祝九「铁锅女王」", "role": "厨师", "tint": "baa676", "bio": "曾拿铁锅守过粮仓的食堂领头人。豪爽护短，讨厌浪费，会记得谁分到最小的一碗。", "traits": "善炊：基础做饭5秒；易饿：饥饿增长+10%。", "day": 3},
	"gu": {"name": "纪无咎「缝骨师」", "role": "医护", "tint": "a799ba", "bio": "从法医转做救护的冷面医者。理性、刻薄、可靠，熟悉每道伤口，却正在学习如何安慰活人。", "traits": "耐心：照护经验+20%；体弱：非睡眠疲劳增长+10%。", "day": 6},
	"tang": {"name": "陆行舟「燕尾」", "role": "搜寻者", "tint": "91ac9d", "bio": "封锁线上的走私向导。爱开玩笑也爱逞强，留着一张没人来认领的车票。", "traits": "熟路：搜索+20%、脚步声−20%；敏感：受伤时压力增长较快。", "day": 9},
}


static func role(id: String) -> String:
	return DATA[id]["role"]
