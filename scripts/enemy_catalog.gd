class_name EnemyCatalog
extends RefCounted
## Existing combat values, shared by simulation, silhouettes and hover details.
const TYPES := {
	"walker":{"name":"普通行尸","health":40,"damage":14,"chase_speed":125.0,"windup":0.8,"scale":1.0,"color":Color("74836d"),"hint":"扑咬前抬手；受击稳身期间不能连续打断，后退或绕背。"},
	"runner":{"name":"迅捷尸","health":30,"damage":10,"chase_speed":245.0,"windup":0.65,"scale":0.84,"color":Color("9b896e"),"hint":"追击快于步行；蓄力后向最后看到的位置扑击，提前闪开或关门。"},
	"brute":{"name":"重型尸","health":90,"damage":24,"chase_speed":95.0,"windup":1.1,"scale":1.28,"color":Color("657c78"),"hint":"正面硬化组织抵挡刀刺，钉棒较有效；重击不会被轻击打断，可绕背或后退。"},
}

static func stats(kind: String) -> Dictionary:
	return TYPES.get(kind,TYPES["walker"])
