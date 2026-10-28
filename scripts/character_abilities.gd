class_name CharacterAbilities
extends RefCounted
## Stable identities, independent of learned experience. Presentation and rules share this table.
const PROFILES := {
	"lin": {"door":1.25,"melee": 1.0, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "工匠：制作与修整更快，工艺经验+20%。"},
	"xu": {"melee": 1.25, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "战地急救与护卫：治疗更快，援助同伴多恢复10生命；近战伤害+25%。"},
	"chen": {"melee": 1.4, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "潜行与近战：搜索+20%、脚步声−20%、近战伤害+40%；背后突袭另有加成。"},
	"he": {"melee": 0.95, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "专注烹饪：相同原料做出3份熟食（其他人2份），耗时5秒；自身进食需求+10%。"},
	"gu": {"melee": 0.85, "sleep": 1.0, "recovery": 1.0, "music": 1.0, "hint": "精细护理：治疗与援助额外减少15伤势、10疾病，照护经验+20%；体力消耗稍高。"},
	"tang": {"door":1.4,"melee": 1.15, "sleep": 1.25, "recovery": 1.5, "music": 1.0, "hint": "耐力与交涉：睡眠恢复+25%、合适休息时小伤恢复+50%；邻里交换额外得到水1、燃料1。"},
	"lara": {"door":1.4,"melee":1.0,"hint":"探索：搜索+20%、脚步声−20%；门窗效率+40%；背包16格。"},
	"joel": {"melee":1.3,"work":1.1,"music":1.6,"hint":"护送：近战伤害+30%；制作效率额外+10%；吉他安抚+60%。"},
	"ellie": {"melee":1.1,"noise":0.8,"hint":"潜行：搜索+20%；在搜寻者低噪声基础上脚步声再−20%；近战伤害+10%。"},
	"jill": {"melee":1.2,"door":1.2,"hint":"突入：搜索+20%、脚步声−20%；近战伤害+20%，门窗效率+20%。"},
	"liu": {"work":1.2,"recovery":1.15,"hint":"工程：制作效率额外+20%；合适休息时生命与小伤恢复+15%；背包14格。"},
	"wick": {"melee":1.5,"noise":1.2,"hint":"近身战：近战伤害+50%，搜索+20%；脚步声比普通搜寻者高20%，背包12格。"},
}

static func factor(actor: Survivor, key: String) -> float:
	var value := float(PROFILES[actor.person.persona].get(key, 1.0)) if actor.metabolism < 1 else 1.0
	if actor.metabolism < 1 and is_instance_valid(actor.get_parent()) and is_instance_valid(actor.get_parent().get_parent()):
		var game := actor.get_parent().get_parent()
		if game.has_method("chronicle_snapshot"): value *= game.chronicle.perk(actor.person.persona,key)
	return value

static func description(persona: String) -> String:
	var field: String = {"lin":"前哨施工快20%；机修厂、货运站轮值多回收材料1。","xu":"诊所轮值多回收药品1。","chen":"前哨轮值引起的街区压力较低。","he":"旧街、集市、住宅轮值多回收生食1。","gu":"诊所轮值多回收药品1。","tang":"前哨轮值多带回水1。"}.get(persona, "前哨轮值使用常规产出；专长按实际动作生效。")
	return PROFILES[persona]["hint"]+"\n"+field

static func cooking_output(actor: Survivor) -> Dictionary:
	return {"meals": 3 if actor.metabolism < 1 and actor.person.persona == "he" else 2}

static func melee_damage(actor: Survivor, base: int, ambush: bool) -> int:
	return maxi(1, roundi(base * factor(actor, "melee") * (1.8 if ambush else 1.0)))
