extends "res://tests/test_enemy_ai.gd"

func duel(cautious: bool) -> Dictionary:
	var f := isolated("brute")
	var actor := Survivor.new();actor.metabolism=.4;actor.person.persona="chen"
	actor.fatigue=15;actor.weapon_item={"kind":"knife","durability":60}
	var enemy: Dictionary = f.enemies[0]
	f.player_x=840;f.facing=-1;enemy["direction"]=1.0
	var time := 0.0
	while time<35 and actor.health>0 and enemy["hp"]>0:
		var distance := absf(f.player_x-float(enemy["x"]))
		var retreating: bool = cautious and enemy["mode"]=="windup"
		var axis := (signf(f.player_x-float(enemy["x"])) if distance<CombatRules.bite_range(enemy["kind"])+35 else 0.0) if retreating else signf(float(enemy["x"])-f.player_x) if distance>60 else 0.0
		if cautious and not retreating and not f.attack_obstruction(enemy,actor).is_empty(): axis=signf(float(enemy["x"])-f.player_x)
		if not retreating and distance<70 and (not cautious or f.attack_obstruction(enemy,actor).is_empty()):
			f.facing=signf(float(enemy["x"])-f.player_x);f.attack(actor)
		f.tick(.02,actor,{"axis":axis,"sprint":retreating})
		time+=.02
	var report := {"health":actor.health,"fatigue":actor.fatigue,"seconds":time,"enemy_hp":enemy["hp"],"durability":actor.weapon_item["durability"]}
	actor.free();return report

func ordinary_game() -> Node2D:
	var g: Node2D=load("res://scenes/campaign.tscn").instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false);return g

