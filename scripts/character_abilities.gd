class_name CharacterAbilities
extends RefCounted
## Stable identities, independent of learned experience. Presentation and rules share this table.
const PROFILES := {
	"lin":{"door":1.25,"melee":1.0,"hint":"工具与修整更快；工艺经验+20%，门窗作业+25%。"},
	"xu":{"melee":0.9,"hint":"治疗更快；医疗援助额外恢复10生命；重视同伴伤情。"},
	"chen":{"melee":1.4,"hint":"近战伤害+40%，背袭另有加成；侦察训练保留搜索+20%、脚步声−20%。"},
	"he":{"melee":0.95,"hint":"基础烹饪5秒，同料熟食3份；自身饥饿增长+10%。"},
	"gu":{"melee":0.85,"hint":"照护经验+20%；护理额外减少伤势15、疾病10；活动疲劳增长+10%。"},
	"tang":{"door":1.4,"melee":1.15,"sleep":1.25,"recovery":1.5,"hint":"背包16格；睡眠恢复+25%、休息恢复+50%；互助额外水1、燃料1。"},
	"alice":{"melee":1.55,"recovery":1.2,"hunger":1.15,"hint":"近战伤害+55%，合适休息时恢复+20%；饥饿增长+15%。"},
	"conan":{"melee":0.65,"noise":0.75,"door":1.3,"hint":"搜索+20%；搜寻者基础上脚步声再−25%；门窗效率+30%；近战−35%，背包10格。"},
	"rick":{"ranged":1.25,"melee":1.05,"noise":1.1,"hint":"枪械命中伤害+25%；近战+5%；脚步声+10%，背包12格。"},
	"tesla":{"work":1.25,"melee":0.85,"strain":1.1,"hint":"制作与设施工程效率额外+25%；活动疲劳增长+10%；背包12格。"},
	"pooh":{"support":1.4,"calm":1.5,"music":1.3,"melee":0.65,"hunger":1.1,"hint":"共餐心境与信任收益+40%，安慰减压及缓解创伤+50%；可准备每日分享点心；自身更易饿。"},
	"mickey":{"support":1.2,"melee":0.8,"hint":"邻里互助额外得到水2、燃料1；共餐心境与信任+20%；保留两天互助冷却和原料成本。"},
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

static func needs_multiplier(actor: Survivor, key: String) -> float:
	var fallback := 1.1 if (key == "hunger" and actor.person.persona == "he") or (key == "strain" and actor.person.persona == "gu") else 1.0
	return float(PROFILES[actor.person.persona].get(key, fallback))

static func ranged_damage(actor: Survivor, base: int) -> int:
	return maxi(1, roundi(base * factor(actor,"ranged")))

static func cooking_output(actor: Survivor) -> Dictionary:
	return {"meals": 3 if actor.metabolism < 1 and actor.person.persona == "he" else 2}

static func melee_damage(actor: Survivor, base: int, ambush: bool) -> int:
	return maxi(1, roundi(base * factor(actor, "melee") * (1.8 if ambush else 1.0)))
