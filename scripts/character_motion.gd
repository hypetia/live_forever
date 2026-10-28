class_name CharacterMotion
extends RefCounted
## Procedural joint animation. Samples simulation state; never awards items,
## changes position, or decides a hit. All joints are local to physical feet.
static func pose(mode: String,time: float,progress: float,facing: float,weapon: String='') -> Dictionary:
 var p:=clampf(progress,0,1);var wave:=sin(time*8)
 var hip:=Vector2(0,-24);var shoulder:=Vector2(0,-52);var head:=Vector2(0,-66)
 var front:=Vector2(22*facing,-29);var back:=Vector2(-15*facing,-31)
 var left:=Vector2(-8,-3);var right:=Vector2(10,-3);var knee_l:=Vector2(-6,-14);var knee_r:=Vector2(7,-14)
 var angle:=-.25;var root:=Vector2.ZERO;var rotation:=0.0
 match mode:
  'walk','run','sneak':
   var speed:=13.0 if mode=='run' else 6.0 if mode=='sneak' else 9.0
   var stride:=sin(time*speed);var reach:=13.0 if mode=='run' else 6.0 if mode=='sneak' else 9.0
   left.x-=stride*reach;right.x+=stride*reach
   left.y-=maxf(0,cos(time*speed))* (10 if mode=='run' else 5)
   right.y-=maxf(0,-cos(time*speed))* (10 if mode=='run' else 5)
   root.y=-absf(stride)*(3 if mode=='run' else 1.4)
   shoulder.x=facing*(6 if mode=='run' else 1);head.x=shoulder.x
   if mode=='sneak':hip.y+=5;shoulder+=Vector2(facing*6,17);head+=Vector2(facing*7,19)
   front=Vector2((19-stride*8)*facing,shoulder.y+21);back=Vector2((-15+stride*8)*facing,shoulder.y+23)
   knee_l=(hip+left)*.5+Vector2(-3,0);knee_r=(hip+right)*.5+Vector2(3,0)
  'climb':
   var phase:=sin(time*8)
   hip+=Vector2(0,3);shoulder.x=3*facing;head.x=3*facing
   front=Vector2(12*facing,-72+phase*13);back=Vector2(-12*facing,-72-phase*13)
   left+=Vector2(-4,-14-maxf(0,phase)*14);right+=Vector2(4,-14-maxf(0,-phase)*14)
   knee_l=Vector2(-17,-28);knee_r=Vector2(17,-28);angle=1.2
  'search':
   hip.y+=8;shoulder+=Vector2(9*facing,13);head+=Vector2(13*facing,16)
   front=Vector2((27+wave*5)*facing,-25+cos(time*8)*4);back=Vector2(18*facing,-31-wave*4)
   knee_l=Vector2(-16,-15);right.x+=10*facing
  'door','window','build','craft','repair':
   var force:=mode=='window';shoulder.x+=facing*5;head.x+=facing*7
   front=Vector2((25+wave*(10 if force else 4))*facing,-44+cos(time*8)* (11 if force else 6))
   back=Vector2(17*facing,-43-wave*3)
   if mode=='window':hip.y+=5;shoulder.y+=5;head.y+=6
  'vault':
   root.y=-sin(p*PI)*27;hip+=Vector2(5*facing,-sin(p*PI)*4);shoulder+=Vector2(9*facing,9);head+=Vector2(15*facing,11)
   front=Vector2(38*facing,-35);back=Vector2(19*facing,-40)
   left+=Vector2(-14*facing,-sin(p*PI)*23);right+=Vector2(15*facing,-sin(p*PI)*28)
   knee_l=Vector2(-15*facing,-26);knee_r=Vector2(22*facing,-29);angle=1.1
  'windup':
   var release:=smoothstep(.72,1.0,p)
   var reach: float = 49 if weapon=='spear' else 45 if weapon=='bat' else 40 if weapon=='knife' else 37
   shoulder.x=facing*lerpf(-4*p,7,release);head.x=facing*lerpf(-5*p,6,release)
   front=Vector2(lerpf(22-12*p,reach,release)*facing,lerpf(-38-15*p,-38,release));back=Vector2(lerpf(8,17,release)*facing,-41)
   angle=lerpf(lerpf(-.25,-1.5,p),.5,release) if not weapon in ['spear','pistol'] else -.12
   if weapon=='pistol':front=Vector2(22*facing,-57);angle=-.05
  'attack':
   var recovery:=smoothstep(0,1,p)
   var reach: float = 49 if weapon=='spear' else 45 if weapon=='bat' else 40 if weapon=='knife' else 37
   shoulder.x=facing*7*(1-recovery);head.x=facing*6*(1-recovery)
   front=Vector2(lerpf(reach,22,recovery)*facing,lerpf(-38,-29,recovery));back=Vector2(lerpf(17,-15,recovery)*facing,lerpf(-41,-31,recovery))
   angle=lerpf(.5,-.25,recovery) if not weapon in ['spear','pistol'] else -.12
   if weapon=='pistol':front=Vector2((22-10*sin(p*PI))*facing,-57+28*recovery);angle=-.25*sin(p*PI)
  'reload':
   front=Vector2(18*facing,-44);back=Vector2((10+sin(p*PI*4)*6)*facing,-38+sin(p*PI)*10);angle=-.8
  'hurt':
   root+=Vector2(-facing*sin(p*PI)*8,3*sin(p*PI));shoulder.x-=facing*9*sin(p*PI);head.x-=facing*12*sin(p*PI)
   front=Vector2(12*facing,-44);back=Vector2(-10*facing,-38);angle=-1.1
  'eat','drink':
   front=Vector2(11*facing,-57+sin(time*3)*3);back=Vector2(9*facing,-40)
   head.x+=facing*(2 if mode=='drink' else 0)
  'cook':
   shoulder.x+=4*facing;head.x+=6*facing
   front=Vector2(24*facing+cos(time*5)*5,-38+sin(time*5)*4);back=Vector2(14*facing,-36)
  'heal','aid','self_heal':
   front=Vector2((18+wave*4)*facing,-36);back=Vector2(11*facing,-32-wave*3)
   shoulder+=Vector2(3*facing,3);head+=Vector2(4*facing,5)
  'dead':root=Vector2(facing*10*p,-7*p);rotation=facing*PI*.48*p
  'sleep':root=Vector2(-38,-24+sin(time*1.7)*.5);rotation=PI/2
  'music':front=Vector2(17*facing,-30+sin(time*11)*4);back=Vector2(35*facing,-48)
  'cold':front=Vector2(-4*facing,-42);back=Vector2(7*facing,-43);shoulder.x=sin(time*19)*.65;head.x=shoulder.x
  _:head.y+=sin(time*1.6)*.7;front.y+=sin(time*1.6)*1.4
 return {'facing':facing,'mode':mode,'time':time,'root':root,'rotation':rotation,'hip':hip,'shoulder':shoulder,'head':head,'front':front,'back':back,'left':left,'right':right,'knee_l':knee_l,'knee_r':knee_r,'angle':angle}

