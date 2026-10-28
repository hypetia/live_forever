extends SceneTree
const Pilot=preload('res://tests/camp_pilot.gd')
func _initialize() -> void:call_deferred('_run')
func _run() -> void:
 var args:=OS.get_cmdline_user_args()
 var scenario:String=args[0] if args.size()>0 else 'classic'
 var style:String=args[1] if args.size()>1 else 'quiet'
 var output:String=args[2] if args.size()>2 else 'user://tactical-balance.json'
 var until:int=int(args[3]) if args.size()>3 else 35
 var game:Node2D=load('res://scenes/campaign.tscn').instantiate();game.persistence_enabled=false;root.add_child(game);game.set_process(false)
 game.chronicle.apply_scenario(game,scenario)
 var pilot:=Pilot.new();pilot.style=style;pilot.setup(game)
 var cooperation: Dictionary={'aid':0,'cook':0}
 game.self_care.cooperation_completed.connect(func(kind: String,_id: int,_target: int):cooperation[kind]+=1)
 var records:Array=[];var previous_day:=0;var steps:=0;var issue:=''
 var stamp:=Time.get_ticks_msec()
 while not game.game_over and game.expansion.day(game)<=until and (game.expansion.outcome.is_empty() or until>35) and steps<1000000:
  if until>35 and not game.expansion.outcome.is_empty():game.expansion.endless=true
  pilot.tick(1.0/20);steps+=1
  var day:int=game.expansion.day(game)
  if day!=previous_day:
   previous_day=day
   issue=SaveSystem.validate(SaveSystem.capture(game))
   records.append({'day':day,'health':game.survivors.map(func(a):return a.health),'needs':game.survivors.map(func(a):return [a.hunger,a.person.thirst,a.fatigue,a.infection,a.illness]),'stock':game.inventory.snapshot(),'camp':game.camp_snapshot(),'stage':game.expansion.stage,'trips':pilot.trips,'sieges':pilot.siege_count,'error':issue})
   print('TACTICAL DAY ',scenario,' / ',style,' ',day,' stage ',game.expansion.stage,' hp ',game.survivors.map(func(a):return roundi(a.health)),' stock ',game.inventory.snapshot(),' valid ',issue)
   var f:=FileAccess.open(output+'.checkpoint.json',FileAccess.WRITE);f.store_string(JSON.stringify({'records':records,'snapshot':SaveSystem.capture(game)},' '));f.close()
   if not issue.is_empty():break
 var won:bool=game.expansion.outcome=='victory'
 var okay:bool=issue.is_empty() and not game.game_over and game.survivors.all(func(a):return a.health>0) and ((won and until==35) or (until!=35 and game.expansion.day(game)>until))
 okay=okay and game.camp.food.conditions.values().all(func(c):return c['nutrition']>=25 and c['fever']<50)
 var report:Dictionary={'cooperation':cooperation,'passed':okay,'scenario':scenario,'style':style,'until':until,'victory':won,'issue':issue,'steps':steps,'wall_seconds':(Time.get_ticks_msec()-stamp)/1000.0,'records':records,'snapshot':SaveSystem.capture(game),'no_inventory_grants':true,'no_teleports':true,'no_health_need_enemy_or_mission_overrides':true,'live_defenses':pilot.siege_count}
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,' '));file.close()
 print('TACTICAL BALANCE ', 'PASS' if okay else 'FAIL',' ',scenario,'/',style,' day ',game.expansion.day(game),' issue ',issue,' file ',output)
 game.free();await create_timer(.1).timeout;quit(0 if okay else 1)
