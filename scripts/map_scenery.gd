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
	# Distant skyline moves at a different speed to the walkable foreground.
	for band in range(14): rect(camera,210+band*32,1095,33,Color("283945").lerp(Color("101e25"),band/14.0))
	for i in range(23):
		var x := i*212.0+camera*0.65-100
		var high := 55.0+fposmod(i*71,125)
		rect(x,510-high,147,high+150,Color("192a33"))
		for j in range(3): rect(x+16+j*38,529-high,5,10,Color(0.7,0.67,0.48,0.14))
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
	art.room(canvas,Rect2(x-camera,ceiling,end-x,floor_y-ceiling),tint)
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
	for pos in range(int(x+60),int(end-55),190):
		var y := ceiling+19
		if kind in ["server","store"]:
			rect(pos,y,85,23,Color("37413d"));line(Vector2(pos+4,y+7),Vector2(pos+78,y+7),accent.darkened(.25),1)
		elif kind in ["ward","pharmacy","pump","control","pipe"]:
			rect(pos,y,89,33,Color("243e44"))
			for j in range(3): rect(pos+4+j*29,y+3,23,26,Color("698d8c"))
			line(Vector2(pos,y+35),Vector2(pos+92,y+35),Color("a2b8a6"),3)
		elif kind in ["machine","workshop","generator"]:
			rect(pos,y+12,76,39,Color("34403c"));rect(pos+5,y+17,66,29,Color("838773"),false,2)
			for j in range(4): line(Vector2(pos+8+j*17,y+18),Vector2(pos+8+j*17,y+43),Color("9ca08a"),1)
		elif kind == "office":
			rect(pos,y+12,78,43,Color("8e896b"));rect(pos+8,y+18,22,25,Color("c6c5a9"));rect(pos+40,y+25,25,18,Color("aaa991"))
		else:
			art.window(canvas,Vector2(pos-camera,y),Vector2(68,minf(65,floor_y-y-25)))
	for i in range(6):
		var stain_x := x+fposmod(i*137.0+17,end-x-20)
		line(Vector2(stain_x,ceiling+12),Vector2(stain_x+7,ceiling+46+i%3*10),Color(0.03,0.05,0.04,.25),3)
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
	polygon([Vector2(x,y),Vector2(x+w,y),Vector2(x+w+16,y+21),Vector2(x-12,y+21)],tint.darkened(.24))
	for j in range(8): rect(x+j*w/8,y+19,w/16,9,tint)
	for dx in [0,w]: line(Vector2(x+dx,y),Vector2(x+dx,618),Color("6b7163"),3)

func shelf(x: float,y: float,tint: Color) -> void:
	rect(x-35,y-84,70,83,Color("35413b"))
	for yy in [-80,-52,-24]:
		line(Vector2(x-37,y+yy+20),Vector2(x+37,y+yy+20),Color("8b8a70"),3)
		for j in range(4): rect(x-29+j*16,y+yy+4,10,15,tint.darkened(.08+j*.05))
	for dx in [-37,37]: line(Vector2(x+dx,y-86),Vector2(x+dx,y),Color("747e70"),3)

func sofa(x: float,y: float,tint: Color) -> void:
	rect(x-57,y-47,112,40,tint.darkened(.2));rect(x-51,y-42,100,20,tint)
	for dx in [-57,47]: rect(x+dx,y-32,11,29,tint.lightened(.07))
	for dx in [-45,36]: line(Vector2(x+dx,y-5),Vector2(x+dx,y),Color("283431"),5)
	line(Vector2(x,y-39),Vector2(x,y-12),Color("47554b"),2)

func bed(x: float,y: float,tint: Color) -> void:
	for dx in [-60,54]: line(Vector2(x+dx,y-31),Vector2(x+dx,y),Color("8c9c91"),4)
	rect(x-62,y-29,120,14,Color("b9b8a3"));rect(x-29,y-32,88,16,tint);rect(x-56,y-33,23,9,Color("d1cdb7"))
	line(Vector2(x-64,y-13),Vector2(x+61,y-13),Color("647d75"),3)

func chair(x: float,y: float) -> void:
	rect(x-13,y-44,26,23,Color("68766a"));line(Vector2(x-14,y-20),Vector2(x+15,y-20),Color("9ca18c"),4)
	for dx in [-11,11]: line(Vector2(x+dx,y-18),Vector2(x+dx*1.3,y),Color("596959"),3)

func radiator(x: float,y: float) -> void:
	for j in range(8): rect(x+j*6,y-34,4,30,Color("7b8678"))
	line(Vector2(x-3,y-35),Vector2(x+52,y-35),Color("929985"),3)

