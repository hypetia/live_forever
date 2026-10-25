class_name PeopleCatalog
extends RefCounted

const ORIGINALS := ["lin", "xu", "chen"]
const CANDIDATES := ["he", "gu", "tang"]
const MAX_LIVING := 5
const MAX_HISTORY := 6
const RECRUIT_COST := {"raw_food": 2, "water": 2, "medicine": 1}
const DATA := {
	"lin": {"name": "林舟", "role": "工匠", "tint": "9da88a", "bio": "曾修理收音机的人。手稳，也很难放下没做完的活。", "traits": "细致：工艺经验+20%；执拗：疲劳85以上时额外积累压力。", "day": 1},
	"xu": {"name": "许遥", "role": "医护", "tint": "9aaeb3", "bio": "习惯在忙乱中保持冷静。能照顾别人，也需要有人照顾她。", "traits": "镇静：失去队友时压力增量较低；牵挂：队伍受伤时更容易担忧。", "day": 1},
	"chen": {"name": "陈野", "role": "搜寻者", "tint": "b39a86", "bio": "总会先看一眼门外。熟悉街巷，却不愿让同伴等得太久。", "traits": "警觉：搜索+20%、脚步声−20%；独行超过两分钟后会缓慢积累压力。", "day": 1},
	"he": {"name": "沈禾", "role": "厨师", "tint": "baa676", "bio": "带着一只旧饭盒来敲门。她愿意做饭，前提是桌边能多留一个位置。", "traits": "善炊：基础做饭5秒；易饿：饥饿增长+10%。", "day": 3},
	"gu": {"name": "顾苒", "role": "医护", "tint": "a799ba", "bio": "从临时救护站离开，仍保留着给每份药写标签的习惯。", "traits": "耐心：照护经验+20%；体弱：非睡眠疲劳增长+10%。", "day": 6},
	"tang": {"name": "唐弥", "role": "搜寻者", "tint": "91ac9d", "bio": "过去沿河送货。记路很快，见到血时却需要一点时间平静。", "traits": "熟路：搜索+20%、脚步声−20%；敏感：受伤时压力增长较快。", "day": 9},
}


static func role(id: String) -> String:
	return DATA[id]["role"]