static func field_context(state: ExpeditionState,actor: Survivor,hurt: float=0) -> Dictionary:
 var mode:='idle';var p:=0.0
 if state.moving:mode='sneak' if state.sneaking else 'run' if state.sprinting else 'walk'
 elif actor.cold_exposure>=30:mode='cold'
 if state.search_index>=0:mode='search';p=state.search_progress/maxf(.1,state.search_duration)
 if not state.interior.action.is_empty():
  mode=state.interior.action['kind'];p=float(state.interior.action['elapsed'])/(1.2 if mode=='door' else 3.0 if mode=='window' else 1.0)
 if state.climb_target!=-1:mode='climb';p=state.climb_progress
 if state.reload_remaining>0:mode='reload';p=1-state.reload_remaining/1.4
 var w:=actor.weapon();var cooldown:=float(w.get('cooldown',1.1));var windup:=float(w.get('windup',.2))
 if state.attack_windup>0:mode='windup';p=1-state.attack_windup/windup
 elif cooldown-state.attack_cooldown>=windup and cooldown-state.attack_cooldown<windup+.3:mode='attack';p=(cooldown-state.attack_cooldown-windup)/.3
 if hurt>0:mode='hurt';p=1-hurt/.4
 return {'mode':mode,'progress':clampf(p,0,1),'tool':(not state.interior.action.is_empty() and state.interior.action.get('quiet',false)) or state.search_tool}

