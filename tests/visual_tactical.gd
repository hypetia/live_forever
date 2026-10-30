extends "res://tests/visual_campaign.gd"
func _run() -> void:
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 await process_frame;await process_frame
 for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.size=size
  for n in range(5):await process_frame
  await keypress(KEY_F2)
  check(game.chronicle_view.opened and game.paused,'F2 opens and pauses scenario selection at '+str(size))
  check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(game.chronicle_view.window.get_global_rect()),'scenario window remains inside the design viewport at '+str(size))
  await keypress(KEY_ESCAPE)
  await keypress(KEY_F3)
  check(game.chronicle_view.opened and game.chronicle_view.person_buttons.size()==game.survivors.size() and game.chronicle_view.choice_buttons.size()==2,'F3 exposes the actual roster, histories and selectable beliefs at '+str(size))
  await keypress(KEY_ESCAPE)
 root.size=Vector2i(1440,900)
 await keypress(KEY_F2);await picture('res://docs/v21-starts.png');await keypress(KEY_ESCAPE)
 await keypress(KEY_F3);await picture('res://docs/v21-people.png');await keypress(KEY_ESCAPE)
 var stock:Dictionary=game.inventory.snapshot();game.chronicle_view.show_page('starts')
 var choose:Button
 for c in game.chronicle_view.body.get_children():
  if c is Button and c.text.contains('旧城旅社'):choose=c
 game.chronicle_view.body.get_parent().ensure_control_visible(choose)
 await process_frame;await process_frame
 await click_at(choose.get_global_rect().get_center())
 check(game.new_dialog.visible and game.inventory.snapshot()==stock,'scenario selection confirms before replacing real supplies')
 game.new_dialog.get_cancel_button().pressed.emit();await process_frame
 check(game.inventory.snapshot()==stock,'cancel preserves the current campaign')
 var toolkit:Dictionary=game.expansion.gear.filter(func(item):return item['kind']=='toolkit')[0]
 game.expansion.assign_gear(game,toolkit['id'],2)
 game.paused=false;game.end_day();game.cycle.roles.assign(['guard','bed','scavenge']);game.cycle.loadout={'tools':1};game.start_expedition()
 # Explicit rendering fixture positions the player beside the first partition;
 # all interaction after positioning uses actual dispatched keys.
 var f:ExpeditionState=game.expedition
 for e in f.enemies:e['hp']=0;e['mode']='dead' # Explicit isolated room-rendering fixture.
 var x:float=InteriorState.layout('street')[0]['x'];f.player_x=x-35
 await held_key(KEY_ALT,true);sim(game,.2)
 check(f.interior.peeking,'held Alt produces the bounded peek state')
 await picture('res://docs/v21-door-peek.png');await held_key(KEY_ALT,false)
 await held_key(KEY_E,true);sim(game,1.7);await held_key(KEY_E,false);sim(game,.05)
 check(f.interior.doors[0]['open'],'held E opens the physically nearby door')
 await held_key(KEY_E,true);sim(game,1.7);await held_key(KEY_E,false);sim(game,.05)
 check(not f.interior.doors[0]['open'],'a second held E closes the door')
 await held_key(KEY_X,true);sim(game,3.5);await held_key(KEY_X,false);sim(game,.05)
 check(f.interior.doors[0]['window']==1 and f.bag['tools']==1 and game.survivors[f.actor_id].tool_item['durability']==92,'actual X input quietly opens a window and wears the equipped kit once')
 await held_key(KEY_X,true);sim(game,1.3);await held_key(KEY_X,false);sim(game,.05)
 check(f.player_x>x,'second X input vaults through the actual window')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'graphical room interaction stays saveable')
 game.free()
 game=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.simulation_time=1800;game.cycle.seed=43;game.enter_night_planning();game.cycle.roles.assign(['guard','guard','bed']);game.start_expedition()
 await process_frame;await process_frame
 check(game.siege.active and game.siege_view.pause_panel.visible,'night attack has its own visible preparation pause')
 game.compact.refresh()
 check(game.cards.all(func(c):return c.visible),'every defending person has a visible selectable card')
 check(game.cards.all(func(c):return c.get_global_rect().end.x<game.siege_view.toolbar.position.x),'defender cards do not overlap the combat controls')
 await click_at(game.cards[1].get_global_rect().get_center())
 check(game.selected_id==1,'actual defender card click transfers control during a raid')
 await double_click(game.cards[1].get_global_rect().get_center())
 check(not game.center.visible and game.selected_id==1,'double-clicking a defender cannot open instant-care or recruitment menus during battle')
 await keypress(KEY_SPACE);sim(game,6)
 check(game.siege.wave==1 and not game.siege_view.pause_panel.visible,'Space resumes actual visible enemy waves')
 await picture('res://docs/v21-base-defense.png')
 var before:float=game.siege.elapsed;await keypress(KEY_ESCAPE);sim(game,1)
 check(game.paused and game.siege.elapsed==before,'Escape pauses the actual defense clock')
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'visible active defense can be saved')
 game.free();await create_timer(.15).timeout
 print('TACTICAL VISUAL RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
