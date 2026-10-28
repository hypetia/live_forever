class_name PersonalityArt
extends RefCounted
static func face(c: CanvasItem,id: String,at: Vector2,s: float=1.0) -> void:
 var dark:=Color('293038')
 match id:
  'lin':
   c.draw_arc(at+Vector2(0,-3)*s,12*s,PI,TAU,20,Color('c8c7bf'),4*s,true)
   for x in [-6,6]:c.draw_circle(at+Vector2(x,1)*s,5*s,Color('807660'),false,1.6*s,true)
   c.draw_circle(at+Vector2(0,5)*s,4*s,Color('bea487'))
   for x in [-4,4]:c.draw_line(at+Vector2(x,8)*s,at+Vector2(x*1.5,10)*s,Color('ddd9cc'),3*s,true)
  'xu':
   c.draw_arc(at+Vector2(0,-3)*s,12*s,PI,TAU,20,dark,6*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-11,-8)*s,at+Vector2(5,-10)*s,at+Vector2(-8,7)*s]),Color('deddd3'))
   c.draw_line(at+Vector2(2,-7)*s,at+Vector2(4,10)*s,Color('8c675c'),1.5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-6,14)*s,at+Vector2(0,19)*s,at+Vector2(6,14)*s]),Color('dce0dc'))
  'chen':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('9f875b'),5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-7)*s,at+Vector2(8,-9)*s,at+Vector2(-5,4)*s]),Color('aa9267'))
  'he':
   c.draw_arc(at+Vector2(0,-2)*s,11*s,PI,TAU,20,Color('304c70'),6*s,true)
   c.draw_line(at+Vector2(-11,-5)*s,at+Vector2(10,-5)*s,Color('b24f40'),4*s,true)
   c.draw_polyline(PackedVector2Array([at+Vector2(-9,-4)*s,at+Vector2(-17,0)*s,at+Vector2(-14,9)*s]),Color('b24f40'),3*s,true)
  'gu':
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,Color('394944'),5*s,true)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-2)*s,at+Vector2(x,18)*s,Color('394944'),4*s,true)
   c.draw_line(at+Vector2(-11,-8)*s,at+Vector2(11,-8)*s,Color('95b4a9'),3*s,true)
   c.draw_circle(at+Vector2(0,-8)*s,2*s,Color('d0c299'))
  'tang':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-8,14)*s,at+Vector2(0,19)*s,at+Vector2(8,14)*s,at+Vector2(0,24)*s]),Color('d5d7ce'))
   c.draw_line(at+Vector2(0,18)*s,at+Vector2(0,27)*s,dark,3*s,true)
  'alice':
   c.draw_arc(at+Vector2(0,-2)*s,12*s,PI,TAU,20,Color('6c483c'),5*s,true)
   for x in [-10,10]:c.draw_line(at+Vector2(x,-2)*s,at+Vector2(x,15)*s,Color('6c483c'),4*s,true)
   c.draw_line(at+Vector2(-9,15)*s,at+Vector2(9,15)*s,Color('a74f45'),5*s,true)
  'conan':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,5*s,true)
   for x in [-5,5]:c.draw_circle(at+Vector2(x,2)*s,4.5*s,Color('8daab5'),false,1.5*s,true)
   c.draw_line(at+Vector2(-1,2)*s,at+Vector2(1,2)*s,dark,1.5*s,true)
   c.draw_colored_polygon(PackedVector2Array([at+Vector2(-8,15)*s,at+Vector2(0,18)*s,at+Vector2(8,15)*s,at+Vector2(8,21)*s,at+Vector2(0,18)*s,at+Vector2(-8,21)*s]),Color('b2574e'))
  'rick':
   c.draw_arc(at+Vector2(0,-3)*s,12*s,PI,TAU,20,Color('635748'),5*s,true)
   c.draw_arc(at+Vector2(0,4)*s,9*s,0,PI,20,Color('716450'),5*s,true)
   c.draw_line(at+Vector2(-15,-9)*s,at+Vector2(15,-9)*s,Color('826e4d'),3*s,true)
   c.draw_rect(Rect2(at+Vector2(-9,-18)*s,Vector2(18,9)*s),Color('826e4d'))
  'tesla':
   c.draw_arc(at+Vector2(0,-3)*s,11*s,PI,TAU,20,dark,5*s,true)
   c.draw_line(at+Vector2(-5,7)*s,at+Vector2(5,7)*s,dark,2*s,true)
   c.draw_line(at+Vector2(-6,-9)*s,at+Vector2(7,-5)*s,Color('71757c'),2*s,true)
   c.draw_line(at+Vector2(0,16)*s,at+Vector2(0,27)*s,Color('d6d5cd'),3*s,true)
  'pooh':
   var gold:=Color('d4ae54')
   for x in [-10,10]:c.draw_circle(at+Vector2(x,-10)*s,6*s,gold)
   c.draw_circle(at,13*s,gold)
   c.draw_circle(at+Vector2(0,5)*s,7*s,Color('debd70'))
   for x in [-4,4]:c.draw_circle(at+Vector2(x,-1)*s,1.4*s,dark)
   c.draw_circle(at+Vector2(0,3)*s,2*s,dark)
   c.draw_arc(at+Vector2(0,5)*s,4*s,0,PI,10,Color('795b37'),1*s,true)
  'mickey':
   for x in [-12,12]:c.draw_circle(at+Vector2(x,-12)*s,8*s,dark)
   c.draw_circle(at,12*s,dark)
   for x in [-4,4]:c.draw_circle(at+Vector2(x,0)*s,7*s,Color('cfb799'))
   c.draw_circle(at+Vector2(0,6)*s,7*s,Color('cfb799'))
   for x in [-4,4]:c.draw_line(at+Vector2(x,-3)*s,at+Vector2(x,2)*s,dark,2*s,true)
   c.draw_circle(at+Vector2(0,4)*s,2.5*s,dark)
   c.draw_arc(at+Vector2(0,6)*s,4*s,0,PI,12,dark,1*s,true)