static func shelter_context(actor: Survivor,game: Node2D) -> Dictionary:
 var mode:='idle';var p:=0.0
 if actor.state in [Survivor.TaskState.MOVING,Survivor.TaskState.RETURNING] or actor.manual_walking:mode='run' if actor.move_multiplier>1.1 else 'walk'
 if not actor.position.y in [430.0,640.0]:mode='climb'
 if actor.state==Survivor.TaskState.WORKING and not actor.orders.is_empty():mode=actor.orders[0];p=actor.progress()
 if not actor.activity.is_empty():mode=actor.activity['kind'];p=actor.activity['progress']
 if mode=='idle' and actor.cold_exposure>=30:mode='cold'
 if game.has_method('siege_snapshot') and game.siege.active:
  var id:=str(actor.survivor_id);var w:=actor.weapon();var windup:=float(w.get('windup',.18));var cooldown:=float(w.get('cooldown',1.1))
  if game.siege.strikes.has(id):mode='windup';p=1-float(game.siege.strikes[id]['remaining'])/windup
  elif cooldown-float(game.siege.cooldowns.get(id,0))>=windup and cooldown-float(game.siege.cooldowns.get(id,0))<windup+.3:mode='attack';p=(cooldown-float(game.siege.cooldowns.get(id,0))-windup)/.3
  var hurt: float = game.siege.invulnerable.get(id,0)
  if hurt>.8:mode='hurt';p=(1.2-hurt)/.4
 return {'mode':mode,'progress':clampf(p,0,1)}

