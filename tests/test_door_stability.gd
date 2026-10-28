extends "res://tests/test_tactical_campaign.gd"

func _run() -> void:
 var game:=trip();var field:ExpeditionState=game.expedition;var actor:Survivor=game.survivors[field.actor_id]
 var wall:float=InteriorState.layout('street')[0]['x']
 for direction in [1.0,-1.0]:
  field.player_x=wall-direction*40;field.floor_level=0;field.player_y=620
  for n in range(180):field.tick(1.0/60,actor,{'axis':direction})
  var at:float=field.player_x;var fatigue:float=actor.fatigue
  for n in range(120):field.tick(1.0/60,actor,{'axis':direction})
  expect(is_equal_approx(field.player_x,at) and absf(at-wall)>=17.99,'holding against the closed door does not oscillate or cross from side '+str(direction))
  expect(not field.moving and is_equal_approx(actor.fatigue,fatigue),'a blocked character stops walking animation and does not accumulate walking fatigue')
  field.tick(.1,actor,{'axis':-direction})
  expect((field.player_x-at)*direction<0,'walking away from a closed door works immediately')
  field.player_x=wall-direction*8
  field.tick(.01,actor,{'axis':direction})
  expect(is_equal_approx(field.player_x,wall-direction*8),'an older save inside the margin is not pushed backwards')
  field.tick(.1,actor,{'axis':-direction})
  expect((field.player_x-(wall-direction*8))*direction<0,'an older save inside the margin can walk away')
 field.interior.doors[0]['open']=true;field.player_x=wall-25
 field.tick(.3,actor,{'axis':1.0})
 expect(field.player_x>wall,'opening the door permits crossing the same boundary')
 valid(game,'stable door movement');game.free()
 print('DOOR STABILITY RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
