class_name CharacterMotion
extends RefCounted
## Procedural joint animation. Samples simulation state; never awards items,
## changes position, or decides a hit. All joints are local to physical feet.
static func pose(mode: String,time: float,progress: float,facing: float,weapon: String='',motion: Dictionary={}) -> Dictionary:
 var p:=clampf(progress,0,1);var wave:=sin(time*8)
 var hip:=Vector2(0,-24);var shoulder:=Vector2(0,-52);var head:=Vector2(0,-66)
 var front:=Vector2(22*facing,-29);var back:=Vector2(-15*facing,-31)
 var left:=Vector2(-8,-3);var right:=Vector2(10,-3);var knee_l:=Vector2(-6,-14);var knee_r:=Vector2(7,-14)
 var angle:=-.25;var root:=Vector2.ZERO;var rotation:=0.0
 match mode:
  'walk','run','sneak':
   var speed:=13.0 if mode=='run' else 6.0 if mode=='sneak' else 9.0
   var phase:=float(motion.get('phase',time*speed));var amount:=float(motion.get('weight',1.0))
   var stride:=sin(phase)*amount;var reach:=13.0 if mode=='run' else 6.0 if mode=='sneak' else 9.0
   left.x-=stride*reach;right.x+=stride*reach
   left.y-=maxf(0,cos(phase))* (10 if mode=='run' else 5)*amount
   right.y-=maxf(0,-cos(phase))* (10 if mode=='run' else 5)*amount
   root.y=-absf(stride)*(3 if mode=='run' else 1.4)
   shoulder.x=facing*(6 if mode=='run' else 1)*amount;head.x=shoulder.x
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
  'windup','attack':
   # Both phases sample the same contact pose at the actual damage boundary.
   var release:=smoothstep(.58,1.0,p) if mode=='windup' else 1.0
   var recovery:=smoothstep(0,1,p) if mode=='attack' else 0.0
   var anticipation:=smoothstep(0,.58,p) if mode=='windup' else 1.0
   var start:=Vector2(12,-53);var contact:=Vector2(40,-38)
   var start_angle:=-1.8;var contact_angle:=.45
   if weapon=='bat':start=Vector2(-5,-68);contact=Vector2(43,-36);start_angle=-2.0;contact_angle=.65
   elif weapon=='knife':start=Vector2(12,-43);contact=Vector2(39,-46);start_angle=-.8;contact_angle=.05
   elif weapon=='spear':start=Vector2(2,-42);contact=Vector2(48,-42);start_angle=-.10;contact_angle=-.10
   elif weapon=='pistol':start=Vector2(22,-57);contact=start;start_angle=-.05;contact_angle=-.05
   var hand:=Vector2(22,-29).lerp(start,anticipation).lerp(contact,release).lerp(Vector2(22,-29),recovery)
   front=Vector2(hand.x*facing,hand.y)
   var rear:=Vector2(-15,-31).lerp(Vector2(8,-42),anticipation).lerp(Vector2(18,-42),release).lerp(Vector2(-15,-31),recovery)
   back=Vector2(rear.x*facing,rear.y)
   angle=lerpf(lerpf(-.25,start_angle,anticipation),contact_angle,release)
   angle=lerpf(angle,-.25,recovery)
   shoulder.x=facing*lerpf(-4*anticipation,8,release)*(1-recovery);head.x=shoulder.x*.8
   hip.x=shoulder.x*.3;left.x-=3*release*(1-recovery);right.x+=4*release*(1-recovery)
   if weapon=='pistol':
    var recoil:=sin(minf(1,p*4)*PI)* (1-recovery) if mode=='attack' else 0.0
    front=Vector2((22-8*recoil)*facing,lerpf(-57,-29,recovery)-3*recoil);angle=-.05-.15*recoil
    back=(front+Vector2(-6*facing,5)).lerp(Vector2(-15*facing,-31),recovery)
    if mode=='windup':
     front=Vector2(22*facing,lerpf(-29,-57,anticipation));angle=lerpf(-.25,-.05,anticipation)
     back=Vector2(-15*facing,-31).lerp(front+Vector2(-6*facing,5),anticipation)
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
   if motion.get('stationary',false):
    var stir:=smoothstep(.20,.32,p);var serve:=smoothstep(.82,.94,p)
    var chopping:=Vector2(8*facing,-43+sin(time*12)*4)
    var stirring:=Vector2((23+cos(time*5)*4)*facing,-56+sin(time*5)*2)
    front=chopping.lerp(stirring,stir).lerp(Vector2(12*facing,-38),serve)
    back=Vector2(18*facing,-41).lerp(Vector2(12*facing,-47),stir).lerp(Vector2(3*facing,-36),serve)
   else:
    front=Vector2(24*facing+cos(time*5)*5,-38+sin(time*5)*4);back=Vector2(14*facing,-36)
  'talk':
   front=Vector2((15+sin(time*3)*5)*facing,-40+cos(time*3)*3);back=Vector2(-12*facing,-29);head.x+=facing*2
  'share':
   var offer:=smoothstep(.18,.42,p)*(1-smoothstep(.75,1.0,p))
   shoulder.x=3*facing;head.x=5*facing
   front=Vector2((16+15*offer)*facing,-39+sin(time*3)*1.5);back=Vector2(10*facing,-35)
  'receive':
   var accept:=smoothstep(.18,.42,p)*(1-smoothstep(.75,1.0,p))
   front=Vector2((12+15*accept)*facing,lerpf(-34,-43,accept));back=Vector2(10*facing,-37)
   head+=Vector2(3*facing,sin(p*PI*3)*1.2)
  'patient':
   hip.y+=3;shoulder+=Vector2(-2*facing,4);head+=Vector2(-3*facing,5)
   front=Vector2(22*facing,-43);back=Vector2(10*facing,-34)
  'heal','aid','self_heal':
   front=Vector2((18+wave*4)*facing,-36);back=Vector2(11*facing,-32-wave*3)
   shoulder+=Vector2(3*facing,3);head+=Vector2(4*facing,5)
  'dead':
   var fall:=smoothstep(0,1,p)
   root=Vector2(facing*10*fall,-7*fall);rotation=facing*PI*.48*fall
   front=Vector2(lerpf(22,34,fall)*facing,lerpf(-29,-17,fall));head.x+=facing*sin(p*PI)*5
  'sleep':root=Vector2(-38,-24+sin(time*1.7)*.5);rotation=PI/2
  'music':front=Vector2(17*facing,-30+sin(time*11)*4);back=Vector2(35*facing,-48)
  'cold':front=Vector2(-4*facing,-42);back=Vector2(7*facing,-43);shoulder.x=sin(time*19)*.65;head.x=shoulder.x
  _:head.y+=sin(time*1.6)*.7;front.y+=sin(time*1.6)*1.4
 if not motion.is_empty() and mode in ['idle','cold','walk','run','sneak']:
  var settle:=float(motion.get('weight',0))
  if mode in ['idle','cold'] and settle>0:
   var last_stride:=sin(float(motion.get('phase',0)))*9*settle
   left.x-=last_stride;right.x+=last_stride
   knee_l=(hip+left)*.5;knee_r=(hip+right)*.5
  var lean:=clampf(float(motion.get('velocity',0))/150,-1.5,1.5)*2
  shoulder.x+=lean;head.x+=lean
  root.y+=sin(float(motion.get('turn',0))*PI)*1.5
  var injury:=clampf(float(motion.get('injury',0))/100,0,1)
  shoulder.y+=injury*4;head.y+=injury*5
  shoulder.x-=facing*injury*3
  if mode in ['walk','run']:
   left.y=lerpf(left.y,-3,injury*.6);root.y+=sin(float(motion.get('phase',0)))*injury*1.8*settle
  var burden:=clampf(float(motion.get('burden',0)),0,1)
  shoulder.x+=facing*burden*3;head.x+=facing*burden*4
 if mode=='reload' and float(motion.get('weight',0))>.01:
  var gait:=pose('walk',time,0,facing,weapon,motion)
  left=gait['left'];right=gait['right'];knee_l=gait['knee_l'];knee_r=gait['knee_r']
  root.y+=float(gait['root'].y)*.5
 return {'facing':facing,'mode':mode,'time':time,'root':root,'rotation':rotation,'hip':hip,'shoulder':shoulder,'head':head,'front':front,'back':back,'left':left,'right':right,'knee_l':knee_l,'knee_r':knee_r,'angle':angle,'progress':p,'weapon':weapon,'turn':float(motion.get('turn',0)) if mode in ['walk','run','sneak'] else 0.0}

