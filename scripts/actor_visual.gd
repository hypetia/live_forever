class_name ActorVisual
extends RefCounted
## A small shared texture mesh follows the existing action joints. No simulation state is touched.
const COLUMNS := 12
const ROWS := 20
const MAX_MESHES := 96
static var bindings: Dictionary = {}
static var meshes: Dictionary = {}

static func scale_for(id: String) -> Vector2:
 return Vector2(.78,.76) if id=='conan' else Vector2(1.1,.84) if id=='pooh' else Vector2(.95,.82) if id=='mickey' else Vector2.ONE

static func height(id: String) -> float:
 return 101.0*scale_for(id).y

static func remap(data: Dictionary) -> Dictionary:
 var result:=data.duplicate()
 for key in ['hip','shoulder','head','knee_l','knee_r','left','right']:
  var point:Vector2=data[key]
  var vertical:float={'hip':1.65,'shoulder':1.35,'head':1.32,'knee_l':1.5,'knee_r':1.5,'left':1.0,'right':1.0}[key]
  result[key]=Vector2(point.x*.85,point.y*vertical)
 # Hands that touch a real work surface retain that exact surface height.
 var contact:bool=data.get('world_contact',false) or data.get('stationary',false) or data['mode'] in ['craft','repair','build','door','window','search','cook','aid']
 for key in ['front','back']:
  var point:Vector2=data[key];result[key]=Vector2(point.x,point.y*(1.0 if contact else 1.32))
 if data['mode']=='sleep':result['root']=data['root']+Vector2(0,-14)
 return result

static func _source_joints(id: String) -> Dictionary:
 var toy:bool=id in ['pooh','mickey']
 var shoulder:=.37 if toy else .245
 var hip:=.65 if toy else .56
 return {'hip':Vector2(.5,hip),'shoulder':Vector2(.5,shoulder),'neck':Vector2(.5,.30 if toy else .20),'crown':Vector2(.5,.01),
  'arm_l':Vector2(.36,shoulder+.015),'elbow_l':Vector2(.24,.51 if toy else .405),'hand_l':Vector2(.22,.65 if toy else .595),
  'arm_r':Vector2(.64,shoulder+.015),'elbow_r':Vector2(.76,.51 if toy else .405),'hand_r':Vector2(.79,.65 if toy else .595),
  'knee_l':Vector2(.39,.83 if toy else .77),'foot_l':Vector2(.37,.99),'knee_r':Vector2(.62,.83 if toy else .77),'foot_r':Vector2(.67,.99)}

static func _segments() -> Array:
 return [['hip','shoulder'],['shoulder','neck'],['neck','crown'],['arm_l','elbow_l'],['elbow_l','hand_l'],['arm_r','elbow_r'],['elbow_r','hand_r'],['hip','knee_l'],['knee_l','foot_l'],['hip','knee_r'],['knee_r','foot_r']]

static func _rest_point(point: Vector2) -> Vector2:
 return Vector2((point.x-.5)*64,(point.y-1)*110)

static func _binding(id: String) -> Dictionary:
 if bindings.has(id):return bindings[id]
 var joints:=_source_joints(id)
 var segments:=_segments()
 var vertices:Array=[]
 var uvs:=PackedVector2Array()
 var indices:=PackedInt32Array()
 var frame:=RealismAssets.figure_frame(id)
 var texture_size:=RealismAssets.figure_texture(id).get_size()
 for y in range(ROWS+1):
  for x in range(COLUMNS+1):
   var uv:=Vector2(float(x)/COLUMNS,float(y)/ROWS)
   uvs.append((frame.position+uv*frame.size)/texture_size)
   var point:=_rest_point(uv)
   var candidates:Array=[]
   for bone in range(segments.size()):
    if uv.y<float(joints['neck'].y)-.015 and bone!=2:continue
    if uv.y>float(joints['neck'].y)+.035 and bone==2:continue
    var a:=_rest_point(joints[segments[bone][0]])
    var b:=_rest_point(joints[segments[bone][1]])
    var vector:=b-a;var length:=vector.length();var axis:=vector/length
    var along:float=(point-a).dot(axis)/length
    var across:float=(point-a).dot(Vector2(-axis.y,axis.x))
    var distance:=point.distance_to(a+vector*clampf(along,0,1))
    candidates.append({'bone':bone,'along':along,'across':across,'distance':distance})
   candidates.sort_custom(func(a,b):return a['distance']<b['distance'])
   var influences:Array=candidates.slice(0,mini(3,candidates.size()))
   var total:=0.0
   for influence in influences:
    influence['weight']=1.0/pow(maxf(1.0,float(influence['distance'])),4);total+=float(influence['weight'])
   for influence in influences:influence['weight']/=total
   vertices.append(influences)
 for y in range(ROWS):
  for x in range(COLUMNS):
   var a:=y*(COLUMNS+1)+x;var b:=a+COLUMNS+1
   indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
 var result:={'vertices':vertices,'uvs':uvs,'indices':indices}
 bindings[id]=result
 return result