func counter(x: float,y: float,tint: Color) -> void:
	rect(x-55,y-47,110,47,Color("5b6757"));rect(x-60,y-50,120,5,tint.lightened(.14))
	for dx in [-45,-12,21]: rect(x+dx,y-37,26,30,Color("85917a"),false)
	circle(Vector2(x+20,y-54),11,Color("3d4a44"));line(Vector2(x+30,y-54),Vector2(x+49,y-54),Color("a4aa93"),3)

func cross(x: float,y: float,tint: Color) -> void:
	rect(x-17,y-5,34,10,tint);rect(x-5,y-17,10,34,tint)

func curtain(x: float,y: float,tint: Color) -> void:
	line(Vector2(x-45,y),Vector2(x+50,y),Color("939d92"),2)
	for j in range(9): rect(x-44+j*8,y+3,7,81,tint.darkened(.1 if j%2 else .0))

func car(x: float,y: float,tint: Color) -> void:
	polygon([Vector2(x-91,y-21),Vector2(x-78,y-45),Vector2(x-40,y-49),Vector2(x-15,y-73),Vector2(x+47,y-71),Vector2(x+70,y-45),Vector2(x+102,y-35),Vector2(x+104,y-15)],tint)
	polygon([Vector2(x-26,y-47),Vector2(x-7,y-67),Vector2(x+39,y-65),Vector2(x+58,y-46)],Color("2e4247"))
	for dx in [-55,65]: circle(Vector2(x+dx,y-14),15,Color("202b2c"));circle(Vector2(x+dx,y-14),7,Color("777c70"))
	line(Vector2(x-88,y-31),Vector2(x+98,y-29),tint.lightened(.2),2)

func machine(x: float,y: float,tint: Color) -> void:
	rect(x-56,y-85,112,76,Color("505e58"));rect(x-63,y-12,126,12,Color("39463f"))
	rect(x-48,y-77,55,45,Color("283b3c"));rect(x+16,y-72,29,23,Color("9b9c7d"))
	for j in range(3): circle(Vector2(x+23+j*8,y-59),2,tint)
	circle(Vector2(x-16,y-53),17,Color("6b7971"));circle(Vector2(x-16,y-53),7,Color("263632"))
	line(Vector2(x-44,y-23),Vector2(x+45,y-23),Color("84917b"),3)

func barrel(x: float,y: float,tint: Color) -> void:
	rect(x-22,y-56,44,56,tint)
	for yy in [-51,-16]: line(Vector2(x-23,y+yy),Vector2(x+23,y+yy),tint.lightened(.23),4)
	circle(Vector2(x+8,y-39),5,tint.darkened(.4))

func tank(x: float,y: float,tint: Color) -> void:
	rect(x-55,y-113,110,99,tint.darkened(.1));circle(Vector2(x,y-110),54,tint)
	rect(x-56,y-107,112,90,tint)
	for dx in [-36,36]: line(Vector2(x+dx,y-19),Vector2(x+dx,y),Color("53675e"),8)
	line(Vector2(x+57,y-43),Vector2(x+89,y-43),Color("94a593"),8)
	circle(Vector2(x,y-59),18,Color("394f4c"));cross(x,y-59,Color("8ba793"))

func pipe(x: float,top: float,bottom: float,tint: Color) -> void:
	line(Vector2(x,top),Vector2(x,bottom-13),Color("344d4b"),17)
	line(Vector2(x-3,top),Vector2(x-3,bottom-13),tint.darkened(.2),6)
	line(Vector2(x,top+22),Vector2(x+90,top+22),Color("728982"),13)
	for yy in range(int(top+10),int(bottom-15),46): line(Vector2(x-12,yy),Vector2(x+12,yy),Color("899a86"),3)
	circle(Vector2(x+17,bottom-56),15,Color("a28b67"));circle(Vector2(x+17,bottom-56),10,Color("344a45"));cross(x+17,bottom-56,Color("9a9f84"))

func console(x: float,y: float,tint: Color) -> void:
	rect(x-46,y-62,92,62,Color("4e635f"));rect(x-40,y-57,80,31,Color("263b3e"))
	for j in range(5):
		rect(x-34+j*14,y-50,9,10,Color("87b5a5").darkened(j*.08))
		circle(Vector2(x-28+j*13,y-13),2,tint)
	line(Vector2(x-45,y-25),Vector2(x+46,y-25),Color("90a393"),2)

func server(x: float,y: float,tint: Color) -> void:
	rect(x-28,y-98,56,98,Color("35494c"));rect(x-25,y-95,50,92,Color("667a78"),false,2)
	for j in range(7):
		rect(x-20,y-86+j*12,33,5,Color("263a3e"))
		circle(Vector2(x+19,y-83+j*12),1.5,tint if sin(clock*.8+j)>-.4 else Color("394a48"))