static func field_context(state: ExpeditionState,actor: Survivor,hurt: float=0) -> Dictionary:
 var mode:='idle';var p:=0.0
 if state.moving:mode='sneak' if state.sneaking else 'run' if state.sprinting else 'walk'
 elif actor.cold_exposure>=30:mode='cold'
 if state.search_index>=0 and state.search_active:mode='search';p=state.search_progress/maxf(.1,state.search_duration)
 if not state.interior.action.is_empty():
  mode=state.interior.action['kind'];p=float(state.interior.action['elapsed'])/(1.2 if mode=='door' else 3.0 if mode=='window' else 1.0)
 if state.climb_target!=-1:mode='climb';p=state.climb_progress
 if state.reload_remaining>0:mode='reload';p=1-state.reload_remaining/1.4
 var w:=actor.weapon();var cooldown:=float(w.get('cooldown',1.1));var windup:=float(w.get('windup',.2))
 if state.attack_windup>0:mode='windup';p=1-state.attack_windup/windup
 elif cooldown-state.attack_cooldown>=windup and cooldown-state.attack_cooldown<windup+.3:mode='attack';p=(cooldown-state.attack_cooldown-windup)/.3
 if hurt>0:mode='hurt';p=1-hurt/.4
 var context:={'mode':mode,'progress':clampf(p,0,1),'facing':state.facing,'tool':(not state.interior.action.is_empty() and state.interior.action.get('quiet',false)) or state.search_tool}
 if mode=='search' and state.search_index>=0:
  var definition:Dictionary=state.site_definitions()[state.search_index]
  var kind:String=LocationEnvironment.profile(state.location_id)['containers'][state.search_index]
  var dx:=float(definition['x'])-state.player_x
  context['facing']=signf(dx) if absf(dx)>2 else state.facing
  context['contact']=Vector2(clampf(dx,-40,40),-52 if kind in ['cabinet','locker','shelf','console'] else -42 if kind in ['barrel','tank'] else -30)
 if mode in ['door','window']:
  var x:float=InteriorState.layout(state.location_id)[int(state.interior.action['door'])]['x']
  var dx:=x+(28 if mode=='window' else 6)-state.player_x
  context['facing']=signf(dx) if absf(dx)>2 else state.facing
  context['contact']=Vector2(clampf(dx,-46,46),-88 if mode=='window' else -57)
 return context

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
 var context:={'mode':mode,'progress':clampf(p,0,1),'facing':actor.facing}
 if game.has_method('self_care_snapshot') or 'self_care' in game:
  if mode=='aid':
   var aid:Dictionary=game.self_care.members.get(actor.person.persona,{}).get('aid',{})
   if not aid.is_empty():context['partner_x']=game.survivors[int(aid['target'])].position.x-actor.position.x
  if mode=='idle':
   for record in game.self_care.members.values():
    var aid:Dictionary=record.get('aid',{})
    if aid.is_empty() or int(aid['target'])!=actor.survivor_id or float(aid['elapsed'])<=0:continue
    for medic:Survivor in game.survivors:
     if game.self_care.members.get(medic.person.persona,{})==record and medic.activity.get('kind','')=='aid' and medic.position.distance_to(actor.position)<=56:
      context={'mode':'patient','progress':float(aid['elapsed'])/4,'facing':1.0 if medic.position.x>actor.position.x else -1.0}
 if 'expansion' in game:
  for job in game.expansion.jobs:
   if job['kind']!='picnic' or float(job['elapsed'])<=0:continue
   var host:Survivor=game.survivors[int(job['actor'])]
   if host.activity.get('kind','')!='eat' or not host.route.is_empty():continue
   if host==actor:
    context['mode']='share'
    var closest:Survivor=null
    for guest:Survivor in game.survivors:
     if _meal_guest(guest,host) and (closest==null or guest.position.distance_to(host.position)<closest.position.distance_to(host.position)):closest=guest
    if closest!=null:context['facing']=1.0 if closest.position.x>host.position.x else -1.0
   elif context['mode']=='idle' and _meal_guest(actor,host):
    context={'mode':'receive','progress':float(job['elapsed'])/float(job['duration']),'facing':1.0 if host.position.x>actor.position.x else -1.0}
 if context['mode']=='cook' and game.stove.cooking_state().get('actor',-1)==actor.survivor_id:context['stationary']=true
 return context

