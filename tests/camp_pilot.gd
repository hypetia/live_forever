extends "res://tests/tactical_pilot.gd"
# Normal player commands only: no stock, positions, needs, enemy or date injection.
var camp_timer:=0.0
func tick(delta: float) -> void:
 if game.expedition.active and game.expedition.loot_site>=0:
  game.camp.food.open_cache(game)
  if game.expedition.capacity-game.expedition.used_capacity()>3:
   for kind in ['vegetables','meat','herbs','seeds','cans','drinks']:
    if game.camp.food.slots()>=2:break
    if game.camp.food.amount(kind)<5:game.camp.food.transfer(game,kind,2)
 camp_timer-=delta
 if camp_timer<=0 and game.cycle.phase=='day':
  camp_timer=.5;manage_camp()
 super.tick(delta)
func manage_camp() -> void:
 var food:CampFood=game.camp.food;var day:int=game.expansion.day(game)
 game.camp.situation.backup_on=game.camp.situation.resilience['generator']
 for actor:Survivor in game.survivors:
  var id:=actor.survivor_id
  if actor.health<60 or actor.hunger>=65 or actor.person.thirst>=65 or actor.fatigue>=75 or not actor.orders.is_empty() or not actor.route.is_empty() or game._external_busy(id):continue
  var kinds:Array=[]
  var hungry:bool=game.survivors.any(func(a):return a.health>0 and food.conditions[a.person.persona]['nutrition']<60)
  if hungry and game.inventory.amount('meals')<3:kinds.append_array(['balanced','salad','broth'])
  if game.inventory.amount('water')<12:kinds.append_array(['boil_water','filter_water'])
  if food.plots.any(func(plot):return int(plot['ready'])<=day):kinds.append('harvest')
  if food.plots.size()<int(food.infrastructure['plots']) and game.inventory.amount('water')>=10:kinds.append('plant_veg')
  if day>=8 and game.inventory.amount('materials')>=15 and game.inventory.amount('tools')>=3:
   kinds.append_array(['planter','pantry','settling_filter','backup_power','supply_pact'])
  if game.camp.situation.forecast(day)['visible'] and game.inventory.amount('fuel')>=8:kinds.append('lure_horde')
  if game.inventory.amount('materials')>=12 and game.inventory.amount('fuel')>=5:kinds.append('caravan_trade')
  for kind in kinds:
   if food.error(game,kind,id).is_empty() and food.start_job(game,kind,id):break
