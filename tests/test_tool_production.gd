extends "res://tests/test_campaign.gd"

func fresh() -> Node2D:
	var g:Node2D=load("res://scenes/campaign.tscn").instantiate()
	g.persistence_enabled=false;root.add_child(g);g.set_process(false);g.chronicle.manual_defense=false
	for actor:Survivor in g.survivors:
		actor.person.routine=false;actor.hunger=20;actor.fatigue=10;actor.person.thirst=20
		for key in g.camp.relations.policies[actor.person.persona]:g.camp.relations.policies[actor.person.persona][key]=false
	return g

func kit(g: Node2D,kind: String="toolkit",actor_id: int=2) -> Dictionary:
	var id:int=g.expansion.next_id;g.expansion.grant(kind)
	expect(g.expansion.assign_gear(g,id,actor_id),"physical tool instance equips in its own slot")
	return g.survivors[actor_id].tool_item

func trip(g: Node2D,map: String="street") -> ExpeditionState:
	g.end_day();g.cycle.roles.assign(["floor","floor","scavenge"]);g.choose_destination(map)
	g.cycle.loadout={"tools":1}
	expect(g.start_expedition(),"tool test departs through ordinary night planning")
	for enemy in g.expedition.enemies:enemy["hp"]=0;enemy["mode"]="dead"
	return g.expedition

func place_at(field: ExpeditionState,index: int) -> void:
	var site:Dictionary=field.site_definitions()[index]
	field.player_x=site["x"];field.floor_level=site["floor"];field.player_y=ExpeditionState.FLOOR_Y[field.floor_level]