static func _meal_guest(actor: Survivor,host: Survivor) -> bool:
 return actor!=host and actor.health>0 and actor.state!=Survivor.TaskState.AWAY and absf(actor.position.y-host.position.y)<=45 and absf(actor.position.x-host.position.x)<=220


static func draw(c: CanvasItem,at: Vector2,actor: Survivor,data: Dictionary,armed: bool=false,tint_override: Color=Color.TRANSPARENT,base: Transform2D=Transform2D.IDENTITY) -> void:
 data=data.duplicate()
 var identity:=actor.person.persona
 var color:=actor.tint if tint_override==Color.TRANSPARENT else tint_override
 if data['mode']=='idle':
  var breath:=sin(float(data['time'])*(1.4 if identity=='pooh' else 1.8)+actor.survivor_id*1.7)
  data['shoulder']+=Vector2(0,breath*.65)
  data['head']+=Vector2(0,breath*.8)
  if identity in ['chen','rick','alice']:data['front']+=Vector2(0,-3)
  elif identity in ['lin','tesla']:data['head']+=Vector2(data['facing']*2,1)
  elif identity=='pooh':data['back']=Vector2(-8*data['facing'],-33)

 data=ActorVisual.remap(data)
 var f: float=data.get('facing',actor.facing);var mode: String=data['mode']
 var pivot:=1-sin(float(data.get('turn',0))*PI)*.18
 c.draw_set_transform_matrix(base*Transform2D(float(data['rotation']),Vector2(pivot,1)*ActorVisual.scale_for(identity),0,at+data['root']))
 var hip: Vector2=data['hip'];var shoulder: Vector2=data['shoulder'];var head: Vector2=data['head']
 ActorVisual.draw(c,identity,data,Color(1.20,1.10,1.04) if tint_override!=Color.TRANSPARENT and tint_override!=actor.tint else Color.WHITE)
 # Equipment remains independent of the clothing texture and reflects durability.
 if not actor.coat_item.is_empty():
  var coat:=Color('827362') if actor.coat_item['durability']>0 else Color('59544e')
  var fabric:=RealismAssets.figure_frame('xu');fabric.position+=fabric.size*Vector2(.35,.27);fabric.size*=Vector2(.3,.3)
  RealismAssets.region_quad(c,RealismAssets.PEOPLE,PackedVector2Array([shoulder+Vector2(-12,-2),shoulder+Vector2(12,-2),hip+Vector2(14,4),hip+Vector2(-14,4)]),fabric,Color(1.1,1.0,.82,.85))
  for side in [-1,1]:c.draw_line(shoulder+Vector2(side*7,2),hip+Vector2(side*3,-4),coat.lightened(.25),2,true)
 if not actor.armor_item.is_empty():
  var armor:=Color('68746b') if actor.armor_item['kind']=='vest' else Color('85765d')
  if actor.armor_item['durability']<=0:armor=Color('62544f')
  var fabric:=RealismAssets.figure_frame('brute');fabric.position+=fabric.size*Vector2(.35,.26);fabric.size*=Vector2(.3,.25)
  RealismAssets.region_quad(c,RealismAssets.PEOPLE,PackedVector2Array([shoulder+Vector2(-9,1),shoulder+Vector2(9,1),hip+Vector2(8,-9),hip+Vector2(-8,-9)]),fabric,armor.lightened(.25))
  for side in [-1,1]:c.draw_rect(Rect2(shoulder+Vector2(side*7-3,11),Vector2(6,8)),armor.lightened(.15))
  c.draw_line(shoulder,hip+Vector2(0,-9),armor.darkened(.3),1,true)
 var hand: Vector2=data['front']
 if mode=='drink':
  c.draw_rect(Rect2(hand+Vector2(-5,-7),Vector2(10,12)),Color('829fa2'))
  c.draw_rect(Rect2(hand+Vector2(-4,-5),Vector2(8,3)),Color('c1d6d0'))
  c.draw_arc(hand+Vector2(5,-1),4,-PI/2,PI/2,12,Color('a6bdc0'),2,true)
 elif mode in ['eat','share','receive']:
  var bowl:Vector2=data['back']+Vector2(3,0)
  c.draw_colored_polygon(PackedVector2Array([bowl+Vector2(-9,-3),bowl+Vector2(9,-3),bowl+Vector2(6,4),bowl+Vector2(-6,4)]),Color('b49f7b'))
  c.draw_line(bowl+Vector2(-8,-3),bowl+Vector2(8,-3),Color('d6c39c'),2,true)
  if mode=='eat':
   c.draw_line(hand,hand+Vector2(7*f,-4),Color('c8baa0'),2,true)
   c.draw_circle(hand+Vector2(7*f,-4),2,Color('c8baa0'))
  else:
   c.draw_rect(Rect2(hand+Vector2(-6,-3),Vector2(12,5)),Color('bb905b'))
   c.draw_line(hand+Vector2(-5,-3),hand+Vector2(5,-3),Color('dfbd7d'),2,true)
 elif mode in ['heal','aid','self_heal']:
  c.draw_circle(hand,4,Color('e0dbc7'));c.draw_arc(hand,4,0,TAU,12,Color('898f82'),1,true)
  c.draw_line(hand,data['back'],Color('d6d0ba'),3,true)
  c.draw_rect(Rect2(data['back']+Vector2(-8,-2),Vector2(15,7)),Color('65736a'))
 elif mode=='patient':
  c.draw_line(hand+Vector2(-6,0),hand+Vector2(5,0),Color('e1dbc8'),5,true)
  for x in [-4,0,4]:c.draw_line(hand+Vector2(x,-2),hand+Vector2(x,3),Color('a5aa98'),1,true)
 elif mode=='cook' and data.get('stationary',false):
  var p:float=data.get('progress',0)
  if p<.28:
   c.draw_line(hand,hand+Vector2(0,-10),Color('c7cec0'),3,true)
   c.draw_line(hand+Vector2(0,-10),hand+Vector2(7*f,-10),Color('9aa699'),3,true)
  elif p<.88:
   c.draw_line(hand+Vector2(0,-7),hand+Vector2(3*f,8),Color('c4b18b'),2,true)
  else:
   var bowl:Vector2=data['back']
   c.draw_arc(bowl,8,0,PI,12,Color('bba27c'),4,true)
   c.draw_line(hand,hand+Vector2(9*f,-7),Color('c4b18b'),2,true)
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
  _weapon_trail(c,data,actor.weapon_item['kind'])
  EquipmentArt.weapon(c,actor.weapon_item['kind'],shoulder+Vector2(-19*f,14) if stowed else hand,f,1.15 if stowed else data['angle'],1,actor.weapon_item['durability']<=0)
 c.draw_set_transform_matrix(base)

