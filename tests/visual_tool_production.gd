extends "res://tests/visual_campaign.gd"
var output:="/tmp/tool-production-pictures"

func _run() -> void:
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var g:Node2D=load("res://scenes/campaign.tscn").instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false);g.chronicle.manual_defense=false
	for actor:Survivor in g.survivors:
		actor.person.routine=false
		for key in g.camp.relations.policies[actor.person.persona]:g.camp.relations.policies[actor.person.persona][key]=false
	await process_frame;await keypress(KEY_K)
	check(g.interface.workshop_open and g.interface.production_counts.size()==3,"workbench exposes quantity and mode controls for parts and both kinds of tools")
	await picture(output+"/workbench.png")
	var initial:Dictionary=g.inventory.snapshot()
	var count:SpinBox=g.interface.production_counts["craft"]
	await click_at(count.global_position+Vector2(count.size.x-9,8));await click_at(count.global_position+Vector2(count.size.x-9,8))
	check(count.value==3,"actual spinbox arrows set a three-piece batch")
	await click_at(g.interface.workshop_recipes["craft"].get_global_rect().get_center())
	check(not g.paused and not g.interface.workshop_open and g.production.orders[0]["amount"]==3,"arrange button returns to live play with the requested finite plan")
	for i in range(200):
		sim(g,.1)
		if g.survivors[0].state==Survivor.TaskState.WORKING:break
	check(g.survivors[0].held_cost.get("materials",0)==2,"GUI pause fixture has reached real paid production")
	await keypress(KEY_K);await click_button(g.interface.workshop_panel,"生产计划")
	check(g.interface.production_actions.has("craft"),"production sidebar opens the actual queued job and its controls")
	await picture(output+"/orders.png")
	await click_at(g.interface.production_actions["craft"].get_global_rect().get_center())
	check(g.production.orders[0]["paused"] and g.inventory.amount("materials")==initial["materials"],"pause button cancels unfinished work and refunds paid inputs")
	await keypress(KEY_ESCAPE);sim(g,15)
	check(g.inventory.amount("tools")==initial["tools"],"paused plans do not resume behind the closed menu")
	await keypress(KEY_K);await click_button(g.interface.workshop_panel,"生产计划")
	await click_at(g.interface.production_actions["craft"].get_global_rect().get_center());await keypress(KEY_ESCAPE);sim(g,65)
	check(g.production.orders.is_empty() and g.inventory.amount("tools")==initial["tools"]+3 and g.inventory.amount("materials")==initial["materials"]-6,"resume completes exactly three paid jobs")
	await keypress(KEY_K);await click_button(g.interface.workshop_panel,"工作台")
	var mode:OptionButton=g.interface.production_modes["craft"]
	await click_at(mode.get_global_rect().get_center())
	for i in range(3):
		if mode.get_popup().get_focused_item()==1:break
		await keypress(KEY_DOWN)
	await keypress(KEY_ENTER)
	check(mode.selected==1,"actual mode dropdown selects stock replenishment")
	await click_at(g.interface.workshop_recipes["craft"].get_global_rect().get_center());sim(g,5)
	check(g.production.orders[0]["mode"]=="stock" and g.inventory.amount("materials")==initial["materials"]-6,"a fulfilled stock target spends no further materials")
	await keypress(KEY_K);await click_button(g.interface.workshop_panel,"生产计划")
	var cancel:Button=g.interface.workshop_panel.find_children("*","Button",true,false).filter(func(button):return button.text=="取消")[0]
	await click_at(cancel.get_global_rect().get_center());await keypress(KEY_ESCAPE)
	check(g.production.orders.is_empty(),"queue cancellation removes a standing stock target")
	await keypress(KEY_O)
	check(g.equipment_view.slot_buttons.size()==4,"equipment has a dedicated fourth tool slot")
	await click_at(g.equipment_view.slot_buttons[3].get_global_rect().get_center())
	var id:int=g.expansion.gear.filter(func(item):return item["kind"]=="toolkit")[0]["id"]
	await click_at(g.equipment_view.item_buttons[id].get_global_rect().get_center())
	check(g.survivors[0].tool_item.get("id",-1)==id,"real equipment action assigns a particular toolkit")
	await picture(output+"/equipment.png");await keypress(KEY_ESCAPE)
	g.end_day();await process_frame
	await click_at(g.interface.role_equipment_buttons[0][3].get_global_rect().get_center())
	check(g.equipment_view.selected_actor==0 and g.equipment_view.selected_slot==3,"night crew row opens that person's tool slot directly")
	await click_at(g.equipment_view.actor_buttons[2].get_global_rect().get_center())
	await click_at(g.equipment_view.item_buttons[id].get_global_rect().get_center())
	check(g.survivors[0].tool_item.is_empty() and g.survivors[2].tool_item.get("id",-1)==id,"tool transfer keeps one owner and one physical durability value")
	await keypress(KEY_ESCAPE)
	for resolution in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080)]:
		root.size=resolution;await process_frame;await process_frame
		check(g.interface.role_equipment_buttons.values().all(func(buttons):return buttons.size()==4 and buttons[3].get_global_rect().end.x<1020),"four independent crew equipment entries fit at "+str(resolution))
	root.size=Vector2i(1440,900);await process_frame
	await click_at(g.interface.map_buttons["works"].get_global_rect().get_center())
	await picture(output+"/planning.png")
	await click_at(g.interface.depart_button.get_global_rect().get_center())
	check(g.cycle.phase=="scavenge" and not g.compact.camp_button.visible and g.expedition_view.equipment_buttons.size()==4,"departure retains tool ownership and exposes its real field durability")
	# Declared positioning and dead-enemy fixture; paid production and GUI transfers
	# above are real. This frame checks the found-tool interaction, not combat.
	var field:ExpeditionState=g.expedition
	for enemy in field.enemies:enemy["hp"]=0;enemy["mode"]="dead"
	var site:Dictionary=field.site_definitions()[1];field.player_x=site["x"];field.floor_level=site["floor"];field.player_y=ExpeditionState.FLOOR_Y[field.floor_level]
	field._search(15,g.survivors[field.actor_id]);g._process(0);await process_frame
	check(g._loot_open and g.interface.container_grid.items.any(func(entry):return entry["kind"]=="tool_cache"),"actual searched container offers the used toolkit as a distinct item")
	var index:int=g.interface.container_grid.items.find_custom(func(entry):return entry["kind"]=="tool_cache")
	await click_at(g.interface.container_grid.cells[index].get_global_rect().get_center())
	check(g.production.carried==["works_tools"] and g.interface.cargo_grid.items.any(func(entry):return entry["kind"]=="tool_cache"),"clicking the found-tool cell transfers it into real cargo")
	await picture(output+"/found-tool.png")
	await keypress(KEY_ESCAPE);await keypress(KEY_I)
	check(g.expedition_view.stack_grid.items.any(func(entry):return entry["kind"]=="tool_cache"),"ordinary field backpack also displays the carried recovery")
	await keypress(KEY_I);await keypress(KEY_O)
	check(g.equipment_view.read_only and g.equipment_view.slot_buttons.size()==4,"field equipment inspection keeps the same four slots without warehouse access")
	await keypress(KEY_ESCAPE)
	field.player_x=90;field.floor_level=0;field.player_y=620;g.expedition_retreat();await process_frame
	await dialog_click(g.departure_dialog,g.departure_dialog.get_ok_button())
	check(g.cycle.phase=="dawn" and g.production.recovered.has("works_tools") and g.expansion.gear.any(func(item):return item["kind"]=="toolkit" and item["durability"]==70 and item["owner"]==""),"confirmed exit deposits the used kit once, with its real condition")
	check(SaveSystem.validate(SaveSystem.capture(g)).is_empty(),"complete production, assignment and found-tool flow remains saveable")
	await dispose_scene(g)
	# Declared depleted-stock fixture verifies planning remains available before
	# the next scavenging trip, without crediting any free supplies.
	g=load("res://scenes/campaign.tscn").instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
	g.inventory.try_take({"materials":g.inventory.amount("materials")},"declared depleted-stock UI fixture")
	await process_frame;await keypress(KEY_K)
	check(not g.interface.workshop_recipes["craft"].disabled,"an unfunded plan can be scheduled before its materials arrive")
	await click_at(g.interface.workshop_recipes["craft"].get_global_rect().get_center());sim(g,2)
	check(g.production.orders.size()==1 and g.production.status(g,g.production.orders[0]).begins_with("缺料") and g.inventory.amount("materials")==0,"unfunded GUI plan waits without a debit or free production")
	await dispose_scene(g)
	print("TOOL PRODUCTION VISUAL RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
