class_name CombatRules
extends RefCounted
## Shared field/base rules. A visible hit is not automatically an interrupt.
const STAGGER_GUARD := 2.4

static func effort(weapon: Dictionary) -> float:
	return float(weapon.get("effort",2.5))

static func tempo(actor: Survivor) -> float:
	return 1.0+clampf((actor.fatigue-55)/70.0,0,.55)+clampf((actor.injury-40)/150.0,0,.25)

static func frontal(enemy: Dictionary, attacker_x: float) -> bool:
	return (attacker_x-float(enemy["x"]))*float(enemy["direction"])>=-10

static func damage(enemy: Dictionary, attacker_x: float, weapon: Dictionary, strength: int) -> int:
	if enemy["kind"] != "brute" or not frontal(enemy,attacker_x): return strength
	var factor := .9 if weapon.has("magazine") else .85 if weapon.get("impact","")=="heavy" else .55
	return maxi(1,roundi(strength*factor))

static func interrupt(enemy: Dictionary, attacker_x: float, weapon: Dictionary, ambush: bool) -> bool:
	if float(enemy.get("brace",0))>0: return false
	if enemy["mode"]=="windup" and float(enemy["timer"])<=.28 and not ambush and weapon.get("impact","")!="heavy": return false
	if enemy["kind"]=="brute" and frontal(enemy,attacker_x) and weapon.get("impact","")!="heavy": return false
	enemy["brace"]=STAGGER_GUARD
	return true

static func stagger_seconds(kind: String) -> float:
	return .22 if kind in ["runner","brute"] else .35

static func engage(kind: String) -> float:
	return {"walker":64.0,"runner":122.0,"brute":102.0}[kind]

static func bite_range(kind: String) -> float:
	return {"walker":72.0,"runner":76.0,"brute":112.0}[kind]

static func telegraph(c: CanvasItem, enemy: Dictionary, point: Vector2, scale_factor: float = 1) -> void:
	if enemy["kind"]=="brute":
		var center := point+Vector2(float(enemy["direction"])*18,-62)*scale_factor
		c.draw_colored_polygon(PackedVector2Array([center+Vector2(-9,-10),center+Vector2(9,-10),center+Vector2(7,9),center+Vector2(0,15),center+Vector2(-7,9)]),Color("707b77"))
		c.draw_line(center+Vector2(0,-7),center+Vector2(0,8),Color("b9bcb0"),2,true)
	if float(enemy.get("brace",0))>0:
		c.draw_arc(point+Vector2(0,-84)*scale_factor,8,0,TAU,18,Color("dac18d"),2,true)
	if enemy["mode"]!="windup": return
	var progress := 1.0-clampf(float(enemy["timer"])/float(EnemyCatalog.stats(enemy["kind"])["windup"]),0,1)
	var width := bite_range(enemy["kind"])
	var facing: float = enemy["direction"]
	var color := Color(.9,.45,.27,.2+.6*progress)
	c.draw_line(point+Vector2(0,-2),point+Vector2(facing*width,-2),color,3,true)
	c.draw_arc(point+Vector2(0,-35)*scale_factor,42*scale_factor,-PI/2,-PI/2+TAU*progress,32,color,3,true)
	if enemy["kind"]=="runner":
		for i in range(2):
			var at := point+Vector2(facing*(width-15-i*18),-8)
			c.draw_line(at-Vector2(facing*7,5),at,color,2,true)
			c.draw_line(at,at-Vector2(facing*7,-5),color,2,true)

static func details(c: CanvasItem, font: Font, enemy: Dictionary, point: Vector2) -> void:
	var at := Vector2(clampf(point.x-160,12,760),maxf(40,point.y-270))
	c.draw_rect(Rect2(at,Vector2(320,112)),GameUi.PANEL)
	c.draw_rect(Rect2(at,Vector2(320,112)),GameUi.ACCENT,false,1)
	var entry := EnemyCatalog.stats(enemy["kind"])
	c.draw_string(font,at+Vector2(12,25),entry["name"],HORIZONTAL_ALIGNMENT_LEFT,296,20,GameUi.ACCENT)
	c.draw_multiline_string(font,at+Vector2(12,52),entry["hint"],HORIZONTAL_ALIGNMENT_LEFT,296,16,3,GameUi.TEXT)
