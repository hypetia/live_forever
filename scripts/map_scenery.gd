class_name MapScenery
extends RefCounted
## Original cutaway set dressing. Geometry stays aligned to simulation floors.
var canvas: CanvasItem
var camera := 0.0
var clock := 0.0

func rect(x: float,y: float,w: float,h: float,color: Color,fill: bool = true,stroke: float = 1.0) -> void:
 if x+w-camera < -60 or x-camera > 1110: return
 canvas.draw_rect(Rect2(x-camera,y,w,h),color,fill,stroke if not fill else -1.0)

func line(a: Vector2,b: Vector2,color: Color,width: float = 1.0) -> void:
 if maxf(a.x,b.x)-camera < -60 or minf(a.x,b.x)-camera > 1110: return
 canvas.draw_line(a-Vector2(camera,0),b-Vector2(camera,0),color,width,true)

func circle(p: Vector2,r: float,color: Color) -> void:
 if p.x+r-camera < -60 or p.x-r-camera > 1110: return
 canvas.draw_circle(p-Vector2(camera,0),r,color)

func polygon(points: Array,color: Color) -> void:
 var out := PackedVector2Array()
 for p: Vector2 in points: out.append(p-Vector2(camera,0))
 canvas.draw_colored_polygon(out,color)

func draw(c: CanvasItem,state: ExpeditionState,scroll: float,time: float,art: SceneArt) -> void:
 canvas = c; camera = scroll; clock = time
 var id := state.location_id
 var accent := Color(str(state.area()["accent"]))
 var width := float(state.area()["width"])
 RealismAssets.backdrop(canvas,Rect2(0,210,1095,430),id,camera,true)
 if id in ["waterworks","evac","street"]:
  rect(0,639,width,52,Color("203f4b"))
  for i in range(40):
   var x := fposmod(i*113.0+time*8,width)
   line(Vector2(x,647+i%5*8),Vector2(x+39,647+i%5*8),Color(0.43,0.62,0.65,0.2))
 if id in ["broadcast","residential"]:
  for i in range(11):
   var x := i*390.0+camera*0.3-200
   polygon([Vector2(x,560),Vector2(x+220,302+i%3*35),Vector2(x+450,560)],Color("23383e"))
 if id in ["works","depot","evac"]:
  for x in range(420,int(width),970):
   line(Vector2(x,302),Vector2(x,557),Color("34474c"),9)
   line(Vector2(x-90,301),Vector2(x+440,301),Color("34474c"),8)
   line(Vector2(x+230,305),Vector2(x+230,414+sin(time*.25)*3),Color("64706a"),1)
   line(Vector2(x,320),Vector2(x+170,302),Color("5b6765"),2)
 if id == "evac":
  polygon([Vector2(810,579),Vector2(1620,579),Vector2(1530,631),Vector2(880,631)],Color("3a535b"))
  rect(1010,488,370,90,Color("5d7479"))
  for xx in range(1030,1360,56): rect(xx,506,38,29,Color("a2b4a8"))
  line(Vector2(1220,487),Vector2(1220,440),Color("87998e"),3)
  line(Vector2(1195,450),Vector2(1245,450),Color("87998e"),2)
 if id == "broadcast":
  for x in [710.0,2320.0,3150.0]:
   line(Vector2(x,258),Vector2(x-57,398),Color("4e5a65"),5)
   line(Vector2(x,258),Vector2(x+57,398),Color("4e5a65"),5)
   for j in range(5): line(Vector2(x-j*10,268+j*26),Vector2(x+j*10,268+j*26),Color("7e8994"),2)
   circle(Vector2(x,255),3,Color("df735a") if sin(time*1.4)>0 else Color("66473f"))
 RealismAssets.wall(canvas,Rect2(-camera,429,width,191),id,.48)
 # A continuous catwalk outside the rooms makes every visible floor traversable.
 rect(state.upper_left(),390,width-state.upper_left()-120,22,Color("333d3d"))
 for x in range(int(state.upper_left()),int(width-120),120):
  line(Vector2(x,414),Vector2(x,616),Color("303c3b"),7)
  line(Vector2(x,415),Vector2(x+80,463),Color("424d46"),3)
 for room: Array in LocationEnvironment.profile(id)["rooms"]:
  room_draw(art,room,accent)
 # Every map has recognisable objects at the entrance as well as at the far end.
 match id:
  "street":
   for x in [510.0,1110.0,1770.0]: car(x,620,Color("687367"))
   for x in [240.0,780.0,1350.0]: awning(x,440,140,accent)
   lamp(1160,620,accent)
  "clinic":
   car(550,620,Color("afb7a9")); cross(550,574,Color("af7564"))
   cross(1110,334,Color("c3d6cc"))
   for x in [1660.0,2200.0]: bed(x,400,Color("89a29a"))
   for x in [1190.0,1800.0]: curtain(x,294,Color("6b8d86"))
  "works":
   for x in [660.0,1510.0,2220.0]: machine(x,620,accent)
   for x in [1880.0,2510.0]: barrel(x,620,Color("82705a"))
   for x in range(960,2850,220): line(Vector2(x,294),Vector2(x+80,294),Color("9c9677"),3)
  "residential":
   for x in [730.0,1420.0,1950.0]:
    line(Vector2(x,309),Vector2(x+190,318),Color("89948d"),1)
    for j in range(4): rect(x+20+j*38,311+j*2,21,34,Color("797e73").darkened(j*.06))
   for x in [410.0,1260.0,1910.0]: radiator(x,620)
   for x in [780.0,1350.0,2000.0]: rect(x,391,140,6,Color("d0d7d2"))
  "market":
   for x in [240.0,810.0,1230.0,1860.0,2250.0]:
    awning(x,456,220,Color("a6976d") if int(x)%3 else Color("768a6c"))
    stall(x+20,620,accent)
   for x in [1650.0,2570.0]: freezer(x,620)
  "waterworks":
   for x in [560.0,1510.0,2520.0]: tank(x,620,Color("718b88"))
   for x in [940.0,2140.0]: pipe(x,445,620,accent)
   for x in [1600.0,2680.0]: console(x,400,accent)
  "depot":
   for x in range(0,int(width),115): rect(x,642,62,9,Color("6f6859"))
   for y in [639.0,654.0]: line(Vector2(0,y),Vector2(width,y),Color("9b9b8a"),3)
   for x in [640.0,1540.0,2560.0,3370.0]: carriage(x,620,accent)
   for x in [420.0,2270.0]: lamp(x,620,accent)
  "broadcast":
   for x in [460.0,2340.0]:
    line(Vector2(x,472),Vector2(x+45,538),Color("64747c"),8)
    canvas.draw_arc(Vector2(x-camera,472),44,0.05,PI-.05,28,Color("8b9ea3"),6,true)
    line(Vector2(x-40,475),Vector2(x+40,475),Color("a1afb0"),3)
   for x in [1920.0,2680.0,3140.0]: server(x,400,accent)
   machine(2220,620,accent)
  "evac":
   for x in [480.0,1370.0,2590.0,3340.0]:
    line(Vector2(x,625),Vector2(x,687),Color("6c6956"),14)
    circle(Vector2(x,612),15,Color("898773"));circle(Vector2(x,612),8,Color("384548"))
   polygon([Vector2(770,655),Vector2(1290,655),Vector2(1230,691),Vector2(830,691)],Color("34434b"))
   for x in [1180.0,2780.0]: carriage(x,620,Color("537379"))
   lamp(1980,620,accent)
 # Surface visuals match the exact intervals used by movement and hearing.
 for z: Array in LocationEnvironment.zones(id,state.condition): surface_draw(z)
 for i in range(52):
  var x := 175+fposmod(i*137.0,width-310)
  var y := 628.0+i%4*4
  line(Vector2(x,y),Vector2(x+12+i%5*3,y+3),Color("303c36"),3)
 for x in state.ladders(): ladder(x,accent)
 if not state.route_open: ladder(state.route_x(),Color("58605a"))
 rect(0,620,width,5,Color("879184"))
 rect(state.upper_left(),400,width-state.upper_left()-120,5,Color("96a291"))

