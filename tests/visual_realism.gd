extends 'res://tests/visual_campaign.gd'
func _run() -> void:
 var output:String=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output)
 var g:Node2D=load('res://scenes/campaign.tscn').instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
 for actor:Survivor in g.survivors:g.self_care.set_enabled(g,actor,false)
 await process_frame;g._process(0);await picture(output+'/shelter.png')
 var before:=SaveSystem.capture(g)
 for i in range(12):g.queue_redraw();await process_frame
 check(SaveSystem.capture(g)==before,'material and mesh rendering never changes simulation or inventory')
 g.select_survivor(2);var person:Survivor=g.survivors[2]
 await click_at(person.global_position+Vector2(0,-65));check(g.selected_id==2,'textured character still responds to actual scene clicks')
 await held_key(KEY_D,true);sim(g,.3);await held_key(KEY_D,false)
 check(person.position.x>before['actors'][2]['position'][0],'real D key moves the textured character')
 check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),'walking after art upgrade remains saveable')
 var frame_times:Array=[]
 for i in range(45):
  var start:=Time.get_ticks_usec();g.queue_redraw();await process_frame
  if i>=15:frame_times.append((Time.get_ticks_usec()-start)/1000.0)
 frame_times.sort();print('REALISM FRAME MS median=',frame_times[15],' p95=',frame_times[28],' meshes=',ActorVisual.meshes.size())
 check(ActorVisual.meshes.size()<=ActorVisual.MAX_MESHES,'mesh cache stays bounded during live frames')
 g.free();await process_frame
 var gallery:Node2D=load('res://tests/art_gallery.gd').new();root.add_child(gallery);await process_frame;await picture(output+'/cast.png')
 for mode in ['walk','attack','search','cook','sleep']:
  gallery.mode=mode;gallery.queue_redraw();await process_frame;await picture(output+'/cast-'+mode+'.png')
 gallery.free();await process_frame
 for id in LocationCatalog.ALL_IDS:
  g=load('res://scenes/campaign.tscn').instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
  # Authored visual fixtures expose each existing map; gameplay unlocks are unchanged.
  g.expedition=g.regions[id];g.expedition.begin(2,{},1);g.cycle.phase='scavenge';g.expedition.environment_active=false
  g.expedition.player_x=650 if id in ['street','clinic','market'] else 1400
  g.expedition.floor_level=0;g.expedition.player_y=620;g.expedition.elapsed=2
  g._process(0);await process_frame;await picture(output+'/map-'+id+'.png')
  g.free();await process_frame
 await create_timer(.1).timeout
 print('REALISM VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
