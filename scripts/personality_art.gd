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
  'lara':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('5d4134'),5*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(9,-5)*s,at+Vector2(15,3)*s,at+Vector2(14,24)*s]),Color('5d4134'),5*s,true)
   c.draw_line(at+Vector2(-9,15)*s,at+Vector2(9,15)*s,Color('4b9c9a'),5*s,true)
  'joel':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,Color('57524a'),6*s,true)
   c.draw_arc(at+Vector2(0,4)*s,9*s,0,PI,20,Color('625b50'),5*s,true)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-2)*s,at+Vector2(x,5)*s,Color('a5a094'),2*s,true)
  'ellie':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('8b5745'),5*s,true)
   c.draw_line(at+Vector2(9,0)*s,at+Vector2(14,17)*s,Color('8b5745'),4*s,true)
   for x in [-4,4]:c.draw_circle(at+Vector2(x,5)*s,1*s,Color('966b50'))
  'jill':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('65523f'),5*s,true)
   c.draw_line(at+Vector2(-12,-7)*s,at+Vector2(11,-7)*s,Color('46769a'),5*s,true)
   c.draw_circle(at+Vector2(-3,-9)*s,9*s,Color('46769a'))
   c.draw_circle(at+Vector2(3,-10)*s,2*s,Color('b8b4a0'))
  'liu':
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,Color('302f2c'),5*s,true)
   c.draw_arc(at+Vector2(0,0)*s,16*s,0,PI,20,Color('bfc6c6'),4*s,true)
   c.draw_line(at+Vector2(-12,15)*s,at+Vector2(12,15)*s,Color('bc7041'),5*s,true)
  'wick':
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,dark,6*s,true)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-3)*s,at+Vector2(x,15)*s,dark,5*s,true)
   c.draw_arc(at+Vector2(0,4)*s,8*s,0,PI,20,dark,3*s,true)
   c.draw_line(at+Vector2(0,14)*s,at+Vector2(0,24)*s,Color('b9b3a7'),3*s,true)