func room_draw(art: SceneArt,data: Array,accent: Color) -> void:
 var x := float(data[0]);var end := float(data[1]);var floor_y: float = ExpeditionState.FLOOR_Y[int(data[2])]
 if end-camera < -60 or x-camera > 1110: return
 var ceiling := 285.0 if int(data[2]) == 1 else 427.0
 var kind: String = data[3]
 var tint := Color("63726a")
 if kind in ["ward","pharmacy","pump","control"]: tint = Color("6a8582")
 if kind in ["machine","workshop","generator","store"]: tint = Color("756e5d")
 if kind in ["bedroom","flat","kitchen"]: tint = Color("807a68")
 if kind == "stalls":
  # Open-air stalls retain the skyline behind them, rather than another room.
  for pos in range(int(x+35),int(end-30),140):
   line(Vector2(pos,ceiling+28),Vector2(pos,floor_y-5),Color("687969"),4)
  return
 art.room(canvas,Rect2(x-camera,ceiling,end-x,floor_y-ceiling),tint,canvas.game.expedition.location_id)
 if kind in ["ward","pharmacy","pump","control","pipe"]:
  for yy in range(int(ceiling+12),int(floor_y-4),28): line(Vector2(x+10,yy),Vector2(end-4,yy),Color(.48,.62,.57,.16),1)
  for xx in range(int(x+12),int(end-4),39): line(Vector2(xx,ceiling+12),Vector2(xx,floor_y-3),Color(.16,.28,.26,.2),1)
 elif kind in ["bedroom","flat","kitchen"]:
  for xx in range(int(x+25),int(end-15),34):
   line(Vector2(xx,ceiling+9),Vector2(xx,floor_y-4),Color(.6,.56,.42,.12),2)
   rect(xx-3,ceiling+48,6,9,Color(.37,.42,.3,.23))
 elif kind in ["machine","workshop","generator"]:
  for xx in range(int(x+16),int(end-4),38):
   line(Vector2(xx,ceiling+13),Vector2(xx,floor_y-5),Color(.12,.18,.16,.36),4)
   circle(Vector2(xx,ceiling+21),2,Color("a2a089"))
  line(Vector2(x+25,ceiling+23),Vector2(end-20,ceiling+30),Color("242e29"),3)

 rect(x,ceiling,end-x,8,Color("232c2d"))
 # Partitions stop above the walkable doorway, keeping the real path visible.
 rect(x,ceiling,9,maxf(12,floor_y-ceiling-92),Color("303c3a"))
 line(Vector2(x+9,floor_y-92),Vector2(x+9,floor_y-5),Color("a3997c"),2)
 var mid := (x+end)*.5
 match kind:
  "ward","bedroom": bed(mid+40,floor_y,Color("87978a"))
  "flat","waiting","hall": sofa(mid,floor_y,Color("778071")); radiator(x+32,floor_y)
  "kitchen","canteen": counter(mid-40,floor_y,accent);shelf(end-72,floor_y,accent)
  "pharmacy","store","shop": shelf(mid-30,floor_y,accent);shelf(end-75,floor_y,accent)
  "control","office": console(mid,floor_y,accent);chair(mid+70,floor_y)
  "server": server(mid,floor_y,accent);server(end-60,floor_y,accent)
  "pump","pipe": pipe(mid,ceiling+30,floor_y,accent)
  "machine","generator","workshop": machine(mid,floor_y,accent)
  "coldroom": freezer(mid,floor_y)
 lamp(mid-62,floor_y,accent,true)

