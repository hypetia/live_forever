class_name PersonalityArt
extends RefCounted
## Small original silhouette details, shared by the world and portrait cards.
static func face(c: CanvasItem,id: String,at: Vector2,s: float=1.0) -> void:
 var dark:=Color('293038');var brass:=Color('c4aa75')
 match id:
  'lin':
   c.draw_line(at+Vector2(-10,-1)*s,at+Vector2(10,-1)*s,dark,3*s,true)
   for x in [-5,5]:c.draw_arc(at+Vector2(x,0)*s,4*s,0,TAU,18,brass,2*s,true)
   c.draw_line(at+Vector2(-4,8)*s,at+Vector2(4,8)*s,Color('5a5145'),3*s,true)
  'xu':
   c.draw_arc(at+Vector2(0,0),12*s,PI,TAU,20,Color('cbd1c7'),5*s,true)
   c.draw_rect(Rect2(at+Vector2(-8,2)*s,Vector2(16,7)*s),Color('b9c7c8'))
   c.draw_line(at+Vector2(7,-8)*s,at+Vector2(13,9)*s,Color('e4e3d4'),3*s,true)
  'chen':
   c.draw_arc(at+Vector2(0,-1)*s,12*s,PI,TAU,20,dark,5*s,true)
   c.draw_line(at+Vector2(-9,10)*s,at+Vector2(9,11)*s,Color('8c6756'),6*s,true)
   c.draw_line(at+Vector2(5,-2)*s,at+Vector2(2,5)*s,Color('8d6050'),1.5*s,true)
  'he':
   c.draw_circle(at+Vector2(-8,-11)*s,6*s,dark)
   c.draw_line(at+Vector2(-11,-6)*s,at+Vector2(10,-6)*s,Color('b45f49'),5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(9,-8)*s,at+Vector2(19,-5)*s,at+Vector2(10,-2)*s]),Color('b45f49'))
  'gu':
   c.draw_arc(at,11*s,PI,TAU,20,Color('bec1b9'),6*s,true)
   c.draw_arc(at+Vector2(5,1)*s,4*s,0,TAU,20,brass,1.5*s,true)
   c.draw_line(at+Vector2(-9,10)*s,at+Vector2(10,10)*s,Color('414454'),4*s,true)
  'tang':
   c.draw_arc(at+Vector2(-1,-2)*s,11*s,PI,TAU,20,Color('565f56'),6*s,true)
   c.draw_line(at+Vector2(-5,-5)*s,at+Vector2(17,-5)*s,Color('707c67'),4*s,true)
   c.draw_line(at+Vector2(-10,8)*s,at+Vector2(-17,18)*s,Color('b19b66'),4*s,true)