static func draw(c: CanvasItem,at: Vector2,actor: Survivor,data: Dictionary,armed: bool=false,tint_override: Color=Color.TRANSPARENT,base: Transform2D=Transform2D.IDENTITY) -> void:
 var color:=actor.tint if tint_override==Color.TRANSPARENT else tint_override
 var f: float=data.get('facing',actor.facing);var mode: String=data['mode']
 c.draw_set_transform_matrix(base*Transform2D(float(data['rotation']),at+data['root']))
 var hip: Vector2=data['hip'];var shoulder: Vector2=data['shoulder'];var head: Vector2=data['head']
 for pair in [[hip+Vector2(-5,0),data['knee_l'],data['left']],[hip+Vector2(5,0),data['knee_r'],data['right']]]:
  c.draw_polyline(PackedVector2Array(pair),Color('293733'),7,true)
  c.draw_line(pair[2]+Vector2(-4,1),pair[2]+Vector2(6,1),Color('8e9286'),3,true)
 c.draw_rect(Rect2(shoulder+Vector2(-17*f-4,0),Vector2(11,28)),color.darkened(.45))
 c.draw_polygon(PackedVector2Array([shoulder+Vector2(-10,-4),shoulder+Vector2(10,-4),hip+Vector2(13,1),hip+Vector2(-12,1)]),PackedColorArray([color]))
 if not actor.coat_item.is_empty():
  var coat:=Color('827362') if actor.coat_item['durability']>0 else Color('59544e')
  c.draw_colored_polygon(PackedVector2Array([shoulder+Vector2(-13,-3),shoulder+Vector2(13,-3),hip+Vector2(14,10),hip+Vector2(-14,10)]),coat)
  c.draw_line(shoulder,hip+Vector2(0,9),Color('bca78b'),2,true)
 if not actor.armor_item.is_empty():
  var armor:=Color('687e79') if actor.armor_item['kind']=='vest' else Color('9a896c')
  if actor.armor_item['durability']<=0:armor=Color('62544f')
  c.draw_rect(Rect2(shoulder+Vector2(-11,1),Vector2(22,21)),armor)
 _arm(c,shoulder+Vector2(-7*f,7),data['back'],color.darkened(.12),-f)
 _arm(c,shoulder+Vector2(7*f,5),data['front'],color.lightened(.1),f)
 c.draw_rect(Rect2(head+Vector2(-3,5),Vector2(7,10)),Color('ad987e'))
 c.draw_circle(head,9,Color('c7b294'));c.draw_arc(head+Vector2(0,-2),9,PI,TAU,16,Color('333b3b'),5,true)
 PersonalityArt.face(c,actor.person.persona,head,.9)
 var hand: Vector2=data['front']
 if mode=='drink':
  c.draw_rect(Rect2(hand+Vector2(-5,-7),Vector2(10,12)),Color('829fa2'))
  c.draw_rect(Rect2(hand+Vector2(-4,-5),Vector2(8,3)),Color('c1d6d0'))
  c.draw_arc(hand+Vector2(5,-1),4,-PI/2,PI/2,12,Color('a6bdc0'),2,true)
 elif mode=='eat':
  var bowl:Vector2=data['back']+Vector2(3,0)
  c.draw_colored_polygon(PackedVector2Array([bowl+Vector2(-9,-3),bowl+Vector2(9,-3),bowl+Vector2(6,4),bowl+Vector2(-6,4)]),Color('b49f7b'))
  c.draw_line(bowl+Vector2(-8,-3),bowl+Vector2(8,-3),Color('d6c39c'),2,true)
  c.draw_line(hand,hand+Vector2(7*f,-4),Color('c8baa0'),2,true)
  c.draw_circle(hand+Vector2(7*f,-4),2,Color('c8baa0'))
 elif mode in ['heal','aid','self_heal']:
  c.draw_line(hand+Vector2(-5,0),hand+Vector2(5,0),Color('ecdbba'),3);c.draw_line(hand+Vector2(0,-5),hand+Vector2(0,5),Color('ecdbba'),3)
 elif mode=='cook':
  var pot:Vector2=data['back']+Vector2(7,-1)
  c.draw_colored_polygon(PackedVector2Array([pot+Vector2(-10,-4),pot+Vector2(10,-4),pot+Vector2(8,6),pot+Vector2(-8,6)]),Color('596965'))
  c.draw_line(pot+Vector2(-11,-4),pot+Vector2(11,-4),Color('b9bba7'),2,true)
  c.draw_line(hand,hand+Vector2(7*f,-10),Color('b9bba7'),2,true)
  var steam:=sin(float(data.get('time',0))*3)*2
  for x in [-5,4]:c.draw_line(pot+Vector2(x,-8),pot+Vector2(x+steam,-15),Color(.8,.85,.8,.55),1,true)
 elif mode in ['craft','repair','build'] or (mode in ['window','search'] and data.get('tool',false)):
  c.draw_line(hand,hand+Vector2(8*f,-12),Color('aab3a3'),3,true);c.draw_line(hand+Vector2(3*f,-12),hand+Vector2(13*f,-12),Color('aab3a3'),4,true)
 elif mode=='music':
  c.draw_circle(Vector2(6,-32),10,Color('a58a5b'));c.draw_circle(Vector2(17,-37),7,Color('a58a5b'));c.draw_line(Vector2(18,-38),Vector2(41,-49),Color('bca177'),4,true)
 elif armed and not actor.weapon_item.is_empty():
  var stowed: bool = mode in ['climb','vault','search']
  EquipmentArt.weapon(c,actor.weapon_item['kind'],shoulder+Vector2(-19*f,14) if stowed else hand,f,1.15 if stowed else data['angle'],1,actor.weapon_item['durability']<=0)
 c.draw_set_transform_matrix(base)

static func _arm(c: CanvasItem,shoulder: Vector2,hand: Vector2,color: Color,direction: float) -> void:
 var elbow: Vector2=(shoulder+hand)*.5+Vector2(direction*3,5)
 c.draw_polyline(PackedVector2Array([shoulder,elbow,hand]),color,6,true);c.draw_circle(hand,3,Color('bdab91'))

static func death_progress(age: float,terminal: bool) -> float:
 return 1.0 if terminal else clampf(age/.55,0,1)