func _run() -> void:
	test_batch_and_stock()
	test_equipment_orders()
	test_worker_priority()
	await test_append_manual()
	test_interrupt_and_reload()
	test_field_tools()
	test_maintenance()
	test_tool_cache()
	print("TOOL PRODUCTION RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func test_batch_and_stock() -> void:
	var g:=fresh();var initial:Dictionary=g.inventory.snapshot()
	expect(ShelterInventory.NAMES["tools"]=="机械零件" and BackpackStacks.limit("tools")==4,"consumable components have a distinct name and bounded four-unit stacks")
	expect(g.expansion.gear.any(func(item):return item["kind"]=="toolkit" and item["owner"]==""),"every normal start has a reusable spare toolkit")
	expect(g.production.plan(g,"craft","batch",3,0),"one command creates a three-piece production batch")
	expect(g.inventory.snapshot()==initial,"planning does not prepay or remotely create supplies")
	advance(g,65)
	expect(g.inventory.amount("tools")==initial["tools"]+3 and g.inventory.amount("materials")==initial["materials"]-6,"three physical jobs pay six materials and produce exactly three components")
	expect(g.production.orders.is_empty() and g.survivors[0].completed_by_task["craft"]==3,"a completed batch stops and keeps real worker statistics")
	expect(g.production.condition==94,"workbench tools remain reusable and wear once per completed part")
	var target:int=g.inventory.amount("tools")+1
	expect(g.production.plan(g,"craft","stock",target,0),"replenishment target can be set separately from batch count")
	advance(g,35);var materials:int=g.inventory.amount("materials")
	expect(g.inventory.amount("tools")==target and g.production.status(g,g.production.orders[0])=="库存充足","stock orders stop at the requested warehouse quantity")
	advance(g,30)
	expect(g.inventory.amount("materials")==materials,"full-stock plans never keep spending materials")
	g.inventory.try_take({"tools":1},"declared use of a component");advance(g,35)
	expect(g.inventory.amount("tools")==target and g.inventory.amount("materials")==materials-2,"a later consumption triggers only the missing piece")
	g.inventory.try_take({"tools":1},"need one more component");g.inventory.try_take({"materials":g.inventory.amount("materials")},"declared scarcity fixture")
	advance(g,10)
	expect(g.production.status(g,g.production.orders[0]).begins_with("缺料"),"unfunded orders wait without manufacturing free items")
	g.inventory.deposit({"materials":2},"returned supplies");advance(g,35)
	expect(g.inventory.amount("tools")==target and g.inventory.amount("materials")==0,"new supplies resume the waiting order without another click")
	var saved:Dictionary=g.production.snapshot()
	expect(not g.production.plan(g,"craft","stock",0,0) and not g.production.plan(g,"craft","batch",21,0) and not g.production.plan(g,"knife","batch",1,0) and g.production.snapshot()==saved,"invalid targets and recipes are atomic no-ops")
	valid(g,"stock-order save");g.free()

func test_equipment_orders() -> void:
	var g:=fresh();var next:int=g.expansion.next_id
	expect(g.production.plan(g,"toolkit","stock",2,0),"toolkit spare-stock plan uses the equipment pipeline")
	advance(g,55)
	expect(g.production.stock(g,"toolkit")==2 and g.expansion.next_id==next+1,"one missing spare creates exactly one independently numbered kit")
	var first:int=g.expansion.gear.filter(func(item):return item["kind"]=="toolkit")[0]["id"]
	expect(g.expansion.assign_gear(g,first,2),"an assigned toolkit leaves the spare stock count")
	advance(g,5)
	expect(g.production.stock(g,"toolkit")==1 and g.production.status(g,g.production.orders[0]).begins_with("缺料"),"replenishment distinguishes carried equipment from warehouse spares")
	g.production.plan(g,"craft","batch",1,0);advance(g,70)
	expect(g.production.stock(g,"toolkit")==2 and g.expansion.next_id==next+2,"component production unblocks equipment production without recursive free inputs")
	g.production.remove(g,"toolkit");next=g.expansion.next_id
	expect(g.production.plan(g,"lockpick","batch",3,0),"disposable tools also support a finite physical batch")
	advance(g,60)
	expect(g.production.stock(g,"lockpick")==3 and g.expansion.next_id==next+3,"three disposable picks retain separate physical identities")
	expect(g.production.orders.is_empty(),"equipment batch removes its finished order")
	valid(g,"equipment and component orders settle consistently");g.free()

func test_worker_priority() -> void:
	var g:=fresh();var actor:Survivor=g.survivors[0];var original:Dictionary=g.inventory.snapshot()
	g.production.plan(g,"craft","batch",1,0)
	for field in ["hunger","thirst","fatigue","health"]:
		actor.hunger=20;actor.person.thirst=20;actor.fatigue=10;actor.health=100
		if field=="thirst":actor.person.thirst=70
		else:actor.set(field,25 if field=="health" else 75)
		advance(g,1)
		expect(not g.production.orders[0]["active"] and g.production.status(g,g.production.orders[0])=="等待工人恢复","production leaves urgent "+field+" needs to self care")
	expect(g.inventory.amount("materials")==original["materials"] and g.inventory.amount("tools")==original["tools"],"urgent needs never reserve production inputs or start forced labor")
	actor.hunger=20;actor.person.thirst=20;actor.fatigue=10;actor.health=100
	advance(g,30)
	expect(g.production.orders.is_empty(),"recovered worker can resume an enabled target")
	var tools:int=g.inventory.amount("tools");var materials:int=g.inventory.amount("materials")
	g.select_survivor(0);g.assign_task("craft")
	g.production.plan(g,"craft","stock",tools+1,2);advance(g,45)
	expect(g.inventory.amount("tools")==tools+1 and g.inventory.amount("materials")==materials-2,"stock target accounts for another worker's already scheduled production")
	valid(g,"need priority and outstanding manual production");g.free()

func test_append_manual() -> void:
	var g:=fresh();var actor:Survivor=g.survivors[0]
	g.production.plan(g,"craft","batch",3,0)
	for i in range(200):
		advance(g,.1)
		if actor.state==Survivor.TaskState.WORKING:break
	var before:int=g.inventory.amount("tools")
	var shift:=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.keycode=KEY_SHIFT;shift.pressed=true
	Input.parse_input_event(shift);Input.flush_buffered_events();await process_frame;await process_frame
	g.select_survivor(0);g.select_task("eat");g.assign_selected()
	var release:InputEventKey=shift.duplicate();release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events();await process_frame
	expect(actor.orders==["craft","eat"] and g.production.orders[0]["active"] and g.production.orders[0]["paused"],"Shift append retains the current paid piece while pausing later automation")
	valid(g,"manual follow-up attached to an active production plan")
	var clone:=fresh();expect(SaveSystem.apply_state(clone,SaveSystem.capture(g)).is_empty(),"a paused current piece and manual follow-up survive save restoration")
	advance(clone,35)
	expect(clone.inventory.amount("tools")==before+1 and clone.production.orders[0]["amount"]==2 and not clone.production.orders[0]["active"],"completed piece counts once before the queued manual task; remaining batch does not grow")
	clone.production.toggle(clone,"craft");advance(clone,40)
	expect(clone.inventory.amount("tools")==before+3 and clone.production.orders.is_empty(),"resuming the paused remainder preserves the original total batch quantity")
	g.production.remove(g,"craft")
	expect(actor.orders==["eat"] and g.inventory.amount("tools")==before,"cancelling the production plan preserves an explicitly appended manual follow-up")
	valid(g,"production cancellation with a retained manual task")
	clone.free();g.free()

func test_interrupt_and_reload() -> void:
	var g:=fresh();g.production.plan(g,"craft","batch",3,0)
	for i in range(200):
		advance(g,.1)
		if g.survivors[0].state==Survivor.TaskState.WORKING:break
	expect(g.survivors[0].held_cost.get("materials",0)==2,"save and cancellation fixture has reached actual paid work")
	advance(g,.2)
	var captured:=SaveSystem.capture(g);valid(g,"in-progress production plan")
	var clone:=fresh();expect(SaveSystem.apply_state(clone,captured).is_empty(),"mid-job save restores order, paid inputs and work progress")
	advance(clone,65)
	expect(clone.inventory.amount("tools")==int(captured["stock"]["tools"])+3 and clone.production.orders.is_empty(),"reload finishes the remaining count once without duplicating inputs or output")
	valid(clone,"finished restored batch");clone.free()
	var before:int=g.inventory.amount("materials")+int(g.survivors[0].held_cost.get("materials",0))
	g.production.remove(g,"craft")
	expect(g.inventory.amount("materials")==before and g.survivors[0].orders.is_empty() and g.production.condition==100,"cancelling unfinished work refunds held inputs once and does not award output or wear")
	g.production.remove(g,"craft")
	expect(g.inventory.amount("materials")==before,"a repeated cancellation cannot refund twice")
	g.production.plan(g,"craft","batch",2,0);advance(g,2);g.select_survivor(0);g.assign_task("sleep")
	expect(g.production.orders[0]["paused"] and not g.production.orders[0]["active"],"a manual command pauses automation instead of being overwritten")
	advance(g,30)
	expect(g.inventory.amount("tools")==int(captured["stock"]["tools"]),"paused plans cannot silently restart after the manual task")
	g.production.toggle(g,"craft");advance(g,2)
	g.end_day()
	expect(g.production.orders.size()==1 and not g.production.orders[0]["paused"] and not g.production.orders[0]["active"],"sunset suspends the actual job while retaining the enabled production target")
	valid(g,"night-paused order");var stock:Dictionary=g.inventory.snapshot();advance(g,20)
	expect(g.inventory.snapshot()==stock,"planning never runs production behind the overlay")
	g.cycle.roles.fill("floor");g.start_expedition();g.begin_day()
	for actor:Survivor in g.survivors:actor.hunger=20;actor.person.thirst=20;actor.fatigue=10
	advance(g,55)
	expect(g.production.orders.is_empty(),"enabled production resumes on the next day when its worker has recovered")
	var corrupted:=SaveSystem.capture(g);corrupted["production"]["condition"]=-1
	expect(not SaveSystem.validate(corrupted).is_empty(),"negative tool condition is rejected before applying a save")
	corrupted=SaveSystem.capture(g);corrupted["production"]["orders"]=[{"kind":"craft","mode":"stock","amount":3,"actor":g.survivors[0].person.persona,"active":true,"paused":false}]
	expect(not SaveSystem.validate(corrupted).is_empty(),"forged active orders need a real corresponding paid task")
	g.free()

func test_field_tools() -> void:
	var g:=fresh();var tools:=kit(g);var field:=trip(g);var actor:Survivor=g.survivors[field.actor_id]
	expect(g.expansion.equipped_slots(actor)==2,"weapon and equipped toolkit each reserve one backpack slot")
	place_at(field,2);field._search(.25,actor);field._reset_search()
	expect(tools["durability"]==100 and field.sites[2]["locked"],"an interrupted search does not damage tools or unlock the cabinet")
	field._search(4,actor)
	expect(tools["durability"]==92 and not field.sites[2]["locked"] and field.bag["tools"]==1,"successful lock opening wears the toolkit without consuming mechanical components")
	field._search(4,actor)
	expect(tools["durability"]==92,"reopening a searched container cannot charge tool wear again")
	field.player_x=field.route_x();field.floor_level=0;field.player_y=620;field.loot_site=-1
	field._clear_route(.3,actor);field._reset_route()
	expect(tools["durability"]==92,"cancelled route clearance preserves the kit")
	field._clear_route(6,actor)
	expect(field.route_open and tools["durability"]==80 and field.bag["tools"]==1,"clearing a passage reuses the same kit and costs twelve durability")
	var wall:Dictionary=InteriorState.layout(field.location_id)[0];field.player_x=wall["x"]-30;field.floor_level=wall["floor"];field.player_y=ExpeditionState.FLOOR_Y[field.floor_level]
	field.interior.controls(field,actor,.1,{"window":true});valid(g,"quiet window operation with a real equipped tool")
	field.interior.controls(field,actor,4,{"window":true})
	expect(field.interior.doors[0]["window"]==1 and tools["durability"]==72 and field.bag["tools"]==1,"quiet window removal wears eight durability and leaves components intact")
	# Declared construction supplies; toolkit speed and wear use the real model.
	place_at(field,DistrictSystem.POINTS[field.location_id]);field._search(10,actor);field.bag["materials"]=5
	expect(g.districts.begin_work(g,"build"),"field toolkit can be used for actual outpost engineering")
	g.districts.tick_work(g,7.3,{})
	expect(g.districts.regions[field.location_id]["built"] and tools["durability"]==66 and field.bag["tools"]==0,"toolkit makes a nine-second outpost finish earlier, wearing six durability while assembly consumes its component")
	tools["durability"]=1;FieldTools.spend(actor,"route")
	expect(tools["durability"]==0 and not FieldTools.can_use(actor,"route"),"last use breaks a kit without allowing negative durability")
	valid(g,"broken field toolkit persists");g.free()
	g=fresh();var pick:=kit(g,"lockpick");field=trip(g);actor=g.survivors[field.actor_id]
	expect(not FieldTools.can_use(actor,"route") and not FieldTools.can_use(actor,"window"),"disposable picks cannot replace a toolkit for engineering")
	var id:int=pick["id"];var used:int=field.used_capacity();place_at(field,2);field._search(4,actor)
	expect(actor.tool_item.is_empty() and not g.expansion.gear.any(func(item):return item["id"]==id),"a successful lock opening consumes the exact disposable pick instance")
	expect(field.used_capacity()==used-1 and field.bag["tools"]==1,"used pick frees its equipment slot and leaves assembly components untouched")
	valid(g,"consumed disposable tool save");g.free()

func test_maintenance() -> void:
	var g:=fresh();g.production.condition=0;var before:Dictionary=g.inventory.snapshot()
	expect(g.production.rate()==.65 and g.expansion.start_job(g,"service_tools"),"worn bench tools can be serviced without a functioning kit or upgrade")
	advance(g,45)
	expect(g.production.condition==60 and g.production.rate()==1.0,"actual maintenance restores sixty condition and full production speed")
	expect(g.inventory.amount("materials")==before["materials"]-1 and g.inventory.amount("tools")==before["tools"]-1,"maintenance consumes one material and one component once")
	g.inventory.deposit({"materials":3,"tools":1},"declared repair supplies");var item:=kit(g);item["durability"]=0
	expect(g.expansion.start_job(g,"repair",item["id"]),"broken portable tools use existing physical equipment repair")
	advance(g,45)
	expect(item["durability"]==60,"repair restores the original toolkit instead of creating another instance")
	var pick:=kit(g,"lockpick");pick["durability"]=0
	expect(not g.expansion.start_job(g,"repair",pick["id"]),"single-use lockpicks cannot be recycled through equipment repair")
	valid(g,"serviced tools and equipment");g.free()

func test_tool_cache() -> void:
	var g:=fresh();var field:=trip(g,"works");var actor:Survivor=g.survivors[field.actor_id]
	place_at(field,1);field._search(12,actor)
	var key:String="works_tools";var count:int=g.expansion.gear.size();var used:int=field.used_capacity()
	field.bag["water"]=(field.capacity-used)*BackpackStacks.limit("water")
	expect(not g.production.transfer(g,key) and g.production.carried.is_empty(),"full cargo rejects pickup without erasing the source")
	field.bag["water"]=0
	var origin:float=field.player_x;field.player_x+=200
	expect(not g.production.transfer(g,key),"remote cache transfer cannot bypass the searched object's physical range")
	field.player_x=origin
	# Declared ordinary-supply depletion fixture: only the found tool remains.
	for resource in field.sites[1]["contents"]:field.sites[1]["contents"][resource]=0
	g.camp.food.open_cache(g);g.camp.food.caches[g.camp.food.cache_key(field,1)].clear()
	expect(InteractionFeedback.site(g,1)["supplied"],"remaining toolkit keeps an otherwise depleted container visibly supplied")
	expect(g.production.cache_entries(g).size()==1,"searched workshop cabinet contains an actual recoverable toolkit")
	expect(g.production.transfer(g,key) and field.used_capacity()==used+1,"picking up the kit occupies a real cargo slot")
	expect(not InteractionFeedback.site(g,1)["supplied"],"taking the final toolkit turns the now-empty container grey")
	expect(g.expansion.gear.size()==count and g.production.cache_entries(g).is_empty(),"carried cache is not remotely credited to the warehouse or shown twice")
	expect(not g.production.transfer(g,key),"repeat pickup cannot duplicate a tool")
	valid(g,"carried toolkit has a searched source and correct cargo weight")
	expect(g.production.transfer(g,key,true) and field.used_capacity()==used,"putting the kit back restores the same container and frees its slot")
	g.paused=true;expect(g.production.transfer(g,key),"paused inventory allows the same deliberate transfers as ordinary supplies");g.paused=false
	expect(g.production.transfer(g,key,true) and g.production.transfer(g,key),"the same cache can be put back and carried again without duplication")
	var saved:=SaveSystem.capture(g);var clone:=fresh()
	expect(SaveSystem.apply_state(clone,saved).is_empty() and clone.production.carried==[key],"save and load preserve a found toolkit before return")
	field=clone.expedition;field.player_x=90;field.floor_level=0;field.player_y=620
	clone.expedition_retreat();clone.confirm_departure()
	expect(clone.cycle.phase=="dawn" and clone.production.recovered.has(key) and clone.production.carried.is_empty(),"ordinary exit settles the cached tool once")
	expect(clone.expansion.gear.size()==count+1 and clone.expansion.gear[-1]["kind"]=="toolkit" and clone.expansion.gear[-1]["durability"]==70,"returned tool retains its authored used condition and independent identity")
	valid(clone,"recovered toolkit settled at dawn")
	var bad:=SaveSystem.capture(clone);bad["production"]["carried"]=[key]
	expect(not SaveSystem.validate(bad).is_empty(),"a cache cannot be both recovered and still carried")
	clone.free()
	var lost:=fresh();expect(SaveSystem.apply_state(lost,saved).is_empty(),"loss scenario restores the actual carried cache")
	lost.expedition._finish(false)
	expect(lost.production.carried.is_empty() and lost.production.recovered.has(key) and not lost.expansion.gear.any(func(item):return item["kind"]=="toolkit" and item["durability"]==70),"death loses the found tool without recreating its cache or crediting the warehouse")
	valid(lost,"lost field tools settle with survivor death");lost.free();g.free()
