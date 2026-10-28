extends "res://tests/visual_campaign.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var output:String=args[0] if not args.is_empty() else ProjectSettings.globalize_path('user://character-references')
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 for scenario in ['classic','convoy','infirmary']:
  game.chronicle.apply_scenario(game,scenario);game._process(0)
  await process_frame;await process_frame
  var names:Array=game.survivors.map(func(a):return a.display_name)
  check(names.all(func(n):return n in ['斯塔克','克里斯','里昂','小当家','灰原哀','杰克船长']),'actual roster cards use recognizable names in '+scenario)
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
  if child is Button and child.text.begins_with('接纳 约翰'):wick_button=child
 check(is_instance_valid(wick_button) and not wick_button.disabled,'last arrival has a reachable eligible recruitment control')
 var raw_before:int=game.inventory.amount('raw_food')
 if is_instance_valid(wick_button):await click_at(wick_button.get_global_rect().get_center())
 check(game.survivors.back().person.persona=='wick' and game.inventory.amount('raw_food')==raw_before-2,'actual last catalogue button recruits Wick and pays the joining cost')
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('catalogue.png'))
 game.chronicle_view.close();game._process(0)
 await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join('expanded-team.png'))
 check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'catalogue-recruited party remains a valid campaign')
 game.free();await create_timer(.2).timeout
 print('CHARACTER REFERENCES VISUAL RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
