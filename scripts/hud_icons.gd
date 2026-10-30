class_name HudIcons
extends RefCounted
## Small monochrome pictograms; no emoji or font fallback dependencies.
static func draw(c: CanvasItem, kind: String, at: Vector2, size: float, color: Color) -> void:
	c.draw_set_transform(at, 0, Vector2.ONE * size / 20.0)
	match kind:
		"health", "medicine":
			c.draw_line(Vector2(-7, 0), Vector2(7, 0), color, 4, true)
			c.draw_line(Vector2(0, -7), Vector2(0, 7), color, 4, true)
		"hydration", "water":
			c.draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(-6,0),Vector2(-5,6),Vector2(0,9),Vector2(5,6),Vector2(6,0)]), color)
		"vigor", "bed":
			c.draw_arc(Vector2.ZERO, 8, 0.6, 5.5, 18, color, 3, true)
			c.draw_line(Vector2(4,-5),Vector2(-1,2),color,2,true)
		"fullness", "raw_food":
			for x in [-5, -1, 3]: c.draw_line(Vector2(x,-8),Vector2(x,-1),color,2,true)
			c.draw_line(Vector2(-1,-1),Vector2(-1,9),color,2,true)
			c.draw_line(Vector2(8,-8),Vector2(8,9),color,2,true)
		"meals", "table":
			c.draw_arc(Vector2.ZERO,8,0,TAU,24,color,2,true)
			c.draw_arc(Vector2.ZERO,4,0,TAU,16,color,1,true)
		"fuel", "stove":
			c.draw_colored_polygon(PackedVector2Array([Vector2(1,-10),Vector2(-6,0),Vector2(-5,7),Vector2(2,9),Vector2(7,3),Vector2(4,-4),Vector2(1,2)]),color)
		"tools":
			c.draw_arc(Vector2.ZERO,6,0,TAU,16,color,2,true)
			for n in range(8):
				var direction:=Vector2.from_angle(n*TAU/8)
				c.draw_line(direction*6,direction*10,color,3,true)
		"workbench":
			c.draw_line(Vector2(-7,8),Vector2(5,-6),color,4,true)
			c.draw_line(Vector2(-1,-8),Vector2(9,0),color,4,true)
		"materials":
			c.draw_rect(Rect2(-8,-7,16,14),color,false,2)
			c.draw_line(Vector2(-6,-5),Vector2(6,5),color,1,true)
			c.draw_line(Vector2(6,-5),Vector2(-6,5),color,1,true)
		"exit":
			c.draw_rect(Rect2(-7,-9,11,18),color,false,2)
			c.draw_line(Vector2(-1,0),Vector2(10,0),color,2,true)
			c.draw_line(Vector2(6,-4),Vector2(10,0),color,2,true)
			c.draw_line(Vector2(6,4),Vector2(10,0),color,2,true)
		"search":
			c.draw_arc(Vector2(-2,-2),6,0,TAU,20,color,2,true)
			c.draw_line(Vector2(3,3),Vector2(9,9),color,3,true)
		"attack":
			c.draw_line(Vector2(-7,8),Vector2(8,-9),color,3,true)
			c.draw_line(Vector2(-7,0),Vector2(1,7),color,2,true)
		"bag":
			c.draw_rect(Rect2(-7,-5,14,14),color,false,2)
			c.draw_arc(Vector2(0,-5),5,PI,TAU,12,color,2,true)
		"save":
			c.draw_rect(Rect2(-8,-8,16,16),color,false,2)
			c.draw_rect(Rect2(-4,-7,8,5),color,false,2)
			c.draw_rect(Rect2(-4,2,8,6),color,false,1)
	c.draw_set_transform(Vector2.ZERO)
