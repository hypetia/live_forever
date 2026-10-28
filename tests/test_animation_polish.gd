extends "res://tests/test_selected_cast.gd"

func _run() -> void:
 var slow:=MotionPlayback.new();var fast:=MotionPlayback.new()
 slow.sample(Vector2.ZERO,.1,1);fast.sample(Vector2.ZERO,.1,1)
 for i in range(1,21):
  slow.sample(Vector2(i*3,0),.02,1)
  fast.sample(Vector2(i*3,0),.04,1)
 expect(is_equal_approx(slow.phase,fast.phase),'equal real travel gives equal foot phase at different walking speeds')
 var at:=slow.phase
 for i in range(20):slow.sample(Vector2(60,0),.02,1)
 expect(slow.phase==at and slow.weight==0,'standing against a wall neither advances footsteps nor leaves a running pose')
 slow.sample(Vector2(60,0),0,-1)
 expect(slow.phase==at and slow.weight==0,'paused animation cannot advance stride or turn')
 slow.sample(Vector2(800,0),.02,-1)
 expect(slow.phase==at and slow.weight==0,'teleport and load do not create a burst of footsteps')
 var landed:=false
 for i in range(1,30):
  var frame:=slow.sample(Vector2(800-i*3,0),.02,-1)
  landed=landed or frame['step']
 expect(landed and slow.weight>.9,'actual movement starts a weighted gait and contact events')
 var pose:=CharacterMotion.pose('walk',1,0,1,'',{'phase':1.2,'weight':0,'velocity':0})
 expect(pose['left']==Vector2(-8,-3) and pose['right']==Vector2(10,-3),'a zero-speed movement flag cannot lift feet')
 var wounded:=CharacterMotion.pose('walk',1,0,1,'',{'phase':1.2,'weight':1,'injury':80})
 var healthy:=CharacterMotion.pose('walk',1,0,1,'',{'phase':1.2,'weight':1,'injury':0})
 expect(wounded['head'].y>healthy['head'].y and wounded['left'].y>healthy['left'].y,'actual injury produces guarded posture and shorter lift')
 for kind in ['knife','bat','spear','pistol']:
  var before:=CharacterMotion.pose('windup',0,1,1,kind)
  var after:=CharacterMotion.pose('attack',0,0,1,kind)
  expect(before['front'].distance_to(after['front'])<.001 and absf(before['angle']-after['angle'])<.001,'contact boundary is continuous for '+kind)
  var resting:=CharacterMotion.pose('idle',0,0,1,kind)
  var ready:=CharacterMotion.pose('windup',0,0,1,kind);var recovered:=CharacterMotion.pose('attack',0,1,1,kind)
  expect(ready['front']==resting['front'] and ready['back']==resting['back'],'attack starts from resting hands without a snap '+kind)
  expect(recovered['front']==resting['front'] and recovered['back']==resting['back'] and recovered['left']==resting['left'] and recovered['right']==resting['right'],'recovery returns both hands and feet to rest '+kind)
  var mirrored:=CharacterMotion.pose('windup',0,1,-1,kind)
  expect(before['front'].x==-mirrored['front'].x and before['front'].y==mirrored['front'].y,'both facing directions preserve weapon timing '+kind)
 expect(CharacterMotion.pose('windup',0,.45,1,'bat')['front']!=CharacterMotion.pose('windup',0,.45,1,'knife')['front'],'heavy swing and knife anticipation have different silhouettes')
 var g:=setup('pooh');var host:Survivor=g.survivors.back();var guest:Survivor=g.survivors[0]
 host.position=SurvivalExpansion.job_position('picnic');guest.position=host.position+Vector2(70,0)
 g.survivors[1].position=Vector2(200,640);g.survivors[2].position=Vector2(950,430)
 g.select_survivor(host.survivor_id);g.expansion.start_job(g,'picnic')
 expect(CharacterMotion.shelter_context(guest,g)['mode']=='idle','a reservation before work cannot make companions eat')
 advance(g,2)
 var state:=SaveSystem.capture(g)
 expect(CharacterMotion.shelter_context(host,g)['mode']=='share' and CharacterMotion.shelter_context(guest,g)['mode']=='receive','host offers food and nearby idle companion responds during paid preparation')
 expect(CharacterMotion.shelter_context(g.survivors[1],g)['mode']=='idle' and CharacterMotion.shelter_context(g.survivors[2],g)['mode']=='idle','different floor and distant people do not mime sharing')
 for i in range(50):
  CharacterMotion.shelter_context(host,g);CharacterMotion.shelter_context(guest,g)
 expect(SaveSystem.capture(g)==state,'sampling group animation never changes food, cooldown, direction or saved state')
 guest.manual_walking=true
 expect(CharacterMotion.shelter_context(guest,g)['mode']=='walk','a player movement order takes priority over group gestures')
 guest.manual_walking=false
 g.expansion.cancel(g,host.survivor_id)
 expect(CharacterMotion.shelter_context(guest,g)['mode']=='idle','cancelled sharing leaves no stale companion animation')
 g.free()
 g=fresh()
 for a:Survivor in g.survivors:g.self_care.set_enabled(g,a,a.survivor_id==1)
 guest=g.survivors[0];var medic:Survivor=g.survivors[1]
 guest.health=55;g.self_care.set_cooperation(g,medic,'medical',true)
 var stock:int=g.inventory.amount('medicine');advance(g,.1)
 expect(absf(medic.route.back().x-guest.position.x)==42,'medic approaches a bedside position instead of overlapping the patient')
 for i in range(300):
  advance(g,1.0/60)
  if medic.activity.get('kind','')=='aid':break
 expect(medic.activity.get('kind','')=='aid' and CharacterMotion.shelter_context(guest,g)['mode']=='patient','only care physically in progress triggers the patient response')
 expect(medic.position.distance_to(guest.position)<=56 and g.inventory.amount('medicine')==stock and guest.health<60,'care animation cannot grant treatment before completion')
 state=SaveSystem.capture(g)
 for i in range(20):CharacterMotion.shelter_context(guest,g)
 expect(SaveSystem.capture(g)==state,'patient presentation does not override facing, work or medical ownership')
 advance(g,5)
 expect(g.inventory.amount('medicine')==stock-1 and guest.health>=85 and CharacterMotion.shelter_context(guest,g)['mode']!='patient','completed care pays once and clears patient pose')
 valid(g,'animation polish physical care');g.free()
 var audio:=GameAudio.new();audio.persistent=false;root.add_child(audio)
 expect(audio.sounds.has('hurt') and audio.sounds['hurt'].data!=audio.sounds['notice'].data,'injury has its own sound rather than the notification fallback')
 expect(audio.sounds['foot_wood'].data!=audio.sounds['foot_gravel'].data,'indoor and outdoor feet use distinct material sounds')
 expect(audio.foley!=audio.effects,'foley cannot cut off actual attack and injury cues')
 audio.free()
 print('ANIMATION POLISH RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