func freezer(x: float,y: float) -> void:
	rect(x-49,y-61,98,61,Color("849c95"));rect(x-47,y-64,94,7,Color("bdc9b8"))
	line(Vector2(x,y-58),Vector2(x,y-4),Color("3d5b55"),2)
	for dx in [-10,10]: line(Vector2(x+dx,y-42),Vector2(x+dx,y-24),Color("dae0c9"),3)

func stall(x: float,y: float,tint: Color) -> void:
	rect(x-30,y-39,120,39,Color("647352"));rect(x-35,y-43,130,5,Color("a2a17d"))
	for j in range(4):
		rect(x-22+j*27,y-55,24,12,Color("7c6b45"))
		for k in range(3): circle(Vector2(x-17+j*27+k*6,y-57),3,tint)

func carriage(x: float,y: float,tint: Color) -> void:
	rect(x-116,y-113,232,90,tint.darkened(.35));rect(x-108,y-106,216,77,tint.darkened(.18))
	for j in range(12): line(Vector2(x-103+j*18,y-103),Vector2(x-103+j*18,y-33),tint.darkened(.35),2)
	rect(x-112,y-32,224,11,Color("303c3a"))
	for dx in [-77,-50,50,77]: circle(Vector2(x+dx,y-11),10,Color("263032"));circle(Vector2(x+dx,y-11),4,Color("8e8f79"))

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

static func container(c: CanvasItem,at: Vector2,kind: String,body: Color,edge: Color,empty: bool) -> void:
	# Uniform bounds retain the established interaction rectangle. Empty containers
	# use only neutral grey, including shelves, contents, handles and open lids.
	var x := at.x;var y := at.y
	match kind:
		"shelf","cabinet","locker","console":
			c.draw_rect(Rect2(x-29,y-76,58,76),body)
			c.draw_rect(Rect2(x-27,y-74,54,72),edge,false,2)
			for yy in [-55,-31]: c.draw_line(Vector2(x-26,y+yy),Vector2(x+26,y+yy),edge,2,true)
			if not empty:
				for j in range(6): c.draw_rect(Rect2(x-20+j%3*15,y-69+j/3*25,9,16),edge.darkened(.17))
			elif kind != "shelf": c.draw_line(Vector2(x-28,y-74),Vector2(x-42,y-69),edge,3,true)
		"barrel","tank":
			c.draw_rect(Rect2(x-25,y-55,50,55),body)
			for yy in [-52,-15]: c.draw_line(Vector2(x-25,y+yy),Vector2(x+25,y+yy),edge,3,true)
			c.draw_circle(Vector2(x+9,y-37),6,edge)
			if empty: c.draw_line(Vector2(x-24,y-56),Vector2(x+10,y-65),edge,3,true)
		"freezer","stall":
			c.draw_rect(Rect2(x-38,y-45,76,45),body);c.draw_rect(Rect2(x-37,y-44,74,43),edge,false,2)
			c.draw_line(Vector2(x,y-42),Vector2(x,y-4),edge,2,true)
			c.draw_line(Vector2(x-12,y-30),Vector2(x+12,y-30),edge,3,true)
			if empty: c.draw_line(Vector2(x-38,y-46),Vector2(x+17,y-58),edge,3,true)
		_:
			c.draw_rect(Rect2(x-25,y-38,50,38),body);c.draw_rect(Rect2(x-23,y-36,46,34),edge,false,2)
			c.draw_line(Vector2(x-22,y-32),Vector2(x+22,y-6),edge.darkened(.2),2,true)
			if empty: c.draw_line(Vector2(x-25,y-39),Vector2(x+12,y-49),edge,3,true)

static func cover(c: CanvasItem,at: Vector2,width: float,id: String) -> void:
	var tint := Color("647566") if id in ["street","residential","market"] else Color("637879") if id in ["clinic","waterworks"] else Color("7a7665")
	c.draw_rect(Rect2(at-Vector2(0,50),Vector2(width,50)),tint.darkened(.3))
	c.draw_rect(Rect2(at-Vector2(0,50),Vector2(width,4)),tint.lightened(.3))
	match id:
		"clinic":
			for x in range(8,int(width-6),20): c.draw_line(at+Vector2(x,-40),at+Vector2(x,-8),tint,2,true)
		"market","works","depot","evac":
			for x in range(6,int(width),27): c.draw_rect(Rect2(at+Vector2(x,-43),Vector2(minf(23,width-x-2),35)),tint,false,1)
		"waterworks":
			for y in [-36,-17]: c.draw_line(at+Vector2(5,y),at+Vector2(width-5,y),tint.lightened(.05),9,true)
		"broadcast":
			for y in [-38,-23,-8]: c.draw_line(at+Vector2(7,y),at+Vector2(width-7,y),tint,3,true)
		_:
			c.draw_rect(Rect2(at+Vector2(8,-38),Vector2(width-16,17)),tint)
			c.draw_line(at+Vector2(width/2,-36),at+Vector2(width/2,-5),tint.darkened(.4),2,true)
