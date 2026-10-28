class_name PersonalityArt
extends RefCounted
## Small original silhouette details, shared by the world and portrait cards.
static func face(c: CanvasItem,id: String,at: Vector2,s: float=1.0) -> void:
 var dark:=Color('293038')
 match id:
  'lin':
   c.draw_arc(at+Vector2(0,-3)*s,9*s,PI,TAU,18,dark,4*s,true)
   c.draw_line(at+Vector2(-5,5)*s,at+Vector2(5,5)*s,dark,2*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-5,7)*s,at+Vector2(0,11)*s,at+Vector2(5,7)*s]),dark,2*s,true)
  'xu':
   c.draw_arc(at+Vector2(0,-3)*s,10*s,PI,TAU,20,dark,5*s,true)
   c.draw_line(at+Vector2(-7,-7)*s,at+Vector2(7,-7)*s,dark,4*s,true)
   c.draw_line(at+Vector2(-7,8)*s,at+Vector2(6,9)*s,Color('766c5f'),2*s,true)
   c.draw_line(at+Vector2(-12,14)*s,at+Vector2(12,14)*s,Color('526552'),6*s,true)
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
   var hair:=Color('9d7558')
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,hair,6*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-10,-7)*s,at+Vector2(8,-8)*s,at+Vector2(-6,3)*s]),hair)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-2)*s,at+Vector2(x*.8,12)*s,hair,4*s,true)
   c.draw_line(at+Vector2(-7,14)*s,at+Vector2(7,14)*s,Color('ddd8cb'),5*s,true)
  'tang':
   c.draw_arc(at+Vector2(-1,-2)*s,11*s,PI,TAU,20,Color('493a2c'),6*s,true)
   c.draw_line(at+Vector2(-11,-6)*s,at+Vector2(10,-6)*s,Color('994a3c'),4*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-16,-8)*s,at+Vector2(-10,-18)*s,at+Vector2(0,-14)*s,at+Vector2(11,-18)*s,at+Vector2(16,-8)*s]),Color('5b4938'))
   for x in [-10,9]:c.draw_line(at+Vector2(x,2)*s,at+Vector2(x*1.2,20)*s,dark,3*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-5,6)*s,at+Vector2(0,16)*s,at+Vector2(5,6)*s]),dark,2*s,true)
  'goku':
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-13,1)*s,at+Vector2(-20,-9)*s,at+Vector2(-8,-8)*s,at+Vector2(-12,-20)*s,at+Vector2(0,-13)*s,at+Vector2(8,-24)*s,at+Vector2(10,-10)*s,at+Vector2(21,-14)*s,at+Vector2(12,1)*s]),dark)
   c.draw_line(at+Vector2(-10,16)*s,at+Vector2(10,16)*s,Color('db853d'),6*s,true)
  'conan':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,5*s,true)
   for x in [-5,5]:c.draw_circle(at+Vector2(x,2)*s,4.5*s,Color('8daab5'),false,1.5*s,true)
   c.draw_line(at+Vector2(-1,2)*s,at+Vector2(1,2)*s,dark,1.5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-8,15)*s,at+Vector2(0,18)*s,at+Vector2(8,15)*s,at+Vector2(8,21)*s,at+Vector2(0,18)*s,at+Vector2(-8,21)*s]),Color('b2574e'))
  'batman':
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,dark,7*s,true)
   for side in [-1,1]:c.draw_colored_polygon(PackedVector2Array([at+Vector2(side*11,-3)*s,at+Vector2(side*10,-24)*s,at+Vector2(side*4,-10)*s]),dark)
   c.draw_line(at+Vector2(-10,1)*s,at+Vector2(10,1)*s,dark,4*s,true)
   for x in [-5,5]:c.draw_line(at+Vector2(x-2,0)*s,at+Vector2(x+2,0)*s,Color('b6c7c8'),1.3*s,true)
  'sherlock':
   c.draw_arc(at+Vector2(0,-3)*s,12*s,PI,TAU,20,dark,6*s,true)
   for x in [-8,-3,3,8]:c.draw_circle(at+Vector2(x,-10+abs(x)*.35)*s,3*s,dark)
   c.draw_line(at+Vector2(-10,15)*s,at+Vector2(10,15)*s,Color('3e4e68'),7*s,true)
   c.draw_line(at+Vector2(7,14)*s,at+Vector2(8,28)*s,Color('3e4e68'),5*s,true)
  'harry':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,6*s,true)
   for x in [-5,5]:c.draw_circle(at+Vector2(x,2)*s,4.5*s,dark,false,1.5*s,true)
   c.draw_line(at+Vector2(-1,2)*s,at+Vector2(1,2)*s,dark,1.5*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(3,-8)*s,at+Vector2(1,-4)*s,at+Vector2(4,-4)*s,at+Vector2(2,0)*s]),Color('a35e51'),1.4*s,true)
   c.draw_line(at+Vector2(-9,16)*s,at+Vector2(9,16)*s,Color('934941'),5*s,true)
  'neo':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,5*s,true)
   c.draw_line(at+Vector2(-10,1)*s,at+Vector2(10,1)*s,dark,3*s,true)
   for x in [-5,5]:c.draw_rect(Rect2(at+Vector2(x-4,-1)*s,Vector2(8,5)*s),dark)
   c.draw_line(at+Vector2(-10,16)*s,at+Vector2(10,16)*s,Color('252c2a'),6*s,true)
