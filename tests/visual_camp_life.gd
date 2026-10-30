extends "res://tests/visual_campaign.gd"
func tab(g: Node2D,label: String) -> void:
 for node in g.camp_view.root.find_children('*','Button',true,false):
  if node.text==label:await click_at(node.get_global_rect().get_center());return
 check(false,'tab reachable '+label)
func item_click(grid: BackpackGrid,kind: String) -> void:
 for index in range(grid.items.size()):
  if grid.items[index]['kind']=='provision' and grid.items[index]['key']==kind:await click_at(grid.cells[index].get_global_rect().get_center());return
 check(false,'visible typed stack '+kind)
func _run() -> void:
 var output:String=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output)
 var g:Node2D=load('res://scenes/campaign.tscn').instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
 for a:Survivor in g.survivors:g.self_care.set_enabled(g,a,false)
 # Fund only this declared UI construction fixture, not campaign balance validation.
 g.inventory.deposit({'materials':10,'tools':2},'GUI construction fixture')
 await process_frame;await keypress(KEY_F5)
 check(g.camp_view.opened and g.paused and g.camp_view.page=='situation','F5 opens paused actual camp screen')
 var clock:float=g.simulation_time;sim(g,3);check(g.simulation_time==clock,'reading forecast spends no game time')
 await tab(g,'物资');check(g.camp_view.page=='food','food tab receives actual click')
 await picture(output+'/camp-food.png')
 await tab(g,'生产');check(g.camp_view.page=='production','production tab receives actual click')
 await click_at(g.camp_view.actions['category:building'].get_global_rect().get_center())
 check(g.camp_view.actions.has('planter') and not g.camp_view.actions['planter'].disabled,'categorized planter recipe reachable')
 var material:int=g.inventory.amount('materials')
 await click_at(g.camp_view.actions['planter'].get_global_rect().get_center())
 check(not g.camp_view.opened and not g.paused and g.camp.food.jobs.size()==1,'recipe click closes panel and starts actual walking job')
 check(g.inventory.amount('materials')==material-5 and g.camp.food.infrastructure['plots']==0,'paid blueprint has no early planter')
 sim(g,45);check(g.camp.food.infrastructure['plots']==1 and g.camp.food.jobs.is_empty(),'physical construction finishes actual planter')
 await keypress(KEY_F5);await tab(g,'生产');await click_at(g.camp_view.actions['category:garden'].get_global_rect().get_center())
 check(not g.camp_view.actions['plant_veg'].disabled and g.camp_view.actions['harvest'].disabled,'real UI distinguishes sowing from immature harvest')
 await click_at(g.camp_view.actions['plant_veg'].get_global_rect().get_center());sim(g,35)
 check(g.camp.food.plots.size()==1,'UI sowing becomes actual growing crop')
 await keypress(KEY_F5);await tab(g,'健康');check(g.camp_view.actions.has('care:1') and g.camp_view.actions['care:1'].disabled,'nonmedic care correctly disabled with explicit target')
 await tab(g,'关系');check(g.camp_view.actions.has('talk:xu'),'relationship screen provides a specific companion')
 var trust:int=g.people.relationship(0,1)
 await click_at(g.camp_view.actions['talk:xu'].get_global_rect().get_center())
 check(not g.camp_view.opened and not g.camp.relations.job.is_empty(),'companion click starts physical attendance')
 sim(g,50);check(g.people.relationship(0,1)==trust+2 and g.camp.relations.job.is_empty(),'UI conversation resolves only after travel and actual time')
 await keypress(KEY_F5);await tab(g,'关系');await picture(output+'/camp-relations.png');await keypress(KEY_ESCAPE)
 check(not g.camp_view.opened and not g.paused,'Escape returns to running game')
 check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),'actual UI actions leave a valid save')
 g.free();await create_timer(.1).timeout
 g=load('res://scenes/campaign.tscn').instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
 for a:Survivor in g.survivors:g.self_care.set_enabled(g,a,false)
 g.end_day();g.cycle.roles.assign(['guard','bed','scavenge']);check(g.start_expedition(),'normal first-night departure for field UI')
 await process_frame
 await click_at(g.world_offset()+Vector2(300,620)*g.world_scale());sim(g,8)
 check(g._loot_open and g.expedition.loot_site==0,'actual click walks and searches to open mixed loot')
 var cans:int=g.camp.food.amount('cans')
 await item_click(g.interface.container_grid,'cans')
 check(g.camp.food.amount('cans',g.camp.food.cargo)==1 and g.camp.food.amount('cans')==cans,'real typed loot click transfers one to carried stack')
 await item_click(g.interface.container_grid,'drinks');await keypress(KEY_ESCAPE)
 check(not g._loot_open,'Escape closes physical loot panel')
 await keypress(KEY_I);check(g.expedition_view.bag_open,'I opens actual carried food grid')
 await item_click(g.expedition_view.stack_grid,'drinks')
 check(not g.expedition_view.bag_open and not g.camp.food.field_action.is_empty(),'clicking drink starts held field use')
 sim(g,1);check(g.expedition_view.search_bar.visible and g.expedition_view.search_bar.value>0,'field drinking shows real progress bar')
 sim(g,1.2);check(g.camp.food.field_action.is_empty() and g.camp.food.amount('drinks',g.camp.food.cargo)==0,'actual field drink finishes and consumes exactly one')
 check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),'mixed typed field inventory remains saveable')
 await picture(output+'/camp-field-food.png')
 g.free();await create_timer(.1).timeout
 print('CAMP VISUAL RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
