class_name SceneArt
extends RefCounted
## Original layered cutaway scenery. Floors and every hotspot retain real coordinates.
var plaster: ImageTexture
var wood: ImageTexture

func _init() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 71413
	noise.frequency = 0.13
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var grain := 0.52 + noise.get_noise_2d(x,y)*0.26
			if y % 31 == 0 or (x + (16 if y / 31 % 2 else 0)) % 47 == 0: grain -= 0.07
			image.set_pixel(x,y,Color(grain,grain*0.98,grain*0.91,1))
	plaster = ImageTexture.create_from_image(image)
	for y in range(128):
		for x in range(128):
			var grain := 0.36 + noise.get_noise_2d(x*0.4,y*4)*0.15
			if y % 15 == 0: grain *= 0.5
			image.set_pixel(x,y,Color(grain,grain*0.85,grain*0.67,1))
	wood = ImageTexture.create_from_image(image)

func shelter(g: Node2D) -> void:
	g.draw_rect(Rect2(0,0,1440,900),Color("0b1115"))
	g.draw_set_transform(g.world_offset(),0,g.world_scale())
	for band in range(30):
		g.draw_rect(Rect2(-100,80+band*21,1300,22),Color("202e35").lerp(Color("0c171c"),band/30.0))
	for i in range(23):
		var height := 100.0 + fposmod(i*79.0,190)
		var x := i*53.0-65 + sin(g.weather_time*0.06)*2
		g.draw_rect(Rect2(x,445-height,47,height+240),Color("15232b") if i%2 else Color("18282d"))
		for j in range(4): g.draw_rect(Rect2(x+10,450-height+j*29,4,7),Color(0.5,0.56,0.53,0.07))
	# The open upper storey reaches the roof; dark framing creates depth.
	g.draw_colored_polygon(PackedVector2Array([Vector2(87,210),Vector2(143,185),Vector2(959,194),Vector2(1010,211)]),Color("1d2526"))
	g.draw_rect(Rect2(97,207,905,449),Color("111a1b"))
	room(g,Rect2(112,219,874,211),Color("65706a"))
	room(g,Rect2(112,447,874,193),Color("465650"))
	g.draw_rect(Rect2(662,220,194,420),Color(0.03,0.05,0.05,0.45))
	for i in range(11):
		var x := 143+i*78
		g.draw_rect(Rect2(x,220,4,420),Color(0.02,0.03,0.03,0.16))
		g.draw_line(Vector2(x,220),Vector2(x+2,420),Color("4a524b"),1,true)
	# Broken plaster, long damp stains and exposed pipes.
	for i in range(21):
		var x := 135+fposmod(i*157.0,825)
		var y := 232+fposmod(i*83.0,167) + (220 if i%2 else 0)
		g.draw_colored_polygon(PackedVector2Array([Vector2(x,y),Vector2(x+24,y-6),Vector2(x+19,y+22),Vector2(x+37,y+35),Vector2(x+3,y+29)]),Color(0.12,0.16,0.15,0.24))
		g.draw_polyline(PackedVector2Array([Vector2(x+32,y-13),Vector2(x+37,y),Vector2(x+31,y+13),Vector2(x+37,y+27)]),Color(0.025,0.035,0.035,0.5),1,true)
	for x in [119,975]:
		g.draw_line(Vector2(x,224),Vector2(x,637),Color("171f20"),7,true)
		g.draw_line(Vector2(x+2,224),Vector2(x+2,637),Color("596056"),1,true)
	window(g,Vector2(165,266),Vector2(84,126))
	window(g,Vector2(457,259),Vector2(100,131))
	window(g,Vector2(893,268),Vector2(57,124))
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
		g.draw_line(point+Vector2(-18,0),point+Vector2(19,0),Color("717568"),4,true)
	g.draw_line(Vector2(674,409),Vector2(793,620),Color("757c6d"),2,true)
	for i in range(0,14,3):
		var point := ShelterNavigation.TOP_STAIR.lerp(ShelterNavigation.BOTTOM_STAIR,i/14.0)
		g.draw_line(point+Vector2(-17,-21),point+Vector2(-17,0),Color("757c6d"),2,true)
	# Beds, shelving and clutter are part of the rooms, not an interface panel.
	g.draw_texture_rect(wood,Rect2(285,404,127,14),true)
	g.draw_rect(Rect2(290,398,117,10),Color("7c8471"))
	g.draw_rect(Rect2(294,397,25,8),Color("b2af97"))
	for x in [292,402]:g.draw_line(Vector2(x,417),Vector2(x,430),Color("596257"),5,true)
	for y in [512,545,578,611]:g.draw_texture_rect(wood,Rect2(884,y,74,5),true)
	for x in [883,956]:g.draw_line(Vector2(x,499),Vector2(x,638),Color("596052"),4,true)
	for i in range(8):g.draw_rect(Rect2(892+(i%3)*21,520+(i/3)*33,15,24),Color("68705a") if i%2 else Color("77684d"))
	for x in [315,352]:
		g.draw_texture_rect(wood,Rect2(x,606,33,32),true)
		g.draw_line(Vector2(x,606),Vector2(x+31,636),Color("8a7a59"),2,true)
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
	for i in range(50):
		var x := fposmod(i*137.0-g.weather_time*37,1090)
		var y := 125+fposmod(i*79.0+g.weather_time*170,570)
		if x < 96 or x > 1004 or y < 196:g.draw_line(Vector2(x,y),Vector2(x-4,y+13),Color(0.7,0.8,0.82,0.18),1,true)
	for i in range(35):
		var x := 89+fposmod(i*137.0,930)
		g.draw_line(Vector2(x,663),Vector2(x+17,670+fposmod(i*7.0,17)),Color("172124"),5,true)
	if g.move_marker_time > 0:g.draw_arc(g.move_marker-Vector2(0,2),12,0,TAU,24,Color(0.8,0.73,0.53,g.move_marker_time),1,true)
	g.draw_set_transform(Vector2.ZERO)

