extends "res://tests/visual_campaign.gd"

func _run() -> void:
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 # Explicit shortage and kitchen-tier fixture; all decisions, travel and payments are real.
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared GUI kitchen shortage')
 for actor:Survivor in game.survivors:actor.hunger=85;actor.person.thirst=20;actor.fatigue=20
 game.select_survivor(2)
 var stock:Dictionary=game.inventory.snapshot()
 await keypress(KEY_F4)
 check(game.chronicle_view.opened and game.chronicle_view.page=='cooperate' and game.paused,'real F4 opens the paused cooperation policy')
 var toggle:CheckBox=null
 for child in game.chronicle_view.body.get_children():
  if child is CheckBox and child.text.begins_with('主动为队伍备餐'):toggle=child;break
 check(is_instance_valid(toggle) and not toggle.disabled,'shared food permission is reachable in the real policy panel')
 if is_instance_valid(toggle):await click_at(toggle.get_global_rect().get_center())
 check(game.self_care.members['lin']['shared_cooking'] and not game.self_care.members['xu']['shared_cooking'],'real checkbox authorizes only the intended helper')
 check(game.inventory.snapshot()==stock and game.expansion.jobs.is_empty(),'permission alone while paused cannot spend ingredients or create food')
 await keypress(KEY_ESCAPE);sim(game,2)
 check(not game.paused and game.expansion.jobs.size()==1 and game.expansion.jobs[0]['kind']=='cook_stew','closing the panel lets the authorized helper start one real efficient recipe')
 check(game.selected_id==2 and game.survivors[0].self_care_kind=='cook_shared','the new helper action never takes control away from the player')
 check(game.inventory.amount('raw_food')==int(stock['raw_food'])-2 and game.inventory.amount('water')==int(stock['water'])-1 and game.inventory.amount('fuel')==int(stock['fuel'])-1 and game.inventory.amount('meals')==0,'actual GUI authorization reserves exact stew ingredients without early meals')
 check(game.survivors[1].orders.is_empty() and game.survivors[2].orders.is_empty(),'hungry companions wait without starting duplicate pots')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'GUI-created advanced autonomous job is saveable')
 sim(game,50)
 check(game.survivors.all(func(actor):return actor.completed_by_task['eat']==1 and actor.hunger<40),'three people complete real walks and table use and each eat a paid portion')
 check(game.expansion.jobs.is_empty() and game.inventory.amount('meals')==0 and game.inventory.amount('fuel')==int(stock['fuel'])-1,'completed shared service uses exactly one batch and does not repeat unnecessarily')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'completed autonomous kitchen remains a valid playable campaign')
 game.free();await create_timer(.2).timeout
 print('KITCHEN PLANNING VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