static func _target_joints(data: Dictionary) -> Dictionary:
 var f:float=data['facing'];var shoulder:Vector2=data['shoulder'];var hip:Vector2=data['hip']
 var left:Vector2=data['back'];var right:Vector2=data['front']
 var arm_l:=shoulder+Vector2(-7*f,5);var arm_r:=shoulder+Vector2(7*f,5)
 return {'hip':hip,'shoulder':shoulder,'neck':shoulder+Vector2(0,-8),'crown':data['head']+Vector2(0,-11),
  'arm_l':arm_l,'elbow_l':(arm_l+left)*.5+Vector2(-f*3,4),'hand_l':left,
  'arm_r':arm_r,'elbow_r':(arm_r+right)*.5+Vector2(f*3,4),'hand_r':right,
  'knee_l':data['knee_l'],'foot_l':data['left'],'knee_r':data['knee_r'],'foot_r':data['right']}

static func deformed_vertices(id: String,data: Dictionary) -> PackedVector3Array:
 var binding:=_binding(id);var target:=_target_joints(data);var segments:=_segments()
 var transforms:Array=[]
 for segment in segments:
  var a:Vector2=target[segment[0]];var vector:Vector2=target[segment[1]]-a
  var axis:=vector.normalized();var across:=Vector2(-axis.y,axis.x)*float(data['facing'])
  transforms.append([a,vector,across])
 var points:=PackedVector3Array();points.resize(binding['vertices'].size())
 for index in range(points.size()):
  var point:=Vector2.ZERO
  for influence in binding['vertices'][index]:
   var transform:Array=transforms[int(influence['bone'])]
   point+=(transform[0]+transform[1]*float(influence['along'])+transform[2]*float(influence['across']))*float(influence['weight'])
  points[index]=Vector3(point.x,point.y,0)
 return points

static func draw(c: CanvasItem,id: String,data: Dictionary,tint: Color=Color.WHITE,slot: String="") -> void:
 var key:=str(c.get_instance_id())+':'+id+':'+slot
 var rate:=15.0 if data['mode'] in ['idle','cold','sleep'] else 30.0
 var stamp:='%s:%s:%d:%d'%[data['mode'],data['facing'],floori(float(data['time'])*rate),floori(float(data.get('progress',0))*30)]
 if not meshes.has(key):
  if meshes.size()>=MAX_MESHES:meshes.erase(meshes.keys()[0])
  meshes[key]={'mesh':ArrayMesh.new(),'stamp':''}
 var entry:Dictionary=meshes[key];var mesh:ArrayMesh=entry['mesh']
 # Local bone animation is 30 fps (idle breathing 15); world movement and input remain 60 fps.
 if entry['stamp']!=stamp:
  var binding:=_binding(id)
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=deformed_vertices(id,data);arrays[Mesh.ARRAY_TEX_UV]=binding['uvs'];arrays[Mesh.ARRAY_INDEX]=binding['indices']
  mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);entry['stamp']=stamp
 c.draw_mesh(mesh,RealismAssets.figure_texture(id),Transform2D.IDENTITY,tint)

static func portrait(c: CanvasItem,id: String,destination: Rect2) -> void:
 var texture:=RealismAssets.figure_texture(id);var frame:=RealismAssets.figure_frame(id)
 var source:=Rect2(frame.position+frame.size*Vector2(.15,0),frame.size*Vector2(.7,.59 if id in ['pooh','mickey'] else .50))
 c.draw_texture_rect_region(texture,destination,source)