static func contact_pose(data: Dictionary,context: Dictionary) -> Dictionary:
 if not context.has('contact'):return data
 var result:=data.duplicate();result['world_contact']=true;var contact:Vector2=context['contact']
 var tremor:=sin(float(data['time'])*8)*2
 result['front']=contact+Vector2(0,tremor)
 result['back']=contact+Vector2(-float(data['facing'])*10,8-tremor)
 return result

static func _arm(c: CanvasItem,shoulder: Vector2,hand: Vector2,color: Color,direction: float,persona: String="") -> void:
 var elbow: Vector2=(shoulder+hand)*.5+Vector2(direction*3,5)
 c.draw_polyline(PackedVector2Array([shoulder,elbow,hand]),color,6,true);c.draw_circle(hand,3,Color('d4ae54') if persona=='pooh' else Color('dfded3') if persona=='mickey' else Color('bdab91'))

static func death_progress(age: float,terminal: bool) -> float:
 return 1.0 if terminal else clampf(age/.55,0,1)

static func _weapon_trail(c: CanvasItem,data: Dictionary,weapon: String) -> void:
 if weapon not in ['knife','bat','spear']:return
 var mode:String=data['mode'];var p:float=data.get('progress',0)
 if (mode!='windup' or p<.65) and (mode!='attack' or p>.22):return
 var path:=PackedVector2Array();var f:float=data['facing']
 var tip:=30.0 if weapon=='knife' else 43.0 if weapon=='bat' else 76.0
 for i in range(6):
  var phase:=clampf(p-(5-i)*.025,0,1)
  var sample:=pose(mode,float(data['time']),phase,f,weapon)
  if mode=='attack' and p-(5-i)*.025<0:sample=pose('windup',float(data['time']),1+p-(5-i)*.025,f,weapon)
  sample=ActorVisual.remap(sample)
  var offset:=Vector2(tip,0).rotated(float(sample['angle']))
  path.append(sample['front']+Vector2(offset.x*f,offset.y))
 c.draw_polyline(path,Color(.87,.85,.7,.28),2,true)
