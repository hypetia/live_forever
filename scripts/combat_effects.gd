class_name CombatEffects
extends RefCounted
## Bounded visual state. It never changes combat outcomes or saved simulation.
const MAX_PARTICLES := 96
const MAX_MARKS := 48
var particles: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var reactions: Dictionary = {}
var player_time := 0.0
var player_direction := 1.0
var pulse := 0.0

func clear() -> void:
	particles.clear()
	marks.clear()
	reactions.clear()
	player_time = 0
	pulse = 0

func hit(index: int, at: Vector2, direction: float, damage: int, lethal: bool) -> void:
	reactions[index] = {"age":0.0,"lethal":lethal,"direction":direction}
	_spray(at+Vector2(0,-42),direction,18 if lethal else 12)
	marks.append({"at":at+Vector2(direction*8,-1),"width":18.0 if lethal else 9.0})
	if marks.size() > MAX_MARKS: marks.pop_front()
	pulse = maxf(pulse,0.14 if lethal else 0.07)

func hurt(at: Vector2, direction: float) -> void:
	player_time = 0.4
	player_direction = direction
	pulse = 0.18
	_spray(at+Vector2(0,-40),direction,8)

func _spray(at: Vector2, direction: float, count: int) -> void:
	for index in range(count):
		if particles.size() >= MAX_PARTICLES: particles.pop_front()
		particles.append({"at":at,"velocity":Vector2(direction*(28+index*7),-72+(index%5)*23),"life":0.42+(index%3)*0.09,"radius":1.2+(index%3)*0.6})

func step(delta: float) -> void:
	player_time = maxf(0,player_time-delta)
	pulse = maxf(0,pulse-delta)
	for index in reactions.keys():
		reactions[index]["age"] += delta
		if reactions[index]["age"] > 0.8: reactions.erase(index)
	for particle in particles.duplicate():
		particle["life"] -= delta
		particle["velocity"].y += 190*delta
		particle["at"] += particle["velocity"]*delta
		if particle["life"] <= 0: particles.erase(particle)

func shake() -> Vector2:
	return Vector2(sin(pulse*110),cos(pulse*92))*minf(2.5,pulse*13)

func draw_marks(c: CanvasItem,camera: float) -> void:
	for mark in marks:
		var shape := PackedVector2Array()
		for i in range(16): shape.append(mark["at"]-Vector2(camera,0)+Vector2(cos(i*TAU/16)*mark["width"],sin(i*TAU/16)*3))
		c.draw_colored_polygon(shape,Color("76303a"))

func draw_particles(c: CanvasItem,camera: float) -> void:
	for particle in particles:
		c.draw_circle(particle["at"]-Vector2(camera,0),particle["radius"],Color("bd5b57") if particle["life"] > 0.3 else Color("7e333a"))

func draw_enemy(c: CanvasItem,enemy: Dictionary,index: int,point: Vector2,time: float) -> void:
	var kind: String = enemy["kind"]
	var definition := EnemyCatalog.stats(kind)
	var scale: float = definition["scale"]
	var direction: float = enemy["direction"]
	var reaction: Dictionary = reactions.get(index,{})
	var age: float = reaction.get("age",1.0)
	var tint: Color = definition["color"]
	if enemy["hp"] <= 0:
		var fall := clampf(age/0.48,0,1) if reaction.get("lethal",false) else 1.0
		var up := Vector2.UP.rotated(direction*PI*0.48*fall)
		var hip := point+Vector2(direction*10*fall,-22*scale*(1-fall))
		var pool := PackedVector2Array()
		for i in range(24): pool.append(point+Vector2(cos(i*TAU/24)*23*scale,sin(i*TAU/24)*4-1))
		c.draw_colored_polygon(pool,Color("60272e"))
		c.draw_line(hip,hip+up*29*scale,tint.darkened(0.25),14*scale,true)
		c.draw_circle(hip+up*42*scale,9*scale,tint.lightened(0.08))
		c.draw_line(hip,point+Vector2(-direction*18*scale,-3),Color("3f4e49"),7*scale,true)
		c.draw_line(hip+up*22*scale,hip+up*17*scale+Vector2(direction*17,-1),tint.darkened(0.2),5*scale,true)
		return
	var recoil := maxf(0,1-age/0.28)
	var lean := (sin(recoil*PI)*float(reaction.get("direction",0))*11)/(1.5 if kind == "brute" else 1.0)
	if age < 0.09: tint = tint.lerp(Color("f3c9bb"),0.85)
	var moving: bool = enemy["mode"] in ["chase","patrol","investigate"]
	var stride := sin(time*(15 if kind == "runner" else 6 if kind == "brute" else 8))* (9 if kind == "runner" else 5) if moving else 0.0
	var torso := point+Vector2(lean+(direction*5 if kind == "runner" else 0),0)
	var shoulder := torso+Vector2(0,-52*scale)
	var width := (16.0 if kind == "brute" else 10.0)*scale
	c.draw_line(point+Vector2(-5*scale,-24*scale),point+Vector2(-8+stride,-2),Color("35463e"),7*scale,true)
	c.draw_line(point+Vector2(5*scale,-24*scale),point+Vector2(8-stride,-2),Color("35463e"),7*scale,true)
	c.draw_colored_polygon(PackedVector2Array([shoulder+Vector2(-width,0),shoulder+Vector2(width,-3),torso+Vector2(width,-22*scale),torso+Vector2(-width,-22*scale)]),tint)
	if kind == "brute":
		c.draw_line(shoulder+Vector2(-width,9),shoulder+Vector2(width,9),tint.lightened(0.25),6,true)
		c.draw_rect(Rect2(torso+Vector2(-10,-48),Vector2(20,19)),tint.darkened(0.2))
	c.draw_circle(torso+Vector2(direction*5,-64*scale),9*scale,tint.lightened(0.28))
	var arm := Vector2(direction* (42 if enemy["mode"] == "windup" else 24),-38*scale)
	if kind == "brute" and enemy["mode"] == "windup": arm = Vector2(direction*23,-80)
	if recoil > 0: arm.x -= float(reaction.get("direction",0))*recoil*14
	c.draw_line(shoulder+Vector2(direction*7,8),torso+arm,tint.lightened(0.15),6*scale,true)
	if kind == "brute": c.draw_circle(torso+arm,5.5,tint.lightened(0.1))