func room(c: CanvasItem, rect: Rect2, tint: Color) -> void:
	c.draw_texture_rect(plaster,rect,true,tint)
	for band in range(12):c.draw_rect(Rect2(rect.position+Vector2(0,band*rect.size.y/12),Vector2(rect.size.x,rect.size.y/12+1)),Color(0.02,0.035,0.035,0.30-band*0.012))
	c.draw_rect(Rect2(rect.position,Vector2(rect.size.x,17)),Color(0.02,0.025,0.025,0.45))

func window(c: CanvasItem, at: Vector2, extent: Vector2) -> void:
	c.draw_rect(Rect2(at-Vector2(6,5),extent+Vector2(12,10)),Color("141e20"))
	c.draw_rect(Rect2(at,extent),Color("31454a"))
	for i in range(6):c.draw_rect(Rect2(at+Vector2(1,i*extent.y/6),Vector2(extent.x-2,extent.y/6)),Color(0.32,0.39,0.38,0.12-i*0.012))
	c.draw_line(at+Vector2(extent.x/2,0),at+Vector2(extent.x/2,extent.y),Color("758075"),3,true)
	c.draw_line(at+Vector2(0,extent.y*0.55),at+Vector2(extent.x,extent.y*0.55),Color("68756d"),3,true)
	c.draw_polyline(PackedVector2Array([at+Vector2(13,4),at+Vector2(22,21),at+Vector2(15,39),at+Vector2(28,52)]),Color("899184"),1,true)
	c.draw_line(at+Vector2(-4,extent.y-18),at+Vector2(extent.x+4,extent.y-41),Color("69624c"),8,true)
	c.draw_line(at+Vector2(2,extent.y-19),at+Vector2(extent.x,extent.y-42),Color("9a8a65"),1,true)
	c.draw_colored_polygon(PackedVector2Array([at+Vector2(1,extent.y),at+extent,at+extent+Vector2(100,39),at+Vector2(40,extent.y+39)]),Color(0.61,0.73,0.73,0.035))

func expedition(c: CanvasItem, state: ExpeditionState, camera: float) -> void:
	var upper := state.upper_left()
	var width: float = state.area()["width"]
	c.draw_texture_rect(plaster,Rect2(160-camera,429,850,191),true,Color("566158"))
	c.draw_texture_rect(plaster,Rect2(upper-camera,285,width-upper-120,335),true,Color(str(state.area()["color"])).lightened(0.3))
	for x in range(170,int(width),173):
		if x-camera < -80 or x-camera > 1160:continue
		c.draw_rect(Rect2(x-camera,434,7,186),Color(0.04,0.05,0.05,0.48))
		c.draw_line(Vector2(x-camera+4,435),Vector2(x-camera+4,620),Color("556158"),1,true)
		c.draw_polyline(PackedVector2Array([Vector2(x-camera+21,473),Vector2(x-camera+29,484),Vector2(x-camera+23,507),Vector2(x-camera+34,528)]),Color(0.03,0.045,0.04,0.48),1,true)
