class_name SceneArt
extends RefCounted
## Original layered cutaway scenery. Floors and every hotspot retain real coordinates.
static var shared_wood: ImageTexture
var wood: ImageTexture
var map_scenery := MapScenery.new()

func _init() -> void:
 if shared_wood==null:
  var noise:=FastNoiseLite.new();noise.seed=71413;noise.frequency=.13
  var image:=Image.create(128,128,false,Image.FORMAT_RGBA8)
  for y in range(128):
   for x in range(128):
    var grain:=.36+noise.get_noise_2d(x*.4,y*4)*.15
    if y%15==0:grain*=.5
    image.set_pixel(x,y,Color(grain,grain*.85,grain*.67,1))
  shared_wood=ImageTexture.create_from_image(image)
 wood=shared_wood

func shelter(g: Node2D) -> void:
 g.draw_rect(Rect2(0,0,1440,900),Color("0b1115"))
 g.draw_set_transform(g.world_offset(),0,g.world_scale())
 RealismAssets.backdrop(g,Rect2(-100,80,1300,580),'shelter',0,SurvivalRules.is_night(g.simulation_time))
 # The open upper storey reaches the roof; dark framing creates depth.
 g.draw_colored_polygon(PackedVector2Array([Vector2(87,210),Vector2(143,185),Vector2(959,194),Vector2(1010,211)]),Color("1d2526"))
 g.draw_rect(Rect2(97,207,905,449),Color("111a1b"))
 var home: String = g.residence.current
 room(g,Rect2(112,219,874,211),Color("747060") if home == "row" else Color("586873") if home == "depot" else Color("65706a"),"depot_home" if home=="depot" else home)
 room(g,Rect2(112,447,874,193),Color("5b6150") if home == "row" else Color("3b4b59") if home == "depot" else Color("465650"),{"shelter":"works","row":"shelter","depot":"depot"}[home])
 g.draw_rect(Rect2(662,220,194,420),Color(0.03,0.05,0.05,0.45))
 for x in [119,975]:
  g.draw_line(Vector2(x,224),Vector2(x,637),Color("171f20"),7,true)
  g.draw_line(Vector2(x+2,224),Vector2(x+2,637),Color("596056"),1,true)
 # Floor and roof boards carry the same coordinates as navigation.
 for rect in [Rect2(98,210,905,14),Rect2(98,430,584,15),Rect2(716,430,287,15),Rect2(98,640,905,17)]:
  g.draw_texture_rect(wood,rect,true,Color("a5a38d"))
  g.draw_line(rect.position,rect.position+Vector2(rect.size.x,0),Color("8c8c76"),2,true)
  g.draw_rect(Rect2(rect.position+Vector2(0,rect.size.y),Vector2(rect.size.x,9)),Color(0.025,0.035,0.035,0.8))
 for x in [97,986]:
  g.draw_texture_rect(wood,Rect2(x,205,14,454),true,Color("777f74"))
  g.draw_line(Vector2(x+3,210),Vector2(x+3,653),Color("a3a18a"),1,true)
 for i in range(14):
  var point := ShelterNavigation.TOP_STAIR.lerp(ShelterNavigation.BOTTOM_STAIR,i/14.0)
  g.draw_line(point+Vector2(-18,4),point+Vector2(19,4),Color("111b1d"),8,true)
  g.draw_texture_rect(wood,Rect2(point+Vector2(-18,-2),Vector2(37,5)),true,Color("a29b7d"))
 g.draw_line(Vector2(674,409),Vector2(793,620),Color("757c6d"),2,true)
 for i in range(0,14,3):
  var point := ShelterNavigation.TOP_STAIR.lerp(ShelterNavigation.BOTTOM_STAIR,i/14.0)
  g.draw_line(point+Vector2(-17,-21),point+Vector2(-17,0),Color("757c6d"),2,true)
 # Beds, shelving and clutter are part of the rooms, not an interface panel.
 RealismAssets.prop(g,0,Rect2(282,352,130,78))
 RealismAssets.prop(g,4,Rect2(882,516,75,122),Color(.76,.80,.72))
 for x in [315,352]:RealismAssets.prop(g,6,Rect2(x,608,35,32),Color(.8,.82,.77))
 # Local lamplight and animated dust give the still rooms a living surface.
 var glow := 0.95+sin(g.weather_time*2.4)*0.03+sin(g.weather_time*5.1)*0.02
 g.draw_line(Vector2(392,220),Vector2(392,275),Color("171c1b"),2,true)
 g.draw_colored_polygon(PackedVector2Array([Vector2(382,275),Vector2(402,275),Vector2(409,284),Vector2(375,284)]),Color("a39b7d"))
 g.draw_line(Vector2(378,285),Vector2(406,285),Color("ead1a1"),3,true)
 for radius in range(150,10,-8):g.draw_circle(Vector2(392,325),radius,Color(0.87,0.67,0.35,0.005*glow))
 g.draw_colored_polygon(PackedVector2Array([Vector2(381,285),Vector2(403,285),Vector2(494,428),Vector2(300,428)]),Color(0.82,0.69,0.42,0.045))
 for i in range(24):
  var x := 310+fposmod(i*37+sin(g.weather_time*0.3+i)*10,175)
  var y := 295+fposmod(i*17+g.weather_time*3,127)
  g.draw_circle(Vector2(x,y),0.7,Color(0.85,0.81,0.64,0.13))
 g._draw_house_details()
 residence_details(g)
 for i in range(50):
  var x := fposmod(i*137.0-g.weather_time*37,1090)
  var y := 125+fposmod(i*79.0+g.weather_time*170,570)
  if x < 96 or x > 1004 or y < 196:g.draw_line(Vector2(x,y),Vector2(x-4,y+13),Color(0.7,0.8,0.82,0.18),1,true)
 for i in range(35):
  var x := 89+fposmod(i*137.0,930)
  g.draw_line(Vector2(x,663),Vector2(x+17,670+fposmod(i*7.0,17)),Color("172124"),5,true)
 if g.move_marker_time > 0:g.draw_arc(g.move_marker-Vector2(0,2),12,0,TAU,24,Color(0.8,0.73,0.53,g.move_marker_time),1,true)
 g.draw_set_transform(Vector2.ZERO)

