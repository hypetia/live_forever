extends "res://tests/visual_animation_polish.gd"

func _run() -> void:
 var args:=OS.get_cmdline_user_args();output=args[0] if not args.is_empty() else '/tmp/scene-polish-frames'
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 for actor:Survivor in game.survivors:game.self_care.set_enabled(game,actor,false)
 # Declared stove starting position; preparation, payments and completion are real.
 var actor:Survivor=game.survivors[0];actor.position=game.stove.work_position();game.select_survivor(0)
 var meals:int=game.inventory.amount('meals')
 game.open_station('cook');await process_frame;await process_frame
 await click_at(game.interface.workshop_recipes['cook'].get_global_rect().get_center())
 check(not game.interface.workshop_open and not game.context_open and actor.orders==['cook'],'the real kitchen recipe command closes menus and exposes the operating stove')
 sim(game,.5);await capture(game,'cook-preparation')
 check(game.stove.cooking_state().get('actor',-1)==0,'ordinary paid cooking starts the real stove animation')
 sim(game,2.3);await capture(game,'cook-stirring')
 check(CharacterMotion.shelter_context(actor,game).get('stationary',false),'stirring uses the actual stove pot instead of a floating second pot')
 game.paused=true;var time:float=game.stove.animation_time;var frozen:=SaveSystem.capture(game)
 for n in range(4):await process_frame;RenderingServer.force_draw()
 check(game.stove.animation_time==time and SaveSystem.capture(game)==frozen,'pause freezes steam and physical cooking together')
 game.paused=false;sim(game,2.5);await capture(game,'cook-serving')
 sim(game,2)
 check(game.inventory.amount('meals')==meals+2 and game.stove.cooking_state().is_empty(),'ordinary cooking pays once and stops its operation animation')
 game.facilities.levels['stove']=2;game.facilities.sync(game);actor.position=SurvivalExpansion.job_position('cook_stew')
 game.open_station('cook');await process_frame;await process_frame
 await click_at(game.interface.workshop_recipes['cook_stew'].get_global_rect().get_center())
 check(game.expansion.jobs.any(func(job):return job['kind']=='cook_stew') and not game.interface.workshop_open,'advanced stew uses its actual recipe button and returns to the scene')
 sim(game,3);await capture(game,'advanced-cooking')
 check(actor.activity.get('kind','')=='cook','advanced recipe visibly cooks rather than performing construction')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'animated kitchen remains saveable')
 game.free()
 game=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.cycle.loadout={'tools':1};game.start_expedition()
 var f:ExpeditionState=game.expedition;actor=game.survivors[f.actor_id]
 # Explicit isolated scene fixture; all interactions use real held input.
 for e in f.enemies:e['hp']=0;e['mode']='dead'
 var wall:float=InteriorState.layout(f.location_id)[0]['x'];f.player_x=wall-28;f.player_y=620;f.floor_level=0
 await held_key(KEY_E,true);sim(game,.5);await held_key(KEY_E,false)
 await capture(game,'door-opening')
 check(f.interior.visual_open(0)>0 and f.interior.visual_open(0)<1 and not f.interior.doors[0]['open'],'real use input moves the door leaf before committing access')
 sim(game,1.2)
 check(f.interior.doors[0]['open'],'the real door completes its existing timed opening')
 await capture(game,'door-open')
 var tools:int=f.bag['tools']
 await held_key(KEY_X,true);sim(game,1.3);await held_key(KEY_X,false)
 await capture(game,'window-lifting')
 check(f.interior.action.get('quiet',false) and f.interior.doors[0]['window']==0 and f.bag['tools']==tools,'real quiet-window input animates lifting before payment')
 sim(game,2.3)
 check(f.interior.doors[0]['window']==1 and f.bag['tools']==tools-1,'actual lifted window commits and pays once')
 f.player_x=300-35;f.player_y=620;f.floor_level=0
 await held_key(KEY_E,true);sim(game,.7)
 await capture(game,'container-search')
 check(f.search_active and InteractionFeedback.site(game,0)['opened']>0,'actual search visibly opens its container')
 await held_key(KEY_E,false);sim(game,.1)
 check(not f.search_active and f.search_progress>0,'releasing use stops the displayed work and retains actual progress')
 await held_key(KEY_E,true);sim(game,4);await held_key(KEY_E,false)
 check(game._loot_open,'completing the same real search opens transfer')
 for key in ['raw_food','water']:f.take_loot(key,100,actor)
 for entry in game.camp.food.cache_entries(game):game.camp.food.transfer(game,entry['key'],100)
 game.close_loot();await capture(game,'container-empty')
 check(not InteractionFeedback.site(game,0)['supplied'] and InteractionFeedback.site(game,0)['opened']==1,'emptied container retains an open grey appearance')
 # Water-zone position is a display fixture. Subsequent walking, contact and pause are real.
 f.condition=0;f.player_x=660;f.player_y=620;f.floor_level=0
 game.expedition_view.motion.reset();game.expedition_view._process(.016)
 await held_key(KEY_D,true)
 var splash:=false
 for n in range(8):
  sim(game,.06);await process_frame
  splash=splash or game.expedition_view.footfalls.marks.any(func(mark):return mark['kind']=='water')
 await held_key(KEY_D,false);await capture(game,'water-footsteps')
 check(splash and f.player_x>660,'walking in the real wet zone creates foot-contact ripples')
 game.paused=true;var marks:Array=game.expedition_view.footfalls.marks.duplicate(true)
 for n in range(4):await process_frame
 check(game.expedition_view.footfalls.marks==marks,'pause preserves visible splash age')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'object animation and wet footsteps retain valid campaign state')
 game.free();await create_timer(.2).timeout
 print('SCENE POLISH VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
