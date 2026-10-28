class_name PeopleCatalog
extends RefCounted

const ORIGINALS := ["lin", "xu", "chen"]
const CANDIDATES := ["he", "gu", "tang"]
const MAX_LIVING := 5
const MAX_HISTORY := 6
const RECRUIT_COST := {"raw_food": 2, "water": 2, "medicine": 1}
const DATA := {
	"lin": {"reference":"托尼·斯塔克｜《钢铁侠》：工程天才、爱逞强，靠修理与制作帮助队伍。", "name": "斯塔克", "role": "工匠", "tint": "995747", "bio": "自信又爱逞强的工程师，习惯自己造工具、修设备。能解决技术难题，也常把休息排在最后。", "traits": "细致：工艺经验+20%；执拗：精神15以下时额外积累压力。", "day": 1},
	"xu": {"reference":"纲手｜《火影忍者》：擅长医疗，也能在近战中保护伤员。", "name": "纲手", "role": "医护", "tint": "77916d", "bio": "性格强硬的医生，能救治伤员，也能在近战中保护队伍。看到同伴受伤时比嘴上说的更在意。", "traits": "镇静：失去队友时压力增量较低；牵挂：队伍受伤时更容易担忧。", "day": 1},
	"chen": {"reference":"里昂·S·肯尼迪｜《生化危机》：冷静的感染区外勤，擅长近身作战与探索。", "name": "里昂", "role": "搜寻者", "tint": "64788b", "bio": "进入感染区寻找幸存者的前警员。习惯先观察再行动，擅长近战与探索；长时间独行会感到压力。", "traits": "警觉：搜索+20%、脚步声−20%；独行超过两分钟后会缓慢积累压力。", "day": 1},
	"he": {"reference":"山治｜《海贼王》：能打的厨师，食物紧缺时仍尽力照顾同伴。", "name": "山治", "role": "厨师", "tint": "46545f", "bio": "能打的餐馆厨师，擅长把有限食材做成更多份饭。嘴上不饶人，仍会照顾好同伴的餐食。", "traits": "善炊：基础做饭5秒；易饿：饥饿增长+10%。", "day": 3},
	"gu": {"reference":"华佗｜历史人物：精细照护与伤病处理，重视休养。", "name": "华佗", "role": "医护", "tint": "a69b80", "bio": "游走于聚居地的医生，擅长伤口、感染与疾病护理。体力较弱，重视工作后的休养。", "traits": "耐心：照护经验+20%；体弱：非睡眠疲劳增长+10%。", "day": 6},
	"tang": {"reference":"韦小宝｜《鹿鼎记》：善于交涉、找退路与随机应变。", "name": "韦小宝", "role": "搜寻者", "tint": "91ac9d", "bio": "靠交涉和机变穿过封锁线的向导。擅长交易、翻窗与恢复体力，知道什么时候该寻找退路。", "traits": "熟路：搜索+20%、脚步声−20%；敏感：受伤时压力增长较快。", "day": 9},
}


static func role(id: String) -> String:
	return DATA[id]["role"]
