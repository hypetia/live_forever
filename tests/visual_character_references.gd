extends "res://tests/visual_campaign.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var output:String=args[0] if not args.is_empty() else ProjectSettings.globalize_path('user://character-references')
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 for scenario in ['classic','convoy','infirmary']:
  game.chronicle.apply_scenario(game,scenario);game._process(0)
  await process_frame;await process_frame
  var names:Array=game.survivors.map(func(a):return a.display_name)
  check(names.all(func(n):return n in ['阿笠博士','黑杰克','里昂','小当家','端木蓉','詹姆斯·邦德']),'actual roster cards use recognizable names in '+scenario)
  game.chronicle_view.show_page('people')
  var text:=''
  for child in game.chronicle_view.body.get_children():
   if child is Label:text+=child.text
  check(text.contains('角色原型：') and names.all(func(n):return text.contains(n)),'actual character page contains each resident and visible prototype reference in '+scenario)
  await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join(scenario+'.png'))
  game.chronicle_view.close()
  check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'new roster identities remain valid in '+scenario)
 # Day-18 arrival fixture; use actual catalogue controls and native mouse events.
 game.simulation_time=17*720;game.people.last_day=18;game.upkeep.level=1
 game.chronicle_view.show_page('roster')
 await process_frame;await process_frame
 var catalogue:=''
 for child in game.chronicle_view.body.get_children():
  if child is Label:catalogue+=child.text
 check(PeopleCatalog.DATA.values().all(func(info):return catalogue.contains(info['name']) and catalogue.contains(info['reference'])),'scrollable catalogue contains all twelve names and source works')
 var scroll:ScrollContainer=game.chronicle_view.body.get_parent()
 scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 await process_frame;await process_frame
 var wick_button:Button
 for child in game.chronicle_view.body.get_children():
  if child is Button and child.text.begins_with('接纳 米老鼠'):wick_button=child
 check(is_instance_valid(wick_button) and not wick_button.disabled,'last arrival has a reachable eligible recruitment control')
 var raw_before:int=game.inventory.amount('raw_food')
 if is_instance_valid(wick_button):await click_at(wick_button.get_global_rect().get_center())
 check(game.survivors.back().person.persona=='mickey' and game.inventory.amount('raw_food')==raw_before-2,'actual last catalogue button recruits Mickey and pays the joining cost')
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('catalogue.png'))
 game.chronicle_view.close();game._process(0)
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('expanded-team.png'))
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'catalogue-recruited party remains a valid campaign')
 check(game.people.recruit(game,'pooh'),'final roster can recruit Pooh as the fifth living resident')
 game.self_care.sync(game)
 for a:Survivor in game.survivors:
  game.self_care.set_enabled(game,a,false)
  a.position=Vector2([410,480,680,750,600][a.survivor_id],430)
  a.person.morale=40;a.person.stress=60;a.person.trauma=20
 game.chronicle_view.show_page('people')
 await process_frame;await process_frame
 var picnic:Button
 for child in game.chronicle_view.body.get_children():
  if child is Button and child.text.begins_with('让维尼分享'):picnic=child
 check(is_instance_valid(picnic) and not picnic.disabled,'Pooh special activity has an available visible character-page control')
 if is_instance_valid(picnic):await click_at(picnic.get_global_rect().get_center())
 check(not game.chronicle_view.opened and game.expansion.jobs.any(func(j):return j['kind']=='picnic'),'actual mouse command starts physical picnic preparation and returns to the scene')
 sim(game,2)
 check(game.chronicle.meal_day==0,'visible preparation grants no early comfort')
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('picnic-preparing.png'))
 sim(game,12)
 check(game.chronicle.meal_day==18 and game.survivors[0].person.morale>44,'completed visible picnic benefits the nearby companions')
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('picnic-complete.png'))
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'five selected residents and completed picnic have a valid persistent state')
 game.free();await create_timer(.2).timeout
 print('CHARACTER REFERENCES VISUAL RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
