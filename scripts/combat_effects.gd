class_name CombatEffects
extends RefCounted
## Bounded visual state. It never changes combat outcomes or saved simulation.
const MAX_PARTICLES := 96
const MAX_MARKS := 48
var particles: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var reactions: Dictionary = {}
var player_time := 0.0
var player_direction := 1.0
var pulse := 0.0

func clear() -> void:
 particles.clear()
 marks.clear()
 reactions.clear()
 player_time = 0
 pulse = 0

func hit(index: int, at: Vector2, direction: float, damage: int, lethal: bool) -> void:
 reactions[index] = {"age":0.0,"lethal":lethal,"direction":direction}
 _spray(at+Vector2(0,-42),direction,18 if lethal else 12)
 marks.append({"at":at+Vector2(direction*8,-1),"width":18.0 if lethal else 9.0})
 if marks.size() > MAX_MARKS: marks.pop_front()
 pulse = maxf(pulse,0.14 if lethal else 0.07)

func hurt(at: Vector2, direction: float) -> void:
 player_time = 0.4
 player_direction = direction
 pulse = 0.18
 _spray(at+Vector2(0,-40),direction,8)

func _spray(at: Vector2, direction: float, count: int) -> void:
 for index in range(count):
  if particles.size() >= MAX_PARTICLES: particles.pop_front()
  particles.append({"at":at,"velocity":Vector2(direction*(28+index*7),-72+(index%5)*23),"life":0.42+(index%3)*0.09,"radius":1.2+(index%3)*0.6})

func step(delta: float) -> void:
 player_time = maxf(0,player_time-delta)
 pulse = maxf(0,pulse-delta)
 for index in reactions.keys():
  reactions[index]["age"] += delta
  if reactions[index]["age"] > 0.8: reactions.erase(index)
 for particle in particles.duplicate():
  particle["life"] -= delta
  particle["velocity"].y += 190*delta
  particle["at"] += particle["velocity"]*delta
  if particle["life"] <= 0: particles.erase(particle)

func shake() -> Vector2:
 return Vector2(sin(pulse*110),cos(pulse*92))*minf(2.5,pulse*13)

func draw_marks(c: CanvasItem,camera: float) -> void:
 for mark in marks:
  var shape := PackedVector2Array()
  for i in range(16): shape.append(mark["at"]-Vector2(camera,0)+Vector2(cos(i*TAU/16)*mark["width"],sin(i*TAU/16)*3))
  c.draw_colored_polygon(shape,Color("76303a"))

func draw_particles(c: CanvasItem,camera: float) -> void:
 for particle in particles:
  c.draw_circle(particle["at"]-Vector2(camera,0),particle["radius"],Color("bd5b57") if particle["life"] > 0.3 else Color("7e333a"))

func draw_enemy(c: CanvasItem,enemy: Dictionary,index: int,point: Vector2,time: float,stationary: bool=false) -> void:
 _draw_painted_enemy(c,enemy,index,point,time,stationary)

func _draw_painted_enemy(c: CanvasItem,enemy: Dictionary,index: int,point: Vector2,time: float,stationary: bool) -> void:
 var kind:String=enemy['kind'];var definition:=EnemyCatalog.stats(kind);var facing:float=enemy['direction']
 var reaction:Dictionary=reactions.get(index,{});var age:float=reaction.get('age',1.0)
 var mode:='idle';var progress:=0.0
 if enemy['hp']<=0:
  mode='dead';progress=clampf(age/.48,0,1) if reaction.get('lethal',false) else 1.0
  c.draw_colored_polygon(PackedVector2Array([point+Vector2(-25,-2),point+Vector2(25,-2),point+Vector2(20,3),point+Vector2(-20,3)]),Color('60272e'))
 elif int(enemy.get('climb_target',-1))!=-1:mode='climb'
 elif enemy['mode']=='windup':mode='windup';progress=clampf(1-float(enemy.get('timer',0))/float(definition['windup']),0,1)
 elif age<.28:mode='hurt';progress=age/.28
 elif not stationary and enemy['mode'] in ['chase','patrol','investigate']:mode='run' if kind=='runner' and enemy['mode']=='chase' else 'walk'
 var pose:=ActorVisual.remap(CharacterMotion.pose(mode,time,progress,facing))
 if mode not in ['dead','climb']:
  pose['shoulder']+=Vector2(facing*4,4);pose['head']+=Vector2(facing*6,7)
  if mode in ['idle','walk','run']:
   pose['front']=Vector2(facing*(24+sin(time*3)*3),-45);pose['back']=Vector2(facing*14,-42)
 var scale:float=definition['scale']
 var base:=Transform2D.IDENTITY
 if 'game' in c and c.game.expedition.active:base=Transform2D(0.0,c.game.world_scale(),0,c.game.world_offset()+shake())
 c.draw_set_transform_matrix(base*Transform2D(float(pose['rotation']),Vector2.ONE*scale,0,point+pose['root']))
 ActorVisual.draw(c,kind,pose,Color(1.3,1.16,1.08) if age<.09 else Color(.88,.94,.88),str(index))
 c.draw_set_transform_matrix(base)
