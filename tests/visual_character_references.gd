extends "res://tests/visual_campaign.gd"
func _run() -> void:
 var args:=OS.get_cmdline_user_args();var output:String=args[0] if not args.is_empty() else ProjectSettings.globalize_path('user://character-references')
 DirAccess.make_dir_recursive_absolute(output)
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 for scenario in ['classic','convoy','infirmary']:
  game.chronicle.apply_scenario(game,scenario);game._process(0)
  await process_frame;await process_frame
  var names:Array=game.survivors.map(func(a):return a.display_name)
  check(names.all(func(n):return n in ['斯塔克','纲手','里昂','山治','华佗','韦小宝']),'actual roster cards use recognizable names in '+scenario)
  game.chronicle_view.show_page('people')
  var text:=''
  for child in game.chronicle_view.body.get_children():
   if child is Label:text+=child.text
  check(text.contains('角色原型：') and names.all(func(n):return text.contains(n)),'actual character page contains each resident and visible prototype reference in '+scenario)
  await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output.path_join(scenario+'.png'))
  game.chronicle_view.close()
  check(SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'new roster identities remain valid in '+scenario)
 game.free();await create_timer(.2).timeout
 print('CHARACTER REFERENCES VISUAL RESULT: %d checks, %d failures' % [checks,failures]);quit(1 if failures else 0)
