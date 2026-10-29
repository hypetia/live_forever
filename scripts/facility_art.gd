class_name FacilityArt
extends RefCounted
## Original painted construction/production atlas; all lit states are driven by simulation.
const TEXTURE := preload("res://assets/art/facilities.png")
const REGIONS := [[93, 9, 178, 276], [408, 8, 288, 278], [784, 52, 368, 217], [1223, 142, 266, 137], [46, 303, 300, 207], [444, 333, 254, 182], [801, 321, 323, 195], [1198, 318, 312, 203], [22, 531, 332, 257], [398, 534, 361, 243], [796, 558, 352, 219], [1216, 521, 280, 267], [30, 788, 324, 211], [408, 811, 344, 190], [798, 805, 341, 199], [1174, 826, 330, 175]]

static func fitted_rect(index: int, box: Rect2) -> Rect2:
	var r: Array = REGIONS[index]
	var source := Rect2(r[0],r[1],r[2],r[3])
	var scale_factor := minf(box.size.x/source.size.x,box.size.y/source.size.y)
	var size := source.size*scale_factor
	return Rect2(Vector2(box.get_center().x-size.x*.5,box.end.y-size.y),size)

static func prop(c: CanvasItem, index: int, box: Rect2, tint: Color = Color.WHITE) -> void:
	var r: Array = REGIONS[index]
	c.draw_texture_rect_region(TEXTURE,fitted_rect(index,box),Rect2(r[0],r[1],r[2],r[3]),tint)

static func construction(c: CanvasItem, at: Vector2, progress: float) -> void:
	prop(c,12,Rect2(at-Vector2(57,78),Vector2(114,78)))
	c.draw_rect(Rect2(at-Vector2(47,89),Vector2(94,5)),Color("25312d"))
	c.draw_rect(Rect2(at-Vector2(47,89),Vector2(94*clampf(progress,0,1),5)),Color("c8b17b"))

static func built(c: CanvasItem, kind: String, at: Vector2, heated: bool, time: float) -> void:
	if kind == "bed":
		RealismAssets.prop(c,0,Rect2(at-Vector2(60,78),Vector2(120,78)))
		return
	var index: int = {"heater":0,"filter":1,"barricade":2}[kind]
	prop(c,index,Rect2(at-Vector2(58,118),Vector2(116,118)))
	if kind == "heater" and heated:
		var ember := at+Vector2(8,-33)
		for radius in range(30,3,-5): c.draw_circle(ember,radius,Color(.95,.46,.13,.012))
		for i in range(3):
			var phase := time*5+i*2
			c.draw_line(ember+Vector2(i*3-3,3),ember+Vector2(sin(phase)*2,-4-absf(sin(phase))*4),Color("dc984a"),2,true)
