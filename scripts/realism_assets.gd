class_name RealismAssets
extends RefCounted
## Original compact art atlases. Regions are authored from visible alpha bounds, never sliced at runtime.
const PEOPLE := preload("res://assets/art/survivors.png")
const BACKDROPS := preload("res://assets/art/backdrops.png")
const PLACES := preload("res://assets/art/locations.png")
const PROPS := preload("res://assets/art/props.png")
const FIGURES := [[192, 10, 178, 355], [509, 5, 162, 361], [789, 6, 167, 360], [1085, 7, 161, 359], [212, 367, 149, 359], [504, 362, 165, 366], [798, 367, 156, 361], [1085, 362, 171, 364], [200, 723, 161, 360], [512, 724, 145, 357], [795, 723, 147, 360], [1078, 724, 190, 358]]
const OBJECTS := [[20, 72, 327, 211], [392, 41, 319, 232], [772, 74, 278, 205], [1121, 66, 283, 213], [80, 310, 208, 264], [453, 308, 176, 261], [767, 347, 280, 221], [1104, 379, 306, 166], [41, 630, 302, 176], [468, 580, 150, 235], [736, 639, 364, 162], [1192, 575, 189, 241], [22, 827, 332, 222], [391, 832, 304, 222], [721, 892, 364, 140], [1102, 894, 330, 132]]
const IDS := {'lin':0,'xu':1,'chen':2,'he':3,'gu':4,'tang':5,'alice':6,'rick':7,'tesla':8,'walker':9,'runner':10,'brute':11}
const LOCATIONS := {'shelter':0,'row':1,'depot_home':2,'street':3,'clinic':4,'works':5,'residential':6,'market':7,'waterworks':8,'depot':9,'broadcast':10,'evac':11}
const SPECIAL := {'conan':preload('res://assets/art/conan.svg'),'pooh':preload('res://assets/art/pooh.svg'),'mickey':preload('res://assets/art/mickey.svg')}

static func figure_texture(id: String) -> Texture2D:
 return SPECIAL.get(id,PEOPLE)

static func figure_frame(id: String) -> Rect2:
 if SPECIAL.has(id):return Rect2(20,20,320,410)
 var row:Array=FIGURES[int(IDS.get(id,0))]
 var trim:=5.0 if int(IDS.get(id,0))>=4 else 0.0
 var height:=float(row[3])-trim;var width:=height*.72
 return Rect2(float(row[0])+float(row[2])*.5-width*.5,float(row[1])+trim,width,height)

static func object_rect(index: int) -> Rect2:
 var r:Array=OBJECTS[index]
 return Rect2(r[0],r[1],r[2],r[3])

static var desaturated_props: ImageTexture

static func neutral_props() -> Texture2D:
 if desaturated_props==null:
  var image:=PROPS.get_image()
  if image.is_compressed():image.decompress()
  image.adjust_bcs(.78,1.0,0.0)
  desaturated_props=ImageTexture.create_from_image(image)
 return desaturated_props

static func region_quad(c: CanvasItem,texture: Texture2D,points: PackedVector2Array,source: Rect2,tint: Color=Color.WHITE,flip: bool=false) -> void:
 var a:=source.position/texture.get_size();var b:=source.end/texture.get_size()
 var uv:=PackedVector2Array([Vector2(b.x if flip else a.x,a.y),Vector2(a.x if flip else b.x,a.y),Vector2(a.x if flip else b.x,b.y),Vector2(b.x if flip else a.x,b.y)])
 c.draw_polygon(points,PackedColorArray([tint,tint,tint,tint]),uv,texture)

static func prop(c: CanvasItem,index: int,destination: Rect2,tint: Color=Color.WHITE,empty: bool=false,flip: bool=false) -> void:
 var texture:Texture2D=neutral_props() if empty else PROPS
 if flip:
  region_quad(c,texture,PackedVector2Array([destination.position,Vector2(destination.end.x,destination.position.y),destination.end,Vector2(destination.position.x,destination.end.y)]),object_rect(index),tint,true)
 else:c.draw_texture_rect_region(texture,destination,object_rect(index),tint)

static func wall(c: CanvasItem,destination: Rect2,id: String,dim: float=1.0) -> void:
 var index:int=LOCATIONS.get(id,0)
 var tile:=Vector2(PLACES.get_width()/3.0,PLACES.get_height()/4.0)
 var source:=Rect2(Vector2(index%3,index/3)*tile+Vector2(2,2),tile-Vector2(4,4))
 var count:=maxi(1,roundi(destination.size.x/(destination.size.y*2.0)))
 for part in range(count):
  var target:=Rect2(destination.position+Vector2(destination.size.x*part/count,0),Vector2(destination.size.x/count,destination.size.y))
  var crop:=source
  var aspect:=target.size.x/target.size.y
  if aspect>source.size.x/source.size.y:
   crop.size.y=source.size.x/aspect;crop.position.y+=source.size.y-crop.size.y
  else:
   crop.size.x=source.size.y*aspect;crop.position.x+=(source.size.x-crop.size.x)*.5
  c.draw_texture_rect_region(PLACES,target,crop,Color(dim,dim,dim))


static func backdrop(c: CanvasItem,destination: Rect2,id: String,camera: float=0,night: bool=false) -> void:
 var strip:=2 if id in ['waterworks','evac'] else 1 if id in ['works','depot','depot_home','broadcast'] else 0
 var height:=BACKDROPS.get_height()/3.0
 var source:=Rect2(0,strip*height+2,BACKDROPS.get_width(),height-4)
 var aspect:=destination.size.x/destination.size.y
 source.size.x=minf(source.size.x,source.size.y*aspect)
 source.position.x=fposmod(camera*.18,maxf(1,BACKDROPS.get_width()-source.size.x))
 c.draw_texture_rect_region(BACKDROPS,destination,source,Color(.35,.43,.50) if night else Color(.66,.69,.69))

static func door(c: CanvasItem,destination: Rect2,opened: float=0,tint: Color=Color.WHITE) -> void:
 var source:=object_rect(6)
 source.position+=source.size*Vector2(.08,.28);source.size*=Vector2(.82,.62)
 var top:=destination.position;var width:=maxf(4,destination.size.x*(1-opened*.8));var depth:=opened*15
 region_quad(c,PROPS,PackedVector2Array([top,top+Vector2(width,-depth),top+Vector2(width,destination.size.y-depth),top+Vector2(0,destination.size.y)]),source,tint)
 c.draw_line(top,top+Vector2(0,destination.size.y),Color('aaa08c'),1,true)
 c.draw_circle(top+Vector2(width-5,destination.size.y*.55-depth),2,Color('b5aa8e'))
