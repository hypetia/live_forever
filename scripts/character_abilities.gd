class_name CharacterAbilities
extends RefCounted
## Stable identities, independent of learned experience. Presentation and rules share this table.
const PROFILES := {
	"lin": {"melee": 1.0, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "工匠：制作与修整更快，工艺经验+20%。"},
	"xu": {"melee": 0.9, "sleep": 1.0, "recovery": 1.0, "music": 1.6, "hint": "医护：治疗更快，援助同伴多恢复10生命；擅长吉他，安抚效果+60%。"},
	"chen": {"melee": 1.4, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "潜行与近战：搜索+20%、脚步声−20%、近战伤害+40%；背后突袭另有加成。"},
	"he": {"melee": 0.95, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "节俭厨师：相同原料做出3份熟食（其他人2份），耗时5秒；自身进食需求+10%。"},
	"gu": {"melee": 0.85, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "精细护理：治疗与援助额外减少15伤势、10疾病，照护经验+20%；体力消耗稍高。"},
	"tang": {"melee": 1.15, "sleep": 1.25, "recovery": 1.5, "music": 1.0, "hint": "耐力与交涉：睡眠恢复+25%、合适休息时小伤恢复+50%；邻里交换额外得到水1、燃料1。"},
}

static func factor(actor: Survivor, key: String) -> float:
	return float(PROFILES[actor.person.persona].get(key, 1.0)) if actor.metabolism < 1 else 1.0

static func description(persona: String) -> String:
	var field: String = {"lin":"前哨施工快20%；机修厂、货运站轮值多回收材料1。","xu":"诊所轮值多回收药品1。","chen":"前哨轮值引起的街区压力较低。","he":"旧街、集市、住宅轮值多回收生食1。","gu":"诊所轮值多回收药品1。","tang":"前哨轮值多带回水1。"}[persona]
	return PROFILES[persona]["hint"]+"\n"+field

static func cooking_output(actor: Survivor) -> Dictionary:
	return {"meals": 3 if actor.metabolism < 1 and actor.person.persona == "he" else 2}

static func melee_damage(actor: Survivor, base: int, ambush: bool) -> int:
	return maxi(1, roundi(base * factor(actor, "melee") * (1.8 if ambush else 1.0)))