func ladder(x: float,accent: Color) -> void:
 for y in range(408,620,18): line(Vector2(x-12,y),Vector2(x+12,y),accent.lightened(.12),3)
 for dx in [-14,14]: line(Vector2(x+dx,400),Vector2(x+dx,620),accent,3)

func awning(x: float,y: float,w: float,tint: Color) -> void:
 var source:=RealismAssets.object_rect(7);source.position.y+=source.size.y*.3;source.size.y*=.6
 RealismAssets.region_quad(canvas,RealismAssets.PROPS,PackedVector2Array([Vector2(x-camera,y),Vector2(x+w-camera,y),Vector2(x+w+16-camera,y+21),Vector2(x-12-camera,y+21)]),source,Color(.86,.91,.83))
 for j in range(12):line(Vector2(x+j*w/12,y+19),Vector2(x+j*w/12-1,y+23+j%3),Color('777c66'),1)
 for dx in [0,w]:line(Vector2(x+dx,y),Vector2(x+dx,618),Color('555f55'),3)

func shelf(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,4,Rect2(x-camera-33,y-84,66,84),Color(.76,.80,.76))


func sofa(x: float,y: float,tint: Color) -> void:
 rect(x-57,y-47,112,40,tint.darkened(.2));rect(x-51,y-42,100,20,tint)
 for dx in [-57,47]: rect(x+dx,y-32,11,29,tint.lightened(.07))
 for dx in [-45,36]: line(Vector2(x+dx,y-5),Vector2(x+dx,y),Color("283431"),5)
 line(Vector2(x,y-39),Vector2(x,y-12),Color("47554b"),2)

func bed(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,0,Rect2(x-camera-62,y-77,124,77),Color(.84,.87,.83))