func residence_details(g: Node2D) -> void:
 var home: ResidenceSystem = g.residence
 if home.current == "row":
  for x in [127,960]:
   for y in range(235,605,35):
    g.draw_line(Vector2(x,y),Vector2(x+sin(y)*16,y+28),Color("455340"),4,true)
  for x in range(142,960,92): g.draw_line(Vector2(x,207),Vector2(x+41,194),Color("81705b"),5,true)
 elif home.current == "depot":
  for x in range(134,970,64):
   g.draw_line(Vector2(x,455),Vector2(x,633),Color(0.3,0.39,0.45,0.3),2,true)
  for x in [128,854]:
   g.draw_rect(Rect2(x,548,100,88),Color("3d4a4e"))
   g.draw_line(Vector2(x,548),Vector2(x+100,636),Color("7d7763"),4,true)
  g.draw_rect(Rect2(872,467,85,31),Color("ba9b4d"))
  for x in range(880,947,16): g.draw_line(Vector2(x,470),Vector2(x+11,494),Color("343d3c"),5,true)
 var sec: Dictionary = home.security
 var tint := Color("748b83").lerp(Color("584b3c"),1-home.condition/100)
 if sec["gate"] > 0:
  g.draw_rect(Rect2(117,536,48,104),Color("242c2a"))
  for y in range(546,632,19):g.draw_line(Vector2(120,y),Vector2(164,y),tint,5+sec["gate"],true)
  g.draw_line(Vector2(119,540),Vector2(161,637),tint,4,true)
 if sec["mesh"] > 0:
  for at in [Vector2(165,266),Vector2(457,259),Vector2(893,268)]:
   var width := 54 if at.x > 800 else 82
   for x in range(5,width,15):g.draw_line(at+Vector2(x,2),at+Vector2(x,123),tint,2,true)
   for y in range(8,120,17):g.draw_line(at+Vector2(2,y),at+Vector2(width,y),tint,1,true)
 if sec["alarm"] > 0:
  g.draw_line(Vector2(116,535),Vector2(178,529),Color("b7ad87"),1,true)
  for x in [131,153]:
   g.draw_line(Vector2(x,532),Vector2(x,547),Color("b7ad87"),1,true)
   g.draw_circle(Vector2(x,549),4,Color("b7ad87"))
 if sec["stakes"] > 0:
  for x in [72,83,94]:
   g.draw_line(Vector2(x,662),Vector2(x+12,610),tint,5,true)
   g.draw_line(Vector2(x+16,661),Vector2(x-2,615),tint,4,true)
 if home.guitar:
  g.draw_circle(Vector2(584,405),10,Color("a58a5b"))
  g.draw_circle(Vector2(584,393),7,Color("a58a5b"))
  g.draw_line(Vector2(584,390),Vector2(589,365),Color("bca177"),4,true)
  g.draw_circle(Vector2(584,399),3,Color("343832"))

func room(c: CanvasItem, rect: Rect2, tint: Color, id: String='shelter') -> void:
 RealismAssets.wall(c,rect,id,.87 if rect.position.y>435 else 1.0)
 for band in range(12):c.draw_rect(Rect2(rect.position+Vector2(0,band*rect.size.y/12),Vector2(rect.size.x,rect.size.y/12+1)),Color(0.02,0.035,0.035,.12-band*.006))
 c.draw_rect(Rect2(rect.position,Vector2(rect.size.x,10)),Color(0.02,0.025,0.025,.45))

func expedition(c: CanvasItem, state: ExpeditionState, camera: float) -> void:
 map_scenery.draw(c,state,camera,c.game.weather_time,self)
