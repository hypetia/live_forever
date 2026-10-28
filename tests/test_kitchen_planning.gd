extends "res://tests/test_roster_expansion.gd"

func kitchen() -> Node2D:
 var game:=fresh()
 for actor:Survivor in game.survivors:game.self_care.set_enabled(game,actor,false)
 return game

func _run() -> void:
 # Reproduce duplicate cooking while an actual advanced batch is already paid.
 var game:=kitchen();var cook:Survivor=game.survivors[0];var hungry:Survivor=game.survivors[1]
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared empty food fixture')
 cook.position=SurvivalExpansion.job_position('cook_batch');game.select_survivor(0)
 expect(game.expansion.start_job(game,'cook_batch'),'manual advanced batch reserves real ingredients')
 game.self_care.set_enabled(game,hungry,true);hungry.hunger=85;hungry.person.routine=true
 var fuel:int=game.inventory.amount('fuel');advance(game,.2)
 expect(hungry.orders.is_empty() and hungry.self_care_wait=='等待饭菜出锅' and game.inventory.amount('fuel')==fuel,'hungry autonomy waits for the paid advanced batch instead of queuing duplicate fuel use')
 game.free()
 # Reproduce the final drinking water being claimed by autonomous cooking.
 game=kitchen();cook=game.survivors[0];var thirsty:Survivor=game.survivors[1]
 game.self_care.set_enabled(game,cook,true);game.self_care.set_enabled(game,thirsty,true)
 cook.hunger=95;cook.person.routine=true;thirsty.person.thirst=85
 game.inventory.try_take({'meals':game.inventory.amount('meals'),'water':game.inventory.amount('water')-1},'declared final water fixture')
 advance(game,.2)
 expect(not cook.orders.has('cook') and thirsty.self_care_kind=='drink','hungry cooking cannot consume the last water needed by a thirsty resident')
 game.free()

 # Shared kitchen uses unlocked recipes and finishes real meals without switching selection.
 game=kitchen();cook=game.survivors[0]
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,true);a.hunger=85;a.person.thirst=20;a.fatigue=20
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared three-person food shortage')
 cook.position=SurvivalExpansion.job_position('cook_stew');game.select_survivor(2)
 game.self_care.set_cooperation(game,cook,'shared_cooking',true)
 var stock:Dictionary=game.inventory.snapshot();var completions:Array=[]
 game.self_care.cooperation_completed.connect(func(kind,who,_target):completions.append([kind,who]))
 advance(game,.2)
 expect(game.expansion.jobs.size()==1 and game.expansion.jobs[0]['kind']=='cook_stew' and game.expansion.jobs[0]['actor']==0,'three hungry residents get one water-saving stew using the real unlocked kitchen')
 expect(game.selected_id==2 and cook.self_care_kind=='cook_shared','autonomous advanced work retains both its owner and player selection')
 expect(game.inventory.amount('raw_food')==int(stock['raw_food'])-2 and game.inventory.amount('water')==int(stock['water'])-1 and game.inventory.amount('fuel')==int(stock['fuel'])-1 and game.inventory.amount('meals')==0,'advanced autonomy reserves exact ingredients without early output')
 valid(game,'paid autonomous stew')
 var midpoint:=SaveSystem.capture(game);var restored:=fresh()
 var store:=SaveSystem.new();store.path='user://paid-shared-kitchen.json'
 expect(store.write_state(game)['ok'],'paid autonomous advanced work writes to the real save format')
 var read:Dictionary=store.read_state()
 expect(read['ok'] and SaveSystem.validate(read['data']).is_empty() and read['data']['expansion']['jobs'][0]['kind']=='cook_stew','JSON save preserves the shared owner and paid advanced recipe')
 var invalid:Dictionary=midpoint.duplicate(true);invalid['expansion']['jobs'].clear()
 expect(not SaveSystem.apply_state(game,invalid).is_empty() and SaveSystem.capture(game)==midpoint,'an orphaned shared-cooking claim is rejected before changing current resources')
 expect(SaveSystem.apply_state(restored,midpoint).is_empty(),'unfinished advanced shared meal restores through the normal save path')
 advance(game,30);advance(restored,30)
 expect(game.survivors.all(func(a):return a.completed_by_task['eat']==1 and a.hunger<40),'all three residents eat actual produced meals through normal table tasks')
 expect(game.inventory.amount('fuel')==int(stock['fuel'])-1 and completions==[['cook',0]],'one advanced batch uses one fuel and reports one real cooperation completion')
 expect(SaveSystem.capture(game)==SaveSystem.capture(restored),'restored preparation has identical costs, meals and needs without duplicated output')
 valid(game,'completed autonomous stew');valid(restored,'restored autonomous stew');restored.free();game.free()
 # Turning permission off during the paid walk cancels the trip and refunds only once.
 game=kitchen();cook=game.survivors[0]
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 for a:Survivor in game.survivors:a.hunger=85
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared cancellable kitchen need')
 game.self_care.set_enabled(game,cook,true);game.self_care.set_cooperation(game,cook,'shared_cooking',true)
 stock=game.inventory.snapshot();advance(game,.2)
 expect(not game.expansion.jobs.is_empty() and not cook.route.is_empty(),'shared advanced cooking physically approaches the kitchen')
 game.self_care.set_cooperation(game,cook,'shared_cooking',false)
 expect(game.expansion.jobs.is_empty() and cook.route.is_empty() and cook.self_care_kind.is_empty() and game.inventory.snapshot()==stock,'permission withdrawal stops uncompleted work, movement and ownership and refunds exact cost')
 game.self_care.set_cooperation(game,cook,'shared_cooking',false)
 expect(game.inventory.snapshot()==stock,'repeated withdrawal cannot refund the advanced ingredients twice')
 valid(game,'cancelled shared advanced cooking');game.free()
 # Sunset must cancel paid daytime cooking, rather than finish it off screen.
 game=kitchen();cook=game.survivors[0]
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 for a:Survivor in game.survivors:a.hunger=85
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared sunset shared preparation')
 game.self_care.set_enabled(game,cook,true);game.self_care.set_cooperation(game,cook,'shared_cooking',true)
 stock=game.inventory.snapshot();advance(game,.2);game.end_day()
 expect(game.cycle.phase=='planning' and game.expansion.jobs.is_empty() and cook.self_care_kind.is_empty() and game.inventory.snapshot()==stock,'sunset refunds advanced shared cooking and cannot produce hidden meals')
 valid(game,'sunset cancels shared cooking');game.free()
 # Personal player work is never taken over by the helper policy.
 game=kitchen();cook=game.survivors[0]
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 for a:Survivor in game.survivors:a.hunger=85
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared manual override need')
 game.self_care.set_enabled(game,cook,true);game.self_care.set_cooperation(game,cook,'shared_cooking',true)
 stock=game.inventory.snapshot();advance(game,.2);game.select_survivor(0);game.assign_task('craft')
 expect(game.expansion.jobs.is_empty() and cook.orders==['craft'] and cook.self_care_kind.is_empty(),'manual crafting replaces and refunds the autonomous advanced batch')
 advance(game,1)
 expect(cook.orders==['craft'] and game.inventory.amount('water')==int(stock['water']) and game.inventory.amount('fuel')==int(stock['fuel']),'automatic kitchen permission cannot override the new manual order or re-spend its ingredients')
 valid(game,'manual takeover of helper');game.free()
 # An unavailable producer must not make reachable hungry people wait forever.
 game=kitchen();cook=game.survivors[0];var helper:Survivor=game.survivors[1]
 game.scheduler.navigation.stairs_open=false;cook.position=Vector2(200,640)
 expect(game.scheduler.submit(cook,'cook') and cook.state==Survivor.TaskState.BLOCKED,'a real unreachable manual stove order remains explicitly blocked')
 helper.position=game.stove.work_position();game.survivors[2].position=Vector2(500,430);game.survivors[2].hunger=85
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared reachable helper food shortage')
 game.self_care.set_enabled(game,helper,true);game.self_care.set_cooperation(game,helper,'shared_cooking',true)
 expect(not KitchenPlan.pending(game),'blocked cooking is not advertised as food that will arrive')
 advance(game,.2)
 expect(helper.orders==['cook'] and cook.orders==['cook'],'reachable helper can start food while preserving the blocked manual order')
 game.scheduler.navigation.stairs_open=true
 valid(game,'blocked producer does not prevent viable cooking');game.free()
 # An urgent drink interrupts paid autonomous preparation without finishing it remotely.
 game=kitchen();cook=game.survivors[0]
 game.facilities.levels['stove']=2;game.facilities.sync(game)
 for a:Survivor in game.survivors:a.hunger=85
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared dehydration during shared preparation')
 game.self_care.set_enabled(game,cook,true);game.self_care.set_cooperation(game,cook,'shared_cooking',true)
 stock=game.inventory.snapshot();advance(game,.2);cook.person.thirst=95;advance(game,1.1)
 expect(game.expansion.jobs.is_empty() and cook.self_care_kind=='drink' and game.inventory.snapshot()==stock,'critical thirst cancels and refunds advanced preparation and starts a real drink trip on the next needs decision')
 expect(game.inventory.amount('meals')==0 and not cook.route.is_empty() and cook.route.back()==game.water_store.position,'interrupted preparation cannot create food or continue walking toward its old stove target')
 valid(game,'urgent dehydration cancels autonomous advanced food');game.free()
 # Chef skill wins among authorized helpers, and tier-three batches help five people.
 game=kitchen();var chef:=ready_recruit(game,'he')
 game.self_care.sync(game);game.facilities.levels['stove']=2;game.facilities.sync(game)
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,true);a.hunger=85;a.person.thirst=20;a.fatigue=20
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared four-person chef batch')
 game.self_care.set_cooperation(game,game.survivors[0],'shared_cooking',true);game.self_care.set_cooperation(game,chef,'shared_cooking',true)
 advance(game,.2)
 expect(game.expansion.jobs.size()==1 and game.expansion.jobs[0]['actor']==chef.survivor_id and game.expansion.jobs[0]['kind']=='cook_stew','authorized chef is chosen ahead of ordinary helpers and produces a four-person stew')
 valid(game,'chef advanced cooperation');game.free()
 game=kitchen();ready_recruit(game,'alice');ready_recruit(game,'conan');game.self_care.sync(game)
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,true);a.hunger=85;a.person.thirst=20;a.fatigue=20
 game.facilities.levels['stove']=3;game.facilities.sync(game)
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared five-person meal shortage')
 cook=game.survivors[0];game.self_care.set_cooperation(game,cook,'shared_cooking',true);stock=game.inventory.snapshot()
 advance(game,.2)
 expect(game.expansion.jobs.size()==1 and game.expansion.jobs[0]['kind']=='cook_pot','five-person need makes the high-level kitchen useful with one six-portion pot')
 advance(game,60)
 expect(game.survivors.all(func(a):return a.completed_by_task['eat']==1) and game.inventory.amount('meals')==1 and game.inventory.amount('fuel')==int(stock['fuel'])-1,'five actual meals are eaten, one portion remains and only one fuel is consumed')
 valid(game,'five-person efficient kitchen');game.free()
 game=kitchen();chef=ready_recruit(game,'he');game.self_care.sync(game)
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,false);a.hunger=30;a.person.thirst=20
 chef.hunger=85;game.facilities.levels['stove']=3;game.facilities.sync(game)
 game.inventory.try_take({'meals':game.inventory.amount('meals')},'declared one-person meal need')
 expect(KitchenPlan.choose(game,chef)=='cook','one hungry person cannot trigger an oversized advanced batch just because the kitchen is upgraded')
 stock=game.inventory.snapshot();advance(game,.2)
 expect(game.inventory.snapshot()==stock and game.expansion.jobs.is_empty(),'disabled basic care and absent shared permission cannot silently spend cooking supplies')
 expect(not game.expansion.start_job(game,'cook_pot',-1,chef.survivor_id,true),'automatic entry cannot bypass the explicit shared-cooking permission')
 game.free()
 print('KITCHEN PLANNING RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