func _run() -> void:
	var a := Survivor.new();a.metabolism=.4;a.weapon_item={"kind":"knife","durability":100}
	var f := isolated();var e: Dictionary=f.enemies[0]
	f.player_x=760;f.facing=1;e["direction"]=-1.0
	f._resolve_attack(a)
	expect(e["mode"]=="stunned" and e["brace"]>2,"first light hit creates visible stagger and a finite guard window")
	e["mode"]="windup";e["timer"]=.6
	var hp: int=e["hp"];f._resolve_attack(a)
	expect(e["hp"]<hp and e["mode"]=="windup" and e["timer"]==.6,"second hit deals damage without resetting a guarded enemy attack")
	f=isolated();e=f.enemies[0];f.player_x=760;f.facing=1;e["mode"]="windup";e["timer"]=.15;e["direction"]=-1.0
	f._resolve_attack(a)
	expect(e["mode"]=="windup","late committed bite cannot be cancelled by a light hit")
	f=isolated("brute");e=f.enemies[0];f.player_x=760;f.facing=1;e["direction"]=-1.0;e["mode"]="windup";e["timer"]=1.0
	f._resolve_attack(a)
	expect(e["hp"]==80 and e["mode"]=="windup","brute front armor resists knife damage and preserves its heavy attack")
	var front: int=90-e["hp"]
	f=isolated("brute");e=f.enemies[0];f.player_x=760;f.facing=1;e["direction"]=1.0
	f._resolve_attack(a)
	expect(90-e["hp"]>front and e["mode"]=="stunned","attacking the brute from behind bypasses its front armor")
	f=isolated("brute");e=f.enemies[0];f.player_x=760;f.facing=1;e["direction"]=-1.0;e["mode"]="windup";e["timer"]=.9
	a.weapon_item={"kind":"bat","durability":96};f._resolve_attack(a)
	expect(e["hp"]==68 and e["mode"]=="stunned","blunt weapon supplies a distinct armor and stagger counter")
	f=isolated("runner");e=f.enemies[0];f.player_x=900;e["target"]=900;e["direction"]=1.0;e["mode"]="windup";e["timer"]=.24
	a.health=100;tick_enemy(f,a,.12)
	expect(e["x"]>825 and e["x"]<900,"runner pounce moves continuously toward its committed point")
	f.player_x=740;tick_enemy(f,a,.14)
	expect(a.health==100 and e["x"]>825 and e["direction"]==1,"dodging behind the pounce does not make it home or reverse direction")
	f=isolated("runner");e=f.enemies[0];f.player_x=900;e["target"]=900;e["direction"]=1.0;e["mode"]="windup";e["timer"]=.24
	a.health=100;tick_enemy(f,a,.26)
	expect(a.health<100,"standing in the pounce trajectory is dangerous")
	expect(EnemyCatalog.stats("runner")["chase_speed"]>190 and EnemyCatalog.stats("runner")["chase_speed"]<275,"runner catches ordinary walking while sprint remains an escape option")
	f=isolated("runner");f.environment_active=true;f.interior.enabled=true;e=f.enemies[0]
	var wall: Dictionary=InteriorState.layout("street")[0]
	var x: float=wall["x"];e["floor"]=wall["floor"];e["home_floor"]=wall["floor"];e["target_floor"]=wall["floor"];e["x"]=x-25;e["direction"]=1.0;e["target"]=x+80;e["mode"]="windup";e["timer"]=.24
	f.floor_level=wall["floor"];f.player_y=ExpeditionState.FLOOR_Y[f.floor_level];f.player_x=x+60;f.interior.doors[0]["open"]=false
	a.health=100;tick_enemy(f,a,.26)
	expect(e["x"]<x and a.health==100,"closed door blocks the physical pounce and bite")
	a.fatigue=15;var rested := CombatRules.tempo(a);a.fatigue=90
	expect(CombatRules.tempo(a)>rested and CombatRules.effort(GearCatalog.ITEMS["bat"])>CombatRules.effort(GearCatalog.ITEMS["knife"]),"exhaustion slows repeated attacks and heavier weapons cost more effort")
	var reckless := duel(false);var careful := duel(true)
	print("DUEL TELEMETRY ",JSON.stringify({"reckless":reckless,"careful":careful}))
	expect(reckless["health"]<100,"mashing attacks against a brute incurs an actual health cost")
	expect(careful["enemy_hp"]==0 and careful["health"]>reckless["health"],"reading windup and withdrawing beats stationary attack spam")
	a.free()
	var g := ordinary_game();var clinic: ExpeditionState=g.regions["clinic"]
	for index in range(clinic.enemies.size()-1):clinic.enemies[index]["hp"]=0;clinic.enemies[index]["mode"]="dead"
	var wounded: Dictionary=clinic.enemies.back();wounded["hp"]=7
	var origin: float=wounded["x"]
	for key in clinic.sites[0]["contents"]:clinic.sites[0]["contents"][key]=0
	var stock: Dictionary = g.inventory.snapshot();var sites := clinic.sites.duplicate(true)
	g.simulation_time=2520;g.enter_night_planning()
	expect(wounded["hp"]==7 and wounded["x"]==origin,"migration preserves existing wounded enemies rather than scaling or healing them")
	expect(clinic.enemies[0]["hp"]>0 and clinic.enemies[0]["x"]>clinic.ladder_x(),"cleared persistent map receives a new patrol from its far boundary at dusk")
	expect(clinic.sites==sites and g.inventory.snapshot()==stock,"new patrol cannot refill depleted loot or fabricate player supplies")
	var prepared := clinic.snapshot();RegionalThreats.prepare(g)
	expect(clinic.snapshot()==prepared,"opening night planning repeatedly cannot duplicate a migration")
	valid(g,"dusk patrol and persistent wounds")
	var saved := SaveSystem.capture(g);var restored := ordinary_game()
	expect(SaveSystem.apply_state(restored,saved).is_empty() and restored.regions["clinic"].snapshot()==prepared,"loading preserves patrol identities and migration cooldown")
	for enemy in clinic.enemies:enemy["hp"]=0;enemy["mode"]="dead"
	g.districts.regions["clinic"].merge({"built":true,"condition":100.0,"secured_until":10},true)
	g.simulation_time=4680;g.cycle.night_day=7;RegionalThreats.prepare(g)
	expect(clinic.enemies.all(func(enemy):return enemy["hp"]==0) and RegionalThreats.brief(g,"clinic").contains("迁入受阻"),"maintained, secured outpost suppresses migration and advertises that benefit")
	g.simulation_time=7560;g.cycle.night_day=11;RegionalThreats.prepare(g)
	expect(clinic.enemies.any(func(enemy):return enemy["hp"]>0),"expired security permits new patrols again")
	expect(RegionalThreats.tier(4,0)<RegionalThreats.tier(16,0) and RegionalThreats.tier(8,50)>RegionalThreats.tier(8,0),"calendar and regional noise create independent, bounded pressure")
	valid(g,"security expiry and region pressure")
	var street: ExpeditionState=g.regions["street"]
	for enemy in street.enemies:enemy["hp"]=0;enemy["mode"]="dead"
	g.districts.regions["street"].merge({"built":true,"condition":100.0,"secured_until":14},true)
	g.simulation_time=8280;g.cycle.night_day=12;RegionalThreats.prepare(g)
	expect(street.enemies.all(func(enemy):return enemy["hp"]==0),"secured ordinary map also suppresses its regular daily patrol replacement")
	valid(g,"ordinary secured map retains cleared patrols")
	var all_before: Dictionary={}
	expect(g.start_expedition(),"normal departure follows the forecast prepared at dusk")
	for id in g.regions:all_before[id]=g.regions[id].snapshot()
	RegionalThreats.prepare(g)
	expect(g.regions.keys().all(func(id):return g.regions[id].snapshot()==all_before[id]),"pressure director never spawns on an active expedition")
	valid(g,"active expedition with dusk migration")
	g.free();restored.free()
	g=ordinary_game();g.simulation_time=24120;g.enter_night_planning();g.choose_destination("works")
	var contents: Array=g.expedition.sites.map(func(site):return site["contents"].duplicate())
	expect(g.camp.situation.active(34,"scarcity") and g.start_expedition(),"late scarcity starts on a real map with mixed container resource keys")
	for index in range(contents.size()):
		var expected: Dictionary=contents[index]
		if expected.has("raw_food"):expected["raw_food"]=floori(expected["raw_food"]*g.camp.situation.supply_factor(34))
		expect(g.expedition.sites[index]["contents"]==expected,"scarcity reduces only actual food and preserves non-food container keys")
	valid(g,"late scarcity has no missing-key exception or fabricated food field")
	g.free()
	g=ordinary_game();g.simulation_time=1800;g.cycle.seed=43;g.enter_night_planning();g.cycle.roles.assign(["guard","bed","guard"])
	expect(g.start_expedition() and g.siege.active,"declared scheduled attack opens real base combat")
	g.paused=false;g.siege._spawn(g);g.siege.next_wave=999;g.select_survivor(0)
	g.siege.gate=0
	for enemy in g.siege.enemies:enemy["hp"]=0
	var brute: Dictionary=g.siege.enemies[0]
	brute.merge({"kind":"brute","hp":90,"x":220.0,"y":640.0,"floor":0,"entry":0,"mode":"windup","timer":1.0,"target":0,"direction":1.0,"strike_x":260.0},true)
	var fighter: Survivor=g.survivors[0];fighter.position=Vector2(260,640);fighter.route.clear();fighter.state=Survivor.TaskState.IDLE;fighter.health=100
	for item in g.expansion.gear:
		if GearCatalog.ITEMS[item["kind"]]["slot"]=="weapon":item["owner"]=fighter.person.persona if item["kind"]=="knife" else ""
	g.expansion.sync(g)
	expect(g.siege.attack(g,0),"base fighter starts the same actual knife attack")
	g.siege.tick(g,.2)
	expect(brute["hp"]==80 and brute["mode"]=="windup","base defense preserves brute armor and committed heavy attack")
	g.siege.tick(g,.85)
	expect(fighter.health<100,"committed base attack lands if the controlled fighter stays inside its range")
	var civilian: Survivor=g.survivors[1];civilian.position=Vector2(300,640);civilian.route.clear();civilian.weapon_item={}
	brute["x"]=260.0;brute["mode"]="windup";brute["timer"]=1.0;brute["direction"]=1.0
	g.siege.tick(g,.02)
	expect(not civilian.route.is_empty() and civilian.route.back().x>civilian.position.x,"unarmed noncombatant withdraws rather than standing in a heavy attack")
	civilian.route.assign([ShelterNavigation.BOTTOM_STAIR]);civilian.state=Survivor.TaskState.RETURNING;civilian.position=ShelterNavigation.TOP_STAIR.lerp(ShelterNavigation.BOTTOM_STAIR,.99)
	brute["x"]=815.0;brute["mode"]="windup";brute["timer"]=1.0
	g.siege.tick(g,.02)
	expect(civilian.route.all(func(point):return point.y in [430.0,640.0]),"a defender on stairs cannot acquire a lateral route in mid-air")
	valid(g,"shared base combat and stair-safe NPC movement")
	g.free()
	print("COMBAT PRESSURE RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
