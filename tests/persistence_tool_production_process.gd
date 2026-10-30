extends "res://tests/test_tool_production.gd"

func _run() -> void:
	var args:=OS.get_cmdline_user_args();var phase:String=args[0];var slot:String=args[1]
	var g:=fresh();var store:=SaveSystem.new();store.path=slot
	if phase=="write":
		g.production.plan(g,"craft","batch",3,0);g.production.plan(g,"toolkit","stock",2,0)
		for i in range(200):
			advance(g,.1)
			if g.survivors[0].state==Survivor.TaskState.WORKING:break
		expect(g.survivors[0].held_cost.get("materials",0)==2,"writer holds actual inputs in a partly completed batch")
		advance(g,.3);valid(g,"writer in-progress production")
		expect(store.write_state(g)["ok"],"writer atomically saves active work, target and tool condition")
	else:
		var result:=store.read_state()
		expect(result["ok"],"new process reads the checksummed production save")
		if result["ok"]:expect(SaveSystem.apply_state(g,result["data"]).is_empty(),"new process restores the actual pending and active plans")
		if phase=="finish":
			expect(g.survivors[0].held_cost.get("materials",0)==2,"read does not repay or refund held production inputs")
			advance(g,100)
			expect(g.inventory.amount("tools")==3 and g.inventory.amount("materials")==4,"resumed jobs preserve the entire material/component balance")
			expect(g.production.stock(g,"toolkit")==2 and g.production.orders.size()==1 and g.production.orders[0]["mode"]=="stock","finite batch finishes while fulfilled spare-stock order remains enabled")
			valid(g,"resumed orders complete in a separate process")
			expect(store.write_state(g)["ok"],"finished production can be saved again")
		else:
			var stock:Dictionary=g.inventory.snapshot();var gear:Array=g.expansion.gear.duplicate(true)
			advance(g,30)
			expect(g.inventory.snapshot()==stock and g.expansion.gear==gear,"third process cannot repeat completed output or spend against a fulfilled target")
			valid(g,"third process verifies stable replenishment")
	g.free();print("TOOL PRODUCTION PERSISTENCE %s: %d checks, %d failures"%[phase,checks,failures]);quit(1 if failures else 0)
