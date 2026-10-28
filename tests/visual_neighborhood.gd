extends "res://tests/visual_campaign.gd"
## Declared display fixtures isolate presentation, not campaign balance.
var output := "user://neighborhood-visual"
func display_trip(map_id: String) -> Node2D:
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.simulation_time=3600;game.chronicle.manual_defense=false;game.expansion.stage=2;game.expansion.collected.assign(['relay']);game.expansion.warm_nights=2
 game.inventory.deposit({'materials':20,'tools':5,'fuel':10,'water':5,'medicine':3},'declared UI fixture')
 game.end_day();game.choose_destination(map_id);game.cycle.roles.assign(['guard','bed','scavenge']);game.cycle.loadout={'materials':12,'tools':2,'fuel':4,'medicine':1,'water':2};game.start_expedition()
 for e in game.expedition.enemies:e['hp']=0;e['mode']='dead'
 return game
func place(game: Node2D,id: String) -> void:
 var p:=NeighborhoodSystem.point(id);game.expedition.player_x=p.x;game.expedition.player_y=p.y;game.expedition.floor_level=NeighborhoodSystem.NODES[id]['floor']
func capture(game: Node2D,name: String) -> void:
 game._process(0);game.expedition_view.queue_redraw();await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(output.path_join(name+'.png'))
func _run() -> void:
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():output=args[0]
 output=ProjectSettings.globalize_path(output);DirAccess.make_dir_recursive_absolute(output)
 var game:=display_trip('clinic');place(game,'generator')
 for size in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
  root.size=size
  for frame in range(4):await process_frame
  await keypress(KEY_E)
  check(game.neighborhood_view.opened and game.paused,'physical E opens the contextual device choices at '+str(size))
  check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(game.neighborhood_view.window.get_global_rect()),'context card fits the design canvas at '+str(size))
  await capture(game,'clinic-'+str(size.x)+'x'+str(size.y));await keypress(KEY_ESCAPE)
 root.size=Vector2i(1440,900);await process_frame
 await keypress(KEY_E)
 var original:Dictionary=game.neighborhood.snapshot()
 await click_at(game.neighborhood_view.actions['strip_cold'].get_global_rect().get_center())
 check(game.neighborhood_view.opened and game.neighborhood.snapshot()==original,'one click only reviews irreversible demolition and its lost cold-chain output')
 await keypress(KEY_ESCAPE)
 check(not game.neighborhood_view.opened and game.neighborhood.snapshot()==original,'escaping demolition review leaves the actual world unchanged')
 await keypress(KEY_E);await click_at(game.neighborhood_view.actions['restore_cold'].get_global_rect().get_center())
 check(not game.neighborhood_view.opened and not game.paused and game.neighborhood.work.get('id','')=='restore_cold','mouse confirmation starts the same physical timed project as normal commands')
 sim(game,2);await capture(game,'clinic-work')
 check(game.neighborhood.work['elapsed']>1 and game.neighborhood.clinic['mode']=='sealed','visible local progress occurs before supplies are consumed or the generator runs')
 game.paused=true;var frozen:=SaveSystem.capture(game)
 for n in range(5):await process_frame;RenderingServer.force_draw()
 check(SaveSystem.capture(game)==frozen,'rendering facilities, progress and fog while paused never changes simulation')
 game.paused=false;sim(game,12);await capture(game,'clinic-restored')
 check(game.neighborhood.clinic['mode']=='running' and SaveSystem.validate(SaveSystem.capture(game)).is_empty(),'finished visible device change preserves a valid paid save')
 # A distant click chooses a route instead of opening a remote action menu.
 game.expedition.player_x=float(NeighborhoodSystem.NODES['generator']['x'])-210;game.expedition_controls_override=null
 await click_at(game.world_offset()+(NeighborhoodSystem.point('generator')-Vector2(game.expedition_view._camera(),35))*game.world_scale())
 check(game.interface.has_move_target and game.interface.target_site==-3 and not game.neighborhood_view.opened,'distant object click sets an actual approach intent')
 sim(game,3)
 check(game.neighborhood_view.opened and game.neighborhood.near(game,'generator'),'mouse approach reaches the same range boundary before opening the card')
 await keypress(KEY_ESCAPE);place(game,'patient');game._process(0)
 await keypress(KEY_E);await click_at(game.neighborhood_view.actions['rescue'].get_global_rect().get_center());sim(game,9)
 game.expedition_view.bag_open=true;await capture(game,'rescue-carry')
 check(game.expedition.carrying_person and game.expedition_view.stack_grid.items.filter(func(e):return e['kind']=='rescue').size()==2,'back-carried companion and both reserved inventory cells are actually displayed')
 game.free()
 game=display_trip('waterworks');place(game,'valve')
 # This display fixture selects an already restored plant; repair gameplay is covered separately.
 game.neighborhood.water['mode']='running';game.neighborhood.water['connected']=true;game.neighborhood.water['leak']=1
 await keypress(KEY_E);await capture(game,'water-diversion')
 check(game.neighborhood_view.actions.size()==5 and not game.neighborhood_view.actions['repair_leak'].disabled,'largest card presents real route choices and the forecast repair')
 await click_at(game.neighborhood_view.actions['route_home'].get_global_rect().get_center());sim(game,3)
 check(game.neighborhood.water['target']=='home' and not game.neighborhood_view.opened,'route choice finishes in the scene and persists')
 game.neighborhood_view.open_at('valve');game.save_store.path=output.path_join('display-save.json')
 check(game.save_store.write_state(game)['ok'] and game.load_game() and not game.neighborhood_view.opened and game.paused,'load closes contextual UI and resumes paused without changing completed route')
 game.free();await create_timer(.1).timeout
 print('NEIGHBORHOOD VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
