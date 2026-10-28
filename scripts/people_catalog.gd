class_name PeopleCatalog
extends RefCounted

const ORIGINALS := ["lin", "xu", "chen"]
const CANDIDATES := ["he", "gu", "tang"]
const MAX_LIVING := 5
const MAX_HISTORY := 6
const RECRUIT_COST := {"raw_food": 2, "water": 2, "medicine": 1}
const DATA := {
	"lin": {"reference":"托尼·斯塔克｜《钢铁侠》：工程天才、爱逞强，靠修理与制作帮助队伍。", "name": "斯塔克", "role": "工匠", "tint": "995747", "bio": "自信又爱逞强的工程师，习惯自己造工具、修设备。能解决技术难题，也常把休息排在最后。", "traits": "细致：工艺经验+20%；执拗：精神15以下时额外积累压力。", "day": 1},
	"xu": {"reference":"白求恩｜历史人物：专注救治、负责可靠，优先照顾受伤的同伴。", "name": "白求恩", "role": "医护", "tint": "b6c1bd", "bio": "负责的前线医生，习惯先稳定伤员再处理其他事。善于安抚同伴，也会为队伍的伤病担心。", "traits": "镇静：失去队友时压力增量较低；牵挂：队伍受伤时更容易担忧。", "day": 1},
	"chen": {"reference":"里昂·S·肯尼迪｜《生化危机》：冷静的感染区外勤，擅长近身作战与探索。", "name": "里昂", "role": "搜寻者", "tint": "64788b", "bio": "进入感染区寻找幸存者的前警员。习惯先观察再行动，擅长近战与探索；长时间独行会感到压力。", "traits": "警觉：搜索+20%、脚步声−20%；独行超过两分钟后会缓慢积累压力。", "day": 1},
	"he": {"reference":"小当家｜《中华小当家》：专注烹饪，用有限食材为同伴做好饭。", "name": "小当家", "role": "厨师", "tint": "adb7bd", "bio": "热爱烹饪的年轻厨师，擅长把有限食材做成更多份饭。乐观认真，重视每个人都能吃上一顿热饭。", "traits": "善炊：基础做饭5秒；易饿：饥饿增长+10%。", "day": 3},
	"gu": {"reference":"华佗｜历史人物：精细照护与伤病处理，重视休养。", "name": "华佗", "role": "医护", "tint": "a69b80", "bio": "游走于聚居地的医生，擅长伤口、感染与疾病护理。体力较弱，重视工作后的休养。", "traits": "耐心：照护经验+20%；体弱：非睡眠疲劳增长+10%。", "day": 6},
	"tang": {"reference":"杰克·斯派罗｜《加勒比海盗》：机敏、善于交涉，擅长寻找退路。", "name": "杰克船长", "role": "搜寻者", "tint": "76634c", "bio": "爱冒险的船长，靠交涉和机变穿过封锁线。擅长交易、翻窗与寻找退路，受伤时也会紧张。", "traits": "熟路：搜索+20%、脚步声−20%；敏感：受伤时压力增长较快。", "day": 9},
}


static func role(id: String) -> String:
	return DATA[id]["role"]
