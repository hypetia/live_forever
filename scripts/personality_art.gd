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
   c.draw_arc(at,11*s,PI,TAU,20,Color('c4b373'),5*s,true)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-3)*s,at+Vector2(x*1.3,14)*s,Color('c4b373'),5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-5)*s,at+Vector2(-2,-2)*s,at+Vector2(0,1)*s,at+Vector2(2,-2)*s]),Color('6378ad'))
  'chen':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('9f875b'),5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-7)*s,at+Vector2(8,-9)*s,at+Vector2(-5,4)*s]),Color('aa9267'))
   c.draw_line(at+Vector2(-9,10)*s,at+Vector2(9,11)*s,Color('8c6756'),6*s,true)
   c.draw_line(at+Vector2(5,-2)*s,at+Vector2(2,5)*s,Color('8d6050'),1.5*s,true)
  'he':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('d0b25f'),6*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-10,-6)*s,at+Vector2(2,-8)*s,at+Vector2(-6,8)*s]),Color('d0b25f'))
   c.draw_arc(at+Vector2(5,-2)*s,3*s,-PI,PI*.6,12,dark,1.2*s,true)
  'gu':
   c.draw_circle(at+Vector2(0,-13)*s,5*s,Color('c1c3b6'))
   c.draw_arc(at,11*s,PI,TAU,20,Color('bec1b9'),4*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-6,5)*s,at+Vector2(6,5)*s,at+Vector2(0,19)*s]),Color('d3d3c1'))
  'tang':
   c.draw_arc(at+Vector2(-1,-2)*s,11*s,PI,TAU,20,Color('565f56'),6*s,true)
   c.draw_line(at+Vector2(-5,-5)*s,at+Vector2(17,-5)*s,Color('707c67'),4*s,true)
   c.draw_line(at+Vector2(-10,8)*s,at+Vector2(-17,18)*s,Color('b19b66'),4*s,true)
