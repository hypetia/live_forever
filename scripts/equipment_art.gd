class_name EquipmentArt
extends RefCounted
## Shared silhouettes for the actual equipped items, never backpack tools.

static func slots(actor: Survivor) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in [["weapon",actor.weapon_item],["armor",actor.armor_item],["coat",actor.coat_item]]:
		var item: Dictionary = entry[1]
		var kind := str(item.get("kind",""))
		var maximum := int(GearCatalog.ITEMS.get(kind,{}).get("durability",1))
		var durability := int(item.get("durability",0))
		result.append({"slot":entry[0],"kind":kind,"name":GearCatalog.ITEMS.get(kind,{}).get("name",{"weapon":"徒手","armor":"未穿护甲","coat":"未穿冬衣"}[entry[0]]),"durability":durability,"maximum":maximum,"ratio":float(durability)/maximum,"broken":not kind.is_empty() and durability <= 0})
	return result


static func weapon(c: CanvasItem, kind: String, hand: Vector2, facing: float, angle: float = -0.2, scale: float = 1.0, broken: bool = false) -> void:
	var wood := Color("917454") if not broken else Color("635b53")
	var metal := Color("dce4da") if not broken else Color("9e7466")
	var lines: Array = []
	var polygon := PackedVector2Array()
	match kind:
		"knife":
			lines = [[Vector2(-4,0),Vector2(7,0),wood,5],[Vector2(6,-5),Vector2(6,5),metal,2]]
			polygon = PackedVector2Array([Vector2(8,-3),Vector2(30,-3),Vector2(24,3),Vector2(8,3)])
		"bat":
			lines = [[Vector2(-5,0),Vector2(13,0),wood,4],[Vector2(12,0),Vector2(43,0),wood,9]]
			for x in [24,34,41]: lines.append([Vector2(x,-8),Vector2(x,8),metal,2])
		"spear":
			lines = [[Vector2(-27,0),Vector2(59,0),wood,3]]
			polygon = PackedVector2Array([Vector2(56,-5),Vector2(76,0),Vector2(56,5)])
		"pistol":
			lines = [[Vector2(0,1),Vector2(-3,12),wood,6],[Vector2(-5,-4),Vector2(24,-4),metal,7],[Vector2(17,-8),Vector2(17,-4),metal,2]]
		_:
			c.draw_circle(hand,3*scale,Color("c7b294"))
	for line in lines:
		c.draw_line(_point(line[0],hand,facing,angle,scale),_point(line[1],hand,facing,angle,scale),line[2],line[3]*scale,true)
	if not polygon.is_empty():
		var shape := PackedVector2Array()
		for p in polygon: shape.append(_point(p,hand,facing,angle,scale))
		c.draw_colored_polygon(shape,metal)


static func _point(p: Vector2, origin: Vector2, facing: float, angle: float, scale: float) -> Vector2:
	var rotated := (p*scale).rotated(angle)
	return origin+Vector2(rotated.x*facing,rotated.y)


static func icon(c: CanvasItem, slot: Dictionary, at: Vector2) -> void:
	var kind: String = slot["kind"]
	var color := Color("bba47e") if not kind.is_empty() else Color("59655f")
	if slot["slot"] == "weapon":
		if kind.is_empty():
			c.draw_circle(at,7,color)
			for x in [-5,-1,3]: c.draw_line(at+Vector2(x,-9),at+Vector2(x,-2),color,3,true)
		else: weapon(c,kind,at-Vector2(12,0),1,-0.45,0.55 if kind == "spear" else 0.85,slot["broken"])
	else:
		var coat: bool = slot["slot"] == "coat"
		var points := PackedVector2Array([at+Vector2(-7,-12),at+Vector2(-16,-7),at+Vector2(-11,3),at+Vector2(-8,0),at+Vector2(-9,14 if coat else 10),at+Vector2(9,14 if coat else 10),at+Vector2(8,0),at+Vector2(11,3),at+Vector2(16,-7),at+Vector2(7,-12),at+Vector2(4,-7),at+Vector2(-4,-7)])
		c.draw_colored_polygon(points,color)
		c.draw_line(at+Vector2(0,-5),at+Vector2(0,12 if coat else 8),Color("26322e"),2,true)
		if kind == "vest": c.draw_rect(Rect2(at+Vector2(-6,-3),Vector2(12,9)),Color("52615b"),false,2)
	if slot["broken"]:
		c.draw_line(at+Vector2(-18,16),at+Vector2(18,-16),Color("e5967e"),3,true)
