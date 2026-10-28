extends "res://tests/tactical_pilot.gd"
## A player policy, not a fixture: no resource/HP/position/enemy/progress changes.
var district_style := "preserve"
var project_queue: Array[String] = []
var project_trip := false
var rescue_attempted := false
var failures: Array[String] = []

func setup(scene: Node2D) -> void:
 super.setup(scene)
 elective_person=''
 desired['materials']=36;desired['fuel']=24;desired['medicine']=9

func _manage_expansion() -> void:
 # Preserve an actual opening-night construction budget instead of buying
 # every elective upgrade before deciding what the expedition needs.
 if district_style=="preserve" and game.neighborhood.clinic["mode"]=="sealed" and game.expansion.day(game)<=2:return
 var builder:Survivor=game.survivors[0]
 if builder.health>0 and builder.hunger<65 and builder.fatigue<75 and not game._external_busy(0) and builder.orders.is_empty():
  game.select_survivor(0)
  for item in game.expansion.gear:
   if item['kind'] in ['spear','knife','bat','padding','vest'] and item['durability']<int(GearCatalog.ITEMS[item['kind']]['durability'])*.6 and game.facilities.levels['workbench']>=2 and game.inventory.amount('materials')>=4:
    if game.expansion.start_job(game,'repair',int(item['id'])):return
  if game.residence.condition<70 and game.inventory.can_take({'materials':2}):
   if game.expansion.start_job(game,'maintain'):return
  if game.survivors.size()>3 and game.facilities.levels['workbench']>=2 and game.expansion.gear.filter(func(i):return i['kind']=='spear').size()<3 and game.inventory.can_take(GearCatalog.ITEMS['spear']['cost']):
   game.expansion.start_job(game,'spear');return
 super._manage_expansion()

func _preferred_destination(destination: String) -> String:
 project_queue.clear();project_trip=false
 var n:NeighborhoodSystem=game.neighborhood
 if n.clinic['mode']=='sealed' and n.clinic['cold']>0:
  var id:='restore_cold' if district_style=='preserve' else 'strip_cold'
  if game.inventory.can_take(NeighborhoodSystem.ACTIONS[id]['cost']):project_queue.append(id)
 elif n.clinic['stock']>0 and not n.memories.any(func(m):return m['kind']=='take_med'):
  project_queue.append('take_med')
 elif n.rescue['state']=='waiting' and not n.rescue['id'].is_empty() and game.expansion.day(game)>=int(PeopleCatalog.DATA[n.rescue['id']]['day']) and not rescue_attempted and game.inventory.can_take({'medicine':2,'water':2}):
  project_queue.append('rescue')
 elif game.expansion.unlocked(game,'waterworks'):
  if n.water['mode']=='broken' and game.inventory.can_take({'materials':13,'tools':1}):project_queue.append('restore_water')
  elif n.water['mode']=='running' and not n.water['connected'] and game.inventory.can_take({'materials':12,'tools':1}):project_queue.assign(['connect','route_clinic' if district_style=='preserve' else 'route_home'])
  elif n.water['leak'] in [1,2] and game.inventory.can_take({'materials':2}):project_queue.append('repair_leak')
  elif n.water['leak']==3 and n.water['target']=='home' and district_style=='preserve' and not n.memories.any(func(m):return m['kind']=='sterilize'):project_queue.append('route_clinic')
  elif n.water['leak']==3 and n.water['target']=='clinic' and not n.memories.any(func(m):return m['kind']=='sterilize') and game.inventory.can_take({'water':2,'materials':5,'fuel':3}):project_queue.append('sterilize')
  elif n.water['target']=='clinic' and district_style!='preserve' and n.memories.any(func(m):return m['kind']=='sterilize'):project_queue.append('route_home')
 if project_queue.is_empty():return destination
 project_trip=true;part_target=''
 return NeighborhoodSystem.NODES[NeighborhoodSystem.ACTIONS[project_queue[0]]['node']]['map']

func _extra_loadout() -> void:
 # Equip every living member once. The base three-person policy assigned
 # every extra spear to the same guard, leaving its previous spear unused.
 var targets:Array=[]
 for role in ['scavenge','guard','bed','floor']:
  for a:Survivor in game.survivors:
   if a.health>0 and game.cycle.roles[a.survivor_id]==role:targets.append(a.survivor_id)
 var weapons:Array=game.expansion.gear.filter(func(i):return i['kind'] in ['spear','knife','bat'] and i['durability']>0)
 weapons.sort_custom(func(a,b):return int(GearCatalog.ITEMS[a['kind']]['damage'])>int(GearCatalog.ITEMS[b['kind']]['damage']) if a['kind']!=b['kind'] else int(a['id'])<int(b['id']))
 for index in range(mini(targets.size(),weapons.size())):
  var who:int=targets[index]
  if weapons[index]['owner']!=game.survivors[who].person.persona:game.expansion.equip(game,int(weapons[index]['id']),who)
 if not project_trip:return
 var cost:Dictionary={}
 for id in project_queue:
  for key in NeighborhoodSystem.ACTIONS[id]['cost']:cost[key]=int(cost.get(key,0))+int(NeighborhoodSystem.ACTIONS[id]['cost'][key])
 for key in cost:
  game.cycle.loadout[key]=int(cost[key])+(1 if key=='medicine' and game.inventory.amount(key)>int(cost[key]) else 0)

func tick(delta: float) -> void:
 if game.cycle.phase=='day':
  for a:Survivor in game.survivors:
   if a.speciality=='医护':game.self_care.set_cooperation(game,a,'medical',true)
 if game.cycle.phase not in ['scavenge','returning'] or not project_trip:
  super.tick(delta);return
 if game.departure_dialog.visible:
  game.confirm_departure();trips+=1;project_trip=false;return
 var f:ExpeditionState=game.expedition
 if game.paused:game.paused=false
 if game.cycle.phase=='returning':project_queue.clear()
 if not project_queue.is_empty() and game.neighborhood.work.is_empty():
  var job:String=project_queue[0]
  var node:String=NeighborhoodSystem.ACTIONS[job]['node']
  var p:=NeighborhoodSystem.point(node)
  var input:Dictionary=game._route_controls(p.x,int(NeighborhoodSystem.NODES[node]['floor']),false)
  input=_combat(input)
  if game.neighborhood.near(game,node) and f.attack_cooldown<=0 and not f.enemies.any(func(e):return e['hp']>0 and int(e['floor'])==f.floor_level and absf(float(e['x'])-f.player_x)<180):
   var issue:String=game.neighborhood.error(game,job)
   if issue.is_empty():
    game.neighborhood.start(game,job)
    project_queue.pop_front()
    if job=='rescue':rescue_attempted=true
    input={}
   elif issue.begins_with('背包'):
    failures.append(job+': '+issue);project_queue.clear()
  game.expedition_controls_override=input
 elif not game.neighborhood.work.is_empty():
  game.expedition_controls_override={}
 else:
  if f.floor_level==0 and f.player_x<=119:
   game.expedition_retreat();game.confirm_departure();trips+=1;project_trip=false;return
  game.expedition_controls_override=_combat(game._route_controls(110,0,true))
 game.advance_simulation(delta);game.expedition_controls_override=null

func _defend(delta: float) -> void:
 super._defend(delta)
