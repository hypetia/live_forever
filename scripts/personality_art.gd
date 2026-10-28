class_name PersonalityArt
extends RefCounted
## Small original silhouette details, shared by the world and portrait cards.
static func face(c: CanvasItem,id: String,at: Vector2,s: float=1.0) -> void:
 var dark:=Color('293038');var brass:=Color('c4aa75')
 match id:
  'lin':
   c.draw_arc(at+Vector2(0,-3)*s,9*s,PI,TAU,18,dark,4*s,true)
   c.draw_line(at+Vector2(-5,5)*s,at+Vector2(5,5)*s,dark,2*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-5,7)*s,at+Vector2(0,11)*s,at+Vector2(5,7)*s]),dark,2*s,true)
  'xu':
   c.draw_arc(at,11*s,PI,TAU,20,Color('d4d5cc'),4*s,true)
   c.draw_rect(Rect2(at+Vector2(-10,-12)*s,Vector2(20,8)*s),Color('dce0d5'))
   c.draw_line(at+Vector2(-3,-8)*s,at+Vector2(3,-8)*s,Color('ad5e50'),2*s,true)
   c.draw_line(at+Vector2(0,-11)*s,at+Vector2(0,-5)*s,Color('ad5e50'),2*s,true)
   c.draw_line(at+Vector2(-4,7)*s,at+Vector2(4,7)*s,Color('b1b1a7'),2*s,true)
  'chen':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('9f875b'),5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-7)*s,at+Vector2(8,-9)*s,at+Vector2(-5,4)*s]),Color('aa9267'))
   c.draw_line(at+Vector2(-9,10)*s,at+Vector2(9,11)*s,Color('8c6756'),6*s,true)
   c.draw_line(at+Vector2(5,-2)*s,at+Vector2(2,5)*s,Color('8d6050'),1.5*s,true)
  'he':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('304c70'),6*s,true)
   c.draw_line(at+Vector2(-11,-5)*s,at+Vector2(10,-5)*s,Color('b24f40'),4*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-9,-4)*s,at+Vector2(-17,0)*s,at+Vector2(-14,9)*s]),Color('b24f40'),3*s,true)
  'gu':
   c.draw_circle(at+Vector2(0,-13)*s,5*s,Color('c1c3b6'))
   c.draw_arc(at,11*s,PI,TAU,20,Color('bec1b9'),4*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-6,5)*s,at+Vector2(6,5)*s,at+Vector2(0,19)*s]),Color('d3d3c1'))
  'tang':
   c.draw_arc(at+Vector2(-1,-2)*s,11*s,PI,TAU,20,Color('493a2c'),6*s,true)
   c.draw_line(at+Vector2(-11,-6)*s,at+Vector2(10,-6)*s,Color('994a3c'),4*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-16,-8)*s,at+Vector2(-10,-18)*s,at+Vector2(0,-14)*s,at+Vector2(11,-18)*s,at+Vector2(16,-8)*s]),Color('5b4938'))
   for x in [-10,9]:c.draw_line(at+Vector2(x,2)*s,at+Vector2(x*1.2,20)*s,dark,3*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-5,6)*s,at+Vector2(0,16)*s,at+Vector2(5,6)*s]),dark,2*s,true)
