class_name DefenseAssessment
extends RefCounted
## Forecast and resolution share contributions, so an inspection never invents a bonus.
static func components(game: Node2D, preview: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var home: ResidenceSystem = game.residence
	if not home.convoy.is_empty():
		for actor in game.survivors:
			if actor.health <= 0: continue
			result.append({"name":actor.display_name+" · 护送", "value":actor.health/100*(0.7 if actor.weapon().is_empty() else 1.2)*CharacterAbilities.factor(actor,"melee"), "hint":"健康%d · %s · 战斗专长已计入" % [roundi(actor.health),"有武器" if not actor.weapon().is_empty() else "徒手"]})
		return result
	result.append({"name":"住所基础", "value":float(ResidenceSystem.HOMES[home.current]["defense"]), "hint":home.title()})
	result.append({"name":"室内隔断", "value":0.9 if game.cycle.has_build("barricade") else 0.0, "hint":"已建成" if game.cycle.has_build("barricade") else "尚未建造"})
	for key in ["gate","mesh","stakes"]:
		var unit: float = {"gate":0.35,"mesh":0.25,"stakes":0.45}[key]
		result.append({"name":str(ResidenceSystem.PROJECTS[key]["name"]), "value":int(home.security[key])*unit*home.condition/100, "hint":"%d级 · 耐久%d%%" % [home.security[key],roundi(home.condition)]})
	for actor in game.survivors:
		if actor.health <= 0 or actor.survivor_id >= game.cycle.roles.size() or game.cycle.roles[actor.survivor_id] != "guard": continue
		var fatigue: float = minf(100,actor.fatigue+28)-28 if preview else actor.fatigue-28
		var base: float = actor.health/100*maxf(0.2,1-fatigue/160)*1.2*CharacterAbilities.factor(actor,"melee")*(1.15 if not actor.weapon().is_empty() else 1.0)
		result.append({"name":actor.display_name+" · 守夜", "value":base, "hint":"健康%d · %s · 战斗专长与精神已计入" % [roundi(actor.health),"武器加成15%" if not actor.weapon().is_empty() else "徒手"]})
		if home.security["alarm"] > 0:
			result.append({"name":actor.display_name+" · 预警协同", "value":base*(home.guard_multiplier()-1), "hint":"预警设施只增强实际守夜者；受耐久影响"})
	return result

static func total(rows: Array[Dictionary]) -> float:
	var value := 0.0
	for row in rows: value += float(row["value"])
	return value

static func summary(rows: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for row in rows:
		if row["value"] > 0: parts.append("%s %.2f" % [row["name"],row["value"]])
	return "、".join(parts) if not parts.is_empty() else "无人守夜，也没有有效阻挡设施"
