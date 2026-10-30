extends "res://tests/visual_campaign.gd"

func _run() -> void:
	var output: String=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/equipment-gui-artifacts"
	DirAccess.make_dir_recursive_absolute(output)
	var g: Node2D = load("res://scenes/campaign.tscn").instantiate()
	g.persistence_enabled = false
	root.add_child(g); ArchiveFixture.campaign(g); g.set_process(false)
	await process_frame
	g.expansion.grant("knife");g.expansion.grant("knife");g.expansion.grant("vest");g.expansion.grant("coat")
	g.expansion.gear[1]["durability"]=31;g.expansion.gear[2]["durability"]=12
	var controlled: int = g.selected_id
	await keypress(KEY_O)
	var view: EquipmentLoadout = g.equipment_view
	check(view.opened and g.paused,"O opens a dedicated paused equipment screen")
	check(view.item_buttons.size()==3 and view.slot_buttons.size()==4,"three identical weapons and four distinct equipment slots are shown")
	await click_at(view.actor_buttons[0].get_global_rect().get_center())
	await click_at(view.item_buttons[2].get_global_rect().get_center())
	check(g.survivors[0].weapon_item.get("id")==2,"actual item button assigns exact second knife to first person")
	await click_at(view.actor_buttons[1].get_global_rect().get_center())
	await click_at(view.item_buttons[3].get_global_rect().get_center())
	check(g.survivors[1].weapon_item.get("id")==3 and g.survivors[0].weapon_item.get("id")==2 and g.survivors[2].weapon_item.get("id")==1,"real UI independently arms three people with identical knives")
	check(g.selected_id==controlled,"inspecting another person does not steal movement control")
	await click_at(view.slot_buttons[1].get_global_rect().get_center())
	await click_at(view.item_buttons[4].get_global_rect().get_center())
	await click_at(view.slot_buttons[2].get_global_rect().get_center())
	await click_at(view.item_buttons[5].get_global_rect().get_center())
	check(g.survivors[1].armor_item.get("id")==4 and g.survivors[1].coat_item.get("id")==5 and g.survivors[1].weapon_item.get("id")==3,"armor and clothing buttons preserve held weapon")
	await click_at(view.slot_buttons[0].get_global_rect().get_center())
	await picture("res://docs/equipment-loadout.png")
	await keypress(KEY_ESCAPE)
	check(not view.opened and not g.paused and not g.center.visible,"closing restores running time without another menu")
	g.interface.toggle_workshop();g.interface.workshop_section="storage";g.interface._create_workshop()
	var choice: OptionButton = g.interface.workshop_owner_choices[2]
	choice.select(0);choice.item_selected.emit(0);await process_frame
	check(g.survivors[0].weapon_item.is_empty() and g.survivors[1].weapon_item.get("id")==3,"legacy storage warehouse option clears only selected physical item")
	choice=g.interface.workshop_owner_choices[2]
	choice.select(1);choice.item_selected.emit(1);await process_frame
	check(g.survivors[0].weapon_item.get("id")==2,"legacy storage explicitly assigns the chosen owner")
	await keypress(KEY_O);await keypress(KEY_O)
	check(not g.interface.workshop_open and not g.paused,"opening from workshop restores original running clock on close")
	g.end_day();await process_frame
	check(g.interface.role_equipment_buttons.size()==3,"every night role has its own four equipment buttons")
	await click_at(g.interface.role_equipment_buttons[1][0].get_global_rect().get_center())
	check(view.opened and view.selected_actor==1 and view.selected_slot==0,"night role opens the selected person's held weapon slot")
	await keypress(KEY_ENTER)
	check(view.opened and g.cycle.phase=="planning" and not g.expedition.active,"Enter behind the equipment screen cannot depart")
	await click_at(view.item_buttons[2].get_global_rect().get_center())
	check(g.survivors[1].weapon_item.get("id")==2 and g.survivors[0].weapon_item.is_empty() and g.expansion.gear[2]["owner"]=="","explicit transfer releases source and returns replaced knife to warehouse")
	await keypress(KEY_ESCAPE)
	check(g.paused,"night planning remains paused after closing equipment")
	g.cycle.roles.assign(["floor","scavenge","guard"]);g.interface.refresh()
	await picture("res://docs/equipment-night-plan.png")
	await keypress(KEY_ENTER)
	check(g.expedition.active,"departure succeeds after finishing loadout")
	g._process(0)
	await click_at(g.expedition_view.equipment_buttons[0].get_global_rect().get_center())
	check(view.opened and view.read_only and view.selected_actor==1,"field equipment uses same screen with actual expedition actor")
	check(view.item_buttons.size()==1 and view.item_buttons[2].disabled,"field inspection displays worn weapon and prevents warehouse access")
	await keypress(KEY_ESCAPE)
	check(not g.paused,"field inspection restores clock")
	g.paused=true;await keypress(KEY_O);await keypress(KEY_ESCAPE)
	check(g.paused,"opening while already paused preserves pause")
	var state := SaveSystem.capture(g)
	check(SaveSystem.validate(state).is_empty(),"UI-driven multi-item equipment yields valid save")
	await dispose_scene(g)
	# Rendering fixtures contain complete facilities and unfinished work independently.
	g=load("res://scenes/campaign.tscn").instantiate();g.persistence_enabled=false;root.add_child(g);ArchiveFixture.campaign(g);g.set_process(false)
	g.camp.enabled=true;g.camp.food.infrastructure={"plots":2,"trap":true,"pantry":true,"filter":true}
	g.camp.situation.resilience["generator"]=true
	g.camp.food.plots.assign([{"kind":"vegetables","ready":1,"fed":false},{"kind":"herbs","ready":2,"fed":false}])
	for pair in [[0,"bed"],[1,"heater"],[2,"filter"],[3,"barricade"]]:
		g.cycle.builds.append({"slot":pair[0],"type":pair[1],"state":"complete","actor":-1,"elapsed":CampaignCycle.RECIPES[pair[1]]["seconds"]})
	g.cycle.builds.append({"slot":4,"type":"bed","state":"blueprint","actor":-1,"elapsed":12.0})
	g._sync_props();g.expansion.heater_remaining=20
	g.facilities.levels={"workbench":3,"stove":3};g.facilities.sync(g)
	g._process(0);g.queue_redraw();await process_frame;await process_frame;await picture("res://docs/facilities-built.png")
	check(g._extra_props.size()==1 and g.cycle.bed_count()==2,"unfinished construction does not create a usable bed")
	check(g.water_store.interaction_rect().has_point(Vector2(60,-40)),"upgraded filtration body remains clickable")
	for res in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await process_frame;await keypress(KEY_O);await process_frame
		check(Rect2(0,0,1440,900).encloses(g.equipment_view.window.get_global_rect()),"loadout uses fixed logical coordinates across window resolutions")
		await picture(output+"/equipment-%dx%d.png"%[res.x,res.y]);await keypress(KEY_ESCAPE)
	await dispose_scene(g)
	print("EQUIPMENT GUI RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