func chair(x: float,y: float) -> void:
 rect(x-13,y-44,26,23,Color("68766a"));line(Vector2(x-14,y-20),Vector2(x+15,y-20),Color("9ca18c"),4)
 for dx in [-11,11]: line(Vector2(x+dx,y-18),Vector2(x+dx*1.3,y),Color("596959"),3)

func radiator(x: float,y: float) -> void:
 for j in range(8): rect(x+j*6,y-34,4,30,Color("7b8678"))
 line(Vector2(x-3,y-35),Vector2(x+52,y-35),Color("929985"),3)

func counter(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,1,Rect2(x-camera-60,y-62,120,62),Color(.76,.80,.76))


func cross(x: float,y: float,tint: Color) -> void:
 rect(x-17,y-5,34,10,tint);rect(x-5,y-17,10,34,tint)

func curtain(x: float,y: float,tint: Color) -> void:
 line(Vector2(x-45,y),Vector2(x+50,y),Color("939d92"),2)
 for j in range(9): rect(x-44+j*8,y+3,7,81,tint.darkened(.1 if j%2 else .0))

func car(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,14,Rect2(x-camera-105,y-81,210,81),Color(.84,.87,.83))


func machine(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,13,Rect2(x-camera-63,y-91,126,91),Color(.76,.80,.76))


func barrel(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,9,Rect2(x-camera-24,y-75,48,75),Color(.84,.87,.83))


func tank(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,12,Rect2(x-camera-70,y-94,140,94),Color(.84,.87,.83))


func pipe(x: float,top: float,bottom: float,tint: Color) -> void:
 line(Vector2(x,top),Vector2(x,bottom-13),Color("344d4b"),17)
 line(Vector2(x-3,top),Vector2(x-3,bottom-13),tint.darkened(.2),6)
 line(Vector2(x,top+22),Vector2(x+90,top+22),Color("728982"),13)
 for yy in range(int(top+10),int(bottom-15),46): line(Vector2(x-12,yy),Vector2(x+12,yy),Color("899a86"),3)
 circle(Vector2(x+17,bottom-56),15,Color("a28b67"));circle(Vector2(x+17,bottom-56),10,Color("344a45"));cross(x+17,bottom-56,Color("9a9f84"))

func console(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,13,Rect2(x-camera-46,y-67,92,67),Color(.84,.87,.83))


func server(x: float,y: float,tint: Color) -> void:
 rect(x-28,y-98,56,98,Color("35494c"));rect(x-25,y-95,50,92,Color("667a78"),false,2)
 for j in range(7):
  rect(x-20,y-86+j*12,33,5,Color("263a3e"))
  circle(Vector2(x+19,y-83+j*12),1.5,tint if sin(clock*.8+j)>-.4 else Color("394a48"))

func freezer(x: float,y: float) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,5,Rect2(x-camera-34,y-99,68,99),Color(.84,.87,.83))


func stall(x: float,y: float,tint: Color) -> void:
 rect(x-30,y-39,120,39,Color("647352"));rect(x-35,y-43,130,5,Color("a2a17d"))
 for j in range(4):
  rect(x-22+j*27,y-55,24,12,Color("7c6b45"))
  for k in range(3): circle(Vector2(x-17+j*27+k*6,y-57),3,tint)

func carriage(x: float,y: float,tint: Color) -> void:
 if x-camera < -180 or x-camera>1275:return
 RealismAssets.prop(canvas,15,Rect2(x-camera-134,y-108,268,108),Color(.84,.87,.83))


func lamp(x: float,bottom: float,tint: Color,inside: bool = false) -> void:
 var top := bottom-100 if inside else 445.0
 if not inside: line(Vector2(x,top),Vector2(x,bottom),Color("626f65"),4)
 line(Vector2(x-12,top),Vector2(x+12,top),tint.lightened(.3),3)
 for j in range(6,0,-1): circle(Vector2(x,top+28),j*11,Color(.88,.76,.48,.009))
 polygon([Vector2(x-10,top+3),Vector2(x+10,top+3),Vector2(x+54,bottom-6),Vector2(x-49,bottom-6)],Color(.87,.76,.53,.035))

