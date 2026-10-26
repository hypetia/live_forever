class_name EnemyCatalog
extends RefCounted
## Existing combat values, shared by simulation, silhouettes and hover details.
const TYPES := {
	"walker":{"name":"普通行尸","health":40,"damage":14,"chase_speed":105.0,"windup":0.8,"scale":1.0,"color":Color("74836d"),"hint":"速度适中，扑咬前有抬手动作。"},
	"runner":{"name":"迅捷尸","health":30,"damage":10,"chase_speed":155.0,"windup":0.5,"scale":0.84,"color":Color("9b896e"),"hint":"体型瘦小、追击快；生命较低，出手更快。"},
	"brute":{"name":"重型尸","health":90,"damage":24,"chase_speed":75.0,"windup":1.1,"scale":1.28,"color":Color("657c78"),"hint":"体型宽大、生命高；移动慢，重击准备更长。"},
}

static func stats(kind: String) -> Dictionary:
	return TYPES.get(kind,TYPES["walker"])
