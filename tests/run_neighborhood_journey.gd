extends SceneTree
const Pilot=preload('res://tests/neighborhood_pilot.gd')
func _initialize() -> void:call_deferred('_run')
func _run() -> void:
 var args:=OS.get_cmdline_user_args()
 var style:String=args[0] if args.size()>0 else 'preserve'
 var output:String=args[1] if args.size()>1 else 'user://neighborhood-journey.json'
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 var prior_records:Array=[]
 if args.size()>2:
  var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[2]))
  var restore_error:=SaveSystem.apply_state(game,previous['snapshot'])
  if not restore_error.is_empty():push_error(restore_error);quit(1);return
  prior_records=previous['records'];game.paused=false
 var pilot:=Pilot.new();pilot.style='cooperative';pilot.district_style=style;pilot.setup(game)
 var records:Array=prior_records;var prior:=0;var steps:=0;var issue:='';var stamp:=Time.get_ticks_msec()
 while not game.game_over and game.expansion.day(game)<=35 and steps<1100000:
  if game.expansion.outcome=='victory':
   if style!='preserve' or (game.neighborhood.memories.any(func(m):return m['kind']=='sterilize') and game.cycle.phase=='dawn'):break
   game.expansion.endless=true
  pilot.tick(.05);steps+=1
  var day:int=game.expansion.day(game)
  if prior!=day:
   prior=day;issue=SaveSystem.validate(SaveSystem.capture(game))
   records.append({'day':day,'stock':game.inventory.snapshot(),'health':game.survivors.map(func(a):return a.health),'neighborhood':game.neighborhood.snapshot(),'phase':game.cycle.phase,'stage':game.expansion.stage,'issue':issue})
   print('NEIGHBORHOOD DAY ',style,' ',day,' hp ',game.survivors.map(func(a):return roundi(a.health)),' clinic ',game.neighborhood.clinic,' water ',game.neighborhood.water,' issue ',issue)
   var checkpoint:=FileAccess.open(output+'.checkpoint.json',FileAccess.WRITE);checkpoint.store_string(JSON.stringify({'records':records,'snapshot':SaveSystem.capture(game)},' '));checkpoint.close()
   if not issue.is_empty():break
 var n:NeighborhoodSystem=game.neighborhood
 var did_rescue:bool=n.rescue['state']=='safe'
 var did_water:bool=n.water['mode']=='running' and n.water['connected'] and n.water['leak']==3
 var choice:bool=n.clinic['mode']==('running' if style=='preserve' else 'stripped')
 var made_care:bool=n.memories.any(func(m):return m['kind']=='sterilize') if style=='preserve' else true
 var okay:bool=issue.is_empty() and pilot.failures.is_empty() and not game.game_over and game.survivors.all(func(a):return a.health>0) and game.expansion.outcome=='victory' and did_rescue and did_water and choice and made_care
 var report:Dictionary={'passed':okay,'style':style,'issue':issue,'pilot_failures':pilot.failures,'rescued':did_rescue,'stable_water':did_water,'choice':choice,'made_care':made_care,'steps':steps,'wall_seconds':(Time.get_ticks_msec()-stamp)/1000.0,'records':records,'snapshot':SaveSystem.capture(game),'no_resource_hp_position_enemy_or_campaign_injections':true}
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,' '));file.close()
 print('NEIGHBORHOOD JOURNEY ', 'PASS' if okay else 'FAIL',' ',style,' day ',game.expansion.day(game),' issue ',issue,' ',pilot.failures)
 game.free();await create_timer(.1).timeout;quit(0 if okay else 1)
