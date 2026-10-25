class_name TaskCatalog
extends RefCounted
## The UI and scheduler share these prototype recipes.

const TASKS := {
	"repair": {"label": "修整", "facility": "workbench", "cost": {"materials": 1}, "output": {}},
	"cook": {"label": "做饭", "facility": "stove", "cost": {"raw_food": 1, "water": 1, "fuel": 1}, "output": {"meals": 2}},
	"eat": {"label": "吃饭", "facility": "table", "cost": {"meals": 1}, "output": {}},
	"sleep": {"label": "睡觉", "facility": "bed", "cost": {}, "output": {}},
	"craft": {"label": "制作工具", "facility": "workbench", "cost": {"materials": 2}, "output": {"tools": 1}},
	"heal": {"label": "治疗", "facility": "table", "cost": {"medicine": 1}, "output": {}},
}


static func label_for(task_id: String) -> String:
	return TASKS[task_id]["label"]


static func duration_for(task_id: String, actor: Survivor) -> float:
	return duration_for_persona(task_id, actor.person.persona)


static func duration_for_profile(task_id: String, craftsman: bool, medic: bool = false, chef: bool = false) -> float:
	match task_id:
		"cook": return 5.0 if chef else 6.0
		"eat": return 4.0
		"sleep": return 20.0
		"craft": return 6.0 if craftsman else 8.0
		"heal": return 6.0 if medic else 8.0
		_: return 4.5 if craftsman else 6.0


static func duration_for_persona(task_id: String, persona: String) -> float:
	var role := PeopleCatalog.role(persona)
	return duration_for_profile(task_id, role == "工匠", role == "医护", role == "厨师")