func surface_draw(z: Array) -> void:
 var bottom: float = ExpeditionState.FLOOR_Y[int(z[2])]
 var start := float(z[0]);var end := float(z[1]);var kind: String = z[3]
 var tint := Color(str(LocationEnvironment.SURFACES[kind]["color"]))
 if kind in ["water","oil","snow"]:
  polygon([Vector2(start,bottom-1),Vector2(start+29,bottom-5),Vector2(end-35,bottom-4),Vector2(end,bottom+1),Vector2(end-17,bottom+8),Vector2(start+17,bottom+6)],Color(tint,.6))
 for j in range(18):
  var x := start+fposmod(j*31.0,end-start)
  var yy := bottom-2+fposmod(j*11,8)
  if kind == "glass": polygon([Vector2(x,yy),Vector2(x+6,yy-5),Vector2(x+10,yy+1)],Color(tint,.8))
  elif kind == "metal": line(Vector2(x,yy),Vector2(x+9,yy-6),tint,3)
  elif kind == "water": line(Vector2(x,yy),Vector2(x+12+sin(clock*1.6+j)*3,yy),Color(tint,.8),1)
  elif kind == "snow": circle(Vector2(x,yy),4,Color(tint,.8))

static func container(c: CanvasItem,at: Vector2,kind: String,body: Color,edge: Color,empty: bool,opened: float=0.0) -> void:
 var index:int={'shelf':4,'cabinet':4,'locker':11,'console':13,'barrel':9,'tank':12,'freezer':5,'stall':6,'toolbox':8}.get(kind,6)
 var size:Vector2=Vector2(56,76) if kind in ['shelf','cabinet','locker','freezer'] else Vector2(50,75) if kind=='barrel' else Vector2(80,54) if kind=='tank' else Vector2(76,56) if kind=='console' else Vector2(63,37) if kind=='toolbox' else Vector2(58,44)
 var destination:=Rect2(at-Vector2(size.x*.5,size.y),size)
 RealismAssets.prop(c,index,destination,Color(.73,.73,.73) if empty else Color(.95,.97,.91),empty)
 var progress:=clampf(opened,0,1)
 if kind in ['shelf','cabinet','locker','freezer','console']:
  if kind!='shelf' and progress>0:
   var hinge:=destination.position+Vector2(3,3)
   var width:=size.x*.85
   c.draw_rect(Rect2(hinge,Vector2(width,size.y-7)),Color(0.02,.025,.025,progress*.65))
   var leaf:=maxf(3,width*(1-progress))
   var source:=RealismAssets.object_rect(index);source.size.x*=.5
   RealismAssets.region_quad(c,RealismAssets.neutral_props() if empty else RealismAssets.PROPS,PackedVector2Array([hinge,hinge+Vector2(leaf,-progress*6),hinge+Vector2(leaf,size.y-7-progress*6),hinge+Vector2(0,size.y-7)]),source,Color(.6,.6,.6) if empty else Color(.85,.88,.82))
 elif progress>0:
  var hinge:=destination.position+Vector2(0,4)
  c.draw_rect(Rect2(hinge,Vector2(size.x,8)),Color(0.02,.025,.025,.8*progress))
  var source:=RealismAssets.object_rect(index);source.size.y*=.22
  RealismAssets.region_quad(c,RealismAssets.neutral_props() if empty else RealismAssets.PROPS,PackedVector2Array([hinge,hinge+Vector2(size.x*(1-.24*progress),-progress*29),hinge+Vector2(size.x*(1-.24*progress),5-progress*29),hinge+Vector2(0,5)]),source,Color(.7,.7,.7) if empty else Color.WHITE)
 # A restrained edge is reserved for actual hover/range feedback, never text.
 if edge==InteractionFeedback.READY or edge==InteractionFeedback.DISTANT:c.draw_rect(destination.grow(2),edge,false,1.2)

static func _lid(c: CanvasItem,at: Vector2,width: float,opened: float,body: Color,edge: Color) -> void:
 var tip:=at+Vector2(width*(1-.24*opened),-opened*29)
 c.draw_colored_polygon(PackedVector2Array([at,tip,tip+Vector2(0,5),at+Vector2(0,5)]),body.lightened(.08))
 c.draw_line(at,tip,edge,2,true)

static func cover(c: CanvasItem,at: Vector2,width: float,id: String) -> void:
 var index:=12 if id=='waterworks' else 11 if id in ['clinic','broadcast'] else 6
 var count:=maxi(1,roundi(width/65.0));var cell:=width/count
 for part in range(count):
  var height:=54.0 if index==12 else 60.0 if index==11 else 50.0
  RealismAssets.prop(c,index,Rect2(at+Vector2(part*cell,-height),Vector2(cell+2,height)),Color(.64,.70,.66))
